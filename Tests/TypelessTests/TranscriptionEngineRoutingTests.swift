import Foundation
import Testing
@testable import Typeless

@MainActor
struct TranscriptionEngineRoutingTests {
    /// The rule that matters most: Auto asks for language detection, which macOS Speech cannot do.
    /// Honouring the preference there would force one language onto a mixed clip — Qwen3-ASR is
    /// the local multilingual fallback.
    @Test
    func autoAlwaysUsesQwen3ASREvenWhenMacOSSpeechIsPreferred() {
        #expect(TranscriptionEngineChoice.appleSpeech.resolvedEngine(for: .mixed) == .qwen3ASR)
        #expect(TranscriptionEngineChoice.qwen3ASR.resolvedEngine(for: .mixed) == .qwen3ASR)
    }

    @Test
    func singleLanguageModesHonourTheMacOSSpeechPreference() {
        guard TranscriptionEngineChoice.isAppleSpeechAvailable else { return }

        #expect(TranscriptionEngineChoice.appleSpeech.resolvedEngine(for: .chinese) == .appleSpeech)
        #expect(TranscriptionEngineChoice.appleSpeech.resolvedEngine(for: .english) == .appleSpeech)
    }

    @Test
    func choosingQwen3ASRKeepsEveryModeOnQwen3ASR() {
        for language in DictationRecognitionLanguage.allCases {
            #expect(TranscriptionEngineChoice.qwen3ASR.resolvedEngine(for: language) == .qwen3ASR)
        }
    }

    @Test
    func choosingSenseVoiceKeepsEveryModeOnSenseVoice() {
        for language in DictationRecognitionLanguage.allCases {
            #expect(TranscriptionEngineChoice.senseVoice.resolvedEngine(for: language) == .senseVoice)
        }
    }

    @Test
    func routerSendsSenseVoiceDictationToSenseVoice() async throws {
        let appState = AppState(userDefaults: makeIsolatedDefaults())
        appState.setTranscriptionEngine(.senseVoice)
        let senseVoice = RoutingSpyEngine(name: "senseVoice")
        let router = RoutingTranscriptionEngine(
            appState: appState,
            makeAppleEngine: { nil },
            makeQwen3ASREngine: { RoutingSpyEngine(name: "qwen3ASR") },
            makeSenseVoiceEngine: { senseVoice }
        )

        _ = try await router.transcribe(makeClip(), language: .mixed, chineseScriptPreference: .followModel)

        #expect(senseVoice.transcribeCount == 1)
    }

    @Test
    func routerSendsSingleLanguageDictationToMacOSSpeech() async throws {
        guard TranscriptionEngineChoice.isAppleSpeechAvailable else { return }
        let appState = AppState(userDefaults: makeIsolatedDefaults())
        appState.setTranscriptionEngine(.appleSpeech)
        let apple = RoutingSpyEngine(name: "apple")
        let qwen3ASR = RoutingSpyEngine(name: "qwen3ASR")
        let router = RoutingTranscriptionEngine(
            appState: appState,
            makeAppleEngine: { apple },
            makeQwen3ASREngine: { qwen3ASR }
        )

        _ = try await router.transcribe(makeClip(), language: .chinese, chineseScriptPreference: .simplified)

        #expect(apple.transcribeCount == 1)
        #expect(qwen3ASR.transcribeCount == 0)
    }

    @Test
    func routerSendsAutoDictationToQwen3ASRDespiteTheMacOSSpeechPreference() async throws {
        let appState = AppState(userDefaults: makeIsolatedDefaults())
        appState.setTranscriptionEngine(.appleSpeech)
        let apple = RoutingSpyEngine(name: "apple")
        let qwen3ASR = RoutingSpyEngine(name: "qwen3ASR")
        let router = RoutingTranscriptionEngine(
            appState: appState,
            makeAppleEngine: { apple },
            makeQwen3ASREngine: { qwen3ASR }
        )

        _ = try await router.transcribe(makeClip(), language: .mixed, chineseScriptPreference: .followModel)

        #expect(qwen3ASR.transcribeCount == 1)
        #expect(apple.transcribeCount == 0)
    }

    /// The bundled model costs seconds and gigabytes to load. A user who stays on macOS Speech must
    /// never pay for it, which is the entire reason the fast path is worth shipping.
    @Test
    func qwen3ASRIsNeverBuiltWhileTheUserStaysOnMacOSSpeech() async throws {
        guard TranscriptionEngineChoice.isAppleSpeechAvailable else { return }
        let appState = AppState(userDefaults: makeIsolatedDefaults())
        appState.setTranscriptionEngine(.appleSpeech)
        appState.setRecognitionLanguage(.chinese)
        var qwen3ASRBuildCount = 0
        let router = RoutingTranscriptionEngine(
            appState: appState,
            makeAppleEngine: { RoutingSpyEngine(name: "apple") },
            makeQwen3ASREngine: {
                qwen3ASRBuildCount += 1
                return RoutingSpyEngine(name: "qwen3ASR")
            }
        )

        await router.prewarm()
        _ = try await router.transcribe(makeClip(), language: .chinese, chineseScriptPreference: .simplified)
        _ = try await router.transcribe(makeClip(), language: .english, chineseScriptPreference: .followModel)

        #expect(qwen3ASRBuildCount == 0)
    }

    /// Switching modes must reuse the engine that was already built rather than rebuilding it,
    /// otherwise every Auto dictation would reload the bundled model.
    @Test
    func eachEngineIsBuiltOnceAndReused() async throws {
        let appState = AppState(userDefaults: makeIsolatedDefaults())
        appState.setTranscriptionEngine(.qwen3ASR)
        var qwen3ASRBuildCount = 0
        let router = RoutingTranscriptionEngine(
            appState: appState,
            makeAppleEngine: { nil },
            makeQwen3ASREngine: {
                qwen3ASRBuildCount += 1
                return RoutingSpyEngine(name: "qwen3ASR")
            }
        )

        _ = try await router.transcribe(makeClip(), language: .mixed, chineseScriptPreference: .followModel)
        _ = try await router.transcribe(makeClip(), language: .chinese, chineseScriptPreference: .simplified)

        #expect(qwen3ASRBuildCount == 1)
    }

    /// A settings file carried to an older Mac must not leave the app pointing at an engine that
    /// cannot run there.
    @Test
    func savedMacOSSpeechPreferenceDegradesWhenTheSystemCannotRunIt() {
        let defaults = makeIsolatedDefaults()
        defaults.set(TranscriptionEngineChoice.appleSpeech.rawValue, forKey: "transcriptionEngine")
        let appState = AppState(userDefaults: defaults)

        let expected: TranscriptionEngineChoice = TranscriptionEngineChoice.isAppleSpeechAvailable
            ? .appleSpeech
            : .qwen3ASR
        #expect(appState.selectedTranscriptionEngine == expected)
    }

    @Test
    func engineChoicePersistsAcrossLaunches() {
        let defaults = makeIsolatedDefaults()
        let first = AppState(userDefaults: defaults)
        first.setTranscriptionEngine(.qwen3ASR)

        let second = AppState(userDefaults: defaults)
        #expect(second.selectedTranscriptionEngine == .qwen3ASR)
    }

    private func makeClip() -> RecordedAudioClip {
        RecordedAudioClip(fileURL: URL(fileURLWithPath: "/tmp/routing-test.wav"), duration: 1)
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "RoutingTests-\(UUID().uuidString)")!
    }
}

@MainActor
private final class RoutingSpyEngine: TranscriptionEngine {
    let name: String
    private(set) var transcribeCount = 0
    private(set) var prewarmCount = 0

    init(name: String) {
        self.name = name
    }

    func transcribe(
        _ clip: RecordedAudioClip,
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference
    ) async throws -> TranscriptResult {
        transcribeCount += 1
        return TranscriptResult(text: name)
    }

    func prewarm() async {
        prewarmCount += 1
    }
}

@MainActor
struct TranscriptionEngineMenuTests {
    /// The setting is only real if it is reachable. This guards the menu entry itself, so a future
    /// menu rewrite cannot drop the engine picker without failing a test.
    @Test
    func mainMenuOffersAnEngineSetting() {
        let appState = makeMenuAppState()
        let controller = MenuBarController(appState: appState, coordinator: DictationCoordinator(appState: appState))

        let titles = controller.makeMenu().items.map(\.title)

        #expect(titles.contains { $0.hasPrefix("Engine:") })
    }

    @Test
    func engineSubmenuListsAllEnginesAndMarksTheSelectedOne() {
        let appState = makeMenuAppState()
        appState.setTranscriptionEngine(.qwen3ASR)
        let controller = MenuBarController(appState: appState, coordinator: DictationCoordinator(appState: appState))

        let items = controller.transcriptionEngineMenu().items
        let titles = items.map(\.title)

        #expect(titles.contains(TranscriptionEngineChoice.appleSpeech.menuTitle))
        #expect(titles.contains(TranscriptionEngineChoice.qwen3ASR.menuTitle))
        #expect(titles.contains(TranscriptionEngineChoice.senseVoice.menuTitle))
        #expect(items.first { $0.title == TranscriptionEngineChoice.qwen3ASR.menuTitle }?.state == .on)
        #expect(items.first { $0.title == TranscriptionEngineChoice.appleSpeech.menuTitle }?.state == .off)
        #expect(items.first { $0.title == TranscriptionEngineChoice.senseVoice.menuTitle }?.state == .off)
    }

    @Test
    func engineSubmenuOffersDownloadedModelManagementWithoutMacOSSpeechDeletion() {
        let appState = makeMenuAppState()
        let controller = MenuBarController(appState: appState, coordinator: DictationCoordinator(appState: appState))
        let menu = controller.transcriptionEngineMenu()
        let managementItem = menu.items.first { $0.title == "Manage Downloaded Models" }
        let titles = managementItem?.submenu?.items.map(\.title) ?? []

        #expect(titles.contains { $0.contains("Qwen3-ASR") })
        #expect(titles.contains { $0.contains("SenseVoice") })
        #expect(titles.contains("Only NoType downloads are removed"))
        #expect(titles.contains { $0.contains("macOS Speech") } == false)
    }

    /// Auto overrides the preference, so the menu title has to admit it rather than showing a
    /// setting the current recognition mode is quietly ignoring.
    @Test
    func menuTitleShowsWhenAutoOverridesTheSelectedEngine() {
        guard TranscriptionEngineChoice.isAppleSpeechAvailable else { return }
        let appState = makeMenuAppState()
        appState.setTranscriptionEngine(.appleSpeech)
        let controller = MenuBarController(appState: appState, coordinator: DictationCoordinator(appState: appState))

        appState.setRecognitionLanguage(.mixed)
        let overridden = controller.makeMenu().items.map(\.title).first { $0.hasPrefix("Engine:") }
        #expect(overridden?.contains("→") == true)

        appState.setRecognitionLanguage(.chinese)
        let honoured = controller.makeMenu().items.map(\.title).first { $0.hasPrefix("Engine:") }
        #expect(honoured == "Engine: \(TranscriptionEngineChoice.appleSpeech.menuTitle)")
    }

    /// A setting that does nothing is worse than no setting, so macOS Speech is disabled rather
    /// than merely ineffective on a system that cannot run it.
    @Test
    func macOSSpeechIsDisabledWhenTheSystemCannotRunIt() {
        let appState = makeMenuAppState()
        let controller = MenuBarController(appState: appState, coordinator: DictationCoordinator(appState: appState))

        let appleItem = controller.transcriptionEngineMenu().items
            .first { $0.title == TranscriptionEngineChoice.appleSpeech.menuTitle }

        #expect(appleItem?.isEnabled == TranscriptionEngineChoice.isAppleSpeechAvailable)
    }

    private func makeMenuAppState() -> AppState {
        AppState(userDefaults: UserDefaults(suiteName: "EngineMenuTests-\(UUID().uuidString)")!)
    }
}
