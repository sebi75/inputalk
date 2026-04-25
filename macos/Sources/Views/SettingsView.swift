import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var transcription: TranscriptionService
    @EnvironmentObject var permissions: PermissionManager

    @AppStorage("removeFillerWords") private var removeFillerWords = true
    @AppStorage(Defaults.showInDock) private var showInDock = true

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            // Shortcut
            Section {
                HStack {
                    Label("Shortcut", systemImage: "keyboard")
                    Spacer()
                    Text("Fn (Globe)")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("Trigger Modes", systemImage: "hand.tap")
                    Text("Hold Fn: push-to-talk\nDouble-press Fn: hands-free (press again to stop)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } header: {
                Text("Input")
            }

            // Model
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

            // Post-processing
            Section {
                Toggle(isOn: $removeFillerWords) {
                    Label("Remove filler words", systemImage: "text.badge.minus")
                }
            } header: {
                Text("Post-processing")
            }

            // General
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

            // Permissions
            Section {
                HStack {
                    Label("Microphone", systemImage: "mic")
                    Spacer()
                    if permissions.hasMicrophone {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Grant") {
                            Task { await permissions.requestMicrophone() }
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

            // Storage
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

            // About
            Section {
                HStack {
                    Text("Inputalk")
                    Spacer()
                    Text("v0.1.0")
                        .foregroundStyle(.secondary)
                }
                Text("Free, local voice-to-text powered by WhisperKit.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 520)
    }

    // MARK: - Helpers

    private var modelStatusColor: Color {
        switch transcription.modelState {
        case .ready: return .green
        case .loading, .downloading: return .orange
        case .error: return .red
        case .unloaded: return .gray
        }
    }

    private var modelStatusText: String {
        switch transcription.modelState {
        case .ready: return "Ready"
        case .loading: return "Loading..."
        case .downloading(let p): return "Downloading \(Int(p * 100))%"
        case .error(let msg): return msg
        case .unloaded: return "Not loaded"
        }
    }
}
