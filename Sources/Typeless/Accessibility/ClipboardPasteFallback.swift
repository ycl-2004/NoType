import AppKit

@MainActor
struct ClipboardPasteFallback: FallbackTextInserter {
    private let clipboardStore: ClipboardStoring

    init(clipboardStore: ClipboardStoring = ClipboardStore()) {
        self.clipboardStore = clipboardStore
    }

    func paste(_ text: String) throws {
        try clipboardStore.setText(text)
        AppLogger.log("paste fallback: text copied to pasteboard, posting Command+V")
        try sendPasteShortcut()
    }

    private func sendPasteShortcut() throws {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw InsertionError.pasteFailed
        }

        RunLoop.current.run(until: Date().addingTimeInterval(0.08))

        let keyV: CGKeyCode = 9
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false) else {
            throw InsertionError.pasteFailed
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
