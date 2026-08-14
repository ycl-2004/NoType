import Foundation
import Testing
@testable import Typeless

@MainActor
struct AppStateTests {
    @Test
    func updatesStatusTextForRecordingState() {
        let appState = AppState()

        appState.update(for: .recording)

        #expect(appState.statusText == "Recording...")
    }

    @Test
    func defaultsRecognitionLanguageToMixed() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let appState = AppState(userDefaults: defaults)

        #expect(appState.selectedRecognitionLanguage == DictationRecognitionLanguage.mixed)
        #expect(appState.selectedRecognitionLanguage.menuTitle == "Auto (中英混说)")
    }

    @Test
    func loadsSavedRecognitionLanguageFromUserDefaults() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.set(DictationRecognitionLanguage.chinese.rawValue, forKey: "recognitionLanguage")
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let appState = AppState(userDefaults: defaults)

        #expect(appState.selectedRecognitionLanguage == DictationRecognitionLanguage.chinese)
    }

    @Test
    func defaultsChineseScriptPreferenceToFollowModel() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let appState = AppState(userDefaults: defaults)

        #expect(appState.selectedChineseScriptPreference == .followModel)
    }

    @Test
    func loadsSavedChineseScriptPreferenceFromUserDefaults() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.set(ChineseScriptPreference.traditional.rawValue, forKey: "chineseScriptPreference")
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let appState = AppState(userDefaults: defaults)

        #expect(appState.selectedChineseScriptPreference == .traditional)
    }

    @Test
    func defaultsSuccessStatusModeToBoth() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let appState = AppState(userDefaults: defaults)

        #expect(appState.selectedSuccessStatusMode == .both)
    }

    @Test
    func loadsSavedSuccessStatusModeFromUserDefaults() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.set(DictationSuccessStatusMode.transcriptCopied.rawValue, forKey: "successStatusMode")
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let appState = AppState(userDefaults: defaults)

        #expect(appState.selectedSuccessStatusMode == .transcriptCopied)
    }

    @Test
    func defaultsDictationShortcutToEnabledDoubleCommand() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let appState = AppState(userDefaults: defaults)

        #expect(appState.selectedDictationShortcut == .doubleCommand)
        #expect(appState.selectedRecognitionModeShortcut == .commandShiftY)
    }

    @Test
    func loadsSavedShortcutChoicesFromUserDefaults() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.set(DictationShortcutChoice.doubleOption.rawValue, forKey: "dictationShortcutChoice")
        defaults.set(RecognitionModeShortcutChoice.commandOptionY.rawValue, forKey: "recognitionModeShortcutChoice")
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let appState = AppState(userDefaults: defaults)

        #expect(appState.selectedDictationShortcut == .doubleOption)
        #expect(appState.selectedRecognitionModeShortcut == .commandOptionY)
    }

    @Test
    func persistsIndependentDisabledShortcutChoices() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let appState = AppState(userDefaults: defaults)
        appState.setDictationShortcut(.disabled)
        appState.setRecognitionModeShortcut(.disabled)

        let restoredState = AppState(userDefaults: defaults)
        #expect(restoredState.selectedDictationShortcut == .disabled)
        #expect(restoredState.selectedRecognitionModeShortcut == .disabled)
    }

    @Test
    func migratesLegacyShortcutEnablementWithoutLosingDisabledState() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.set(true, forKey: "dictationShortcutEnabled")
        defaults.set(false, forKey: "recognitionModeShortcutEnabled")
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let appState = AppState(userDefaults: defaults)

        #expect(appState.selectedDictationShortcut == .doubleCommand)
        #expect(appState.selectedRecognitionModeShortcut == .disabled)
    }
}
