import AVFoundation
import Foundation

/// Thread-safe audio sample collector used by the real-time audio tap.
/// The tap callback writes samples from the audio thread; the main thread reads on stop.
private final class AudioSampleCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: ContiguousArray<Float> = []
    private(set) var latestLevel: Float = 0

    func append(_ newSamples: [Float], level: Float) {
        lock.lock()
        samples.append(contentsOf: newSamples)
        latestLevel = level
        lock.unlock()
    }

    func drain() -> [Float] {
        lock.lock()
        let result = Array(samples)
        samples.removeAll(keepingCapacity: true)
        latestLevel = 0
        lock.unlock()
        return result
    }

    func reset() {
        lock.lock()
        samples.removeAll(keepingCapacity: true)
        latestLevel = 0
        lock.unlock()
    }
}

@MainActor
class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0

    private var audioEngine: AVAudioEngine?
    private let collector = AudioSampleCollector()
    private let sampleRate: Double = 16000  // WhisperKit expects 16kHz mono
    private var levelPollTimer: Timer?

    func startRecording() throws {
        guard !isRecording else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: false
            )
        else {
            throw AudioRecorderError.formatError
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioRecorderError.converterError
        }

        collector.reset()

        Self.installAudioTap(
            on: inputNode,
            inputFormat: inputFormat,
            targetFormat: targetFormat,
            converter: converter,
            sampleRate: sampleRate,
            collector: collector
        )

        try engine.start()
        audioEngine = engine
        isRecording = true

        // Poll the collector for audio level updates on the main thread
        levelPollTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) {
            [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.audioLevel = self.collector.latestLevel
            }
        }
    }

    func stopRecording() -> [Float] {
        guard isRecording else { return [] }

        levelPollTimer?.invalidate()
        levelPollTimer = nil

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false
        audioLevel = 0

        return collector.drain()
    }

    /// Minimum number of samples for a valid recording (0.5s at 16kHz)
    static let minimumSamples = 8000

    /// Installs the audio tap in a nonisolated context so the closure
    /// does not inherit @MainActor isolation (which would crash on the audio thread).
    nonisolated private static func installAudioTap(
        on inputNode: AVAudioInputNode,
        inputFormat: AVAudioFormat,
        targetFormat: AVAudioFormat,
        converter: AVAudioConverter,
        sampleRate: Double,
        collector: AudioSampleCollector
    ) {
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) {
            buffer, _ in

            let frameCount = AVAudioFrameCount(
                Double(buffer.frameLength) * sampleRate / inputFormat.sampleRate
            )
            guard frameCount > 0 else { return }

            guard
                let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: targetFormat, frameCapacity: frameCount)
            else { return }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) {
                _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            guard status != .error, error == nil,
                let channelData = convertedBuffer.floatChannelData
            else { return }

            let samples = Array(
                UnsafeBufferPointer(
                    start: channelData[0],
                    count: Int(convertedBuffer.frameLength)
                ))

            let rms = samples.reduce(Float(0)) { $0 + $1 * $1 }
            let level = sqrt(rms / max(Float(samples.count), 1))

            collector.append(samples, level: min(level * 5, 1.0))
        }
    }
}

enum AudioRecorderError: LocalizedError {
    case formatError
    case converterError

    var errorDescription: String? {
        switch self {
        case .formatError: return "Failed to create audio format"
        case .converterError: return "Failed to create audio converter"
        }
    }
}
