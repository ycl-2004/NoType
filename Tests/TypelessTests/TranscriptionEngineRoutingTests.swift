import Foundation
import Testing
@testable import Typeless

@MainActor
struct TranscriptionEngineRoutingTests {
    /// The rule that matters most: Auto asks for language detection, which macOS Speech cannot do.
    /// Honouring the preference there would force one language onto a mixed clip — R2T2 is the
    /// local multilingual fallback.
    @Test
    func autoAlwaysUsesR2T2EvenWhenMacOSSpeechIsPreferred() {
        #expect(TranscriptionEngineChoice.appleSpeech.resolvedEngine(for: .mixed) == .r2t2)
        #expect(TranscriptionEngineChoice.r2t2.resolvedEngine(for: .mixed) == .r2t2)
    }

    @Test
    func singleLanguageModesHonourTheMacOSSpeechPreference() {
        guard TranscriptionEngineChoice.isAppleSpeechAvailable else { return }

        #expect(TranscriptionEngineChoice.appleSpeech.resolvedEngine(for: .chinese) == .appleSpeech)
        #expect(TranscriptionEngineChoice.appleSpeech.resolvedEngine(for: .english) == .appleSpeech)
    }

    @Test
    func choosingR2T2KeepsEveryModeOnR2T2() {
        for language in DictationRecognitionLanguage.allCases {
            #expect(TranscriptionEngineChoice.r2t2.resolvedEngine(for: language) == .r2t2)
        }
    }

    @Test
    func newInstallsStartOnR2T2() {
        let appState = AppState(userDefaults: makeIsolatedDefaults())
        #expect(appState.selectedTranscriptionEngine == .r2t2)
    }

    /// Whisper, Qwen3-ASR and SenseVoice were removed; a saved preference for any of them must
    /// still load a working local engine.
    @Test(arguments: ["bundledWhisper", "qwen3ASR", "senseVoice"])
    func savedPreferenceForARemovedEngineLoadsR2T2(rawValue: String) {
        let defaults = makeIsolatedDefaults()
        defaults.set(rawValue, forKey: "transcriptionEngine")
        #expect(AppState(userDefaults: defaults).selectedTranscriptionEngine == .r2t2)
    }

    @Test
    func routingStreamsWheneverTheDictationReachesR2T2() async throws {
        let appState = AppState(userDefaults: makeIsolatedDefaults())
        let r2t2 = RoutingStreamingSpyEngine()
        let router = RoutingTranscriptionEngine(
            appState: appState,
            makeAppleEngine: { RoutingSpyEngine(name: "apple") },
            makeR2T2Engine: { r2t2 }
        )

        #expect(router.canStream)
        appState.setTranscriptionEngine(.appleSpeech)
        appState.setRecognitionLanguage(.mixed)
        #expect(router.canStream, "Auto falls back to R2T2, so it streams too")
        if TranscriptionEngineChoice.isAppleSpeechAvailable {
            appState.setRecognitionLanguage(.chinese)
            #expect(router.canStream == false)
        }
        appState.setTranscriptionEngine(.r2t2)

        let sink = try await router.beginStreaming(
            language: .mixed,
            chineseScriptPreference: .followModel
        )
        sink([0.1, 0.2, 0.3])
        let result = try await router.finishStreaming()

        #expect(r2t2.beginCount == 1)
        #expect(r2t2.chunkCount == 1)
        #expect(result.text == "streamed")
    }

    @Test
    func routerSendsSingleLanguageDictationToMacOSSpeech() async throws {
        guard TranscriptionEngineChoice.isAppleSpeechAvailable else { return }
        let appState = AppState(userDefaults: makeIsolatedDefaults())
        appState.setTranscriptionEngine(.appleSpeech)
        let apple = RoutingSpyEngine(name: "apple")
        let r2t2 = RoutingSpyEngine(name: "r2t2")
        let router = RoutingTranscriptionEngine(
            appState: appState,
            makeAppleEngine: { apple },
            makeR2T2Engine: { r2t2 }
        )

        _ = try await router.transcribe(makeClip(), language: .chinese, chineseScriptPreference: .simplified)

        #expect(apple.transcribeCount == 1)
        #expect(r2t2.transcribeCount == 0)
    }

    @Test
    func routerSendsAutoDictationToR2T2DespiteTheMacOSSpeechPreference() async throws {
        let appState = AppState(userDefaults: makeIsolatedDefaults())
        appState.setTranscriptionEngine(.appleSpeech)
        let apple = RoutingSpyEngine(name: "apple")
        let r2t2 = RoutingSpyEngine(name: "r2t2")
        let router = RoutingTranscriptionEngine(
            appState: appState,
            makeAppleEngine: { apple },
            makeR2T2Engine: { r2t2 }
        )

        _ = try await router.transcribe(makeClip(), language: .mixed, chineseScriptPreference: .followModel)

        #expect(r2t2.transcribeCount == 1)
        #expect(apple.transcribeCount == 0)
    }

    /// The local model costs seconds and gigabytes to load. A user who stays on macOS Speech must
    /// never pay for it, which is the entire reason the fast path is worth shipping.
    @Test
    func r2t2IsNeverBuiltWhileTheUserStaysOnMacOSSpeech() async throws {
        guard TranscriptionEngineChoice.isAppleSpeechAvailable else { return }
        let appState = AppState(userDefaults: makeIsolatedDefaults())
        appState.setTranscriptionEngine(.appleSpeech)
        appState.setRecognitionLanguage(.chinese)
        var r2t2BuildCount = 0
        let router = RoutingTranscriptionEngine(
            appState: appState,
            makeAppleEngine: { RoutingSpyEngine(name: "apple") },
            makeR2T2Engine: {
                r2t2BuildCount += 1
                return RoutingSpyEngine(name: "r2t2")
            }
        )

        await router.prewarm()
        _ = try await router.transcribe(makeClip(), language: .chinese, chineseScriptPreference: .simplified)
        _ = try await router.transcribe(makeClip(), language: .english, chineseScriptPreference: .followModel)

        #expect(r2t2BuildCount == 0)
    }

    /// Switching modes must reuse the engine that was already built rather than rebuilding it,
    /// otherwise every dictation would reload the local model.
    @Test
    func eachEngineIsBuiltOnceAndReused() async throws {
        let appState = AppState(userDefaults: makeIsolatedDefaults())
        var r2t2BuildCount = 0
        let router = RoutingTranscriptionEngine(
            appState: appState,
            makeAppleEngine: { nil },
            makeR2T2Engine: {
                r2t2BuildCount += 1
                return RoutingSpyEngine(name: "r2t2")
            }
        )

        _ = try await router.transcribe(makeClip(), language: .mixed, chineseScriptPreference: .followModel)
        _ = try await router.transcribe(makeClip(), language: .chinese, chineseScriptPreference: .simplified)

        #expect(r2t2BuildCount == 1)
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
            : .r2t2
        #expect(appState.selectedTranscriptionEngine == expected)
    }

    @Test
    func engineChoicePersistsAcrossLaunches() {
        guard TranscriptionEngineChoice.isAppleSpeechAvailable else { return }
        let defaults = makeIsolatedDefaults()
        let first = AppState(userDefaults: defaults)
        first.setTranscriptionEngine(.appleSpeech)

        let second = AppState(userDefaults: defaults)
        #expect(second.selectedTranscriptionEngine == .appleSpeech)
    }

    @Test
    func switchingEnginesReleasesThePreviousModelButKeepsCurrentModelHot() async throws {
        guard TranscriptionEngineChoice.isAppleSpeechAvailable else { return }
        let appState = AppState(userDefaults: makeIsolatedDefaults())
        weak var oldEngine: RoutingSpyEngine?
        var builds = 0
        let router = RoutingTranscriptionEngine(
            appState: appState,
            makeAppleEngine: { RoutingSpyEngine(name: "apple") },
            makeR2T2Engine: {
                let engine = RoutingSpyEngine(name: "r2t2")
                oldEngine = engine
                builds += 1
                return engine
            }
        )
        _ = try await router.transcribe(makeClip(), language: .mixed, chineseScriptPreference: .followModel)
        #expect(oldEngine != nil)
        _ = try await router.transcribe(makeClip(), language: .mixed, chineseScriptPreference: .followModel)
        #expect(builds == 1)
        appState.setTranscriptionEngine(.appleSpeech)
        _ = try await router.transcribe(makeClip(), language: .chinese, chineseScriptPreference: .followModel)
        #expect(oldEngine == nil)
    }

    /// llama.cpp aborts during exit if a model is still loaded, so termination must drop it first.
    @Test
    func releasingResourcesDropsTheLoadedModel() async throws {
        let appState = AppState(userDefaults: makeIsolatedDefaults())
        weak var loaded: RoutingSpyEngine?
        let router = RoutingTranscriptionEngine(
            appState: appState,
            makeAppleEngine: { nil },
            makeR2T2Engine: {
                let engine = RoutingSpyEngine(name: "r2t2")
                loaded = engine
                return engine
            }
        )
        await router.prewarm()
        #expect(loaded != nil)

        router.releaseResources()
        #expect(loaded == nil)
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
private final class RoutingStreamingSpyEngine: StreamingTranscriptionEngine {
    let canStream = true
    private(set) var beginCount = 0
    private(set) var chunkCount = 0

    func transcribe(
        _ clip: RecordedAudioClip,
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference
    ) async throws -> TranscriptResult {
        TranscriptResult(text: "streamed")
    }

    func prewarm() async {}

    func beginStreaming(
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference
    ) async throws -> @Sendable ([Float]) -> Void {
        beginCount += 1
        return { [weak self] samples in
            Task { @MainActor [weak self] in
                guard let self, samples.isEmpty == false else { return }
                self.chunkCount += 1
            }
        }
    }

    func finishStreaming() async throws -> TranscriptResult {
        // The sink is scheduled through a Task so allow the main actor one turn to process it.
        await Task.yield()
        return TranscriptResult(text: "streamed")
    }

    func cancelStreaming() {}
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
    func engineSubmenuListsR2T2FirstWithoutAnExperimentalSection() {
        let appState = makeMenuAppState()
        let controller = MenuBarController(appState: appState, coordinator: DictationCoordinator(appState: appState))

        let items = controller.transcriptionEngineMenu().items
        let titles = items.map(\.title)

        #expect(titles.first == TranscriptionEngineChoice.r2t2.menuTitle)
        #expect(titles.contains(TranscriptionEngineChoice.appleSpeech.menuTitle))
        #expect(titles.contains { $0.localizedCaseInsensitiveContains("experimental") } == false)
        #expect(titles.contains { $0.contains("Qwen3") || $0.contains("SenseVoice") } == false)
        #expect(items.first { $0.title == TranscriptionEngineChoice.r2t2.menuTitle }?.state == .on)
        #expect(items.first { $0.title == TranscriptionEngineChoice.appleSpeech.menuTitle }?.state == .off)
    }

    @Test
    func engineSubmenuOffersDownloadedModelManagementWithoutMacOSSpeechDeletion() {
        let appState = makeMenuAppState()
        let controller = MenuBarController(appState: appState, coordinator: DictationCoordinator(appState: appState))
        let menu = controller.transcriptionEngineMenu()
        let managementItem = menu.items.first { $0.title == "Manage Downloaded Models" }
        let titles = managementItem?.submenu?.items.map(\.title) ?? []

        #expect(titles.contains { $0.contains("R2T2") })
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
