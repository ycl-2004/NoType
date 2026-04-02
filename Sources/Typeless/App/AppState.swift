import Foundation

@MainActor
final class AppState: ObservableObject {
    private enum DefaultsKey {
        static let recognitionLanguage = "recognitionLanguage"
        static let chineseScriptPreference = "chineseScriptPreference"
        static let successStatusMode = "successStatusMode"
    }

    private let userDefaults: UserDefaults

    @Published var dictationState: DictationState = .idle
    @Published var lastError: DictationError?
    @Published var statusText = "Idle"
    @Published var lastTranscriptPreview: String?
    @Published var lastDebugMessage: String?
    @Published var selectedRecognitionLanguage: DictationRecognitionLanguage {
        didSet {
            userDefaults.set(selectedRecognitionLanguage.rawValue, forKey: DefaultsKey.recognitionLanguage)
            onChange?()
        }
    }
    @Published var selectedChineseScriptPreference: ChineseScriptPreference {
        didSet {
            userDefaults.set(selectedChineseScriptPreference.rawValue, forKey: DefaultsKey.chineseScriptPreference)
            onChange?()
        }
    }
    @Published var selectedSuccessStatusMode: DictationSuccessStatusMode {
        didSet {
            userDefaults.set(selectedSuccessStatusMode.rawValue, forKey: DefaultsKey.successStatusMode)
            onChange?()
        }
    }
    var onChange: (() -> Void)?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let savedValue = userDefaults.string(forKey: DefaultsKey.recognitionLanguage)
        selectedRecognitionLanguage = DictationRecognitionLanguage(rawValue: savedValue ?? "") ?? .mixed
        let savedChineseScriptPreference = userDefaults.string(forKey: DefaultsKey.chineseScriptPreference)
        selectedChineseScriptPreference = ChineseScriptPreference(rawValue: savedChineseScriptPreference ?? "") ?? .followModel
        let savedSuccessStatus = userDefaults.string(forKey: DefaultsKey.successStatusMode)
        selectedSuccessStatusMode = DictationSuccessStatusMode(rawValue: savedSuccessStatus ?? "") ?? .both
    }

    func update(for state: DictationState) {
        dictationState = state
        statusText = switch state {
        case .idle:
            "Idle"
        case .recording:
            "Recording..."
        case .transcribing:
            "Transcribing..."
        case .inserting:
            "Inserting text..."
        case let .error(error):
            error.userMessage
        }
        onChange?()
    }

    func setError(_ error: DictationError) {
        lastError = error
        update(for: .error(error))
    }

    func setTranscriptPreview(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        lastTranscriptPreview = trimmed.isEmpty ? nil : String(trimmed.prefix(120))
        onChange?()
    }

    func setDebugMessage(_ message: String) {
        lastDebugMessage = message
        onChange?()
    }

    func setRecognitionLanguage(_ language: DictationRecognitionLanguage) {
        guard selectedRecognitionLanguage != language else { return }
        selectedRecognitionLanguage = language
    }

    func setChineseScriptPreference(_ preference: ChineseScriptPreference) {
        guard selectedChineseScriptPreference != preference else { return }
        selectedChineseScriptPreference = preference
    }

    func setSuccessStatusMode(_ mode: DictationSuccessStatusMode) {
        guard selectedSuccessStatusMode != mode else { return }
        selectedSuccessStatusMode = mode
    }
}
