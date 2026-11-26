import Foundation
import Testing
@testable import Typeless

struct ModelFileIntegrityTests {
    @Test
    func verifiesPublishedDigestAndRejectsSameSizeCorruption() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let integrity = ModelFileIntegrity(name: "fixture", size: 3,
            sha256: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        try Data("abc".utf8).write(to: url)
        try integrity.verify(at: url)
        try Data("abd".utf8).write(to: url)
        #expect(throws: TranscriptionError.self) { try integrity.verify(at: url) }
        try Data("ab".utf8).write(to: url)
        #expect(throws: TranscriptionError.self) { try integrity.verify(at: url) }
    }

    @Test
    func rememberedIdentitySkipsHashingUntilTheFileChanges() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "ModelFileIntegrityTests.\(UUID().uuidString)"
        defer {
            try? FileManager.default.removeItem(at: url)
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        let store = UserDefaultsVerifiedModelFileStore(suiteName: suite)
        let integrity = ModelFileIntegrity(name: "fixture", size: 3,
            sha256: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")

        // Unverified content is hashed and rejected, and nothing is remembered for it.
        try Data("abd".utf8).write(to: url)
        #expect(throws: TranscriptionError.self) { try integrity.verify(at: url, rememberingIn: store) }
        #expect(store.verifiedIdentity(forDigest: integrity.sha256) == nil)

        // A verified file is remembered by identity, so the next launch does not hash it.
        try Data("abc".utf8).write(to: url)
        try integrity.verify(at: url, rememberingIn: store)
        #expect(store.verifiedIdentity(forDigest: integrity.sha256) == (try ModelFileIdentity(url: url)))

        // Rewriting the file in place changes its modification time, which forces a fresh hash.
        try Data("abd".utf8).write(to: url)
        #expect(throws: TranscriptionError.self) { try integrity.verify(at: url, rememberingIn: store) }
    }

    @Test
    func rememberedIdentityIsTrustedWithoutReadingTheFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "ModelFileIntegrityTests.\(UUID().uuidString)"
        defer {
            try? FileManager.default.removeItem(at: url)
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        let store = UserDefaultsVerifiedModelFileStore(suiteName: suite)
        let integrity = ModelFileIntegrity(name: "fixture", size: 3,
            sha256: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        try Data("abd".utf8).write(to: url)
        store.remember(try ModelFileIdentity(url: url), forDigest: integrity.sha256)

        // Documents the trade: an unchanged identity is not re-read, by design.
        try integrity.verify(at: url, rememberingIn: store)
        #expect(throws: TranscriptionError.self) { try integrity.verify(at: url) }
    }

    @Test
    func downloadURLsUseImmutableRevision() {
        #expect(R2T2Paths.modelDownloadURL.path.contains(R2T2Paths.modelRevision))
        #expect(R2T2Paths.projectorDownloadURL.path.contains(R2T2Paths.modelRevision))
        #expect(!R2T2Paths.modelDownloadURL.path.contains("/main/"))
    }
}
