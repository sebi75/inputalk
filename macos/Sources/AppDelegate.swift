import AppKit
import CoreAudio
import QuartzCore
import SwiftUI

enum Defaults {
    static let showInDock = "showInDock"
    static let pasteHistoryFromMenuBar = "pasteHistoryFromMenuBar"
    static let settingsPage = "settingsPage"
}

enum AppIdentity {
    static let developmentBundleID = "com.inputalk.app.dev"

    static var isDevelopmentBuild: Bool {
        Bundle.main.bundleIdentifier == developmentBundleID
    }
}

enum SettingsPage: String {
    case dictation
    case history
    case general
}

// MARK: - App State

enum AppState {
    case idle
    case recording
    case processing
}

// MARK: - App Delegate (Menu Bar App)

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    let audioRecorder = AudioRecorder()
    let audioInputDevices = AudioInputDeviceManager()
    let transcriptionService = TranscriptionService()
    let transcriptionHistory = TranscriptionHistoryStore()
    let shortcutPreferences = ShortcutPreferences()
    lazy var hotkeyManager = HotkeyManager(preferences: shortcutPreferences)
    let permissions = PermissionManager.shared
    let updateService = UpdateService()

    var settingsWindow: NSWindow?
    var onboardingWindow: NSWindow?
    private var appState: AppState = .idle

    /// Serializes recorder start/stop so a stop requested while a start is
    /// still in flight runs after it instead of being dropped.
    private var recordingFlow: Task<Void, Never>?
    /// Bumped on every start/stop; stale transcription completions compare
    /// against it before touching the indicator or app state.
    private var recordingGeneration = 0

    /// Prevent App Nap from making the hotkey unresponsive
    private var activityToken: NSObjectProtocol?

    // MARK: - Floating Indicator

    private var indicatorPanel: NSPanel?
    private var indicatorHostingView: NSHostingView<FloatingIndicatorView>?
    private let indicatorModel = FloatingIndicatorModel()
    private var spectrumSmoother = SpectrumLevelSmoother()
    private var indicatorDismissTask: Task<Void, Never>?
    private var indicatorDisplayLink: CADisplayLink?
    private var lastIndicatorFrameTimestamp: CFTimeInterval?
    private var indicatorNeedsInitialFrame = false
    private var indicatorSizeFrom: CGSize?
    private var indicatorSizeTo: CGSize = .zero
    private var indicatorSizeAnimStart: CFTimeInterval?
    private var didApplyDevelopmentDockBadge = false
    private var microphoneMenu: NSMenu?
    private var activeInputDeviceID: AudioDeviceID?
    private var activeInputDeviceName: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            Defaults.showInDock: true,
            Defaults.pasteHistoryFromMenuBar: true,
        ])

        shortcutPreferences.onChange = { [weak self] in
            self?.hotkeyManager.reloadConfiguration()
        }
        audioInputDevices.onDevicesChanged = { [weak self] in
            self?.handleAudioInputDevicesChanged()
        }

        setupMainMenu()
        setupMenuBar()
        setupHotkey()
        if AppIdentity.isDevelopmentBuild, !permissions.hasAccessibility {
            permissions.requestAccessibility()
        }

        if UserDefaults.standard.bool(forKey: Defaults.showInDock) {
            NSApp.setActivationPolicy(.regular)
        }
        applyDevelopmentDockBadge()

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
        audioRecorder.stopForTermination()
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
        enqueueRecordingWork { await $0.performStartRecording() }
    }

    private func stopRecordingAndTranscribe() {
        enqueueRecordingWork { await $0.performStopRecordingAndTranscribe() }
    }

    private func enqueueRecordingWork(
        _ operation: @escaping @MainActor (AppDelegate) async -> Void
    ) {
        let previous = recordingFlow
        recordingFlow = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            await operation(self)
        }
    }

    private func performStartRecording() async {
        guard !audioRecorder.isRecording else { return }
        recordingGeneration += 1

        indicatorModel.notice = nil
        do {
            var resolution = try audioInputDevices.resolutionForRecording()

            // Show feedback immediately; the capture session starts on a
            // background queue and can take a moment on some microphones.
            appState = .recording
            updateMenuBarIcon(state: .recording)
            spectrumSmoother.reset()
            indicatorModel.spectrumLevels = AudioSpectrum.silence
            showIndicator(state: .recording)
            indicatorModel.notice = resolution.fallbackNotice?.message

            do {
                try await audioRecorder.startRecording(deviceUID: resolution.deviceUID)
            } catch let error as AudioRecorderError where error.shouldTryFallback {
                resolution = try audioInputDevices.fallbackResolution(
                    preferredName: resolution.name,
                    excludingUID: resolution.deviceUID
                )
                indicatorModel.notice = resolution.fallbackNotice?.message
                try await audioRecorder.startRecording(deviceUID: resolution.deviceUID)
            }

            activeInputDeviceID = resolution.deviceID
            activeInputDeviceName = resolution.name
        } catch {
            print("Failed to start recording: \(error)")
            appState = .idle
            updateMenuBarIcon(state: .idle)
            hotkeyManager.recordingWasStopped()
            showTransientWarning(error.localizedDescription)
        }
    }

    private func performStopRecordingAndTranscribe() async {
        guard audioRecorder.isRecording else { return }

        let samples = await audioRecorder.stopRecording()
        activeInputDeviceID = nil
        activeInputDeviceName = nil
        appState = .processing
        updateMenuBarIcon(state: .processing)
        recordingGeneration += 1
        let generation = recordingGeneration

        guard samples.count >= AudioRecorder.minimumSamples else {
            appState = .idle
            updateMenuBarIcon(state: .idle)
            if let notice = indicatorModel.notice {
                showTransientWarning(notice)
            } else {
                showNonSpeechWarning()
            }
            return
        }

        updateIndicator(state: .processing)

        Task {
            // A new recording may start while transcription runs; only the
            // latest generation may touch the indicator and app state.
            do {
                // transcribe() waits for the model if it's still loading —
                // the user just sees "Transcribing" a bit longer on first use
                let text = try await transcriptionService.transcribe(audioSamples: samples)
                if TranscriptionPostProcessor.isNonSpeechOnly(text) {
                    if generation == recordingGeneration {
                        showNonSpeechWarning(text)
                    }
                } else {
                    transcriptionHistory.append(
                        text,
                        duration: AudioRecorder.duration(sampleCount: samples.count)
                    )
                    TextInserter.insertText(text)
                    if generation == recordingGeneration {
                        updateIndicator(state: .done(text: text))
                        scheduleIndicatorDismissal(after: indicatorModel.notice == nil ? 1.5 : 4)
                    }
                }
            } catch {
                print("Transcription failed: \(error)")
                if generation == recordingGeneration {
                    dismissIndicator()
                }
            }

            if generation == recordingGeneration {
                appState = .idle
                updateMenuBarIcon(state: .idle)
            }
        }
    }

    private func handleAudioInputDevicesChanged() {
        guard audioRecorder.isRecording,
            let activeInputDeviceID,
            !audioInputDevices.devices.contains(where: { $0.id == activeInputDeviceID })
        else { return }

        let disconnectedName = activeInputDeviceName ?? "Microphone"
        if let fallbackName = audioInputDevices.fallbackDeviceName {
            indicatorModel.notice =
                "\(disconnectedName) disconnected. Recording stopped. Next recording will use \(fallbackName)."
        } else {
            indicatorModel.notice =
                "\(disconnectedName) disconnected. Recording stopped. No fallback microphone is available."
        }
        // This stop bypasses the hotkey gesture; tell the state machine so the
        // next gesture starts a recording instead of sending a stale stop.
        hotkeyManager.recordingWasStopped()
        stopRecordingAndTranscribe()
    }

    private func showNonSpeechWarning(
        _ text: String = TranscriptionPostProcessor.blankAudioMarker
    ) {
        updateIndicator(state: .warning(text: text))
        scheduleIndicatorDismissal(after: 1.5)
    }

    private func showTransientWarning(_ message: String) {
        indicatorModel.notice = nil
        showIndicator(state: .warning(text: message))
        scheduleIndicatorDismissal(after: 4)
    }

    private func scheduleIndicatorDismissal(after seconds: Double) {
        indicatorDismissTask?.cancel()
        let generation = recordingGeneration
        indicatorDismissTask = Task {
            // A cancelled sleep must not tear down the indicator a newer recording just showed.
            guard (try? await Task.sleep(for: .seconds(seconds))) != nil else { return }
            guard generation == recordingGeneration else { return }
            dismissIndicator()
        }
    }

    // MARK: - Floating Indicator

    private func showIndicator(state: IndicatorState) {
        indicatorDismissTask?.cancel()
        indicatorDismissTask = nil
        indicatorModel.state = state

        let isNewPanel = indicatorPanel == nil
        if isNewPanel {
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

            let hostingView = NSHostingView(rootView: FloatingIndicatorView(model: indicatorModel))
            hostingView.sizingOptions = .intrinsicContentSize
            panel.contentView = hostingView

            indicatorPanel = panel
            indicatorHostingView = hostingView
        }

        if isNewPanel {
            // Hide until the first laid-out frame so a brand-new panel does not
            // flash at (0,0). Reusing a visible panel must not go to alpha 0:
            // NSWindow.displayLink stops callbacks while the window is fully
            // transparent, and startIndicatorTracking will not attach a second
            // link, so the popover stays invisible for the whole recording.
            indicatorPanel?.alphaValue = 0
            indicatorNeedsInitialFrame = true
            indicatorSizeFrom = nil
            indicatorSizeTo = .zero
            indicatorSizeAnimStart = nil
        }

        positionIndicatorNearCursor()
        if let panel = indicatorPanel, panel.frame.width < 1 || panel.frame.height < 1 {
            let mouse = NSEvent.mouseLocation
            panel.setFrame(
                NSRect(x: mouse.x + 14, y: mouse.y + 14, width: 48, height: 32),
                display: true
            )
        }
        indicatorPanel?.orderFrontRegardless()
        startIndicatorTracking()
        revealIndicatorIfLaidOut()
    }

    private func updateIndicator(state: IndicatorState) {
        indicatorModel.state = state
        if state != .recording {
            indicatorModel.spectrumLevels = AudioSpectrum.silence
        }
        positionIndicatorNearCursor()
    }

    private func dismissIndicator() {
        indicatorDismissTask?.cancel()
        indicatorDismissTask = nil
        indicatorDisplayLink?.invalidate()
        indicatorDisplayLink = nil
        lastIndicatorFrameTimestamp = nil
        indicatorPanel?.orderOut(nil)
        indicatorPanel?.contentView = nil
        indicatorHostingView = nil
        indicatorPanel = nil
        indicatorNeedsInitialFrame = false
        indicatorSizeFrom = nil
        indicatorSizeTo = .zero
        indicatorSizeAnimStart = nil
        indicatorModel.notice = nil
    }

    private func startIndicatorTracking() {
        guard indicatorDisplayLink == nil, let panel = indicatorPanel else { return }

        let displayLink = panel.displayLink(
            target: self,
            selector: #selector(updateIndicatorFrame(_:))
        )
        displayLink.add(to: .main, forMode: .common)
        indicatorDisplayLink = displayLink
    }

    @objc private func updateIndicatorFrame(_ displayLink: CADisplayLink) {
        let deltaTime = lastIndicatorFrameTimestamp.map {
            displayLink.timestamp - $0
        } ?? displayLink.duration
        lastIndicatorFrameTimestamp = displayLink.timestamp

        if appState == .recording {
            indicatorModel.spectrumLevels = spectrumSmoother.update(
                targetLevels: audioRecorder.currentSpectrumLevels(),
                deltaTime: deltaTime
            )
        }

        positionIndicatorNearCursor()
        revealIndicatorIfLaidOut()
    }

    private func revealIndicatorIfLaidOut() {
        guard indicatorNeedsInitialFrame,
            let panel = indicatorPanel,
            let hostingView = indicatorHostingView
        else { return }

        hostingView.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
        let contentSize = hostingView.fittingSize
        guard contentSize.width > 0, contentSize.height > 0 else { return }

        positionIndicatorNearCursor()
        panel.alphaValue = 1
        indicatorNeedsInitialFrame = false
    }

    private func positionIndicatorNearCursor() {
        guard let panel = indicatorPanel,
            let hostingView = indicatorHostingView,
            let screen = screenContainingMouse()
        else { return }

        hostingView.layoutSubtreeIfNeeded()
        let targetSize = hostingView.fittingSize
        guard targetSize.width > 0, targetSize.height > 0 else { return }

        let contentSize = interpolatedIndicatorSize(toward: targetSize)
        let origin = FloatingIndicatorPositioner.origin(
            cursor: NSEvent.mouseLocation,
            contentSize: contentSize,
            visibleFrame: screen.visibleFrame
        )
        let frame = NSRect(origin: origin, size: contentSize)

        guard panel.frame != frame else { return }

        panel.setFrame(frame, display: true)
    }

    private func interpolatedIndicatorSize(toward target: CGSize) -> CGSize {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || indicatorNeedsInitialFrame {
            indicatorSizeFrom = nil
            indicatorSizeTo = target
            indicatorSizeAnimStart = nil
            return target
        }

        if !FloatingIndicatorSizeAnimator.sizesAreNearlyEqual(target, indicatorSizeTo) {
            let current = indicatorPanel?.frame.size ?? target
            indicatorSizeFrom =
                current.width > 0 && current.height > 0 ? current : target
            indicatorSizeTo = target
            indicatorSizeAnimStart = CACurrentMediaTime()
        }

        guard let from = indicatorSizeFrom, let start = indicatorSizeAnimStart else {
            return target
        }

        let elapsed = CACurrentMediaTime() - start
        if elapsed >= FloatingIndicatorSizeAnimator.duration {
            indicatorSizeFrom = nil
            indicatorSizeAnimStart = nil
            return target
        }

        return FloatingIndicatorSizeAnimator.size(from: from, to: target, elapsed: elapsed)
    }

    private func screenContainingMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first {
            NSMouseInRect(mouseLocation, $0.frame, false)
        } ?? NSScreen.main
    }

    // MARK: - Main Menu

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            NSMenuItem(
                title: "About Inputalk",
                action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                keyEquivalent: ""))
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(showSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(
            NSMenuItem(
                title: "Hide Inputalk",
                action: #selector(NSApplication.hide(_:)),
                keyEquivalent: "h"))
        let hideOthers = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(
            NSMenuItem(
                title: "Show All",
                action: #selector(NSApplication.unhideAllApplications(_:)),
                keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(
            NSMenuItem(
                title: "Quit Inputalk",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"))

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(
            NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(
            NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(
            NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(
            NSMenuItem(
                title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(
            NSMenuItem(
                title: "Close",
                action: #selector(NSWindow.performClose(_:)),
                keyEquivalent: "w"))
        windowMenu.addItem(
            NSMenuItem(
                title: "Minimize",
                action: #selector(NSWindow.performMiniaturize(_:)),
                keyEquivalent: "m"))

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = menuBarImage(for: .idle)
            button.toolTip = menuBarTooltip(for: .idle)
            button.action = #selector(statusBarButtonClicked)
        }
    }

    func updateMenuBarIcon(state: AppState) {
        guard let button = statusItem.button else { return }
        button.image = menuBarImage(for: state)
        button.contentTintColor = nil
        button.toolTip = menuBarTooltip(for: state)
    }

    private func menuBarTooltip(for state: AppState) -> String {
        let name = AppIdentity.isDevelopmentBuild ? "Inputalk Dev" : "Inputalk"
        return state == .recording ? "\(name) is recording" : name
    }

    private func menuBarImage(for state: AppState) -> NSImage? {
        let image: NSImage?
        switch state {
        case .idle, .recording:
            if let url = Bundle.module.url(forResource: "MenuBarIcon", withExtension: "png"),
                let loaded = NSImage(contentsOf: url)
            {
                image = loaded
            } else {
                image = NSImage(
                    systemSymbolName: "waveform", accessibilityDescription: "Inputalk")
            }
        case .processing:
            image = NSImage(
                systemSymbolName: "ellipsis.circle",
                accessibilityDescription: "Transcribing")
        }
        guard let image else { return nil }
        image.size = NSSize(width: 18, height: 18)
        if AppIdentity.isDevelopmentBuild {
            return Self.orangeMenuBarImage(from: image)
        }
        image.isTemplate = true
        return image
    }

    /// Menu bar template images are always drawn black or white. Recolor into a
    /// non-template image so the Dev build can stay orange.
    private static func orangeMenuBarImage(from image: NSImage) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let colored = NSImage(size: size, flipped: false) { rect in
            image.draw(in: rect)
            NSColor.systemOrange.setFill()
            rect.fill(using: .sourceIn)
            return true
        }
        colored.isTemplate = false
        return colored
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        showContextMenu()
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let microphoneItem = NSMenuItem(
            title: "Microphone", action: nil, keyEquivalent: "")
        let microphoneMenu = NSMenu(title: "Microphone")
        microphoneMenu.delegate = self
        microphoneItem.submenu = microphoneMenu
        menu.addItem(microphoneItem)
        self.microphoneMenu = microphoneMenu
        rebuildMicrophoneMenu(microphoneMenu)

        menu.addItem(NSMenuItem.separator())

        let historyItem = NSMenuItem(title: "History", action: nil, keyEquivalent: "")
        let historyMenu = NSMenu(title: "History")
        rebuildHistoryMenu(historyMenu)
        historyItem.submenu = historyMenu
        menu.addItem(historyItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...", action: #selector(showSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updateItem = NSMenuItem(
            title: "Check for Updates...", action: #selector(checkForUpdatesAction), keyEquivalent: "")
        updateItem.target = self
        updateItem.isEnabled = updateService.isConfigured
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit Inputalk", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
        self.microphoneMenu = nil
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === microphoneMenu else { return }
        audioInputDevices.refresh()
        rebuildMicrophoneMenu(menu)
    }

    private func rebuildMicrophoneMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let canChangeDevice = appState != .recording

        let systemDefaultItem = NSMenuItem(
            title: audioInputDevices.selectedDefaultLabel,
            action: #selector(selectMicrophoneFromMenu(_:)),
            keyEquivalent: ""
        )
        systemDefaultItem.target = self
        systemDefaultItem.state = audioInputDevices.selection == .systemDefault ? .on : .off
        systemDefaultItem.isEnabled = canChangeDevice
        menu.addItem(systemDefaultItem)
        menu.addItem(.separator())

        for device in audioInputDevices.devices {
            let item = NSMenuItem(
                title: device.name,
                action: #selector(selectMicrophoneFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = device.uid
            item.state = audioInputDevices.selection == .device(uid: device.uid) ? .on : .off
            item.isEnabled = canChangeDevice
            menu.addItem(item)
        }

        if audioInputDevices.devices.isEmpty {
            let unavailableItem = NSMenuItem(
                title: "No microphones available", action: nil, keyEquivalent: "")
            unavailableItem.isEnabled = false
            menu.addItem(unavailableItem)
        } else if case .device(let uid) = audioInputDevices.selection,
            audioInputDevices.selectedDevice == nil
        {
            let unavailableItem = NSMenuItem(
                title: "\(audioInputDevices.selectedDeviceName) (Unavailable)",
                action: nil,
                keyEquivalent: ""
            )
            unavailableItem.state = .on
            unavailableItem.isEnabled = false
            unavailableItem.representedObject = uid
            menu.addItem(unavailableItem)
        }

        if audioInputDevices.unavailableSelectionMessage != nil,
            let fallbackName = audioInputDevices.fallbackDeviceName
        {
            menu.addItem(.separator())
            let statusItem = NSMenuItem(
                title: "Using \(fallbackName) as fallback",
                action: nil,
                keyEquivalent: ""
            )
            statusItem.isEnabled = false
            menu.addItem(statusItem)
        } else if appState == .recording {
            menu.addItem(.separator())
            let statusItem = NSMenuItem(
                title: "Stop recording before switching microphones",
                action: nil,
                keyEquivalent: ""
            )
            statusItem.isEnabled = false
            menu.addItem(statusItem)
        }
    }

    @objc private func selectMicrophoneFromMenu(_ sender: NSMenuItem) {
        if let uid = sender.representedObject as? String {
            audioInputDevices.select(.device(uid: uid))
        } else {
            audioInputDevices.select(.systemDefault)
        }
    }

    private func rebuildHistoryMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let recent = Array(transcriptionHistory.entries.prefix(5))
        guard !recent.isEmpty else {
            let emptyItem = NSMenuItem(
                title: "No transcripts yet", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            return
        }

        for entry in recent {
            let item = NSMenuItem(
                title: TranscriptionHistoryStore.menuTitle(for: entry.text),
                action: #selector(copyHistoryFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = NSNumber(value: entry.id)
            item.toolTip = entry.text
            menu.addItem(item)
        }
    }

    @objc private func copyHistoryFromMenu(_ sender: NSMenuItem) {
        guard let id = (sender.representedObject as? NSNumber)?.int64Value,
            let entry = transcriptionHistory.entries.first(where: { $0.id == id })
        else { return }

        // Paste mode restores the user's clipboard afterwards; copy mode replaces it.
        if UserDefaults.standard.bool(forKey: Defaults.pasteHistoryFromMenuBar) {
            TextInserter.insertText(entry.text)
        } else {
            transcriptionHistory.copyToPasteboard(entry)
        }
    }

    // MARK: - Windows

    @objc private func showSettingsAction() {
        showSettings()
    }

    @objc private func checkForUpdatesAction() {
        updateService.checkForUpdates()
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
                    .environmentObject(updateService)
                    .environment(shortcutPreferences)
                    .environment(audioInputDevices)
                    .environment(transcriptionHistory)
            )
            window.isReleasedWhenClosed = false
            window.delegate = self
            settingsWindow = window
        }

        NSApp.setActivationPolicy(.regular)
        applyDevelopmentDockBadge()
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
                .environment(self.shortcutPreferences)
            )
            window.isReleasedWhenClosed = false
            window.delegate = self
            onboardingWindow = window
        }

        NSApp.setActivationPolicy(.regular)
        applyDevelopmentDockBadge()
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        onboardingWindow?.orderOut(nil)
        onboardingWindow?.close()
        onboardingWindow = nil
        if !UserDefaults.standard.bool(forKey: Defaults.showInDock) {
            NSApp.setActivationPolicy(.accessory)
        }
        setupHotkey()
    }

    func applyDockVisibilityPreference() {
        let showInDock = UserDefaults.standard.bool(forKey: Defaults.showInDock)
        let activeWindow = NSApp.keyWindow
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
        if showInDock {
            applyDevelopmentDockBadge()
        }
        Task { @MainActor in
            activeWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func applyDevelopmentDockBadge() {
        guard AppIdentity.isDevelopmentBuild, !didApplyDevelopmentDockBadge else { return }

        let source = NSApp.applicationIconImage ?? NSImage(size: NSSize(width: 256, height: 256))
        let canvas = NSSize(width: 256, height: 256)
        let badged = NSImage(size: canvas, flipped: false) { rect in
            source.draw(in: rect)

            let diameter = min(rect.width, rect.height) * 0.26
            let inset = min(rect.width, rect.height) * 0.1
            let dot = NSRect(
                x: rect.maxX - diameter - inset,
                y: rect.maxY - diameter - inset,
                width: diameter,
                height: diameter
            )
            let ring = NSBezierPath(ovalIn: dot.insetBy(dx: -diameter * 0.08, dy: -diameter * 0.08))
            NSColor.white.setFill()
            ring.fill()
            NSColor.systemOrange.setFill()
            NSBezierPath(ovalIn: dot).fill()
            return true
        }

        NSApp.applicationIconImage = badged
        NSApp.dockTile.display()
        didApplyDevelopmentDockBadge = true
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow else { return }

        if UserDefaults.standard.bool(forKey: Defaults.showInDock) { return }

        let otherWindow: NSWindow? =
            (closedWindow === settingsWindow) ? onboardingWindow : settingsWindow
        if otherWindow?.isVisible != true {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
