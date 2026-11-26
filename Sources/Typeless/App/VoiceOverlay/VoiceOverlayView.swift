import SwiftUI

struct VoiceOverlayView: View {
    @ObservedObject var appState: AppState
    let status: VoiceOverlayStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let capsuleHeight: CGFloat = 36
    /// Long live transcripts are cut at the start, so the newest words stay visible.
    static let maximumCapsuleWidth: CGFloat = 440
    /// The capsule draws its own shadow, so the transparent panel leaves room for it.
    static let shadowMargin: CGFloat = 12
    static let size = CGSize(
        width: maximumCapsuleWidth + 2 * shadowMargin,
        height: capsuleHeight + 2 * shadowMargin
    )

    private var accent: Color {
        if status.isFailure { return Color(red: 0.96, green: 0.51, blue: 0.45) }
        if status == .inserted || status == .copied { return Color(red: 0.48, green: 0.81, blue: 0.63) }
        return Color(red: 0.24, green: 0.60, blue: 1)
    }

    /// While recording, the moving waveform already says "listening"; a text label beside it only
    /// repeated that. The capsule shows the waveform alone, or the waveform and the live text.
    private var visibleText: String? {
        guard status == .recording else { return status.text }
        return appState.showsLiveTranscript ? appState.liveTranscriptPreview : nil
    }

    var body: some View {
        HStack(spacing: 10) {
            indicator
            if let visibleText {
                Text(visibleText)
                    .font(.system(size: 13, weight: status == .recording ? .regular : .semibold))
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .padding(.horizontal, 16)
        .frame(minWidth: Self.capsuleHeight, minHeight: Self.capsuleHeight, maxHeight: Self.capsuleHeight)
        .foregroundStyle(Color(white: 0.94))
        // The 1 pt accent ring is a filled capsule behind an inset one rather than a stroke: a
        // stroked capsule rendered stray vertical segments at its ends in native captures.
        .background {
            ZStack {
                Capsule().fill(accent.opacity(0.9))
                Capsule().fill(Color(red: 0.10, green: 0.11, blue: 0.14)).padding(1)
            }
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.28), radius: 6, y: 2)
        // Proposing the maximum width lets short content hug while long text truncates.
        .padding(Self.shadowMargin)
        .frame(width: Self.size.width, height: Self.size.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(appState.liveTranscriptPreview.map { "\(status.text): \($0)" } ?? status.text)
    }

    @ViewBuilder
    private var indicator: some View {
        if status == .recording {
            if reduceMotion {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))
            } else {
                HStack(spacing: 3) {
                    ForEach(0..<5) { index in
                        Capsule()
                            .frame(width: 3, height: 4 + 16 * appState.voiceAudioLevels[index])
                    }
                }
                .frame(height: 20)
                .animation(.easeOut(duration: 0.10), value: appState.voiceAudioLevels)
            }
        } else if !status.isTransient && status != .hidden {
            if reduceMotion {
                Image(systemName: "ellipsis")
            } else {
                ProcessingIndicator()
            }
        } else {
            Image(systemName: resultSymbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
        }
    }

    private var resultSymbol: String {
        if status.isFailure { return "exclamationmark" }
        return switch status {
        case .noSpeech: "mic.slash"
        case .cancelled: "xmark"
        default: "checkmark"
        }
    }
}

private struct ProcessingIndicator: View {
    @State private var spinning = false

    var body: some View {
        Circle()
            .trim(from: 0.05, to: 0.78)
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
    }
}
