@preconcurrency import WhisperKit
import Foundation

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
    private var loadedModel: String?
    private var loadGeneration = 0
    private var loadTask: Task<Void, Never>?
    private var prewarmedVariants: Set<String> = []

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

    var recordingBlockMessage: String? {
        ModelLifecycle.recordingBlockMessage(selected: selectedModel, loaded: loadedModel)
    }

    var recordingPrepareNotice: String? {
        ModelLifecycle.recordingPrepareNotice(
            selected: selectedModel,
            loaded: loadedModel,
            isPreparing: modelState.isPreparing
        )
    }

    init() {
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "base"
    }

    func loadModel() async {
        loadGeneration += 1
        let generation = loadGeneration
        let variant = selectedModel
        loadTask?.cancel()
        let task = Task { await runLoad(variant: variant, generation: generation) }
        loadTask = task
        await task.value
    }

    /// Delete all downloaded models from disk.
    func deleteAllModels() {
        loadGeneration += 1
        loadTask?.cancel()
        loadTask = nil
        whisperKit = nil
        loadedModel = nil
        prewarmedVariants = []
        modelState = .unloaded
        try? FileManager.default.removeItem(at: Self.modelsDirectory)
    }

    private func isLatest(_ generation: Int) -> Bool {
        ModelLifecycle.shouldPublish(requestID: generation, latestRequestID: loadGeneration)
    }

    private func checkCurrent(_ generation: Int) throws {
        try Task.checkCancellation()
        guard isLatest(generation) else { throw CancellationError() }
    }

    private func discardInstall(_ variant: String) {
        ModelLifecycle.removeInstall(variant: variant, modelsDirectory: Self.modelsDirectory)
        prewarmedVariants.remove(variant)
    }

    private func isCancelledError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let urlError = error as? URLError
        return urlError?.code == .cancelled
    }

    private func runLoad(variant: String, generation: Int) async {
        do {
            try checkCurrent(generation)

            if ModelLifecycle.shouldReuseLoadedModel(selected: variant, loaded: loadedModel),
                whisperKit != nil
            {
                modelState = .ready
                return
            }

            modelState = .checking
            try? FileManager.default.createDirectory(
                at: Self.modelsDirectory, withIntermediateDirectories: true)

            let checkStart = CFAbsoluteTimeGetCurrent()
            let needsDownload = ModelLifecycle.shouldDownload(
                variant: variant,
                modelsDirectory: Self.modelsDirectory
            )
            let checkMs = (CFAbsoluteTimeGetCurrent() - checkStart) * 1000
            var modelFolder = ModelLifecycle.modelFolder(
                for: variant,
                modelsDirectory: Self.modelsDirectory
            )

            if !needsDownload {
                do {
                    let prepared = try await prepareKit(
                        modelFolder: modelFolder,
                        variant: variant,
                        generation: generation
                    )
                    try checkCurrent(generation)
                    whisperKit = prepared.kit
                    loadedModel = variant
                    modelState = .ready
                    logModelLoad(
                        variant: variant,
                        checkMs: checkMs,
                        downloadMs: nil,
                        prewarmS: prepared.prewarmS,
                        loadS: prepared.loadS
                    )
                    return
                } catch {
                    try checkCurrent(generation)
                    guard ModelLifecycle.isBrokenInstallError(error) else { throw error }
                    // Local files looked complete but Core ML rejected them.
                    // Remove the broken bundle before downloading a replacement.
                    discardInstall(variant)
                }
            }

            try checkCurrent(generation)
            modelState = .downloading(progress: 0)
            let downloadStart = CFAbsoluteTimeGetCurrent()
            let progressCallback: @Sendable (Progress) -> Void = { [weak self] progress in
                let fraction = progress.fractionCompleted
                Task { @MainActor [weak self] in
                    guard let self, self.isLatest(generation) else { return }
                    self.modelState = .downloading(progress: fraction)
                }
            }
            modelFolder = try await WhisperKit.download(
                variant: variant,
                downloadBase: Self.modelsDirectory,
                progressCallback: progressCallback
            )
            let downloadMs = (CFAbsoluteTimeGetCurrent() - downloadStart) * 1000

            try checkCurrent(generation)

            let prepared = try await prepareKit(
                modelFolder: modelFolder,
                variant: variant,
                generation: generation
            )

            try checkCurrent(generation)

            whisperKit = prepared.kit
            loadedModel = variant
            modelState = .ready
            logModelLoad(
                variant: variant,
                checkMs: checkMs,
                downloadMs: downloadMs,
                prewarmS: prepared.prewarmS,
                loadS: prepared.loadS
            )
        } catch {
            if isCancelledError(error) || Task.isCancelled || !isLatest(generation) { return }
            if ModelLifecycle.isBrokenInstallError(error) {
                discardInstall(variant)
                modelState = .error(
                    "Couldn't load \(ModelLifecycle.displayName(for: variant)). Press Retry to download it again."
                )
            } else {
                modelState = .error(error.localizedDescription)
            }
        }
    }

    private func prepareKit(
        modelFolder: URL,
        variant: String,
        generation: Int
    ) async throws -> (kit: WhisperKit, prewarmS: Double?, loadS: Double) {
        let kit = try await WhisperKit(
            modelFolder: modelFolder.path,
            verbose: false,
            prewarm: false,
            load: false,
            download: false
        )

        try checkCurrent(generation)

        // Core ML device specialization can take minutes on the first Small
        // or Medium load. WhisperKit prewarm does that pass, unloads, then
        // loadModels reads the cache. Skip prewarm for variants already
        // specialized this process so switching back is not 2x.
        // ponytail: Core ML specialization still runs until it finishes once
        // started. WhisperKit does not expose progress for this work.
        var prewarmS: Double?
        if !prewarmedVariants.contains(variant) {
            modelState = .optimizing
            let prewarmStart = CFAbsoluteTimeGetCurrent()
            try await kit.prewarmModels()
            try checkCurrent(generation)
            prewarmS = CFAbsoluteTimeGetCurrent() - prewarmStart
            prewarmedVariants.insert(variant)
        }

        try checkCurrent(generation)

        modelState = .loading
        let loadStart = CFAbsoluteTimeGetCurrent()
        try await kit.loadModels()
        try checkCurrent(generation)
        let loadS = CFAbsoluteTimeGetCurrent() - loadStart
        return (kit, prewarmS, loadS)
    }

    private func logModelLoad(
        variant: String,
        checkMs: Double,
        downloadMs: Double?,
        prewarmS: Double?,
        loadS: Double
    ) {
        let download = downloadMs.map { String(format: "%.0fms", $0) } ?? "skipped"
        let prewarm = prewarmS.map { String(format: "%.2fs", $0) } ?? "skipped"
        print(
            "[ModelLoad] \(variant) check=\(String(format: "%.0f", checkMs))ms download=\(download) prewarm=\(prewarm) load=\(String(format: "%.2f", loadS))s"
        )
    }

    /// Wait until a usable model is in memory. If one is already loaded, returns
    /// immediately even when a different variant is still preparing.
    func waitUntilReady() async throws {
        if whisperKit != nil { return }

        switch modelState {
        case .unloaded, .error:
            await loadModel()
        default:
            break
        }

        while whisperKit == nil {
            if case .error(let msg) = modelState {
                throw TranscriptionError.modelLoadFailed(msg)
            }
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    func transcribe(audioSamples: [Float]) async throws -> String {
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
        let removeFillerWords = UserDefaults.standard.object(forKey: "removeFillerWords") == nil
            || UserDefaults.standard.bool(forKey: "removeFillerWords")
        return TranscriptionPostProcessor.process(
            text,
            removeFillerWords: removeFillerWords
        )
    }
}

enum TranscriptionPostProcessor {
    static let blankAudioMarker = "[BLANK_AUDIO]"

    /// True when Whisper produced only status markers or sound-event tags
    /// such as `[BLANK_AUDIO]`, `[INAUDIBLE]`, `(claps)`, or `(cars honking)`.
    static func isNonSpeechOnly(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let withoutTokens = trimmed.replacingOccurrences(
            of: #"[\(\[][^\[\]()]+[\)\]]"#,
            with: " ",
            options: .regularExpression
        )
        return withoutTokens
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .isEmpty
    }

    static func process(_ text: String, removeFillerWords: Bool) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Whisper status markers at either end of the text, e.g. "[BLANK_AUDIO] Hello. [INAUDIBLE]".
        let nonSpeechToken = #"(?:\[[A-Za-z][A-Za-z_\s-]*\]|\((?:blank[\s_-]*audio|silence)\))"#
        let edgeNonSpeechPattern = "^(?:\\s*\(nonSpeechToken))+\\s*|(?:\\s*\(nonSpeechToken))+\\s*$"
        let withoutTrailingNonSpeech = result.replacingOccurrences(
            of: edgeNonSpeechPattern,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        if !withoutTrailingNonSpeech.isEmpty {
            result = withoutTrailingNonSpeech
        }

        if removeFillerWords {
            let fillerPatterns = [
                "\\b[Uu]m\\b,?\\s?",
                "\\b[Uu]h\\b,?\\s?",
            ]

            for pattern in fillerPatterns {
                result = result.replacingOccurrences(
                    of: pattern,
                    with: "",
                    options: .regularExpression
                )
            }

            while result.contains("  ") {
                result = result.replacingOccurrences(of: "  ", with: " ")
            }

            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result.isEmpty ? blankAudioMarker : result
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
