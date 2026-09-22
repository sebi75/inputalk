import CoreML
import Foundation
@preconcurrency import WhisperKit

enum ModelState: Equatable {
    case unloaded
    case checking
    case downloading(progress: Double)
    case optimizing
    case loading
    case ready
    case error(String)

    var isPreparing: Bool {
        switch self {
        case .checking, .downloading, .optimizing, .loading: true
        case .unloaded, .ready, .error: false
        }
    }

    var showsSpinner: Bool {
        switch self {
        case .checking, .downloading, .optimizing, .loading: true
        default: false
        }
    }
}

enum ModelLifecycle {
    static let hubRepoPath = "models/argmaxinc/whisperkit-coreml"
    static let requiredModelNames = ["MelSpectrogram", "AudioEncoder", "TextDecoder"]

    static func displayName(for variant: String) -> String {
        guard let first = variant.first else { return variant }
        return first.uppercased() + variant.dropFirst()
    }

    static func folderName(for variant: String) -> String {
        "openai_whisper-\(variant)"
    }

    static func modelFolder(for variant: String, modelsDirectory: URL) -> URL {
        modelsDirectory
            .appendingPathComponent(hubRepoPath)
            .appendingPathComponent(folderName(for: variant))
    }

    static func hubCacheFolder(for variant: String, modelsDirectory: URL) -> URL {
        modelsDirectory
            .appendingPathComponent(hubRepoPath)
            .appendingPathComponent(".cache/huggingface/download")
            .appendingPathComponent(folderName(for: variant))
    }

    static func isInstalled(
        variant: String,
        modelsDirectory: URL,
        fileExists: (URL) -> Bool = { defaultFileExists($0) }
    ) -> Bool {
        let folder = modelFolder(for: variant, modelsDirectory: modelsDirectory)
        return requiredModelNames.allSatisfy { name in
            compiledModelIsComplete(named: name, in: folder, fileExists: fileExists)
        }
    }

    static func compiledModelIsComplete(
        named name: String,
        in folder: URL,
        fileExists: (URL) -> Bool = { defaultFileExists($0) }
    ) -> Bool {
        let bundle = folder.appendingPathComponent("\(name).mlmodelc")
        return fileExists(bundle.appendingPathComponent("model.mil"))
            && fileExists(bundle.appendingPathComponent("coremldata.bin"))
    }

    static func shouldDownload(
        variant: String,
        modelsDirectory: URL,
        fileExists: (URL) -> Bool = { defaultFileExists($0) }
    ) -> Bool {
        !isInstalled(variant: variant, modelsDirectory: modelsDirectory, fileExists: fileExists)
    }

    static func removeInstall(
        variant: String,
        modelsDirectory: URL,
        removeItem: (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }
    ) {
        for url in [
            modelFolder(for: variant, modelsDirectory: modelsDirectory),
            hubCacheFolder(for: variant, modelsDirectory: modelsDirectory),
        ] {
            try? removeItem(url)
        }
    }

    static func isBrokenInstallError(_ error: Error) -> Bool {
        if case WhisperError.modelsUnavailable = error { return true }
        return (error as NSError).domain == MLModelErrorDomain
    }

    static func defaultFileExists(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
            values.isRegularFile == true
        else { return false }
        return (values.fileSize ?? 0) > 0
    }

    static func shouldReuseLoadedModel(selected: String, loaded: String?) -> Bool {
        loaded == selected
    }

    static func shouldPublish(requestID: Int, latestRequestID: Int) -> Bool {
        requestID == latestRequestID
    }

    static func recordingBlockMessage(selected: String, loaded: String?) -> String? {
        guard loaded == nil else { return nil }
        return "\(displayName(for: selected)) isn't ready yet."
    }

    static func recordingPrepareNotice(
        selected: String,
        loaded: String?,
        isPreparing: Bool
    ) -> String? {
        guard isPreparing, let loaded, loaded != selected else { return nil }
        return "Preparing \(displayName(for: selected)) - using \(displayName(for: loaded))"
    }

    /// Formats the download's completed fraction for display.
    static func percentText(from progress: Double) -> String {
        let clamped = min(max(progress, 0), 1)
        return "\(Int((clamped * 100).rounded()))%"
    }
}
