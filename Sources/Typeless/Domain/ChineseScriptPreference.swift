import Foundation

enum ChineseScriptPreference: String, CaseIterable, Equatable {
    case followModel
    case simplified
    case traditional

    var menuTitle: String {
        switch self {
        case .followModel:
            "Follow model"
        case .simplified:
            "简体"
        case .traditional:
            "繁體"
        }
    }

    var statusDescription: String {
        switch self {
        case .followModel:
            "Follow model"
        case .simplified:
            "Simplified Chinese"
        case .traditional:
            "Traditional Chinese"
        }
    }
}
