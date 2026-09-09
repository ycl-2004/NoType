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
