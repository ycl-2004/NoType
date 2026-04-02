import AppKit

enum MenuBarIconRenderer {
    struct Configuration: Equatable {
        let state: DictationState
        let recognitionLanguage: DictationRecognitionLanguage
        let chineseScriptPreference: ChineseScriptPreference
    }

    static func makeImage(for configuration: Configuration) -> NSImage? {
        let canvasSize = NSSize(width: 18, height: 18)
        let image = NSImage(size: canvasSize)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()

        guard let baseImage = baseSymbolImage(for: configuration.state) else {
            return nil
        }

        baseImage.draw(in: NSRect(x: 1, y: 1, width: 16, height: 16))

        drawMarker(
            modeMarker(for: configuration),
            in: NSRect(x: 10.5, y: 10, width: 8, height: 8),
            fontSize: configuration.recognitionLanguage == .english ? 5.4 : 7.0
        )

        if let scriptMarker = scriptMarker(for: configuration) {
            drawMarker(scriptMarker, in: NSRect(x: 10.5, y: -0.2, width: 8, height: 8), fontSize: 6.8)
        }

        image.isTemplate = true
        return image
    }

    static func modeMarker(for configuration: Configuration) -> String {
        configuration.recognitionLanguage.menuBarMarker
    }

    static func scriptMarker(for configuration: Configuration) -> String? {
        configuration.chineseScriptPreference.shouldShowMenuBarMarker(for: configuration.recognitionLanguage)
            ? configuration.chineseScriptPreference.menuBarMarker
            : nil
    }

    static func symbolName(for state: DictationState) -> String {
        switch state {
        case .idle:
            "mic"
        case .recording:
            "mic.fill"
        case .transcribing:
            "waveform"
        case .inserting:
            "arrow.right.circle.fill"
        case .error:
            "exclamationmark.circle.fill"
        }
    }

    static func baseSymbolImage(for state: DictationState) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let image = NSImage(systemSymbolName: symbolName(for: state), accessibilityDescription: "noType")
        image?.isTemplate = true
        return image?.withSymbolConfiguration(configuration)
    }

    private static func drawMarker(_ marker: String, in rect: NSRect, fontSize: CGFloat) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: style
        ]

        NSString(string: marker).draw(in: rect.offsetBy(dx: 0, dy: -0.35), withAttributes: attributes)
    }
}
