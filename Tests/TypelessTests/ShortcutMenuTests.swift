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
    func shortcutMenuShowsSelectedDictationTrigger() {
        let appState = makeShortcutMenuAppState()
        let controller = MenuBarController(appState: appState, coordinator: DictationCoordinator(appState: appState))

        #expect(controller.shortcutsMenu().items.first?.title == "Dictation: Double Command")
    }

    @Test
    func shortcutMenuOffersIndependentDisabledChoices() {
        let appState = makeShortcutMenuAppState()
        let controller = MenuBarController(appState: appState, coordinator: DictationCoordinator(appState: appState))
        let shortcutItems = controller.shortcutsMenu().items

        #expect(shortcutItems[0].submenu?.items.contains { $0.title == "Disabled" } == true)
        #expect(shortcutItems[1].submenu?.items.contains { $0.title == "Disabled" } == true)
    }

    @Test
    func selectingDisabledDictationShortcutUpdatesAppState() {
        let appState = makeShortcutMenuAppState()
        appState.setDictationShortcut(.disabled)

        #expect(appState.selectedDictationShortcut == .disabled)
    }

    @Test
    func mainMenuHidesTranscriptAndMovesDebugInformationIntoDiagnostics() {
        let appState = makeShortcutMenuAppState()
        appState.setTranscriptPreview("A transcript that should not appear")
        appState.setDebugMessage("Recorder started")
        let controller = MenuBarController(appState: appState, coordinator: DictationCoordinator(appState: appState))

        let mainTitles = controller.makeMenu().items.map(\.title)
        #expect(mainTitles.contains("Last Transcript:") == false)
        #expect(mainTitles.contains("Debug:") == false)
        #expect(mainTitles.contains { $0.hasPrefix("Log:") } == false)
        #expect(mainTitles.contains("Diagnostics"))
        #expect(controller.diagnosticsMenu().items.contains { $0.title == "Last Event: Recorder started" })
    }

    @Test
    func diagnosticsShowsRealLocalModelLifecycleWithoutOpeningTheLog() {
        let appState = makeShortcutMenuAppState()
        let controller = MenuBarController(appState: appState, coordinator: DictationCoordinator(appState: appState))

        appState.setLocalModelReadiness(.preparing)
        var titles = controller.diagnosticsMenu().items.map(\.title)
        #expect(titles.contains("Local Model: Preparing…"))
        #expect(titles.contains { $0.contains("Preparing the speech model") })

        appState.setLocalModelReadiness(.ready)
        titles = controller.diagnosticsMenu().items.map(\.title)
        #expect(titles.contains("Local Model: Ready"))
        #expect(titles.contains { $0.contains("loaded and ready") })

        appState.setLocalModelReadiness(.failed("Required model is missing"))
        titles = controller.diagnosticsMenu().items.map(\.title)
        #expect(titles.contains("Local Model: Failed"))
        #expect(titles.contains("Reason: Required model is missing"))
        #expect(titles.contains("Retry Model Preparation"))
    }
}

@MainActor
private func makeShortcutMenuAppState() -> AppState {
    let suiteName = "ShortcutMenuTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return AppState(userDefaults: defaults)
}
