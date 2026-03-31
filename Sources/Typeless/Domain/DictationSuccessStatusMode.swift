import Foundation

enum DictationSuccessStatusMode: String, CaseIterable, Equatable {
    case both
    case transcriptCopied
    case transcriptInserted

    var menuTitle: String {
        switch self {
        case .both:
            "Both"
        case .transcriptCopied:
            "Transcript Copied"
        case .transcriptInserted:
            "Transcript Inserted"
        }
    }

    var statusText: String {
        switch self {
        case .both:
            "Transcript copied and inserted"
        case .transcriptCopied:
            "Transcript copied"
        case .transcriptInserted:
            "Transcript inserted"
        }
    }
}
