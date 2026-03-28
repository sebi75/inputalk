import AppKit
import Combine
import SwiftUI

// MARK: - App State

enum AppState {
    case idle
    case recording
    case processing
}

// MARK: - App Delegate (Menu Bar App)

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let audioRecorder = AudioRecorder()
    let transcriptionService = TranscriptionService()
    let hotkeyManager = HotkeyManager()
    let permissions = PermissionManager.shared

    var settingsWindow: NSWindow?
    var onboardingWindow: NSWindow?
    private var appState: AppState = .idle

    /// Prevent App Nap from making the hotkey unresponsive
    private var activityToken: NSObjectProtocol?

    // MARK: - Floating Indicator

    private var indicatorPanel: NSPanel?
    private var indicatorHostingView: NSHostingView<FloatingIndicatorView>?
    private var audioLevelCancellable: AnyCancellable?
    private var indicatorDismissTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHotkey()

        // Re-check permissions when app becomes active (user returns from System Settings)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.permissions.refresh()
                self?.setupHotkey()
            }
        }

        // Prevent App Nap
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Global hotkey monitoring"
        )

        // Check onboarding
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            showOnboarding()
        }

        // Load model in background (recording is allowed even before it's ready)
        Task {
            await transcriptionService.loadModel()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stop()
        if audioRecorder.isRecording {
            _ = audioRecorder.stopRecording()
        }
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
        }
        dismissIndicator()
    }

    // MARK: - Hotkey Setup

    private func setupHotkey() {
        guard permissions.hasAccessibility else { return }

        hotkeyManager.onRecordStart = { [weak self] in
            self?.startRecording()
        }
        hotkeyManager.onRecordStop = { [weak self] in
            self?.stopRecordingAndTranscribe()
        }
        hotkeyManager.start()
    }

    // MARK: - Recording Flow

    private func startRecording() {
        do {
            try audioRecorder.startRecording()
            appState = .recording
            updateMenuBarIcon(state: .recording)
            showIndicator(state: .recording(level: 0))

            // Subscribe to audio level updates
            audioLevelCancellable = audioRecorder.$audioLevel
                .receive(on: RunLoop.main)
                .sink { [weak self] level in
                    self?.updateIndicator(state: .recording(level: level))
                }
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    private func stopRecordingAndTranscribe() {
        guard audioRecorder.isRecording else { return }

        audioLevelCancellable?.cancel()
        audioLevelCancellable = nil

        let samples = audioRecorder.stopRecording()
        appState = .processing
        updateMenuBarIcon(state: .processing)

        guard samples.count >= AudioRecorder.minimumSamples else {
            appState = .idle
            updateMenuBarIcon(state: .idle)
            dismissIndicator()
            return
        }

        updateIndicator(state: .processing)

        Task {
            do {
                // transcribe() waits for the model if it's still loading —
                // the user just sees "Transcribing" a bit longer on first use
                let text = try await transcriptionService.transcribe(audioSamples: samples)
                if !text.isEmpty {
                    TextInserter.insertText(text)
                    updateIndicator(state: .done(text: text))
                    indicatorDismissTask = Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        dismissIndicator()
                    }
                } else {
                    dismissIndicator()
                }
            } catch {
                print("Transcription failed: \(error)")
                dismissIndicator()
            }

            appState = .idle
            updateMenuBarIcon(state: .idle)
        }
    }

    // MARK: - Floating Indicator

    private func showIndicator(state: IndicatorState) {
        indicatorDismissTask?.cancel()
        indicatorDismissTask = nil

        if indicatorPanel == nil {
            let panel = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.ignoresMouseEvents = true

            let hostingView = NSHostingView(rootView: FloatingIndicatorView(state: state))
            hostingView.sizingOptions = .intrinsicContentSize
            panel.contentView = hostingView

            indicatorPanel = panel
            indicatorHostingView = hostingView
        } else {
            indicatorHostingView?.rootView = FloatingIndicatorView(state: state)
        }

        positionIndicatorAtScreenBottom()
        indicatorPanel?.orderFrontRegardless()
    }

    private func updateIndicator(state: IndicatorState) {
        indicatorHostingView?.rootView = FloatingIndicatorView(state: state)
        // Resize in case content changed
        positionIndicatorAtScreenBottom()
    }

    private func dismissIndicator() {
        indicatorDismissTask?.cancel()
        indicatorDismissTask = nil
        audioLevelCancellable?.cancel()
        audioLevelCancellable = nil
        indicatorPanel?.orderOut(nil)
    }

    private func positionIndicatorAtScreenBottom() {
        guard let panel = indicatorPanel,
            let hostingView = indicatorHostingView,
            let screen = NSScreen.main
        else { return }

        let contentSize = hostingView.fittingSize
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - contentSize.width / 2
        let y = screenFrame.minY + 40  // 40pt above the bottom of the visible area

        panel.setFrame(
            NSRect(x: x, y: y, width: contentSize.width, height: contentSize.height),
            display: true
        )
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = menuBarImage(for: .idle)
            button.action = #selector(statusBarButtonClicked)
        }
    }

    func updateMenuBarIcon(state: AppState) {
        guard let button = statusItem.button else { return }
        button.image = menuBarImage(for: state)
        button.contentTintColor = state == .recording ? .systemRed : nil
    }

    private func menuBarImage(for state: AppState) -> NSImage? {
        switch state {
        case .idle:
            // Custom waveform icon from SPM resource bundle
            if let url = Bundle.module.url(forResource: "MenuBarIcon", withExtension: "png"),
                let image = NSImage(contentsOf: url)
            {
                image.isTemplate = true
                image.size = NSSize(width: 18, height: 18)
                return image
            }
            // Fallback to SF Symbol
            let image = NSImage(
                systemSymbolName: "waveform", accessibilityDescription: "Inputalk")
            image?.isTemplate = true
            return image
        case .recording:
            let image = NSImage(
                systemSymbolName: "waveform", accessibilityDescription: "Recording")
            image?.isTemplate = false
            return image
        case .processing:
            let image = NSImage(
                systemSymbolName: "ellipsis.circle",
                accessibilityDescription: "Transcribing")
            image?.isTemplate = true
            return image
        }
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        showContextMenu()
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "Settings...", action: #selector(showSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit Inputalk", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Windows

    @objc private func showSettingsAction() {
        showSettings()
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 560),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Settings"
            window.titlebarAppearsTransparent = true
            window.center()
            window.contentView = NSHostingView(
                rootView: SettingsView()
                    .environmentObject(transcriptionService)
                    .environmentObject(permissions)
            )
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }

        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Welcome to Inputalk"
            window.center()
            window.contentView = NSHostingView(
                rootView: OnboardingView(onComplete: { [weak self] in
                    self?.closeOnboarding()
                })
                .environmentObject(self.transcriptionService)
                .environmentObject(self.permissions)
            )
            window.isReleasedWhenClosed = false
            onboardingWindow = window
        }

        NSApp.setActivationPolicy(.regular)
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        onboardingWindow?.orderOut(nil)
        onboardingWindow?.close()
        onboardingWindow = nil
        NSApp.setActivationPolicy(.accessory)
        setupHotkey()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
