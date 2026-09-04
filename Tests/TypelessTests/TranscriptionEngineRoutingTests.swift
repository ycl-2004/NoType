import Foundation
import Testing
@testable import Typeless

@MainActor
struct TranscriptionEngineRoutingTests {
    /// The rule that matters most: Auto asks for language detection, which macOS Speech cannot do.
    /// Honouring the preference there would force one language onto a mixed clip — Chinese spoken
    /// into an English model comes back as pinyin.
    @Test
    func autoAlwaysUsesWhisperEvenWhenMacOSSpeechIsPreferred() {
        #expect(TranscriptionEngineChoice.appleSpeech.resolvedEngine(for: .mixed) == .bundledWhisper)
        #expect(TranscriptionEngineChoice.bundledWhisper.resolvedEngine(for: .mixed) == .bundledWhisper)
    }

    @Test
    func singleLanguageModesHonourTheMacOSSpeechPreference() {
        guard TranscriptionEngineChoice.isAppleSpeechAvailable else { return }

        #expect(TranscriptionEngineChoice.appleSpeech.resolvedEngine(for: .chinese) == .appleSpeech)
        #expect(TranscriptionEngineChoice.appleSpeech.resolvedEngine(for: .english) == .appleSpeech)
    }

    @Test
    func choosingWhisperKeepsEveryModeOnWhisper() {
        for language in DictationRecognitionLanguage.allCases {
            #expect(TranscriptionEngineChoice.bundledWhisper.resolvedEngine(for: language) == .bundledWhisper)
        }
    }

    @Test
    func routerSendsSingleLanguageDictationToMacOSSpeech() async throws {
        guard TranscriptionEngineChoice.isAppleSpeechAvailable else { return }
        let appState = AppState(userDefaults: makeIsolatedDefaults())
        appState.setTranscriptionEngine(.appleSpeech)
        let apple = RoutingSpyEngine(name: "apple")
        let whisper = RoutingSpyEngine(name: "whisper")
        let router = RoutingTranscriptionEngine(
            appState: appState,
            makeAppleEngine: { apple },
            makeWhisperEngine: { whisper }
        )

        _ = try await router.transcribe(makeClip(), language: .chinese, chineseScriptPreference: .simplified)

        #expect(apple.transcribeCount == 1)
        #expect(whisper.transcribeCount == 0)
    }

    @Test
    func routerSendsAutoDictationToWhisperDespiteTheMacOSSpeechPreference() async throws {
        let appState = AppState(userDefaults: makeIsolatedDefaults())
        appState.setTranscriptionEngine(.appleSpeech)
        let apple = RoutingSpyEngine(name: "apple")
        let whisper = RoutingSpyEngine(name: "whisper")
        let router = RoutingTranscriptionEngine(
            appState: appState,
            makeAppleEngine: { apple },
            makeWhisperEngine: { whisper }
        )

        _ = try await router.transcribe(makeClip(), language: .mixed, chineseScriptPreference: .followModel)

        #expect(whisper.transcribeCount == 1)
        #expect(apple.transcribeCount == 0)
    }

    /// The bundled model costs seconds and gigabytes to load. A user who stays on macOS Speech must
    /// never pay for it, which is the entire reason the fast path is worth shipping.
    @Test
    func whisperIsNeverBuiltWhileTheUserStaysOnMacOSSpeech() async throws {
        guard TranscriptionEngineChoice.isAppleSpeechAvailable else { return }
        let appState = AppState(userDefaults: makeIsolatedDefaults())
        appState.setTranscriptionEngine(.appleSpeech)
        appState.setRecognitionLanguage(.chinese)
        var whisperBuildCount = 0
        let router = RoutingTranscriptionEngine(
            appState: appState,
            makeAppleEngine: { RoutingSpyEngine(name: "apple") },
            makeWhisperEngine: {
                whisperBuildCount += 1
                return RoutingSpyEngine(name: "whisper")
            }
        )

        await router.prewarm()
        _ = try await router.transcribe(makeClip(), language: .chinese, chineseScriptPreference: .simplified)
        _ = try await router.transcribe(makeClip(), language: .english, chineseScriptPreference: .followModel)

        #expect(whisperBuildCount == 0)
    }

    /// Switching modes must reuse the engine that was already built rather than rebuilding it,
    /// otherwise every Auto dictation would reload the bundled model.
    @Test
    func eachEngineIsBuiltOnceAndReused() async throws {
        let appState = AppState(userDefaults: makeIsolatedDefaults())
        appState.setTranscriptionEngine(.bundledWhisper)
        var whisperBuildCount = 0
        let router = RoutingTranscriptionEngine(
            appState: appState,
            makeAppleEngine: { nil },
            makeWhisperEngine: {
                whisperBuildCount += 1
                return RoutingSpyEngine(name: "whisper")
            }
        )

        _ = try await router.transcribe(makeClip(), language: .mixed, chineseScriptPreference: .followModel)
        _ = try await router.transcribe(makeClip(), language: .chinese, chineseScriptPreference: .simplified)

        #expect(whisperBuildCount == 1)
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
            : .bundledWhisper
        #expect(appState.selectedTranscriptionEngine == expected)
    }

    @Test
    func engineChoicePersistsAcrossLaunches() {
        let defaults = makeIsolatedDefaults()
        let first = AppState(userDefaults: defaults)
        first.setTranscriptionEngine(.bundledWhisper)

        let second = AppState(userDefaults: defaults)
        #expect(second.selectedTranscriptionEngine == .bundledWhisper)
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
    func engineSubmenuListsBothEnginesAndMarksTheSelectedOne() {
        let appState = makeMenuAppState()
        appState.setTranscriptionEngine(.bundledWhisper)
        let controller = MenuBarController(appState: appState, coordinator: DictationCoordinator(appState: appState))

        let items = controller.transcriptionEngineMenu().items
        let titles = items.map(\.title)

        #expect(titles.contains(TranscriptionEngineChoice.appleSpeech.menuTitle))
        #expect(titles.contains(TranscriptionEngineChoice.bundledWhisper.menuTitle))
        #expect(items.first { $0.title == TranscriptionEngineChoice.bundledWhisper.menuTitle }?.state == .on)
        #expect(items.first { $0.title == TranscriptionEngineChoice.appleSpeech.menuTitle }?.state == .off)
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
