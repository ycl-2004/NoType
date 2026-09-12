import Foundation

enum DictationRecognitionLanguage: String, CaseIterable, Equatable {
    case mixed
    case english
    case chinese

    var menuTitle: String {
        switch self {
        case .mixed:
            "Auto (中英混说)"
        case .english:
            "English"
        case .chinese:
            "中文优先"
        }
    }

    var statusDescription: String {
        switch self {
        case .mixed:
            "Auto mixed"
        case .english:
            "English-first"
        case .chinese:
            "Chinese-first"
        }
    }

    var menuBarMarker: String {
        switch self {
        case .mixed:
            "A"
        case .english:
            "EN"
        case .chinese:
            "中"
        }
    }

    var nextCycleValue: DictationRecognitionLanguage {
        switch self {
        case .mixed:
            .chinese
        case .chinese:
            .english
        case .english:
            .mixed
        }
    }
}
