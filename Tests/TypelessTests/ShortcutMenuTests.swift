import Foundation
import Testing
@testable import Typeless

@MainActor
struct ShortcutMenuTests {
    @Test
    func recognitionLanguageCyclesInApprovedOrder() {
        #expect(DictationRecognitionLanguage.mixed.nextCycleValue == .chinese)
        #expect(DictationRecognitionLanguage.chinese.nextCycleValue == .english)
        #expect(DictationRecognitionLanguage.english.nextCycleValue == .mixed)
    }

    @Test
    func shortcutMenuShowsDictationShortcutKeyWhenEnabled() {
        #expect(
            MenuBarController.shortcutMenuTitle(for: .dictation, isEnabled: true) ==
                "Dictation Shortcut: Command + Shift + H"
        )
    }

    @Test
    func shortcutMenuShowsDisabledWhenRecognitionModeShortcutIsOff() {
        #expect(
            MenuBarController.shortcutMenuTitle(for: .recognitionMode, isEnabled: false) ==
                "Recognition Mode Shortcut: Disabled"
        )
    }

    @Test
    func togglingDictationShortcutUpdatesAppState() {
        let appState = makeShortcutMenuAppState()
        appState.setDictationShortcutEnabled(false)

        #expect(appState.isDictationShortcutEnabled == false)
    }
}

@MainActor
private func makeShortcutMenuAppState() -> AppState {
    let suiteName = "ShortcutMenuTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return AppState(userDefaults: defaults)
}
