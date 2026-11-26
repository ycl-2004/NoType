import Foundation
@preconcurrency import llama

protocol R2T2Runtime: Sendable {
    func transcribe(
        samples: [Float],
        language: DictationRecognitionLanguage
    ) async throws -> String
}

/// The R2T2 local engine.
///
/// llama.cpp currently gives NoType the Q4_K_M text model plus the Q8_0 audio projector, but does
/// not expose the R2T2/vLLM streaming-state API. While that native state API is pending, the engine
/// decodes bounded segments and reuses completed segments; only the current tail is previewed.
/// This keeps the product contract correct — no live insertion and one final output pipeline — and
/// leaves the runtime behind a small protocol so true stateful decoding can replace it later.
@MainActor
final class R2T2TranscriptionEngine: StreamingTranscriptionEngine, LocalModelReadinessReporting {
    nonisolated static let sampleRate = R2T2Paths.sampleRate
    nonisolated static let chunkDurationMilliseconds = R2T2Paths.chunkDurationMilliseconds
    nonisolated static let chunkSamples = sampleRate * chunkDurationMilliseconds / 1_000
    nonisolated static let executionProvider = "Metal"

    var onModelReadinessChange: ((LocalModelReadiness) -> Void)?

    private let modelInstaller: R2T2ModelInstalling
    private let makeRuntime: @Sendable (URL, URL) throws -> any R2T2Runtime
    private var runtime: (any R2T2Runtime)?
    private var loadingTask: Task<any R2T2Runtime, Error>?
    private var activeSession: R2T2AudioStream?
    private let appState: AppState

    var canStream: Bool { true }

    init(
        appState: AppState,
        modelInstaller: R2T2ModelInstalling = R2T2ModelInstaller(),
        makeRuntime: @escaping @Sendable (URL, URL) throws -> any R2T2Runtime = {
            try R2T2LlamaRuntime(modelURL: $0, projectorURL: $1)
        }
    ) {
        self.appState = appState
        self.modelInstaller = modelInstaller
        self.makeRuntime = makeRuntime
    }

    func transcribe(
        _ clip: RecordedAudioClip,
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference
    ) async throws -> TranscriptResult {
        let runtime = try await loadRuntime()
        let samples = try loadSamples(for: clip)
        guard samples.isEmpty == false else {
            return TranscriptResult(text: "", rawText: "")
        }

        let rawText = try await R2T2SegmentDecoder.transcribe(samples, runtime: runtime, language: language)
        return Self.makeTranscriptResult(
            rawText,
            language: language,
            chineseScriptPreference: chineseScriptPreference
        )
    }

    func beginStreaming(
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference
    ) async throws -> @Sendable ([Float]) -> Void {
        guard activeSession == nil else {
            throw TranscriptionError.failed("R2T2 streaming session is already active")
        }

        let runtime = try await loadRuntime()
        let sessionID = UUID()
        let session = R2T2StreamSession(
            runtime: runtime,
            language: language,
            chineseScriptPreference: chineseScriptPreference,
            previewsEnabled: appState.showsVoiceOverlay && appState.showsLiveTranscript,
            onPreview: { [weak self] text in
                Task { @MainActor [weak self] in
                    guard let self, self.activeSession?.id == sessionID else { return }
                    self.liveTranscriptDidChange(text)
                }
            }
        )
        let stream = R2T2AudioStream(id: sessionID, session: session)
        activeSession = stream
        return { samples in stream.append(samples) }
    }

    func finishStreaming() async throws -> TranscriptResult {
        guard let stream = activeSession else {
            throw TranscriptionError.failed("R2T2 streaming session is missing")
        }
        defer { activeSession = nil }
        let rawText = try await stream.finish()
        let result = Self.makeTranscriptResult(
            rawText,
            language: stream.session.language,
            chineseScriptPreference: stream.session.chineseScriptPreference
        )
        liveTranscriptDidChange(result.text)
        return result
    }

    func cancelStreaming() {
        activeSession?.cancel()
        activeSession = nil
    }

    func prewarm() async {
        do {
            _ = try await loadRuntime()
        } catch {
            AppLogger.log("R2T2: prewarm failed, model will load on first dictation instead: \(error)")
        }
    }

    private func loadRuntime() async throws -> any R2T2Runtime {
        if let runtime {
            onModelReadinessChange?(.ready)
            return runtime
        }

        if let loadingTask {
            onModelReadinessChange?(.preparing)
            do {
                let loaded = try await loadingTask.value
                runtime = loaded
                onModelReadinessChange?(.ready)
                return loaded
            } catch {
                let message = Self.readinessFailureMessage(for: error)
                onModelReadinessChange?(.failed(message))
                throw error
            }
        }

        onModelReadinessChange?(.preparing)
        let makeRuntime = self.makeRuntime
        // Deduplicate the entire preparation, including downloads and integrity verification.
        let task = Task { @MainActor [modelInstaller] in
            guard try await modelInstaller.installIfNeeded(progress: { message in
                AppLogger.log("R2T2: \(message)")
            }) != nil else {
                throw TranscriptionError.modelUnavailable("R2T2 is not installed. Retry model preparation.")
            }
            if let error = R2T2Paths.validationError() {
                throw TranscriptionError.modelUnavailable(error)
            }
            return try await Task.detached(priority: .userInitiated) {
                try makeRuntime(R2T2Paths.modelURL, R2T2Paths.projectorURL)
            }.value
        }
        loadingTask = task
        defer { loadingTask = nil }
        do {
            let loaded = try await task.value
            runtime = loaded
            onModelReadinessChange?(.ready)
            AppLogger.log("R2T2: verified model and projector loaded with Metal")
            return loaded
        } catch {
            onModelReadinessChange?(.failed(Self.readinessFailureMessage(for: error)))
            throw error
        }
    }

    private func loadSamples(for clip: RecordedAudioClip) throws -> [Float] {
        do {
            return try AudioSamplesLoader.loadSamplesTrimmingTrailingSilence(for: clip)
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.failed(
                "Could not load audio for R2T2: \(error.localizedDescription)"
            )
        }
    }

    private func liveTranscriptDidChange(_ text: String) {
        AppLogger.log("R2T2: stable transcript length=\(text.count)")
        // The preview is display-only. DictationCoordinator remains the only place allowed to
        // touch the captured target or the clipboard.
        appState.setLiveTranscript(text)
    }

    private static func makeTranscriptResult(
        _ rawText: String,
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference
    ) -> TranscriptResult {
        let normalized = normalizeRawText(rawText)
        guard normalized.isEmpty == false else {
            return TranscriptResult(text: "", rawText: "")
        }
        let cleaned = TranscriptPostProcessor.clean(
            normalized,
            preferredLanguage: language,
            chineseScriptPreference: chineseScriptPreference
        )
        return TranscriptResult(text: cleaned, rawText: normalized)
    }

    nonisolated static func normalizeRawText(_ text: String) -> String {
        var normalized = text
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .replacingOccurrences(of: "<|endoftext|>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let marker = normalized.range(of: "<asr_text>", options: [.caseInsensitive]) {
            normalized = String(normalized[marker.upperBound...])
        } else if let languagePrefix = normalized.range(
            of: #"^language\s+[^<]+"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            normalized.removeSubrange(languagePrefix)
        }

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func readinessFailureMessage(for error: Error) -> String {
        if case let TranscriptionError.modelUnavailable(message) = error {
            return message
        }
        return error.localizedDescription
    }
}

private final class R2T2LlamaRuntime: R2T2Runtime, @unchecked Sendable {
    private static let backendInitialized: Void = {
        llama_backend_init()
    }()

    private let model: OpaquePointer
    private let context: OpaquePointer
    private let projector: OpaquePointer
    private let vocabulary: OpaquePointer
    private let sampler: UnsafeMutablePointer<llama_sampler>
    private let lock = NSLock()

    init(modelURL: URL, projectorURL: URL) throws {
        _ = Self.backendInitialized

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = -1 // Metal on Apple Silicon.
        guard let model = modelURL.path.withCString({ llama_model_load_from_file($0, modelParams) }) else {
            throw TranscriptionError.modelUnavailable("llama.cpp could not load the R2T2 GGUF model.")
        }
        self.model = model

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = 8_192
        contextParams.n_batch = 2_048
        contextParams.n_ubatch = 512
        contextParams.n_threads = max(1, Int32(ProcessInfo.processInfo.activeProcessorCount / 2))
        contextParams.n_threads_batch = contextParams.n_threads
        guard let context = llama_init_from_model(model, contextParams) else {
            llama_model_free(model)
            throw TranscriptionError.modelUnavailable("llama.cpp could not create the R2T2 context.")
        }
        self.context = context

        var projectorParams = mtmd_context_params_default()
        projectorParams.use_gpu = true
        projectorParams.n_threads = contextParams.n_threads
        guard let projector = projectorURL.path.withCString({
            mtmd_init_from_file($0, model, projectorParams)
        }) else {
            llama_free(context)
            llama_model_free(model)
            throw TranscriptionError.modelUnavailable("llama.cpp could not load the R2T2 Q8_0 audio projector.")
        }
        guard mtmd_support_audio(projector) else {
            mtmd_free(projector)
            llama_free(context)
            llama_model_free(model)
            throw TranscriptionError.modelUnavailable("The R2T2 projector does not advertise audio input support.")
        }

        guard let vocabulary = llama_model_get_vocab(model),
              let sampler = llama_sampler_init_greedy() else {
            mtmd_free(projector)
            llama_free(context)
            llama_model_free(model)
            throw TranscriptionError.modelUnavailable("llama.cpp could not initialize the R2T2 decoder.")
        }
        self.projector = projector
        self.vocabulary = vocabulary
        self.sampler = sampler
    }

    deinit {
        llama_sampler_free(sampler)
        mtmd_free(projector)
        llama_free(context)
        llama_model_free(model)
    }

    func transcribe(
        samples: [Float],
        language: DictationRecognitionLanguage
    ) async throws -> String {
        try transcribeSynchronously(samples: samples, language: language)
    }

    private func transcribeSynchronously(
        samples: [Float],
        language: DictationRecognitionLanguage
    ) throws -> String {
        lock.lock()
        defer { lock.unlock() }
        guard samples.isEmpty == false else { return "" }

        llama_memory_clear(llama_get_memory(context), true)
        llama_sampler_reset(sampler)

        let instruction: String = switch language {
        case .mixed:
            "Transcribe audio to text."
        case .english:
            "Transcribe the audio into English text."
        case .chinese:
            "Transcribe the audio into Chinese text."
        }
        let prompt = "<|im_start|>user\n<__media__>\(instruction)<|im_end|>\n<|im_start|>assistant\n"

        let bitmap = samples.withUnsafeBufferPointer { buffer in
            mtmd_bitmap_init_from_audio(buffer.count, buffer.baseAddress)
        }
        guard let bitmap else {
            throw TranscriptionError.failed("llama.cpp could not create an audio bitmap.")
        }
        defer { mtmd_bitmap_free(bitmap) }

        guard let chunks = mtmd_input_chunks_init() else {
            throw TranscriptionError.failed("llama.cpp could not tokenize the R2T2 prompt.")
        }
        defer { mtmd_input_chunks_free(chunks) }

        let tokenizeResult: Int32 = prompt.withCString { promptCString in
            var text = mtmd_input_text(
                text: promptCString,
                text_len: prompt.utf8.count,
                add_special: false,
                parse_special: true
            )
            let bitmaps: [OpaquePointer?] = [bitmap]
            return withUnsafePointer(to: &text) { textPointer in
                bitmaps.withUnsafeBufferPointer { bitmapBuffer in
                    mtmd_tokenize(
                        projector,
                        chunks,
                        textPointer,
                        bitmapBuffer.baseAddress,
                        bitmapBuffer.count
                    )
                }
            }
        }
        guard tokenizeResult == 0 else {
            throw TranscriptionError.failed("llama.cpp could not tokenize R2T2 audio (error \(tokenizeResult)).")
        }

        // b11102 mtmd-helper.h exposes the prompt token count before allocating KV positions.
        let outputBudget = 1_024
        guard mtmd_helper_get_n_tokens(chunks) + outputBudget < Int(llama_n_ctx(context)) else {
            throw R2T2DecodeError.limitReached
        }
        try Task.checkCancellation()
        var nPast: Int32 = 0
        let evalResult = mtmd_helper_eval_chunks(
            projector,
            context,
            chunks,
            nPast,
            0,
            2_048,
            true,
            &nPast
        )
        guard evalResult == 0 else {
            throw TranscriptionError.failed("llama.cpp could not evaluate R2T2 audio (error \(evalResult)).")
        }

        // Decode bytes only after the full sequence: a UTF-8 character can span tokens.
        var tokens: [llama_token] = []
        for _ in 0..<outputBudget {
            try Task.checkCancellation()
            let token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocabulary, token) {
                return try detokenize(tokens)
            }
            tokens.append(token)
            var mutableToken = token
            let batch = withUnsafeMutablePointer(to: &mutableToken) {
                llama_batch_get_one($0, 1)
            }
            guard llama_decode(context, batch) == 0 else {
                throw TranscriptionError.failed("llama.cpp failed while decoding R2T2 text.")
            }
        }
        // Never return an apparently successful but truncated transcript.
        throw R2T2DecodeError.limitReached
    }

    private func detokenize(_ tokens: [llama_token]) throws -> String {
        guard !tokens.isEmpty else { return "" }
        // llama_detokenize returns the negative required byte count for an undersized buffer.
        // https://github.com/ggml-org/llama.cpp/blob/b11102/include/llama.h
        let required = tokens.withUnsafeBufferPointer {
            llama_detokenize(vocabulary, $0.baseAddress, Int32($0.count), nil, 0, true, false)
        }
        guard required < 0 else { return "" }
        var bytes = [CChar](repeating: 0, count: Int(-required))
        let count = tokens.withUnsafeBufferPointer { tokens in
            bytes.withUnsafeMutableBufferPointer { buffer in
                llama_detokenize(vocabulary, tokens.baseAddress, Int32(tokens.count),
                                 buffer.baseAddress, Int32(buffer.count), true, false)
            }
        }
        guard count >= 0 else {
            throw TranscriptionError.failed("R2T2 could not decode the transcript bytes.")
        }
        return String(decoding: bytes.prefix(Int(count)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
