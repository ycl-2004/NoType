import AppKit

@MainActor
protocol ClipboardStoring {
    func snapshot() -> ClipboardSnapshot?
    func setText(_ text: String) throws
    func restore(_ snapshot: ClipboardSnapshot?) throws
}

struct ClipboardSnapshot {
    let items: [ClipboardSnapshotItem]
}

struct ClipboardSnapshotItem {
    let representations: [NSPasteboard.PasteboardType: Data]
}

@MainActor
struct ClipboardStore: ClipboardStoring {
    func snapshot() -> ClipboardSnapshot? {
        let pasteboard = NSPasteboard.general
        guard let items = pasteboard.pasteboardItems else {
            return nil
        }

        let snapshotItems = items.map { item in
            let representations = item.types.reduce(into: [NSPasteboard.PasteboardType: Data]()) { partialResult, type in
                if let data = item.data(forType: type) {
                    partialResult[type] = data
                }
            }
            return ClipboardSnapshotItem(representations: representations)
        }

        return ClipboardSnapshot(items: snapshotItems)
    }

    func setText(_ text: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard pasteboard.setString(text, forType: .string) else {
            throw InsertionError.pasteFailed
        }
    }

    func restore(_ snapshot: ClipboardSnapshot?) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard let snapshot, snapshot.items.isEmpty == false else {
            return
        }

        let restoredItems = snapshot.items.map { snapshotItem in
            let item = NSPasteboardItem()
            for (type, data) in snapshotItem.representations {
                item.setData(data, forType: type)
            }
            return item
        }

        guard pasteboard.writeObjects(restoredItems) else {
            throw InsertionError.pasteFailed
        }
    }
}
