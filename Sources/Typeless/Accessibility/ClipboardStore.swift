import AppKit

@MainActor
protocol ClipboardStoring {
    func setText(_ text: String) throws
}

@MainActor
struct ClipboardStore: ClipboardStoring {
    func setText(_ text: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard pasteboard.setString(text, forType: .string) else {
            throw InsertionError.pasteFailed
        }
    }
}
