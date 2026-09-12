import Foundation

/// Splits a long recording into segments an utterance-level recognizer can actually decode.
///
/// Qwen3-ASR is reliable up to roughly 30s and fails badly past it. Measured on 2026-09-09 against
/// the model's own sample files, at every `max_total_len` from 512 to 4096:
///
/// | Audio | Expected | Best observed |
/// | --- | --- | --- |
/// | 31s | 179 chars | 160 chars, correct |
/// | 63s | 628 chars | 220 chars — 65% missing |
/// | 191s | 2672 chars | 83 chars, or the single token `language` |
///
/// Raising `max_total_len` does not fix it and introduces a second failure: a 124s clip at 4096
/// ran away to 6693 characters over 428 seconds. Splitting is the fix — every segment stays inside
/// the range where the model is known to be correct, and short recordings keep the single-decode
/// path that measured fastest.
enum AudioChunker {
    /// Recordings at or under this are decoded whole. 31s was verified correct; the margin below it
    /// is deliberate, because a densely spoken clip produces more tokens than the measured samples.
    static let singleDecodeLimit: TimeInterval = 24

    /// The longest segment handed to the recognizer once splitting starts.
    static let maximumChunkDuration: TimeInterval = 24

    /// A split is only looked for after this much of a chunk has been filled. Without a floor, the
    /// first pause in a sentence would end the chunk and produce many tiny segments.
    static let earliestSplitFraction = 0.6

    /// Sample ranges to decode, in order. A recording short enough to decode whole returns one range.
    ///
    /// Splits land in the middle of the longest pause available, so a cut falls between words rather
    /// than through one. When a chunk contains no pause at all — continuous speech for the full
    /// duration — it is cut at the limit anyway: a hard cut loses a word boundary, while not cutting
    /// loses everything past the model's usable range.
    static func chunkRanges(
        voiceActivity: [Bool],
        totalSamples: Int,
        samplesPerFrame: Int,
        sampleRate: Int
    ) -> [Range<Int>] {
        guard samplesPerFrame > 0, sampleRate > 0, totalSamples > 0 else { return [] }

        let singleDecodeSamples = Int(singleDecodeLimit * Double(sampleRate))
        guard totalSamples > singleDecodeSamples else { return [0..<totalSamples] }

        let maximumChunkSamples = Int(maximumChunkDuration * Double(sampleRate))
        let earliestOffset = Int(Double(maximumChunkSamples) * earliestSplitFraction)

        var ranges: [Range<Int>] = []
        var start = 0

        while start < totalSamples {
            // A tail that already fits is kept whole rather than cut to make an even split.
            if totalSamples - start <= singleDecodeSamples {
                ranges.append(start..<totalSamples)
                break
            }

            let hardEnd = min(start + maximumChunkSamples, totalSamples)
            let end = quietestSplit(
                voiceActivity: voiceActivity,
                searchStart: start + earliestOffset,
                searchEnd: hardEnd,
                samplesPerFrame: samplesPerFrame
            ) ?? hardEnd

            // Guard against a split that fails to advance, which would loop forever.
            guard end > start else {
                ranges.append(start..<totalSamples)
                break
            }

            ranges.append(start..<end)
            start = end
        }

        return ranges
    }

    /// The midpoint of the longest silent run inside the search window, or `nil` when the window
    /// holds no silence.
    private static func quietestSplit(
        voiceActivity: [Bool],
        searchStart: Int,
        searchEnd: Int,
        samplesPerFrame: Int
    ) -> Int? {
        guard searchEnd > searchStart else { return nil }

        let firstFrame = max(0, searchStart / samplesPerFrame)
        let lastFrame = min(voiceActivity.count, (searchEnd + samplesPerFrame - 1) / samplesPerFrame)
        guard firstFrame < lastFrame else { return nil }

        var bestRun: Range<Int>?
        var currentRunStart: Int?

        for frame in firstFrame..<lastFrame {
            if voiceActivity[frame] {
                if let runStart = currentRunStart {
                    bestRun = longer(bestRun, than: runStart..<frame)
                    currentRunStart = nil
                }
            } else if currentRunStart == nil {
                currentRunStart = frame
            }
        }
        if let runStart = currentRunStart {
            bestRun = longer(bestRun, than: runStart..<lastFrame)
        }

        guard let run = bestRun else { return nil }

        let midpointFrame = run.lowerBound + (run.count / 2)
        let split = midpointFrame * samplesPerFrame
        // The midpoint can land outside the window when a silent run starts before it.
        return min(max(split, searchStart), searchEnd)
    }

    private static func longer(_ current: Range<Int>?, than candidate: Range<Int>) -> Range<Int> {
        guard let current, current.count >= candidate.count else { return candidate }
        return current
    }
}
