import Foundation
import Testing
@testable import Typeless

@MainActor
struct AppStateTests {
    @Test
    func localModelReadinessStartsWaitingAndPublishesChanges() {
        let appState = AppState()
        var changeCount = 0
        appState.onChange = { changeCount += 1 }

        #expect(appState.localModelReadiness == .waiting)

        appState.setLocalModelReadiness(.preparing)

        #expect(appState.localModelReadiness == .preparing)
        #expect(changeCount == 1)
    }

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
    func defaultsDictationShortcutToDoubleCommandAndRecognitionModeOff() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let appState = AppState(userDefaults: defaults)

        #expect(appState.dictationShortcuts == [ShortcutBinding(modifier: .command, pressStyle: .double)])
        #expect(appState.recognitionModeShortcuts.isEmpty)
    }

    @Test
    func loadsSavedShortcutBindingsFromUserDefaults() throws {
        let defaults = UserDefaults(suiteName: #function)!
        let dictation = ShortcutBinding(
            keyCode: 14,
            keyName: "E",
            modifiers: [.leftCommand, .rightOption],
            pressStyle: .single
        )
        let recognition = ShortcutBinding(modifier: .rightControl, pressStyle: .double)
        defaults.set(try JSONEncoder().encode([dictation]), forKey: "dictationShortcuts")
        defaults.set(try JSONEncoder().encode([recognition]), forKey: "recognitionModeShortcuts")
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let appState = AppState(userDefaults: defaults)

        #expect(appState.dictationShortcuts == [dictation])
        #expect(appState.recognitionModeShortcuts == [recognition])
    }

    @Test
    func persistsMultipleShortcutBindingsAndCanDisableThem() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let appState = AppState(userDefaults: defaults)
        let first = ShortcutBinding(modifier: .command, pressStyle: .double)
        let second = ShortcutBinding(
            keyCode: 14,
            keyName: "E",
            modifiers: [.leftCommand, .rightOption],
            pressStyle: .single
        )
        appState.addDictationShortcut(second)
        appState.addRecognitionModeShortcut(first)

        let restoredState = AppState(userDefaults: defaults)
        #expect(restoredState.dictationShortcuts.count == 2)
        #expect(restoredState.recognitionModeShortcuts == [first])

        restoredState.removeDictationShortcut(at: 0)
        restoredState.disableRecognitionModeShortcuts()
        #expect(restoredState.dictationShortcuts == [second])
        #expect(restoredState.recognitionModeShortcuts.isEmpty)
    }

    @Test
    func removesTheOldFixedShortcutDefaults() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.set(true, forKey: "dictationShortcutEnabled")
        defaults.set("doubleOption", forKey: "dictationShortcutChoice")
        defaults.set("commandShiftY", forKey: "recognitionModeShortcutChoice")
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let appState = AppState(userDefaults: defaults)

        #expect(appState.dictationShortcuts == [ShortcutBinding(modifier: .command, pressStyle: .double)])
        #expect(appState.recognitionModeShortcuts.isEmpty)
    }
}
