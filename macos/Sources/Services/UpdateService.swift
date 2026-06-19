import Foundation
import Sparkle

@MainActor
class UpdateService: ObservableObject {
    @Published private(set) var isConfigured: Bool
    @Published var automaticallyChecksForUpdates: Bool {
        didSet {
            guard oldValue != automaticallyChecksForUpdates else { return }
            updaterController?.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    private var updaterController: SPUStandardUpdaterController?

    init() {
        let configured = Self.hasValidSparkleConfiguration()
        self.isConfigured = configured
        self.automaticallyChecksForUpdates = true

        guard configured else { return }

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController = controller
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    private static func hasValidSparkleConfiguration() -> Bool {
        guard
            let feedURLString = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            URL(string: feedURLString) != nil,
            let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        else {
            return false
        }

        return !publicKey.isEmpty && publicKey != "REPLACE_WITH_SPARKLE_PUBLIC_ED_KEY"
    }
}
