import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var transcription: TranscriptionService
    @EnvironmentObject var permissions: PermissionManager
    @EnvironmentObject var updates: UpdateService
    @Environment(ShortcutPreferences.self) private var shortcutPreferences
    @Environment(AudioInputDeviceManager.self) private var audioInputDevices
    @Environment(TranscriptionHistoryStore.self) private var transcriptionHistory

    @AppStorage("removeFillerWords") private var removeFillerWords = true
    @AppStorage(Defaults.showInDock) private var showInDock = true
    @AppStorage(Defaults.pasteHistoryFromMenuBar) private var pasteHistoryFromMenuBar = true
    @AppStorage(Defaults.settingsPage) private var settingsPage = SettingsPage.dictation.rawValue

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var shortcutEditor: ShortcutEditorModel?
    @State private var showsMicrophonePermissionError = false
    @State private var copiedEntryID: Int64?
    @State private var copiedResetTask: Task<Void, Never>?
    @State private var entryPendingDeletion: TranscriptionHistoryEntry?
    @State private var showsClearHistoryConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("Page", selection: $settingsPage) {
                Text("General").tag(SettingsPage.general.rawValue)
                Text("Dictation").tag(SettingsPage.dictation.rawValue)
                Text("History").tag(SettingsPage.history.rawValue)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Form {
                switch SettingsPage(rawValue: settingsPage) ?? .dictation {
                case .dictation:
                    dictationSections
                case .history:
                    historySections
                case .general:
                    generalSections
                }
            }
            .formStyle(.grouped)
            .id(settingsPage)
        }
        .frame(width: 400, height: 520)
        .onAppear {
            audioInputDevices.refresh()
            if settingsPage == SettingsPage.history.rawValue {
                transcriptionHistory.refreshStatsIfNeeded()
            }
        }
        .onChange(of: settingsPage) { _, page in
            if page == SettingsPage.dictation.rawValue {
                audioInputDevices.refresh()
            }
            if page == SettingsPage.history.rawValue {
                transcriptionHistory.refreshStatsIfNeeded()
            }
        }
        .onChange(of: transcriptionHistory.entries) { _, _ in
            refreshHistoryStatsIfLooking()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            guard (notification.object as? NSWindow)?.title == "Settings" else { return }
            refreshHistoryStatsIfLooking()
        }
        .sheet(item: $shortcutEditor) { editor in
            ShortcutConfigurationView(editor: editor) { configuration in
                shortcutPreferences.apply(configuration)
            }
        }
        .alert(
            "Delete Transcript?",
            isPresented: Binding(
                get: { entryPendingDeletion != nil },
                set: { if !$0 { entryPendingDeletion = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                entryPendingDeletion = nil
            }
            Button("Delete", role: .destructive) {
                if let entry = entryPendingDeletion {
                    transcriptionHistory.remove(id: entry.id)
                    if copiedEntryID == entry.id {
                        copiedEntryID = nil
                    }
                }
                entryPendingDeletion = nil
            }
        } message: {
            Text(
                TranscriptionHistoryStore.menuTitle(
                    for: entryPendingDeletion?.text ?? "",
                    maxCharacters: 120
                )
            )
        }
        .alert(
            "Clear History?",
            isPresented: $showsClearHistoryConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Clear History", role: .destructive) {
                transcriptionHistory.clear()
                copiedEntryID = nil
            }
        } message: {
            Text("This removes every saved transcript from this Mac.")
        }
        .alert(
            "Microphone Access Required",
            isPresented: $showsMicrophonePermissionError
        ) {
            Button("Close", role: .cancel) {}
            Button("Open Microphone Settings") {
                permissions.openMicrophoneSettings()
            }
        } message: {
            Text(
                "Inputalk could not access the microphone. Allow microphone access in System Settings, then return to Inputalk."
            )
        }
    }

    // MARK: - Dictation

    @ViewBuilder
    private var dictationSections: some View {
        Section {
            Button {
                shortcutEditor = ShortcutEditorModel(
                    configuration: shortcutPreferences.configuration)
            } label: {
                HStack(spacing: 12) {
                    Label("Shortcut", systemImage: "keyboard")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(shortcutPreferences.configuration.chordSummary)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(shortcutPreferences.configuration.behaviorSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()

            Picker(selection: audioInputSelection) {
                Text(audioInputDevices.selectedDefaultLabel)
                    .tag(AudioInputSelection.systemDefault)

                Divider()

                if case .device(let uid) = audioInputDevices.selection,
                    audioInputDevices.selectedDevice == nil
                {
                    Text("\(audioInputDevices.selectedDeviceName) (Unavailable)")
                        .tag(AudioInputSelection.device(uid: uid))
                }

                ForEach(audioInputDevices.devices) { device in
                    Text(device.name)
                        .tag(AudioInputSelection.device(uid: device.uid))
                }
            } label: {
                Label("Microphone", systemImage: "mic")
            }

            if let message = audioInputDevices.unavailableSelectionMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if let error = audioInputDevices.refreshError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Input")
        }

        Section {
            Picker(selection: $transcription.selectedModel) {
                Text("Tiny (~75 MB)").tag("tiny")
                Text("Base (~142 MB)").tag("base")
                Text("Small (~466 MB)").tag("small")
                Text("Medium (~1.5 GB)").tag("medium")
            } label: {
                Label("Model", systemImage: "cpu")
            }

            HStack {
                Label("Status", systemImage: "circle.fill")
                    .foregroundStyle(modelStatusColor)
                Spacer()
                Text(modelStatusText)
                    .foregroundStyle(.secondary)
                if transcription.modelState.showsSpinner {
                    ProgressView()
                        .controlSize(.small)
                }
                if case .error = transcription.modelState {
                    Button("Retry") {
                        Task { await transcription.loadModel() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .onChange(of: transcription.selectedModel) {
                Task { await transcription.loadModel() }
            }
        } header: {
            Text("Transcription")
        }

        Section {
            Toggle(isOn: $removeFillerWords) {
                Label("Remove filler words", systemImage: "text.badge.minus")
            }
        } header: {
            Text("Post-processing")
        }

        Section {
            HStack {
                Label("Microphone", systemImage: "mic")
                Spacer()
                if permissions.hasMicrophone {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Grant") {
                        requestMicrophonePermission()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            HStack {
                Label("Accessibility", systemImage: "hand.raised")
                Spacer()
                if permissions.hasAccessibility {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Grant") {
                        permissions.requestAccessibility()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        } header: {
            Text("Permissions")
        }
    }

    // MARK: - History

    @ViewBuilder
    private var historySections: some View {
        if let stats = transcriptionHistory.stats, let wpm = stats.wordsPerMinute {
            Section {
                HStack {
                    Label("Talking rate", systemImage: "speedometer")
                    Spacer()
                    Text("\(Int(wpm.rounded())) wpm")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("Talk time", systemImage: "clock")
                    Spacer()
                    Text(TranscriptionHistoryStore.formatDuration(stats.durationSeconds))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Stats")
            }
        }

        Section {
            Toggle(isOn: $pasteHistoryFromMenuBar) {
                Label("Paste from menu bar", systemImage: "doc.on.clipboard")
            }

            if transcriptionHistory.entries.isEmpty {
                Text("Transcripts you dictate will show up here so you can copy them later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(transcriptionHistory.entries) { entry in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.text)
                                        .font(.body)
                                        .lineLimit(3)
                                        .textSelection(.enabled)
                                    historyCaption(for: entry)
                                }
                                Spacer(minLength: 8)
                                Button(copiedEntryID == entry.id ? "Copied" : "Copy") {
                                    copyHistoryEntry(entry)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(copiedEntryID == entry.id)
                                Button("Delete", role: .destructive) {
                                    entryPendingDeletion = entry
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .frame(maxHeight: 320)

                Button("Clear History", role: .destructive) {
                    showsClearHistoryConfirmation = true
                }
            }
        } header: {
            Text("History")
        } footer: {
            Text(
                pasteHistoryFromMenuBar
                    ? "Menu bar History pastes into the frontmost app and leaves your clipboard unchanged. Settings Copy only puts text on the clipboard."
                    : "Menu bar History and Settings Copy only put text on the clipboard."
            )
        }
    }

    // MARK: - General

    @ViewBuilder
    private var generalSections: some View {
        Section {
            Toggle(isOn: $launchAtLogin) {
                Label("Launch at Login", systemImage: "arrow.right.circle")
            }
            .onChange(of: launchAtLogin) { _, newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    launchAtLogin = !newValue
                }
            }

            Toggle(isOn: $showInDock) {
                Label("Show in Dock", systemImage: "dock.rectangle")
            }
            .onChange(of: showInDock) { _, _ in
                (NSApp.delegate as? AppDelegate)?.applyDockVisibilityPreference()
            }
        } header: {
            Text("General")
        }

        Section {
            HStack {
                Label("Check for Updates", systemImage: "arrow.down.circle")
                Spacer()
                Button("Check") {
                    updates.checkForUpdates()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!updates.isConfigured)
            }

            Toggle(isOn: Binding(
                get: { updates.automaticallyChecksForUpdates },
                set: { updates.automaticallyChecksForUpdates = $0 }
            )) {
                Label("Automatically check for updates", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(!updates.isConfigured)

            if !updates.isConfigured {
                Text("Sparkle updates are not configured for this build.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        } header: {
            Text("Updates")
        }

        Section {
            HStack {
                Label("Model data", systemImage: "internaldrive")
                Spacer()
                Text(transcription.modelsDiskUsage)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(TranscriptionService.modelsDirectory.path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(
                        nil,
                        inFileViewerRootedAtPath: TranscriptionService.modelsDirectory.path
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        } header: {
            Text("Storage")
        }

        Section {
            HStack {
                Text("Inputalk")
                Spacer()
                Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                    .foregroundStyle(.secondary)
            }
            Text("Free, local voice-to-text powered by WhisperKit.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } header: {
            Text("About")
        }
    }

    // MARK: - Helpers

    private func refreshHistoryStatsIfLooking() {
        guard settingsPage == SettingsPage.history.rawValue else { return }
        guard NSApp.windows.contains(where: { $0.title == "Settings" && $0.isVisible }) else { return }
        transcriptionHistory.refreshStatsIfNeeded()
    }

    private func requestMicrophonePermission() {
        Task {
            if await !permissions.requestMicrophone() {
                showsMicrophonePermissionError = true
            }
        }
    }

    @ViewBuilder
    private func historyCaption(for entry: TranscriptionHistoryEntry) -> some View {
        HStack(spacing: 0) {
            Text(entry.createdAt, format: .relative(presentation: .named))
            if let duration = entry.durationSeconds {
                Text(" · \(TranscriptionHistoryStore.formatDuration(duration))")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func copyHistoryEntry(_ entry: TranscriptionHistoryEntry) {
        transcriptionHistory.copyToPasteboard(entry)

        copiedResetTask?.cancel()
        copiedEntryID = entry.id
        copiedResetTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            if copiedEntryID == entry.id {
                copiedEntryID = nil
            }
        }
    }

    private var audioInputSelection: Binding<AudioInputSelection> {
        Binding(
            get: { audioInputDevices.selection },
            set: { audioInputDevices.select($0) }
        )
    }

    private var modelStatusColor: Color {
        switch transcription.modelState {
        case .ready: return .green
        case .checking, .loading, .optimizing, .downloading: return .orange
        case .error: return .red
        case .unloaded: return .gray
        }
    }

    private var modelStatusText: String {
        switch transcription.modelState {
        case .ready: return "Ready"
        case .checking: return "Checking..."
        case .loading: return "Loading..."
        case .optimizing: return "Optimizing for this Mac"
        case .downloading(let p): return "Downloading \(ModelLifecycle.percentText(from: p))"
        case .error(let msg): return msg
        case .unloaded: return "Not loaded"
        }
    }
}
