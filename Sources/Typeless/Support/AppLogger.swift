import Foundation

enum AppLogger {
    private static let logURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("notype-debug.log")

    static var debugLogURL: URL {
        logURL
    }
    static func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        let data = Data(line.utf8)

        if FileManager.default.fileExists(atPath: logURL.path) {
            if let handle = try? FileHandle(forWritingTo: logURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                return
            }
        }

        try? data.write(to: logURL, options: .atomic)
    }
}
