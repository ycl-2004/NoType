import Foundation

struct TranscriptResult: Equatable {
    let text: String
    let rawText: String

    init(text: String, rawText: String? = nil) {
        self.text = text
        self.rawText = rawText ?? text
    }
}
