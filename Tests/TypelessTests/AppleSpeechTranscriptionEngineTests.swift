import AVFoundation
import Foundation
import Speech
import Testing
@testable import Typeless

/// The engine only exists on macOS 26, so every test guards availability rather than the suite —
/// swift-testing refuses `@Test` on an `@available`-annotated declaration.
struct AppleSpeechTranscriptionEngineTests {
    /// The engine builds a transcriber for exactly one locale, so the script preference has to be
    /// resolved before recognition rather than only in post-processing.
    @Test
    func traditionalPreferenceLeadsWithTaiwanRatherThanCantonese() throws {
        guard #available(macOS 26.0, *) else { return }
        let candidates = AppleSpeechTranscriptionEngine.chineseCandidates(for: .traditional)

        #expect(candidates.first == "zh-TW")
        #expect(candidates.contains("zh-HK"))
    }

    @Test
    func simplifiedAndFollowModelBothLeadWithMainlandChinese() throws {
        guard #available(macOS 26.0, *) else { return }

        #expect(AppleSpeechTranscriptionEngine.chineseCandidates(for: .simplified).first == "zh-CN")
        #expect(AppleSpeechTranscriptionEngine.chineseCandidates(for: .followModel).first == "zh-CN")
    }

    /// Every Chinese preference keeps a fallback after its first choice: a Mac that has only one
    /// Chinese model installed must still transcribe instead of failing outright.
    @Test
    func everyChinesePreferenceKeepsAFallbackLocale() throws {
        guard #available(macOS 26.0, *) else { return }

        for preference in ChineseScriptPreference.allCases {
            #expect(AppleSpeechTranscriptionEngine.chineseCandidates(for: preference).count > 1)
        }
    }

    @Test
    func explicitLanguageChoicesResolveToTheirOwnScript() async throws {
        guard #available(macOS 26.0, *) else { return }

        let chinese = await AppleSpeechTranscriptionEngine.resolveLocale(
            for: .chinese,
            chineseScriptPreference: .simplified
        )
        #expect(chinese.language.languageCode?.identifier == "zh")

        let english = await AppleSpeechTranscriptionEngine.resolveLocale(
            for: .english,
            chineseScriptPreference: .followModel
        )
        #expect(english.language.languageCode?.identifier == "en")
    }

    /// Whisper detects the spoken language itself; this engine cannot. `.mixed` must therefore
    /// still land on a real supported locale instead of returning nothing.
    @Test
    func mixedResolvesToALocaleTheSystemActuallySupports() async throws {
        guard #available(macOS 26.0, *) else { return }

        let resolved = await AppleSpeechTranscriptionEngine.resolveLocale(
            for: .mixed,
            chineseScriptPreference: .followModel
        )
        // Compared against the live list rather than a hardcoded one, which would rot each release.
        let supported = await Set(SpeechTranscriber.supportedLocales.map { $0.identifier(.bcp47) })

        #expect(supported.contains(resolved.identifier(.bcp47)))
    }
}

/// Silence must not surface as an error. Observed on 2026-09-04: starting a recording and not
/// speaking left the menu bar in a red error state, while the Whisper path reported the same
/// situation as "nothing to insert" and stayed idle.
@MainActor
struct AppleSpeechSilenceTests {
    @Test
    func silentClipEndsTheSessionQuietlyInsteadOfRaisingAnError() async throws {
        guard #available(macOS 26.0, *) else { return }
        // Asking for Speech Recognition without a usage description terminates the process, and
        // the `swift test` runner bundle declares none. Only the real app bundle can run this.
        guard Bundle.main.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription") != nil,
              SFSpeechRecognizer.authorizationStatus() == .authorized else { return }

        let silentClip = try makeSilentClip(seconds: 2)
        defer { silentClip.deleteFile() }

        let engine = AppleSpeechTranscriptionEngine()
        let result = try await engine.transcribe(
            silentClip,
            language: .chinese,
            chineseScriptPreference: .simplified
        )

        // An empty transcript is the contract the coordinator reads as "nothing to insert".
        #expect(result.text.isEmpty)
    }

    private func makeSilentClip(seconds: Double) throws -> RecordedAudioClip {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("notype-silence-\(UUID().uuidString).wav")
        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frames = AVAudioFrameCount(format.sampleRate * seconds)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        try file.write(from: buffer)
        return RecordedAudioClip(fileURL: url, duration: seconds)
    }
}
