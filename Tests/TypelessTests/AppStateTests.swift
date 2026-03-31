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
}
