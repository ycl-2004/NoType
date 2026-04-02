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
            "英文优先"
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

    var whisperLanguageCode: String? {
        switch self {
        case .mixed:
            nil
        case .english:
            "en"
        case .chinese:
            "zh"
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
}
