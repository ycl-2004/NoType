import Foundation

enum AppLogger {
    static let retentionInterval: TimeInterval = 5 * 24 * 60 * 60
    private static let store: RollingAppLog = {
        // Test fixtures must never mix with the running app's diagnostics.
        let isTest = ProcessInfo.processInfo.processName == "swiftpm-testing-helper"
            || CommandLine.arguments.first?.contains(".xctest") == true
        let name = isTest ? "notype-tests-\(ProcessInfo.processInfo.processIdentifier).log" : "notype-debug.log"
        return RollingAppLog(url: FileManager.default.temporaryDirectory.appendingPathComponent(name))
    }()

    static var debugLogURL: URL { store.debugLogURL }
    static func log(_ message: String) { store.log(message) }
    static func prune(at url: URL, now: Date) throws {
        try RollingAppLog.prune(at: url, now: now)
    }
}

/// Serialized, size-bounded logging with hourly maintenance rather than a full scan per event.
final class RollingAppLog: @unchecked Sendable {
    static let maximumBytes = 2 * 1_024 * 1_024
    static let maintenanceInterval: TimeInterval = 60 * 60
    private let url: URL
    private let lock = NSLock()
    private var lastMaintenance: Date?
    private let formatter = ISO8601DateFormatter()

    init(url: URL) { self.url = url }

    var debugLogURL: URL {
        lock.lock()
        defer { lock.unlock() }
        try? maintain(now: Date(), incomingBytes: 0)
        return url
    }

    func log(_ message: String, now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        let entry = "[\(formatter.string(from: now))] \(message)\n"
        let data = Data(entry.utf8)
        // One unexpected oversized message must not defeat the file size bound.
        guard data.count <= Self.maximumBytes else { return }
        do {
            try maintain(now: now, incomingBytes: data.count)
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: url, options: .atomic)
            }
        } catch {
            // Diagnostics must not break recording or insertion.
        }
    }

    private func maintain(now: Date, incomingBytes: Int) throws {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        let expired = lastMaintenance.map { now.timeIntervalSince($0) >= Self.maintenanceInterval || now < $0 } ?? true
        guard expired || size + incomingBytes > Self.maximumBytes else { return }
        // Leave headroom on size-triggered maintenance so the next event does not rescan the file.
        let budget = size + incomingBytes > Self.maximumBytes
            ? min(Self.maximumBytes / 2, Self.maximumBytes - incomingBytes)
            : Self.maximumBytes - incomingBytes
        try Self.prune(at: url, now: now, maximumBytes: budget)
        lastMaintenance = now
    }

    static func prune(at url: URL, now: Date, maximumBytes: Int = maximumBytes) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        let offset = size > UInt64(maximumBytes) ? size - UInt64(maximumBytes) : 0
        try handle.seek(toOffset: offset)
        var data = try handle.readToEnd() ?? Data()
        // If seeking into an old large file, discard the partial first line (and its continuation).
        if offset > 0 {
            if let newline = data.firstIndex(of: 10) { data = Data(data[data.index(after: newline)...]) }
            else { data = Data() }
        }
        let original = String(decoding: data, as: UTF8.self)
        let formatter = ISO8601DateFormatter()
        let cutoff = now.addingTimeInterval(-AppLogger.retentionInterval)
        var keep = false
        var retained: [String] = []
        for line in original.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.first == "[", let end = line.firstIndex(of: "]"),
               let timestamp = formatter.date(from: String(line[line.index(after: line.startIndex)..<end])) {
                keep = timestamp >= cutoff
            }
            if keep { retained.append(String(line)) }
        }
        let output = Data(retained.joined(separator: "\n").utf8)
        // Invalid UTF-8 could expand during decoding, so never write it beyond the byte budget.
        if output.count > maximumBytes {
            try Data().write(to: url, options: .atomic)
        } else if offset > 0 || output != data {
            try output.write(to: url, options: .atomic)
        }
    }
}
