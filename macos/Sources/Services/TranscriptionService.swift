@preconcurrency import WhisperKit
import Foundation

enum ModelState: Equatable {
    case unloaded
    case downloading(progress: Double)
    case loading
    case ready
    case error(String)
}

@MainActor
class TranscriptionService: ObservableObject {
    @Published var modelState: ModelState = .unloaded
    @Published var selectedModel: String {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "selectedModel")
        }
    }

    let availableModels = ["tiny", "base", "small", "medium"]

    private var whisperKit: WhisperKit?

    /// All model data lives here.
    /// App cleaners remove ~/Library/Application Support/<bundleID>/ on uninstall.
    static let modelsDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.inputalk.app"
        return appSupport.appendingPathComponent(bundleID).appendingPathComponent("Models")
    }()

    /// Total size of downloaded models on disk.
    var modelsDiskUsage: String {
        let url = Self.modelsDirectory
        guard FileManager.default.fileExists(atPath: url.path) else { return "0 MB" }
        let bytes = (try? FileManager.default.allocatedSizeOfDirectory(at: url)) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    init() {
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "base"
    }

    func loadModel() async {
        guard modelState != .loading else { return }
        if case .downloading = modelState { return }

        modelState = .downloading(progress: 0)
        whisperKit = nil

        // Ensure our models directory exists
        try? FileManager.default.createDirectory(
            at: Self.modelsDirectory, withIntermediateDirectories: true)

        do {
            // Step 1: Download model into our app-specific directory
            let progressCallback: @Sendable (Progress) -> Void = { [weak self] progress in
                let fraction = progress.fractionCompleted
                Task { @MainActor [weak self] in
                    self?.modelState = .downloading(progress: fraction)
                }
            }
            let modelFolder = try await WhisperKit.download(
                variant: selectedModel,
                downloadBase: Self.modelsDirectory,
                progressCallback: progressCallback
            )

            // Step 2: Load from downloaded folder
            modelState = .loading
            let kit = try await WhisperKit(
                modelFolder: modelFolder.path,
                verbose: false,
                prewarm: true,
                load: true,
                download: false
            )
            whisperKit = kit
            modelState = .ready
        } catch {
            modelState = .error(error.localizedDescription)
        }
    }

    /// Delete all downloaded models from disk.
    func deleteAllModels() {
        whisperKit = nil
        modelState = .unloaded
        try? FileManager.default.removeItem(at: Self.modelsDirectory)
    }

    /// Wait until the model is ready. If nothing is loading yet, kicks off a load.
    func waitUntilReady() async throws {
        if modelState == .ready { return }

        // If idle or errored, start a fresh load
        let needsLoad: Bool
        switch modelState {
        case .unloaded, .error: needsLoad = true
        default: needsLoad = false
        }
        if needsLoad {
            Task { await loadModel() }
            // Give loadModel a moment to set its state
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        // Poll until ready or terminal error
        while true {
            if modelState == .ready { return }
            if case .error(let msg) = modelState {
                throw TranscriptionError.modelLoadFailed(msg)
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    func transcribe(audioSamples: [Float]) async throws -> String {
        // Wait for model if it's still downloading/loading
        try await waitUntilReady()

        guard let kit = whisperKit else {
            throw TranscriptionError.modelNotReady
        }

        let options = DecodingOptions(
            task: .transcribe,
            temperature: 0.0,
            usePrefillPrompt: true,
            usePrefillCache: true,
            wordTimestamps: false,
            suppressBlank: true
        )

        let results = try await kit.transcribe(
            audioArray: audioSamples,
            decodeOptions: options
        )

        let text = results.map { $0.text }.joined(separator: " ")
        return postProcess(text)
    }

    // MARK: - Post-Processing

    private func postProcess(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard UserDefaults.standard.object(forKey: "removeFillerWords") == nil
            || UserDefaults.standard.bool(forKey: "removeFillerWords")
        else {
            return result
        }

        let fillerPatterns = [
            "\\b[Uu]m\\b,?\\s?",
            "\\b[Uu]h\\b,?\\s?",
        ]

        for pattern in fillerPatterns {
            result =
                result.replacingOccurrences(
                    of: pattern, with: "", options: .regularExpression)
        }

        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - FileManager Directory Size

extension FileManager {
    func allocatedSizeOfDirectory(at url: URL) throws -> UInt64 {
        var totalSize: UInt64 = 0
        let enumerator = self.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [], errorHandler: nil)

        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: [
                .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
            ])
            totalSize += UInt64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return totalSize
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotReady
    case modelLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotReady: return "Transcription model is not ready"
        case .modelLoadFailed(let msg): return "Model failed to load: \(msg)"
        }
    }
}
