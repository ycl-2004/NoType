import SwiftUI

struct VoiceOverlayView: View {
    @ObservedObject var appState: AppState
    let status: VoiceOverlayStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let size = CGSize(width: 360, height: 48)

    private var accent: Color {
        if status.isFailure { return Color(red: 0.96, green: 0.51, blue: 0.45) }
        if status == .inserted || status == .copied { return Color(red: 0.48, green: 0.81, blue: 0.63) }
        return Color(red: 0.24, green: 0.60, blue: 1)
    }

    var body: some View {
        HStack(spacing: 12) {
            indicator.frame(width: 24, height: 24)
            if status == .recording,
               appState.showsLiveTranscript,
               let liveTranscript = appState.liveTranscriptPreview {
                HStack(spacing: 8) {
                    Text(status.text)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                    MarqueeText(text: liveTranscript)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: Self.size.width - 54, alignment: .leading)
            } else {
                Text(status.text)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .foregroundStyle(Color(white: 0.94))
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color(red: 0.10, green: 0.11, blue: 0.14).opacity(0.96), in: Capsule())
        .overlay(Capsule().strokeBorder(accent.opacity(0.9), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(appState.liveTranscriptPreview.map { "\(status.text): \($0)" } ?? status.text)
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

private struct MarqueeText: View {
    private static let gap: CGFloat = 44
    private static let speed: CGFloat = 34

    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0
    @State private var animationStart = Date()

    var body: some View {
        GeometryReader { proxy in
            let shouldScroll = textWidth > proxy.size.width + 1
            ZStack(alignment: .leading) {
                if shouldScroll && !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                        let cycle = textWidth + Self.gap
                        let elapsed = max(0, context.date.timeIntervalSince(animationStart))
                        let distance = cycle > 0
                            ? (elapsed * Self.speed).truncatingRemainder(dividingBy: cycle)
                            : 0
                        HStack(spacing: Self.gap) {
                            label
                            label
                        }
                        .fixedSize()
                        .offset(x: -distance)
                    }
                } else {
                    Text(text)
                        .font(.system(size: 12, weight: .regular))
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            .frame(width: proxy.size.width, height: 18, alignment: .leading)
            .clipped()
        }
        .frame(height: 18)
        .background(
            Text(text)
                .font(.system(size: 12, weight: .regular))
                .lineLimit(1)
                .fixedSize()
                .hidden()
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: MarqueeTextWidthKey.self, value: proxy.size.width)
                    }
                )
        )
        .onPreferenceChange(MarqueeTextWidthKey.self) { width in
            guard abs(textWidth - width) > 0.5 else { return }
            textWidth = width
            animationStart = .now
        }
        .onChange(of: text) { _, _ in
            animationStart = .now
        }
        .accessibilityLabel(text)
    }

    private var label: some View {
        Text(text)
            .font(.system(size: 12, weight: .regular))
            .lineLimit(1)
            .fixedSize()
    }
}

private struct MarqueeTextWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
