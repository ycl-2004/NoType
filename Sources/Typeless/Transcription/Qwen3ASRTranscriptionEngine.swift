import Foundation
@preconcurrency import SherpaOnnx

private final class Qwen3ASRRecognizerBox: @unchecked Sendable {
    let recognizer: SherpaOnnxOfflineRecognizer

    init(recognizer: SherpaOnnxOfflineRecognizer) {
        self.recognizer = recognizer
    }
}

private struct Qwen3ASRDecodeOutput: Sendable {
    let text: String
    let language: String
}

/// Transcribes with the official sherpa-onnx Qwen3-ASR 0.6B INT8 offline model.
///
/// Qwen3-ASR performs multilingual recognition itself, so unlike the removed Whisper path this
/// engine needs one recognizer and one decode per completed clip. The selected recognition mode is
/// still passed to post-processing for Chinese-script preferences and remains part of the public
/// `TranscriptionEngine` contract.
@MainActor
final class Qwen3ASRTranscriptionEngine: TranscriptionEngine, LocalModelReadinessReporting {
    nonisolated static let sampleRate = AudioSamplesLoader.sampleRate
    nonisolated static let featureDimension = 80
    nonisolated static let executionProvider = "cpu"
    nonisolated static let maxTotalLength = Qwen3ASRPaths.maxTotalLength
    nonisolated static let maxNewTokens = Qwen3ASRPaths.maxNewTokens

    var onModelReadinessChange: ((LocalModelReadiness) -> Void)?

    private let modelInstaller: Qwen3ASRModelInstalling
    private var recognizerBox: Qwen3ASRRecognizerBox?
    private var loadingTask: Task<Qwen3ASRRecognizerBox, Error>?

    init(modelInstaller: Qwen3ASRModelInstalling = Qwen3ASRModelInstaller()) {
        self.modelInstaller = modelInstaller
    }

    func transcribe(
        _ clip: RecordedAudioClip,
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference
    ) async throws -> TranscriptResult {
        let recognizer = try await loadRecognizer()
        let samples: [Float]
        do {
            samples = try AudioSamplesLoader.loadSamplesTrimmingTrailingSilence(for: clip)
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.failed(
                "Could not load audio for Qwen3-ASR: \(error.localizedDescription)"
            )
        }

        guard samples.isEmpty == false else {
            AppLogger.log("Qwen3-ASR: audio samples were empty")
            return TranscriptResult(text: "", rawText: "")
        }

        let vad = AudioEnergyVAD()
        let ranges = AudioChunker.chunkRanges(
            voiceActivity: vad.voiceActivity(in: samples),
            totalSamples: samples.count,
            samplesPerFrame: vad.frameLengthSamples,
            sampleRate: Self.sampleRate
        )

        let startedAt = Date()
        let output = await Task.detached(priority: .userInitiated) {
            Self.decode(samples: samples, ranges: ranges, using: recognizer)
        }.value

        let rawText = output.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let elapsed = Date().timeIntervalSince(startedAt)
        let audioSeconds = Double(samples.count) / Double(Self.sampleRate)
        let realTimeFactor = audioSeconds > 0 ? elapsed / audioSeconds : 0
        AppLogger.log(
            "Qwen3-ASR: language=\(output.language.isEmpty ? "unknown" : output.language), " +
                "\(ranges.count) chunk\(ranges.count == 1 ? "" : "s"), " +
                "\(String(format: "%.2f", elapsed))s for \(String(format: "%.2f", audioSeconds))s " +
                "of audio (rtf \(String(format: "%.3f", realTimeFactor))), raw=\"\(rawText)\""
        )

        guard rawText.isEmpty == false else {
            return TranscriptResult(text: "", rawText: "")
        }

        let cleanedText = TranscriptPostProcessor.clean(
            rawText,
            preferredLanguage: language,
            chineseScriptPreference: chineseScriptPreference
        )
        return TranscriptResult(text: cleanedText, rawText: rawText)
    }

    func prewarm() async {
        do {
            _ = try await loadRecognizer()
        } catch {
            AppLogger.log("Qwen3-ASR: prewarm failed, model will load on first dictation instead: \(error)")
        }
    }

    private func loadRecognizer() async throws -> Qwen3ASRRecognizerBox {
        if let recognizerBox {
            onModelReadinessChange?(.ready)
            return recognizerBox
        }

        if let loadingTask {
            onModelReadinessChange?(.preparing)
            do {
                let loaded = try await loadingTask.value
                recognizerBox = loaded
                onModelReadinessChange?(.ready)
                return loaded
            } catch {
                let message = Self.readinessFailureMessage(for: error)
                onModelReadinessChange?(.failed(message))
                throw error
            }
        }

        onModelReadinessChange?(.preparing)

        if Qwen3ASRPaths.modelFolderExists == false {
            AppLogger.log(
                "Qwen3-ASR: model is missing; downloading to \(Qwen3ASRPaths.displayPath(Qwen3ASRPaths.modelFolder))"
            )
            do {
                guard try await modelInstaller.installIfNeeded(progress: { [weak self] message in
                    self?.onModelReadinessChange?(.preparing)
                    AppLogger.log("Qwen3-ASR: \(message)")
                }) != nil else {
                    let declined = "The Qwen3-ASR model is not installed. Retry model preparation to download it."
                    onModelReadinessChange?(.failed(declined))
                    throw TranscriptionError.modelUnavailable(declined)
                }
            } catch let error as TranscriptionError {
                onModelReadinessChange?(.failed(error.localizedDescription))
                throw error
            } catch {
                let message = "Could not download the Qwen3-ASR model: \(error.localizedDescription)"
                onModelReadinessChange?(.failed(message))
                throw TranscriptionError.modelUnavailable(message)
            }
        }

        if let validationError = Qwen3ASRPaths.validationError() {
            AppLogger.log("Qwen3-ASR: model validation failed: \(validationError)")
            onModelReadinessChange?(.failed(validationError))
            throw TranscriptionError.modelUnavailable(validationError)
        }

        let task = Task.detached(priority: .userInitiated) {
            try Self.makeRecognizer()
        }
        loadingTask = task
        defer { loadingTask = nil }

        do {
            let loaded = try await task.value
            recognizerBox = loaded
            onModelReadinessChange?(.ready)
            AppLogger.log("Qwen3-ASR: INT8 recognizer loaded")
            return loaded
        } catch {
            let message = Self.readinessFailureMessage(for: error)
            onModelReadinessChange?(.failed(message))
            throw error
        }
    }

    /// Decodes each chunk in order and joins the results.
    ///
    /// Chunks are decoded sequentially rather than concurrently: the recognizer is one native object
    /// and the model already saturates the cores it is given. Segments are joined with a space, which
    /// `TranscriptPostProcessor` removes again between Han characters and keeps around Latin text.
    private nonisolated static func decode(
        samples: [Float],
        ranges: [Range<Int>],
        using box: Qwen3ASRRecognizerBox
    ) -> Qwen3ASRDecodeOutput {
        var texts: [String] = []
        var language = ""

        for range in ranges {
            let chunk = range.count == samples.count ? samples : Array(samples[range])
            let result = box.recognizer.decode(samples: chunk, sampleRate: sampleRate)
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty == false {
                texts.append(text)
            }
            if language.isEmpty {
                language = result.lang
            }
        }

        return Qwen3ASRDecodeOutput(text: texts.joined(separator: " "), language: language)
    }

    private nonisolated static func makeRecognizer() throws -> Qwen3ASRRecognizerBox {
        let qwen3ASRConfig = sherpaOnnxOfflineQwen3ASRModelConfig(
            convFrontend: Qwen3ASRPaths.convFrontendURL.path,
            encoder: Qwen3ASRPaths.encoderURL.path,
            decoder: Qwen3ASRPaths.decoderURL.path,
            tokenizer: Qwen3ASRPaths.tokenizerURL.path,
            maxTotalLen: Qwen3ASRPaths.maxTotalLength,
            maxNewTokens: Qwen3ASRPaths.maxNewTokens,
            temperature: Qwen3ASRPaths.temperature,
            topP: Qwen3ASRPaths.topP,
            seed: Qwen3ASRPaths.seed,
            hotwords: ""
        )
        let modelConfig = sherpaOnnxOfflineModelConfig(
            tokens: "",
            numThreads: max(1, ProcessInfo.processInfo.activeProcessorCount / 2),
            provider: executionProvider,
            qwen3Asr: qwen3ASRConfig
        )
        let featureConfig = sherpaOnnxFeatureConfig(
            sampleRate: sampleRate,
            featureDim: featureDimension
        )
        var recognizerConfig = sherpaOnnxOfflineRecognizerConfig(
            featConfig: featureConfig,
            modelConfig: modelConfig,
            decodingMethod: "greedy_search"
        )
        let recognizer = withUnsafePointer(to: &recognizerConfig) {
            SherpaOnnxOfflineRecognizer(config: $0)
        }
        return Qwen3ASRRecognizerBox(recognizer: recognizer)
    }

    private nonisolated static func readinessFailureMessage(for error: Error) -> String {
        if case let TranscriptionError.modelUnavailable(message) = error {
            return message
        }
        return error.localizedDescription
    }
}
