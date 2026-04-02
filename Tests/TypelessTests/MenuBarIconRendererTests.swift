import Testing
@testable import Typeless

struct MenuBarIconRendererTests {
    @Test
    func recognitionLanguageProvidesCompactMenuBarMarker() {
        #expect(DictationRecognitionLanguage.mixed.menuBarMarker == "A")
        #expect(DictationRecognitionLanguage.chinese.menuBarMarker == "中")
        #expect(DictationRecognitionLanguage.english.menuBarMarker == "EN")
    }

    @Test
    func chineseScriptMarkerVisibilityMatchesRecognitionMode() {
        #expect(ChineseScriptPreference.simplified.shouldShowMenuBarMarker(for: .mixed) == true)
        #expect(ChineseScriptPreference.traditional.shouldShowMenuBarMarker(for: .chinese) == true)
        #expect(ChineseScriptPreference.traditional.shouldShowMenuBarMarker(for: .english) == false)
    }

    @Test
    func rendererDoesNotShowScriptMarkerForEnglishMode() {
        let configuration = MenuBarIconRenderer.Configuration(
            state: .idle,
            recognitionLanguage: .english,
            chineseScriptPreference: .traditional
        )

        #expect(MenuBarIconRenderer.scriptMarker(for: configuration) == nil)
    }

    @Test
    func rendererUsesRecognitionMarkerFromLanguage() {
        let configuration = MenuBarIconRenderer.Configuration(
            state: .recording,
            recognitionLanguage: .mixed,
            chineseScriptPreference: .traditional
        )

        #expect(MenuBarIconRenderer.modeMarker(for: configuration) == "A")
    }

    @Test
    func rendererUsesWaveformSymbolWhileTranscribing() {
        #expect(MenuBarIconRenderer.symbolName(for: .transcribing) == "waveform")
    }

    @Test
    func rendererHidesScriptMarkerWhenChineseScriptFollowsModel() {
        let configuration = MenuBarIconRenderer.Configuration(
            state: .idle,
            recognitionLanguage: .mixed,
            chineseScriptPreference: .followModel
        )

        #expect(MenuBarIconRenderer.scriptMarker(for: configuration) == nil)
    }

    @Test
    func rendererShowsTraditionalMarkerForAutoMode() {
        let configuration = MenuBarIconRenderer.Configuration(
            state: .idle,
            recognitionLanguage: .mixed,
            chineseScriptPreference: .traditional
        )

        #expect(MenuBarIconRenderer.scriptMarker(for: configuration) == "繁")
    }
}
