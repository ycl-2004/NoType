import Foundation

/// Joins the independently decoded segments of one recording.
///
/// A segment is decoded without seeing the one after it, so the recognizer closes it with a full
/// stop even when the cut fell in the middle of a sentence. In an 86s dictation on 2026-11-26 all
/// three cuts landed mid-sentence and each produced `。 ` before the clause that continued it.
/// A comma reads acceptably either way — a real sentence end becomes a longer sentence, while a
/// stray full stop breaks one — so a Chinese full stop at a cut becomes a comma.
enum TranscriptSegmentJoiner {
    static func join(_ parts: [String]) -> String {
        let segments = parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        guard var joined = segments.first else { return "" }

        for next in segments.dropFirst() {
            if joined.hasSuffix("。") {
                joined.removeLast()
                joined += "，" + next
            } else if isHan(joined.last), isHan(next.first) {
                // Written Chinese has no word spacing to restore at the cut.
                joined += next
            } else {
                joined += " " + next
            }
        }
        return joined
    }

    private static func isHan(_ character: Character?) -> Bool {
        guard let character else { return false }
        return String(character).range(of: #"^\p{Han}$"#, options: .regularExpression) != nil
    }
}
