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

    /// Hashes only when the file on disk is not the one this digest was last verified against.
    ///
    /// Hashing both R2T2 files at utility priority held every launch in "Preparing" for about 35s
    /// (observed 2026-11-26), although the files had not changed since they were installed. The
    /// identity check is one `stat`. Rewriting or replacing a file changes its file number or
    /// modification time, so a re-download, a partial write or a swapped file is still hashed.
    /// This guards against damaged downloads, not against someone who can already write to the
    /// user's files: such a writer could also restore a modification time.
    func verify(at url: URL, rememberingIn store: some VerifiedModelFileStore) throws {
        if let identity = try? ModelFileIdentity(url: url),
           identity.size == size,
           store.verifiedIdentity(forDigest: sha256) == identity {
            return
        }
        try verify(at: url)
        if let identity = try? ModelFileIdentity(url: url) {
            store.remember(identity, forDigest: sha256)
        }
    }

    private func failure() -> TranscriptionError {
        .modelUnavailable("\(name) failed its size or SHA-256 check. Remove R2T2 in Manage Downloaded Models, then retry preparation to download a verified copy.")
    }
}

/// What a verified file looked like on disk. The path is deliberately left out: installation
/// renames the verified download into place, which keeps the file number and modification time.
struct ModelFileIdentity: Codable, Equatable, Sendable {
    let deviceNumber: UInt64
    let fileNumber: UInt64
    let size: Int64
    let modificationTime: TimeInterval

    init(url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let device = attributes[.systemNumber] as? NSNumber,
              let file = attributes[.systemFileNumber] as? NSNumber,
              let size = attributes[.size] as? NSNumber,
              let modified = attributes[.modificationDate] as? Date else {
            throw CocoaError(.fileReadUnknown)
        }
        deviceNumber = device.uint64Value
        fileNumber = file.uint64Value
        self.size = size.int64Value
        modificationTime = modified.timeIntervalSince1970
    }
}

protocol VerifiedModelFileStore: Sendable {
    func verifiedIdentity(forDigest digest: String) -> ModelFileIdentity?
    func remember(_ identity: ModelFileIdentity, forDigest digest: String)
}

/// Keyed by the expected digest, so pinning a new model revision never reuses an old result.
struct UserDefaultsVerifiedModelFileStore: VerifiedModelFileStore {
    /// `nil` uses the app's standard defaults; tests pass their own suite.
    let suiteName: String?

    init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    func verifiedIdentity(forDigest digest: String) -> ModelFileIdentity? {
        guard let data = defaults.data(forKey: key(digest)) else { return nil }
        return try? JSONDecoder().decode(ModelFileIdentity.self, from: data)
    }

    func remember(_ identity: ModelFileIdentity, forDigest digest: String) {
        guard let data = try? JSONEncoder().encode(identity) else { return }
        defaults.set(data, forKey: key(digest))
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    private func key(_ digest: String) -> String {
        "verifiedModelFile.\(digest)"
    }
}
