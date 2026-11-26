import Foundation
import Testing
@testable import Typeless

struct HotwordStoreTests {
    private func makeStore(_ contents: String?) throws -> HotwordStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("notype-hotwords-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("hotwords.txt")
        if let contents {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
        return HotwordStore(fileURL: url)
    }

    @Test
    func termsSkipCommentsBlanksAndRepeats() throws {
        let store = try makeStore("# comment\n  Ghostty  \n\nClaude Code\r\n千问\nGhostty\n#R2T2\n")
        #expect(store.terms() == ["Ghostty", "Claude Code", "千问"])
    }

    @Test
    func contextPutsOneTermPerLineUnderTheHeader() throws {
        let store = try makeStore("Ghostty\nClaude Code\n")
        #expect(store.promptContext() == "热词：\nGhostty\nClaude Code")
    }

    @Test
    func noTermsMeansNoContext() throws {
        #expect(try makeStore(nil).promptContext() == "")
        #expect(try makeStore(HotwordStore.template).terms().isEmpty)
    }

    @Test
    func contextStaysWithinTheCharacterBudget() {
        let terms = (0..<400).map { "term\($0)" }
        let context = HotwordStore.promptContext(for: terms)
        #expect(context.count <= HotwordStore.maximumCharacters)
        #expect(context.hasPrefix("热词：\nterm0\nterm1\n"))
    }

    @Test
    func createFileIfMissingWritesTheTemplateOnceAndKeepsEdits() throws {
        let store = try makeStore(nil)
        try store.createFileIfMissing()
        #expect(try String(contentsOf: store.fileURL, encoding: .utf8) == HotwordStore.template)
        try "Grok\n".write(to: store.fileURL, atomically: true, encoding: .utf8)
        try store.createFileIfMissing()
        #expect(store.terms() == ["Grok"])
    }
}
