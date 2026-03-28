import SwiftUI

enum IndicatorState: Equatable {
    case recording(level: Float)
    case processing
    case done(text: String)
}

struct FloatingIndicatorView: View {
    let state: IndicatorState
    @State private var animatingDots = false
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            // Left icon
            Group {
                switch state {
                case .recording:
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                        .scaleEffect(pulse ? 1.3 : 1.0)
                        .opacity(pulse ? 0.7 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: pulse
                        )
                        .onAppear { pulse = true }
                case .processing:
                    ProgressView()
                        .controlSize(.small)
                case .done:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 16))
                }
            }
            .frame(width: 18)

            // Content
            switch state {
            case .recording(let level):
                // Waveform bars
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.primary.opacity(0.9))
                            .frame(width: 4, height: barHeight(for: i, level: level))
                            .animation(.easeOut(duration: 0.08), value: level)
                    }
                }
                .frame(height: 24)

                Text("Listening...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)

            case .processing:
                Text("Transcribing")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(.primary.opacity(0.6))
                            .frame(width: 4, height: 4)
                            .offset(y: animatingDots ? -3 : 3)
                            .animation(
                                .easeInOut(duration: 0.4)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.15),
                                value: animatingDots
                            )
                    }
                }
                .onAppear { animatingDots = true }

            case .done(let text):
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 340)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .modifier(GlassCapsuleModifier())
    }

    private func barHeight(for index: Int, level: Float) -> CGFloat {
        let base: CGFloat = 5
        let maxExtra: CGFloat = 19
        // Amplify the level so even quiet speech shows movement
        let amplified = min(pow(level, 0.5) * 1.5, 1.0)
        // Each bar has a different phase for a wave-like look
        let phase = Double(index) * 1.2 + Double(amplified) * 12.0
        let wave = (sin(phase) + 1) / 2  // 0...1
        // Even at zero level, bars should jitter slightly when recording
        let jitter: CGFloat = index % 2 == 0 ? 2 : 0
        return base + jitter + maxExtra * CGFloat(amplified) * wave
    }
}

// MARK: - Liquid Glass with fallback

private struct GlassCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.blue.opacity(0.15)), in: .capsule)
        } else {
            content
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                }
        }
    }
}
