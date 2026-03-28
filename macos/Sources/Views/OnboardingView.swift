import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @EnvironmentObject var transcription: TranscriptionService
    @EnvironmentObject var permissions: PermissionManager
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<4) { i in
                    Circle()
                        .fill(i <= step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            // Step content
            Group {
                switch step {
                case 0:
                    welcomeStep
                case 1:
                    microphoneStep
                case 2:
                    accessibilityStep
                case 3:
                    modelStep
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Spacer()
        }
        .frame(width: 480, height: 420)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Welcome to Inputalk")
                .font(.title.bold())

            Text(
                "Free, local voice-to-text.\nDouble-press Fn to dictate hands-free, or hold Fn for push-to-talk."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            Button("Get Started") {
                withAnimation { step = 1 }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
        }
    }

    private var microphoneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: permissions.hasMicrophone ? "mic.fill" : "mic.slash")
                .font(.system(size: 48))
                .foregroundStyle(permissions.hasMicrophone ? .green : .orange)

            Text("Microphone Access")
                .font(.title2.bold())

            Text("Inputalk needs your microphone to record your voice for transcription.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if permissions.hasMicrophone {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Grant Permission") {
                    Task {
                        await permissions.requestMicrophone()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            Button(permissions.hasMicrophone ? "Continue" : "Skip for now") {
                withAnimation { step = 2 }
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
    }

    private var accessibilityStep: some View {
        VStack(spacing: 16) {
            Image(
                systemName: permissions.hasAccessibility
                    ? "hand.raised.fill" : "hand.raised.slash"
            )
            .font(.system(size: 48))
            .foregroundStyle(permissions.hasAccessibility ? .green : .orange)

            Text("Accessibility Access")
                .font(.title2.bold())

            Text(
                "Required for the global keyboard shortcut and pasting text into other apps."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            if permissions.hasAccessibility {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Open System Settings") {
                    permissions.requestAccessibility()
                }
                .buttonStyle(.borderedProminent)

                Text("After granting, click Continue.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Button(permissions.hasAccessibility ? "Continue" : "Skip for now") {
                withAnimation { step = 3 }
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
    }

    private var modelStep: some View {
        VStack(spacing: 16) {
            Group {
                switch transcription.modelState {
                case .ready:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                case .error(let msg):
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.red)
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                default:
                    ProgressView()
                        .controlSize(.large)
                }
            }

            Text("Speech Model")
                .font(.title2.bold())

            switch transcription.modelState {
            case .ready:
                Text("Model \"\(transcription.selectedModel)\" is ready.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            case .loading:
                Text("Loading model \"\(transcription.selectedModel)\"...")
                    .font(.body)
                    .foregroundStyle(.secondary)
            case .downloading(let progress):
                VStack(spacing: 8) {
                    Text("Downloading model \"\(transcription.selectedModel)\"...")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    ProgressView(value: progress)
                        .frame(width: 200)
                }
            case .error:
                Button("Retry") {
                    Task { await transcription.loadModel() }
                }
                .buttonStyle(.borderedProminent)
            case .unloaded:
                Text("Preparing model...")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .onAppear {
                        Task { await transcription.loadModel() }
                    }
            }

            if transcription.modelState == .ready {
                Button("Start Using Inputalk") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            }
        }
    }
}
