import Foundation
import Testing
@testable import Typeless

struct AppLoggerTests {
    @Test
    func removesExpiredEntriesAndPreservesRecentMultilineEntries() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let formatter = ISO8601DateFormatter()
        let now = formatter.date(from: "2026-09-09T12:00:00Z")!
        let original = """
        undated old data
        [2026-09-04T11:59:59Z] expired
        expired continuation
        [2026-09-04T12:00:00Z] boundary
        boundary continuation
        [2026-09-09T11:00:00Z] recent

        """
        try original.write(to: url, atomically: true, encoding: .utf8)
        try AppLogger.prune(at: url, now: now)
        let result = try String(contentsOf: url, encoding: .utf8)
        #expect(result == "[2026-09-04T12:00:00Z] boundary\nboundary continuation\n[2026-09-09T11:00:00Z] recent\n")
        try AppLogger.prune(at: url, now: now.addingTimeInterval(AppLogger.retentionInterval))
        #expect(try String(contentsOf: url, encoding: .utf8) == "")
    }
}

struct RollingAppLogTests {
    @Test
    func testsUseASeparateDiagnosticLog() {
        #expect(AppLogger.debugLogURL.lastPathComponent.hasPrefix("notype-tests-"))
    }

    @Test
    func boundsLargeLogsAndPreservesNewestEntry() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let now = Date()
        let entry = "[\(ISO8601DateFormatter().string(from: now))] \(String(repeating: "x", count: 1_024))\n"
        try String(repeating: entry, count: 3_000).write(to: url, atomically: true, encoding: .utf8)
        let log = RollingAppLog(url: url)
        log.log("newest", now: now)
        let data = try Data(contentsOf: url)
        #expect(data.count <= RollingAppLog.maximumBytes)
        #expect(String(decoding: data, as: UTF8.self).hasSuffix("newest\n"))
    }

    @Test
    func maintenanceRunsHourlyInsteadOfOnEveryEntry() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let now = Date()
        let log = RollingAppLog(url: url)
        log.log("first", now: now)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("[2000-01-01T00:00:00Z] expired\n".utf8))
        try handle.close()
        log.log("second", now: now.addingTimeInterval(1))
        #expect(try String(contentsOf: url, encoding: .utf8).contains("expired"))
        log.log("third", now: now.addingTimeInterval(RollingAppLog.maintenanceInterval + 1))
        #expect(try !String(contentsOf: url, encoding: .utf8).contains("expired"))
    }
}
