import Foundation
import Testing
@testable import Typeless

struct TrailingSilenceTrimmerTests {
    /// 16 kHz at the 0.1s frame length `EnergyVAD` uses by default.
    private let sampleRate = 16_000
    private let samplesPerFrame = 1_600

    private func frames(speech: Int, silence: Int) -> [Bool] {
        Array(repeating: true, count: speech) + Array(repeating: false, count: silence)
    }

    @Test
    func trimsALongSilentTailAndKeepsPaddingAfterTheLastSpeech() throws {
        // 2s of speech followed by 5s of silence.
        let voiceActivity = frames(speech: 20, silence: 50)

        let kept = try #require(TrailingSilenceTrimmer.trimmedSampleCount(
            voiceActivity: voiceActivity,
            totalSamples: 70 * samplesPerFrame,
            samplesPerFrame: samplesPerFrame,
            sampleRate: sampleRate
        ))

        // 2s of speech plus the 0.5s of padding that is deliberately kept.
        #expect(kept == Int(2.5 * Double(sampleRate)))
    }

    @Test
    func leavesAnOrdinaryEndOfSentencePauseAlone() {
        // 2s of speech and 0.8s of silence: inside the range of a normal pause, so trimming it
        // would risk cutting real speech for almost no saving.
        let voiceActivity = frames(speech: 20, silence: 8)

        let kept = TrailingSilenceTrimmer.trimmedSampleCount(
            voiceActivity: voiceActivity,
            totalSamples: 28 * samplesPerFrame,
            samplesPerFrame: samplesPerFrame,
            sampleRate: sampleRate
        )

        #expect(kept == nil)
    }

    @Test
    func passesTheClipThroughWhenTheDetectorHeardNothing() {
        // Quiet speech the energy threshold missed must still reach the model. Discarding it here
        // would present to the user as "I spoke and nothing happened".
        let kept = TrailingSilenceTrimmer.trimmedSampleCount(
            voiceActivity: Array(repeating: false, count: 40),
            totalSamples: 40 * samplesPerFrame,
            samplesPerFrame: samplesPerFrame,
            sampleRate: sampleRate
        )

        #expect(kept == nil)
    }

    @Test
    func neverTrimsWhenSpeechRunsToTheEndOfTheClip() {
        let kept = TrailingSilenceTrimmer.trimmedSampleCount(
            voiceActivity: frames(speech: 30, silence: 0),
            totalSamples: 30 * samplesPerFrame,
            samplesPerFrame: samplesPerFrame,
            sampleRate: sampleRate
        )

        #expect(kept == nil)
    }

    @Test
    func theKeptPaddingComesOutOfTheSilenceBeforeAnythingIsTrimmed() throws {
        // The padding is kept from the silence itself, so a tail only earns a trim once it exceeds
        // `keptPadding + minimumTrailingSilence`. 1.2s of silence leaves 0.7s to remove and is left
        // alone; 2.0s leaves 1.5s and is trimmed back to speech plus padding.
        let justUnder = TrailingSilenceTrimmer.trimmedSampleCount(
            voiceActivity: frames(speech: 30, silence: 12),
            totalSamples: 42 * samplesPerFrame,
            samplesPerFrame: samplesPerFrame,
            sampleRate: sampleRate
        )

        let justOver = try #require(TrailingSilenceTrimmer.trimmedSampleCount(
            voiceActivity: frames(speech: 30, silence: 20),
            totalSamples: 50 * samplesPerFrame,
            samplesPerFrame: samplesPerFrame,
            sampleRate: sampleRate
        ))

        #expect(justUnder == nil)
        #expect(justOver == Int(3.5 * Double(sampleRate)))
        #expect(justOver < 50 * samplesPerFrame)
    }

    @Test
    func degenerateInputIsPassedThroughRatherThanTrimmedToNothing() {
        #expect(TrailingSilenceTrimmer.trimmedSampleCount(
            voiceActivity: [],
            totalSamples: 0,
            samplesPerFrame: samplesPerFrame,
            sampleRate: sampleRate
        ) == nil)

        #expect(TrailingSilenceTrimmer.trimmedSampleCount(
            voiceActivity: frames(speech: 5, silence: 30),
            totalSamples: 35 * samplesPerFrame,
            samplesPerFrame: 0,
            sampleRate: sampleRate
        ) == nil)
    }
}
