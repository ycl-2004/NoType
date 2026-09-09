import Foundation

enum AppLogger {
    private static let logURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("notype-debug.log")
    private static let lock = NSLock()
    static let retentionInterval: TimeInterval = 5 * 24 * 60 * 60

    static var debugLogURL: URL {
        lock.lock()
        defer { lock.unlock() }
        try? prune(at: logURL, now: Date())
        return logURL
    }

    static func log(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        // Prune before appending, including the first event after launch.
        try? prune(at: logURL, now: now)
        let timestamp = ISO8601DateFormatter().string(from: now)
        let data = Data("[\(timestamp)] \(message)\n".utf8)

        if FileManager.default.fileExists(atPath: logURL.path),
           let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            return
        }
        try? data.write(to: logURL, options: .atomic)
    }

    /// Keep multiline entries together; undated content has no retention guarantee and is dropped.
    static func prune(at url: URL, now: Date) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let original = try String(contentsOf: url, encoding: .utf8)
        let formatter = ISO8601DateFormatter()
        let cutoff = now.addingTimeInterval(-retentionInterval)
        var timestampDecisions: [String: Bool] = [:]
        var keepEntry = false
        var retained = ""
        for line in original.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.first == "[", let end = line.firstIndex(of: "]") {
                let stamp = String(line[line.index(after: line.startIndex)..<end])
                if let decision = timestampDecisions[stamp] {
                    keepEntry = decision
                } else if let timestamp = formatter.date(from: stamp) {
                    keepEntry = timestamp >= cutoff
                    timestampDecisions[stamp] = keepEntry
                }
            }
            if keepEntry {
                retained += String(line) + "\n"
            }
        }
        // split includes the empty component after a trailing newline.
        if original.hasSuffix("\n"), retained.hasSuffix("\n") {
            retained.removeLast()
        }
        if retained != original {
            try retained.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
