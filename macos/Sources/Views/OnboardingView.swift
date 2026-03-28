import SwiftUI

// MARK: - Onboarding View

struct OnboardingView: View {
    let onComplete: () -> Void

    @EnvironmentObject var transcription: TranscriptionService
    @EnvironmentObject var permissions: PermissionManager
    @State private var step = 0

    private let totalSteps = 5

    var body: some View {
        ZStack {
            // Dark background with subtle light pool (matches trylens)
            OnboardingBackground()

            VStack(spacing: 0) {
                ZStack {
                    switch step {
                    case 0: welcomeStep.transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    case 1: microphoneStep.transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    case 2: accessibilityStep.transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    case 3: modelStep.transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    case 4: doneStep.transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)

                if step > 0 && step < totalSteps - 1 {
                    OnboardingPageIndicator(current: step, total: totalSteps)
                        .padding(.bottom, 20)
                }
            }
        }
        .frame(width: 460, height: 480)
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                WelcomeIcon()

                VStack(spacing: 8) {
                    Text("Welcome to Inputalk")
                        .font(.system(size: 22, weight: .semibold))
                        .tracking(-0.3)
                        .foregroundStyle(.white)

                    Text("Free dictation for macOS — let's get you set up")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }

            Spacer()

            OnboardingPillButton("Get Started") {
                withAnimation { step = 1 }
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 40)
    }

    // MARK: - Step 1: Microphone

    private var microphoneStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "mic")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .orange.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .glassed(in: Circle())

                VStack(spacing: 8) {
                    Text("Microphone")
                        .font(.system(size: 20, weight: .semibold))
                        .tracking(-0.3)
                        .foregroundStyle(.white)

                    Text("Inputalk needs your microphone to hear your voice for dictation")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                OnboardingPermissionBadge(granted: permissions.hasMicrophone)
            }

            Spacer()

            VStack(spacing: 12) {
                if permissions.hasMicrophone {
                    OnboardingPillButton("Continue") {
                        withAnimation { step = 2 }
                    }
                } else {
                    OnboardingPillButton("Grant Permission") {
                        Task { await permissions.requestMicrophone() }
                    }

                    Button(action: { withAnimation { step = 2 } }) {
                        Text("Skip for now")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 40)
    }

    // MARK: - Step 2: Accessibility

    private var accessibilityStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "hand.raised.fingers.spread")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .glassed(in: Circle())

                VStack(spacing: 8) {
                    Text("Accessibility")
                        .font(.system(size: 20, weight: .semibold))
                        .tracking(-0.3)
                        .foregroundStyle(.white)

                    Text("Required for the Fn shortcut and pasting text into other apps")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                OnboardingPermissionBadge(granted: permissions.hasAccessibility)
            }

            Spacer()

            VStack(spacing: 12) {
                if permissions.hasAccessibility {
                    OnboardingPillButton("Continue") {
                        withAnimation { step = 3 }
                    }
                } else {
                    OnboardingPillButton("Open System Settings") {
                        permissions.requestAccessibility()
                    }

                    Button(action: { withAnimation { step = 3 } }) {
                        Text("Skip for now")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 40)
    }

    // MARK: - Step 3: Model Download

    private var modelStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "cpu")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .glassed(in: Circle())

                VStack(spacing: 8) {
                    Text("Speech Model")
                        .font(.system(size: 20, weight: .semibold))
                        .tracking(-0.3)
                        .foregroundStyle(.white)

                    modelStatusView
                }
            }

            Spacer()

            if transcription.modelState == .ready {
                OnboardingPillButton("Continue") {
                    withAnimation { step = 4 }
                }
                .padding(.bottom, 8)
            } else if case .error = transcription.modelState {
                OnboardingPillButton("Retry") {
                    Task { await transcription.loadModel() }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 40)
        .onAppear {
            if transcription.modelState == .unloaded {
                Task { await transcription.loadModel() }
            }
        }
    }

    @ViewBuilder
    private var modelStatusView: some View {
        switch transcription.modelState {
        case .ready:
            VStack(spacing: 12) {
                Text("Model \"\(transcription.selectedModel)\" is ready")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.4))

                OnboardingPermissionBadge(granted: true)
            }
        case .loading:
            VStack(spacing: 12) {
                Text("Loading model...")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.4))
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            }
        case .downloading(let progress):
            VStack(spacing: 12) {
                Text("Downloading \"\(transcription.selectedModel)\" — \(Int(progress * 100))%")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.4))
                ProgressView(value: progress)
                    .tint(.white)
                    .frame(width: 200)
            }
        case .error(let msg):
            VStack(spacing: 8) {
                Text(msg)
                    .font(.system(size: 12))
                    .foregroundStyle(.orange.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        case .unloaded:
            Text("Preparing...")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.4))
        }
    }

    // MARK: - Step 4: Done

    private var doneStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                DoneCheckmark()

                VStack(spacing: 8) {
                    Text("You're all set")
                        .font(.system(size: 22, weight: .semibold))
                        .tracking(-0.3)
                        .foregroundStyle(.white)

                    Text("Hold Fn to dictate, release to paste")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.4))
                }

                // Summary
                VStack(spacing: 2) {
                    OnboardingSummaryRow(
                        icon: "mic",
                        title: "Microphone",
                        granted: permissions.hasMicrophone
                    )
                    OnboardingSummaryRow(
                        icon: "hand.raised.fingers.spread",
                        title: "Accessibility",
                        granted: permissions.hasAccessibility
                    )
                    OnboardingSummaryRow(
                        icon: "cpu",
                        title: "Model: \(transcription.selectedModel)",
                        granted: transcription.modelState == .ready
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassed(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Spacer()

            OnboardingPillButton("Start Dictating") {
                onComplete()
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 40)
    }
}

// MARK: - Shared Components

private struct OnboardingBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.10), Color(white: 0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color.white.opacity(0.05), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.3),
                startRadius: 20,
                endRadius: 220
            )
        }
        .ignoresSafeArea()
    }
}

private struct OnboardingPillButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
        } else {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.2),
                                                Color.white.opacity(0.05),
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct WelcomeIcon: View {
    @State private var appeared = false

    var body: some View {
        Image(systemName: "waveform")
            .font(.system(size: 32, weight: .light))
            .foregroundStyle(
                LinearGradient(
                    colors: [.white.opacity(0.9), .white.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 72, height: 72)
            .glassed(in: Circle())
            .scaleEffect(appeared ? 1.0 : 0.3)
            .opacity(appeared ? 1.0 : 0.0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.15)) {
                    appeared = true
                }
            }
    }
}

private struct DoneCheckmark: View {
    @State private var appeared = false

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(.green)
            .frame(width: 64, height: 64)
            .glassed(in: Circle())
            .scaleEffect(appeared ? 1.0 : 0.3)
            .opacity(appeared ? 1.0 : 0.0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.15)) {
                    appeared = true
                }
            }
    }
}

private struct OnboardingPermissionBadge: View {
    let granted: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(granted ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(granted ? "Granted" : "Not Granted")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(granted ? Color.green : Color.orange)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .glassed(in: Capsule())
        .animation(.easeOut(duration: 0.25), value: granted)
    }
}

private struct OnboardingPageIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.white.opacity(0.8) : Color.white.opacity(0.2))
                    .frame(width: index == current ? 7 : 5, height: index == current ? 7 : 5)
                    .animation(.easeOut(duration: 0.2), value: current)
            }
        }
    }
}

private struct OnboardingSummaryRow: View {
    let icon: String
    let title: String
    let granted: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(width: 20)

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.7))

            Spacer()

            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: 14))
                .foregroundStyle(granted ? .green : .orange)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Glass Helper

extension View {
    @ViewBuilder
    func glassed<S: InsettableShape>(in shape: S) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self
                .background(shape.fill(Color.white.opacity(0.05)))
                .overlay(shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}
