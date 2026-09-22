import CoreML
import WhisperKit
import XCTest
@testable import Inputalk

final class ModelLifecycleTests: XCTestCase {
    func testInstalledModelRequiresAllCompiledFiles() throws {
        let root = try makeTempModelsDirectory()
        XCTAssertTrue(ModelLifecycle.shouldDownload(variant: "small", modelsDirectory: root))
        XCTAssertFalse(ModelLifecycle.isInstalled(variant: "small", modelsDirectory: root))

        let folder = ModelLifecycle.modelFolder(for: "small", modelsDirectory: root)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try writeCompiledStub(named: "MelSpectrogram", in: folder)
        try writeCompiledStub(named: "AudioEncoder", in: folder)
        XCTAssertFalse(ModelLifecycle.isInstalled(variant: "small", modelsDirectory: root))

        try writeCompiledStub(named: "TextDecoder", in: folder)
        XCTAssertTrue(ModelLifecycle.isInstalled(variant: "small", modelsDirectory: root))
        XCTAssertFalse(ModelLifecycle.shouldDownload(variant: "small", modelsDirectory: root))
        XCTAssertTrue(ModelLifecycle.shouldDownload(variant: "base", modelsDirectory: root))
    }

    func testEmptyCompiledBundleIsNotInstalled() throws {
        let root = try makeTempModelsDirectory()
        let folder = ModelLifecycle.modelFolder(for: "small", modelsDirectory: root)
        for name in ModelLifecycle.requiredModelNames {
            try FileManager.default.createDirectory(
                at: folder.appendingPathComponent("\(name).mlmodelc"),
                withIntermediateDirectories: true
            )
        }
        XCTAssertFalse(ModelLifecycle.isInstalled(variant: "small", modelsDirectory: root))
        XCTAssertTrue(ModelLifecycle.shouldDownload(variant: "small", modelsDirectory: root))
    }

    func testRemoveInstallDeletesModelAndHubCache() throws {
        let root = try makeTempModelsDirectory()
        let folder = ModelLifecycle.modelFolder(for: "small", modelsDirectory: root)
        let cache = ModelLifecycle.hubCacheFolder(for: "small", modelsDirectory: root)
        try writeCompiledStub(named: "MelSpectrogram", in: folder)
        try writeCompiledStub(named: "AudioEncoder", in: folder)
        try writeCompiledStub(named: "TextDecoder", in: folder)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data("meta".utf8).write(to: cache.appendingPathComponent("config.json.metadata"))

        XCTAssertTrue(ModelLifecycle.isInstalled(variant: "small", modelsDirectory: root))
        ModelLifecycle.removeInstall(variant: "small", modelsDirectory: root)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: cache.path))
        XCTAssertTrue(ModelLifecycle.shouldDownload(variant: "small", modelsDirectory: root))
    }

    func testLatestRequestWins() {
        XCTAssertTrue(ModelLifecycle.shouldPublish(requestID: 2, latestRequestID: 2))
        XCTAssertFalse(ModelLifecycle.shouldPublish(requestID: 1, latestRequestID: 2))
        XCTAssertTrue(ModelLifecycle.shouldReuseLoadedModel(selected: "base", loaded: "base"))
        XCTAssertFalse(ModelLifecycle.shouldReuseLoadedModel(selected: "small", loaded: "base"))
        XCTAssertFalse(ModelLifecycle.shouldReuseLoadedModel(selected: "base", loaded: nil))
    }

    func testRecordingUsesLoadedModelWhileAnotherPrepares() {
        XCTAssertNil(
            ModelLifecycle.recordingBlockMessage(selected: "small", loaded: "base")
        )
        XCTAssertEqual(
            ModelLifecycle.recordingPrepareNotice(
                selected: "small",
                loaded: "base",
                isPreparing: true
            ),
            "Preparing Small - using Base"
        )
        XCTAssertNil(
            ModelLifecycle.recordingPrepareNotice(
                selected: "small",
                loaded: "base",
                isPreparing: false
            )
        )
    }

    func testRecordingBlocksWhenNoModelIsLoaded() {
        XCTAssertEqual(
            ModelLifecycle.recordingBlockMessage(selected: "small", loaded: nil),
            "Small isn't ready yet."
        )
        XCTAssertNil(
            ModelLifecycle.recordingPrepareNotice(
                selected: "small",
                loaded: nil,
                isPreparing: true
            )
        )
    }

    func testBrokenInstallErrorClassification() {
        XCTAssertTrue(ModelLifecycle.isBrokenInstallError(WhisperError.modelsUnavailable()))
        XCTAssertTrue(ModelLifecycle.isBrokenInstallError(NSError(domain: MLModelErrorDomain, code: 1)))
        XCTAssertFalse(ModelLifecycle.isBrokenInstallError(URLError(.notConnectedToInternet)))
        XCTAssertFalse(ModelLifecycle.isBrokenInstallError(WhisperError.tokenizerUnavailable()))
        XCTAssertFalse(ModelLifecycle.isBrokenInstallError(CancellationError()))
    }

    func testPercentTextUsesDownloadProgress() {
        XCTAssertEqual(ModelLifecycle.percentText(from: 0), "0%")
        XCTAssertEqual(ModelLifecycle.percentText(from: 0.33), "33%")
        XCTAssertEqual(ModelLifecycle.percentText(from: 1), "100%")
    }

    private func writeCompiledStub(named name: String, in folder: URL) throws {
        let bundle = folder.appendingPathComponent("\(name).mlmodelc")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        try Data("mil".utf8).write(to: bundle.appendingPathComponent("model.mil"))
        try Data("bin".utf8).write(to: bundle.appendingPathComponent("coremldata.bin"))
    }

    private func makeTempModelsDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("inputalk-model-lifecycle-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }
}
