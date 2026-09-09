import Foundation

/// Decides how much of the silent tail to drop before a recording reaches the model.
///
/// Whisper pays for silence twice. It pads every input to a 30s window, so trailing room noise is
/// decoded like any other audio, and that decode is where the sign-off hallucinations tracked as
/// known issue #2 come from. Trimming the tail removes both costs at once.
///
/// Only the tail is considered. Trimming the head or the middle risks clipping real speech, and
/// "I spoke and nothing happened" is a far worse failure than a stray closing phrase.
enum TrailingSilenceTrimmer {
    /// Shorter tails are inside the range of an ordinary end-of-sentence pause and are not worth
    /// the risk of cutting anything.
    static let minimumTrailingSilence: TimeInterval = 1.0

    /// Kept after the last frame with speech in it, so a trailing consonant that fell below the
    /// energy threshold is still handed to the model.
    static let keptPadding: TimeInterval = 0.5

    /// The number of leading samples to keep, or `nil` when the clip should be passed through
    /// untouched.
    ///
    /// Returning `nil` when the detector heard nothing at all is deliberate: a clip the VAD cannot
    /// hear is exactly the clip that must not be discarded on the VAD's say-so. Quiet speech still
    /// reaches the model, and the existing empty-transcript path handles genuine silence.
    static func trimmedSampleCount(
        voiceActivity: [Bool],
        totalSamples: Int,
        samplesPerFrame: Int,
        sampleRate: Int
    ) -> Int? {
        guard samplesPerFrame > 0, sampleRate > 0, totalSamples > 0 else {
            return nil
        }

        guard let lastSpeechFrame = voiceActivity.lastIndex(of: true) else {
            return nil
        }

        let speechEndSample = (lastSpeechFrame + 1) * samplesPerFrame
        let paddedEndSample = speechEndSample + Int(keptPadding * Double(sampleRate))
        let keptSamples = min(totalSamples, paddedEndSample)
        let removedSeconds = Double(totalSamples - keptSamples) / Double(sampleRate)

        guard removedSeconds >= minimumTrailingSilence else {
            return nil
        }

        return keptSamples
    }
}
