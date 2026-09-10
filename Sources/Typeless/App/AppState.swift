import Foundation

@MainActor
final class AppState: ObservableObject {
    private enum DefaultsKey {
        static let recognitionLanguage = "recognitionLanguage"
        static let chineseScriptPreference = "chineseScriptPreference"
        static let successStatusMode = "successStatusMode"
        static let transcriptionEngine = "transcriptionEngine"
        static let dictationShortcuts = "dictationShortcuts"
        static let recognitionModeShortcuts = "recognitionModeShortcuts"
    }

    private let userDefaults: UserDefaults

    @Published var dictationState: DictationState = .idle
    @Published var lastError: DictationError?
    @Published var statusText = "Idle"
    @Published var lastTranscriptPreview: String?
    @Published var lastDebugMessage: String?
    @Published private(set) var localModelReadiness: LocalModelReadiness = .waiting
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
    @Published var selectedTranscriptionEngine: TranscriptionEngineChoice {
        didSet {
            userDefaults.set(selectedTranscriptionEngine.rawValue, forKey: DefaultsKey.transcriptionEngine)
            onChange?()
        }
    }
    @Published var selectedSuccessStatusMode: DictationSuccessStatusMode {
        didSet {
            userDefaults.set(selectedSuccessStatusMode.rawValue, forKey: DefaultsKey.successStatusMode)
            onChange?()
        }
    }
    @Published var dictationShortcuts: [ShortcutBinding] {
        didSet {
            saveShortcuts(dictationShortcuts, key: DefaultsKey.dictationShortcuts)
            onChange?()
        }
    }
    @Published var recognitionModeShortcuts: [ShortcutBinding] {
        didSet {
            saveShortcuts(recognitionModeShortcuts, key: DefaultsKey.recognitionModeShortcuts)
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
        selectedTranscriptionEngine = Self.loadTranscriptionEngine(from: userDefaults)
        let savedSuccessStatus = userDefaults.string(forKey: DefaultsKey.successStatusMode)
        selectedSuccessStatusMode = DictationSuccessStatusMode(rawValue: savedSuccessStatus ?? "") ?? .both
        dictationShortcuts = Self.loadShortcuts(from: userDefaults, key: DefaultsKey.dictationShortcuts)
            ?? [ShortcutBinding(modifier: .command, pressStyle: .double)]
        // Recognition mode shortcuts are optional. The old fixed shortcut is intentionally not
        // migrated because it is being removed from the client-facing configuration.
        recognitionModeShortcuts = Self.loadShortcuts(from: userDefaults, key: DefaultsKey.recognitionModeShortcuts) ?? []
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

    func setLocalModelReadiness(_ readiness: LocalModelReadiness) {
        guard localModelReadiness != readiness else { return }
        localModelReadiness = readiness
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

    func setTranscriptionEngine(_ engine: TranscriptionEngineChoice) {
        guard selectedTranscriptionEngine != engine else { return }
        selectedTranscriptionEngine = engine
    }

    func setSuccessStatusMode(_ mode: DictationSuccessStatusMode) {
        guard selectedSuccessStatusMode != mode else { return }
        selectedSuccessStatusMode = mode
    }

    func addDictationShortcut(_ shortcut: ShortcutBinding) {
        guard dictationShortcuts.contains(where: { $0.conflicts(with: shortcut) }) == false else { return }
        dictationShortcuts.append(shortcut)
    }

    func removeDictationShortcut(at index: Int) {
        guard dictationShortcuts.indices.contains(index) else { return }
        dictationShortcuts.remove(at: index)
    }

    func disableDictationShortcuts() {
        dictationShortcuts = []
    }

    func addRecognitionModeShortcut(_ shortcut: ShortcutBinding) {
        guard recognitionModeShortcuts.contains(where: { $0.conflicts(with: shortcut) }) == false else { return }
        recognitionModeShortcuts.append(shortcut)
    }

    func removeRecognitionModeShortcut(at index: Int) {
        guard recognitionModeShortcuts.indices.contains(index) else { return }
        recognitionModeShortcuts.remove(at: index)
    }

    func disableRecognitionModeShortcuts() {
        recognitionModeShortcuts = []
    }

    var dictationShortcutMenuTitle: String {
        shortcutMenuTitle(for: dictationShortcuts)
    }

    var recognitionModeShortcutMenuTitle: String {
        shortcutMenuTitle(for: recognitionModeShortcuts)
    }

    /// A saved preference for macOS Speech is ignored on a Mac that cannot run it, so moving a
    /// settings file to an older system degrades to Qwen3-ASR instead of failing. The old
    /// `bundledWhisper` raw value is migrated so existing installs keep a working local engine.
    private static func loadTranscriptionEngine(from userDefaults: UserDefaults) -> TranscriptionEngineChoice {
        guard let rawValue = userDefaults.string(forKey: DefaultsKey.transcriptionEngine) else {
            return .defaultChoice
        }

        let saved: TranscriptionEngineChoice?
        if rawValue == "bundledWhisper" {
            saved = .qwen3ASR
        } else {
            saved = TranscriptionEngineChoice(rawValue: rawValue)
        }

        guard let saved else { return .defaultChoice }

        if saved == .appleSpeech, TranscriptionEngineChoice.isAppleSpeechAvailable == false {
            return .qwen3ASR
        }
        return saved
    }

    private static func loadShortcuts(from userDefaults: UserDefaults, key: String) -> [ShortcutBinding]? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([ShortcutBinding].self, from: data)
    }

    private func saveShortcuts(_ shortcuts: [ShortcutBinding], key: String) {
        guard let data = try? JSONEncoder().encode(shortcuts) else { return }
        userDefaults.set(data, forKey: key)
    }

    private func shortcutMenuTitle(for shortcuts: [ShortcutBinding]) -> String {
        switch shortcuts.count {
        case 0:
            "Off"
        case 1:
            shortcuts[0].menuTitle
        default:
            "\(shortcuts.count) Shortcuts"
        }
    }
}
