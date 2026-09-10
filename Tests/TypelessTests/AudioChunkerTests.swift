import Testing
@testable import Typeless

struct AudioChunkerTests {
    private let sampleRate = 16_000
    private let samplesPerFrame = 1_600

    /// Frames of 100ms each, built from a compact description of speech and silence in seconds.
    private func voiceActivity(_ pattern: [(speech: Bool, seconds: Double)]) -> [Bool] {
        pattern.flatMap { segment in
            [Bool](repeating: segment.speech, count: Int(segment.seconds * 10))
        }
    }

    private func samples(seconds: Double) -> Int {
        Int(seconds * Double(sampleRate))
    }

    private func ranges(_ activity: [Bool], seconds: Double) -> [Range<Int>] {
        AudioChunker.chunkRanges(
            voiceActivity: activity,
            totalSamples: samples(seconds: seconds),
            samplesPerFrame: samplesPerFrame,
            sampleRate: sampleRate
        )
    }

    @Test
    func aRecordingShortEnoughToDecodeWholeIsNotSplit() {
        // The common case. Splitting here would cost a second decode for no reason.
        let activity = voiceActivity([(true, 10)])
        let result = ranges(activity, seconds: 10)

        #expect(result.count == 1)
        #expect(result.first == 0..<samples(seconds: 10))
    }

    @Test
    func aRecordingAtTheSingleDecodeLimitIsStillNotSplit() {
        let limit = AudioChunker.singleDecodeLimit
        let activity = voiceActivity([(true, limit)])

        #expect(ranges(activity, seconds: limit).count == 1)
    }

    @Test
    func aLongRecordingIsSplitAtItsPause() {
        // Speech, a clear pause, then more speech. The cut belongs inside the pause.
        let activity = voiceActivity([(true, 20), (false, 4), (true, 20)])
        let result = ranges(activity, seconds: 44)

        #expect(result.count == 2)

        let cut = result[0].upperBound
        #expect(cut > samples(seconds: 20))
        #expect(cut < samples(seconds: 24))
        // No audio is dropped or decoded twice.
        #expect(result[0].lowerBound == 0)
        #expect(result[1].lowerBound == cut)
        #expect(result[1].upperBound == samples(seconds: 44))
    }

    @Test
    func everySegmentStaysInsideTheModelsUsableRange() {
        // Five minutes, the app's recording cap, with pauses scattered through it.
        let pattern = (0..<10).flatMap { _ in [(true, 25.0), (false, 5.0)] }
        let activity = voiceActivity(pattern)
        let result = ranges(activity, seconds: 300)

        #expect(result.count > 1)
        for range in result {
            let seconds = Double(range.count) / Double(sampleRate)
            #expect(seconds <= AudioChunker.maximumChunkDuration + 0.001)
        }
    }

    @Test
    func continuousSpeechWithNoPauseIsStillCutRatherThanTruncated() {
        // Nothing to split on. A hard cut loses a word boundary; not cutting loses the whole tail.
        let activity = voiceActivity([(true, 90)])
        let result = ranges(activity, seconds: 90)

        #expect(result.count > 1)
        #expect(result.first?.lowerBound == 0)
        #expect(result.last?.upperBound == samples(seconds: 90))
    }

    @Test
    func chunksCoverTheRecordingExactlyWithoutGapsOrOverlap() {
        let activity = voiceActivity([(true, 30), (false, 3), (true, 30), (false, 2), (true, 25)])
        let result = ranges(activity, seconds: 90)

        #expect(result.first?.lowerBound == 0)
        #expect(result.last?.upperBound == samples(seconds: 90))
        for (earlier, later) in zip(result, result.dropFirst()) {
            #expect(earlier.upperBound == later.lowerBound)
        }
    }

    @Test
    func aTailThatAlreadyFitsIsKeptWholeInsteadOfBeingCutAgain() {
        let activity = voiceActivity([(true, 20), (false, 4), (true, 6)])
        let result = ranges(activity, seconds: 30)

        #expect(result.count == 2)
        let tailSeconds = Double(result[1].count) / Double(sampleRate)
        #expect(tailSeconds <= AudioChunker.singleDecodeLimit)
    }

    @Test
    func degenerateInputReturnsNoWorkRatherThanCrashing() {
        #expect(AudioChunker.chunkRanges(
            voiceActivity: [], totalSamples: 0, samplesPerFrame: samplesPerFrame, sampleRate: sampleRate
        ).isEmpty)
        #expect(AudioChunker.chunkRanges(
            voiceActivity: [true], totalSamples: 100, samplesPerFrame: 0, sampleRate: sampleRate
        ).isEmpty)
    }
}
