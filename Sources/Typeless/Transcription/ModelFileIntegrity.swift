import CryptoKit
import Foundation

/// Streaming hashing bounds verification memory regardless of model size.
/// https://developer.apple.com/documentation/cryptokit/sha256
struct ModelFileIntegrity: Sendable {
    let name: String
    let size: Int64
    let sha256: String

    func verify(at url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              (attributes[.size] as? NSNumber)?.int64Value == size else {
            throw failure()
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            try Task.checkCancellation()
            hash.update(data: chunk)
        }
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest == sha256 else { throw failure() }
    }

    private func failure() -> TranscriptionError {
        .modelUnavailable("\(name) failed its size or SHA-256 check. Remove R2T2 in Manage Downloaded Models, then retry preparation to download a verified copy.")
    }
}
