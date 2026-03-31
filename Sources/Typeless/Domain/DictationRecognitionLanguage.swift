import Foundation

enum DictationRecognitionLanguage: String, CaseIterable, Equatable {
    case mixed
    case english
    case chinese

    var menuTitle: String {
        switch self {
        case .mixed:
            "Auto"
        case .english:
            "English"
        case .chinese:
            "中文"
        }
    }

    var statusDescription: String {
        switch self {
        case .mixed:
            "Auto"
        case .english:
            "English"
        case .chinese:
            "Chinese"
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
}
