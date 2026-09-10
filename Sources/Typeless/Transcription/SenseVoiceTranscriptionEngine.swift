import Foundation
@preconcurrency import SherpaOnnx

private final class SenseVoiceRecognizerBox: @unchecked Sendable {
    let recognizer: SherpaOnnxOfflineRecognizer

    init(recognizer: SherpaOnnxOfflineRecognizer) {
        self.recognizer = recognizer
    }
}

private struct SenseVoiceDecodeOutput: Sendable {
    let text: String
    let language: String
}

/// Transcribes with SenseVoice-Small through sherpa-onnx.
///
/// The model is intentionally loaded on demand and always uses the one shared installation under
/// `~/Documents/huggingface`. SenseVoice's language hint is fixed when sherpa creates a recognizer,
/// so the engine recreates the lightweight wrapper when the user changes between auto, Chinese,
/// and English modes while keeping one model file on disk.
@MainActor
final class SenseVoiceTranscriptionEngine: TranscriptionEngine, LocalModelReadinessReporting {
    nonisolated static let sampleRate = 16_000
    nonisolated static let featureDimension = 80
    nonisolated static let executionProvider = "cpu"

    var onModelReadinessChange: ((LocalModelReadiness) -> Void)?

    private let modelInstaller: SenseVoiceModelInstalling
    private var recognizerBox: SenseVoiceRecognizerBox?
    private var recognizerLanguageCode: String?
    private var loadingTask: Task<SenseVoiceRecognizerBox, Error>?
    private var loadingLanguageCode: String?

    init(modelInstaller: SenseVoiceModelInstalling = SenseVoiceModelInstaller()) {
        self.modelInstaller = modelInstaller
    }

    func transcribe(
        _ clip: RecordedAudioClip,
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference
    ) async throws -> TranscriptResult {
        let languageCode = Self.modelLanguageCode(for: language)
        let recognizer = try await loadRecognizer(languageCode: languageCode)
        let samples: [Float]
        do {
            samples = try AudioSamplesLoader.loadSamplesTrimmingTrailingSilence(for: clip)
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.failed(
                "Could not load audio for SenseVoice: \(error.localizedDescription)"
            )
        }

        guard samples.isEmpty == false else {
            AppLogger.log("SenseVoice: audio samples were empty")
            return TranscriptResult(text: "", rawText: "")
        }

        let startedAt = Date()
        let output = await Task.detached(priority: .userInitiated) {
            let result = recognizer.recognizer.decode(
                samples: samples,
                sampleRate: Self.sampleRate
            )
            return SenseVoiceDecodeOutput(text: result.text, language: result.lang)
        }.value

        let rawText = output.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let elapsed = Date().timeIntervalSince(startedAt)
        let audioSeconds = Double(samples.count) / Double(Self.sampleRate)
        let realTimeFactor = audioSeconds > 0 ? elapsed / audioSeconds : 0
        AppLogger.log(
            "SenseVoice: language=\(output.language.isEmpty ? "unknown" : output.language), " +
                "\(String(format: "%.2f", elapsed))s for \(String(format: "%.2f", audioSeconds))s " +
                "of audio (rtf \(String(format: "%.3f", realTimeFactor))), raw=\"\(rawText)\""
        )

        let cleanedText = TranscriptPostProcessor.clean(
            rawText,
            preferredLanguage: language,
            chineseScriptPreference: chineseScriptPreference
        )
        return TranscriptResult(text: cleanedText, rawText: rawText)
    }

    func prewarm() async {
        do {
            _ = try await loadRecognizer(languageCode: Self.modelLanguageCode(for: .mixed))
        } catch {
            AppLogger.log("SenseVoice: prewarm failed, model will load on first dictation instead: \(error)")
        }
    }

    static func modelLanguageCode(for language: DictationRecognitionLanguage) -> String {
        switch language {
        case .mixed:
            "auto"
        case .chinese:
            "zh"
        case .english:
            "en"
        }
    }

    private func loadRecognizer(languageCode: String) async throws -> SenseVoiceRecognizerBox {
        if let recognizerBox, recognizerLanguageCode == languageCode {
            onModelReadinessChange?(.ready)
            return recognizerBox
        }

        if let loadingTask {
            let loaded = try await loadingTask.value
            if loadingLanguageCode == languageCode {
                recognizerBox = loaded
                recognizerLanguageCode = languageCode
                onModelReadinessChange?(.ready)
                return loaded
            }
        }

        recognizerBox = nil
        recognizerLanguageCode = nil
        onModelReadinessChange?(.preparing)

        if SenseVoicePaths.modelFolderExists == false {
            AppLogger.log("SenseVoice: model is missing; downloading to \(SenseVoicePaths.displayPath(SenseVoicePaths.modelFolder))")
            do {
                guard try await modelInstaller.installIfNeeded(progress: { [weak self] message in
                    self?.onModelReadinessChange?(.preparing)
                    AppLogger.log("SenseVoice: \(message)")
                }) != nil else {
                    let declined = "The SenseVoice model is not installed. Retry model preparation to download it."
                    onModelReadinessChange?(.failed(declined))
                    throw TranscriptionError.modelUnavailable(declined)
                }
            } catch let error as TranscriptionError {
                onModelReadinessChange?(.failed(error.localizedDescription))
                throw error
            } catch {
                let message = "Could not download the SenseVoice model: \(error.localizedDescription)"
                onModelReadinessChange?(.failed(message))
                throw TranscriptionError.modelUnavailable(message)
            }
        }

        if let validationError = SenseVoicePaths.validationError() {
            AppLogger.log("SenseVoice: model validation failed: \(validationError)")
            onModelReadinessChange?(.failed(validationError))
            throw TranscriptionError.modelUnavailable(validationError)
        }

        let modelURL = SenseVoicePaths.modelURL
        let tokensURL = SenseVoicePaths.tokensURL
        let task = Task.detached(priority: .userInitiated) {
            try Self.makeRecognizer(
                modelURL: modelURL,
                tokensURL: tokensURL,
                languageCode: languageCode
            )
        }
        loadingTask = task
        loadingLanguageCode = languageCode
        defer {
            if loadingLanguageCode == languageCode {
                loadingTask = nil
                loadingLanguageCode = nil
            }
        }

        do {
            let loaded = try await task.value
            recognizerBox = loaded
            recognizerLanguageCode = languageCode
            onModelReadinessChange?(.ready)
            AppLogger.log("SenseVoice: recognizer loaded with language=\(languageCode)")
            return loaded
        } catch {
            let message = Self.readinessFailureMessage(for: error)
            onModelReadinessChange?(.failed(message))
            throw error
        }
    }

    private nonisolated static func makeRecognizer(
        modelURL: URL,
        tokensURL: URL,
        languageCode: String
    ) throws -> SenseVoiceRecognizerBox {
        let featureConfig = sherpaOnnxFeatureConfig(
            sampleRate: sampleRate,
            featureDim: featureDimension
        )
        let senseVoiceConfig = sherpaOnnxOfflineSenseVoiceModelConfig(
            model: modelURL.path,
            language: languageCode,
            useInverseTextNormalization: true
        )
        let modelConfig = sherpaOnnxOfflineModelConfig(
            tokens: tokensURL.path,
            numThreads: max(1, ProcessInfo.processInfo.activeProcessorCount / 2),
            provider: executionProvider,
            senseVoice: senseVoiceConfig
        )
        var recognizerConfig = sherpaOnnxOfflineRecognizerConfig(
            featConfig: featureConfig,
            modelConfig: modelConfig,
            decodingMethod: "greedy_search"
        )
        let recognizer = withUnsafePointer(to: &recognizerConfig) {
            SherpaOnnxOfflineRecognizer(config: $0)
        }
        return SenseVoiceRecognizerBox(
            recognizer: recognizer
        )
    }

    private nonisolated static func readinessFailureMessage(for error: Error) -> String {
        switch error {
        case let error as TranscriptionError:
            error.localizedDescription
        default:
            error.localizedDescription
        }
    }
}
