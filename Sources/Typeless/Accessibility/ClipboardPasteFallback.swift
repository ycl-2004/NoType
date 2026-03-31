import AppKit

@MainActor
struct ClipboardPasteFallback: FallbackTextInserter {
    private let clipboardStore: ClipboardStoring

    init(clipboardStore: ClipboardStoring = ClipboardStore()) {
        self.clipboardStore = clipboardStore
    }

    func paste(_ text: String, preserveClipboard: Bool) throws {
        let snapshot = preserveClipboard ? clipboardStore.snapshot() : nil
        try clipboardStore.setText(text)
        AppLogger.log("paste fallback: text copied to pasteboard, posting Command+V")
        try sendPasteShortcut()

        guard preserveClipboard else {
            return
        }

        // Give the target app a moment to read the transient pasteboard contents.
        RunLoop.current.run(until: Date().addingTimeInterval(0.12))
        try clipboardStore.restore(snapshot)
        AppLogger.log("paste fallback: original clipboard restored")
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
