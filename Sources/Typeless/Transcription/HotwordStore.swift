import Foundation

/// The user's hotwords for R2T2: a plain text file with one term per line, read at the start of
/// each dictation so edits apply without restarting NoType.
///
/// The list is sent as system-turn context under a 「热词：」 header, one term per line. Measured on
/// five read passages (2026-11-26), that layout fixed "Ghostty" and restored "DMA"/"CPU" casing,
/// while the same terms on one comma-separated line changed nothing. Terms that sound like ordinary
/// words (parser → parse, NoType → no type) were not fixed. See ADR-013.
struct HotwordStore: Sendable {
    /// Every decode carries the list, including each live preview, so its size is bounded.
    static let maximumCharacters = 1_000
    static let header = "热词："

    static let template = """
    # NoType hotwords for R2T2: one term per line, spelled the way you want it written.
    # Names and technical terms help most; common words can make the model insert them unprompted.
    # Lines starting with # are ignored. Changes apply to the next dictation.

    """

    let fileURL: URL

    static var standard: HotwordStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return HotwordStore(
            fileURL: support
                .appendingPathComponent("NoType", isDirectory: true)
                .appendingPathComponent("hotwords.txt")
        )
    }

    /// Terms in file order, trimmed, without blank lines, `#` comments, or repeats.
    func terms() -> [String] {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        var seen = Set<String>()
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.isEmpty == false && $0.hasPrefix("#") == false && seen.insert($0).inserted }
    }

    /// The system-turn context for R2T2, or an empty string when there are no terms.
    func promptContext() -> String {
        Self.promptContext(for: terms())
    }

    static func promptContext(for terms: [String]) -> String {
        var lines: [String] = []
        var length = header.count
        for term in terms {
            length += term.count + 1
            guard length <= maximumCharacters else { break }
            lines.append(term)
        }
        guard lines.isEmpty == false else { return "" }
        return ([header] + lines).joined(separator: "\n")
    }

    /// Creates the file with brief instructions, so the menu always has something to open.
    func createFileIfMissing() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) == false else { return }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Self.template.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
