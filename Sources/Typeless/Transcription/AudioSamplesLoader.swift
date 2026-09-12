import AVFoundation
import Foundation

/// Loads NoType's 16 kHz mono recordings without depending on a transcription backend.
enum AudioSamplesLoader {
    static let sampleRate = 16_000

    static func loadSamplesTrimmingTrailingSilence(for clip: RecordedAudioClip) throws -> [Float] {
        let audioFile = try AVAudioFile(
            forReading: clip.fileURL,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        guard Int(audioFile.processingFormat.sampleRate.rounded()) == sampleRate else {
            throw TranscriptionError.failed(
                "Expected a \(sampleRate) Hz recording, got \(Int(audioFile.processingFormat.sampleRate.rounded())) Hz."
            )
        }
        guard audioFile.processingFormat.channelCount == 1 else {
            throw TranscriptionError.failed("Expected a mono recording.")
        }

        let frameCapacity = AVAudioFrameCount(max(0, audioFile.length))
        guard frameCapacity > 0 else { return [] }
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: frameCapacity
        ) else {
            throw TranscriptionError.failed("Could not allocate an audio buffer.")
        }

        try audioFile.read(into: buffer)
        guard let channelData = buffer.floatChannelData else {
            throw TranscriptionError.failed("Could not read floating-point audio samples.")
        }

        let samples = Array(UnsafeBufferPointer(
            start: channelData[0],
            count: Int(buffer.frameLength)
        ))
        guard samples.isEmpty == false else { return samples }

        let vad = AudioEnergyVAD()
        guard let keptCount = TrailingSilenceTrimmer.trimmedSampleCount(
            voiceActivity: vad.voiceActivity(in: samples),
            totalSamples: samples.count,
            samplesPerFrame: vad.frameLengthSamples,
            sampleRate: sampleRate
        ) else {
            return samples
        }

        let removedSeconds = Double(samples.count - keptCount) / Double(sampleRate)
        AppLogger.log(
            "AudioSamplesLoader: trimmed \(String(format: "%.2f", removedSeconds))s of trailing silence, " +
                "transcribing \(String(format: "%.2f", Double(keptCount) / Double(sampleRate)))s"
        )
        return Array(samples.prefix(keptCount))
    }
}

/// Small energy VAD used only to trim a long silent tail before offline decoding.
/// The threshold and 100 ms frame match the previous local implementation's behavior.
struct AudioEnergyVAD {
    let frameLengthSamples = 1_600
    let energyThreshold: Float = 0.02

    func voiceActivity(in waveform: [Float]) -> [Bool] {
        guard waveform.isEmpty == false else { return [] }

        let frameCount = (waveform.count + frameLengthSamples - 1) / frameLengthSamples
        return (0..<frameCount).map { frameIndex in
            let start = frameIndex * frameLengthSamples
            let end = min(start + frameLengthSamples, waveform.count)
            let frame = waveform[start..<end]
            guard frame.isEmpty == false else { return false }

            let meanSquare = frame.reduce(Float.zero) { partial, sample in
                partial + (sample * sample)
            } / Float(frame.count)
            return meanSquare.squareRoot() > energyThreshold
        }
    }
}
