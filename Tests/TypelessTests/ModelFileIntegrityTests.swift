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
    func downloadURLsUseImmutableRevision() {
        #expect(R2T2Paths.modelDownloadURL.path.contains(R2T2Paths.modelRevision))
        #expect(R2T2Paths.projectorDownloadURL.path.contains(R2T2Paths.modelRevision))
        #expect(!R2T2Paths.modelDownloadURL.path.contains("/main/"))
    }
}
