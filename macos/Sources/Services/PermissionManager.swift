import AppKit
import AVFoundation

@MainActor
class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published var hasAccessibility: Bool = false
    @Published var hasMicrophone: Bool = false

    private init() {
        refresh()
    }

    func refresh() {
        hasAccessibility = AXIsProcessTrusted()
        hasMicrophone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    nonisolated func requestAccessibility() {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        // User must grant in System Settings; we re-check on app activation
    }

    func requestMicrophone() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        hasMicrophone = granted
        return granted
    }
}
