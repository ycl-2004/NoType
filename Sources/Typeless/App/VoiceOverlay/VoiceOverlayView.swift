import SwiftUI

struct VoiceOverlayView: View {
    @ObservedObject var appState: AppState
    let status: VoiceOverlayStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let size = CGSize(width: 160, height: 40)

    private var accent: Color {
        if status.isFailure { return Color(red: 0.96, green: 0.51, blue: 0.45) }
        if status == .inserted || status == .copied { return Color(red: 0.48, green: 0.81, blue: 0.63) }
        return Color(red: 0.24, green: 0.60, blue: 1)
    }

    var body: some View {
        HStack(spacing: 12) {
            indicator.frame(width: 24, height: 24)
            Text(status.text)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(Color(white: 0.94))
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color(red: 0.10, green: 0.11, blue: 0.14).opacity(0.96), in: Capsule())
        .overlay(Capsule().strokeBorder(accent.opacity(0.9), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.text)
    }

    @ViewBuilder
    private var indicator: some View {
        if status == .recording {
            if reduceMotion {
                Image(systemName: "waveform")
            } else {
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Capsule()
                            .frame(width: 3, height: 4 + 20 * appState.voiceAudioLevels[index])
                    }
                }
                .animation(.easeOut(duration: 0.10), value: appState.voiceAudioLevels)
            }
        } else if !status.isTransient && status != .hidden {
            if reduceMotion {
                Image(systemName: "ellipsis")
            } else {
                ProcessingIndicator()
            }
        } else {
            Image(systemName: status.isFailure ? "exclamationmark" : (status == .noSpeech ? "mic.slash" : "checkmark"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
        }
    }
}

private struct ProcessingIndicator: View {
    @State private var spinning = false

    var body: some View {
        Circle()
            .trim(from: 0.05, to: 0.78)
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 16, height: 16)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
    }
}
