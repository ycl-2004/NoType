import Foundation
import Testing
@testable import Typeless

@MainActor
struct R2T2EndToEndTests {
    /// Opt-in synthetic fixture: see docs/decisions/011-r2t2-resource-and-reliability.md.
    /// Does not record a microphone or touch the clipboard.
    @Test
    func transcribesShortAndLongSyntheticAudio() async throws {
        guard let path = ProcessInfo.processInfo.environment["NOTYPE_R2T2_E2E_CLIP"] else { return }
        let defaults = UserDefaults(suiteName: "R2T2E2E-\(UUID().uuidString)")!
        let state = AppState(userDefaults: defaults)
        let engine = R2T2TranscriptionEngine(appState: state)
        await engine.prewarm()
        let clip = RecordedAudioClip(fileURL: URL(fileURLWithPath: path))
        let samples = try AudioSamplesLoader.loadSamplesTrimmingTrailingSilence(for: clip)
        #expect(samples.count > 10 * R2T2Paths.sampleRate)
        let started = Date()
        let short = try await engine.transcribe(clip, language: .english, chineseScriptPreference: .followModel)
        print("R2T2 short (\(Double(samples.count) / 16000)s) elapsed=\(Date().timeIntervalSince(started))s: \(short.text)")
        #expect(short.text.lowercased().contains("telescope"))
        #expect(short.text.lowercased().contains("final"))
        #expect(!short.text.contains("�"))

        let sink = try await engine.beginStreaming(language: .english, chineseScriptPreference: .followModel)
        let long = Array(repeating: samples, count: 4).flatMap { $0 }
        let streamStart = Date()
        for start in stride(from: 0, to: long.count, by: 5_120) {
            sink(Array(long[start..<min(start + 5_120, long.count)]))
            // Accelerated replay still exercises concurrent ingest while the real model decodes.
            try await Task.sleep(for: .milliseconds(1))
        }
        let result = try await engine.finishStreaming()
        print("R2T2 streaming (\(Double(long.count) / 16000)s) elapsed=\(Date().timeIntervalSince(streamStart))s: \(result.text)")
        #expect(result.text.lowercased().components(separatedBy: "telescope").count - 1 == 4)
        #expect(result.text.lowercased().components(separatedBy: "final code").count - 1 == 4)
        #expect(!result.text.contains("�"))
    }
}
