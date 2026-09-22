import Foundation
@preconcurrency import llama

protocol R2T2Runtime: Sendable {
    func transcribe(
        samples: [Float],
        language: DictationRecognitionLanguage,
        isFinal: Bool
    ) async throws -> String
}

/// Experimental R2T2 engine.
///
/// llama.cpp currently gives NoType the Q4_K_M text model plus the Q8_0 audio projector, but does
/// not expose the R2T2/vLLM streaming-state API. While that native state API is pending, the engine
/// runs cumulative prefix decodes at a 320 ms cadence and emits only an append-only stable prefix.
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
    private var activeSession: R2T2StreamSession?
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

        let rawText = try await runtime.transcribe(samples: samples, language: language, isFinal: true)
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
        let session = R2T2StreamSession(
            runtime: runtime,
            language: language,
            chineseScriptPreference: chineseScriptPreference,
            chunkSamples: Self.chunkSamples,
            normalize: Self.normalizeRawText,
            onStableTranscript: { [weak self] text in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    self?.liveTranscriptDidChange(text)
                }
            }
        )
        activeSession = session

        return { samples in
            Task {
                await session.append(samples)
            }
        }
    }

    func finishStreaming() async throws -> TranscriptResult {
        guard let session = activeSession else {
            throw TranscriptionError.failed("R2T2 streaming session is missing")
        }
        activeSession = nil

        let rawText = try await session.finish()
        let language = session.language
        let preference = session.chineseScriptPreference
        let result = Self.makeTranscriptResult(
            rawText,
            language: language,
            chineseScriptPreference: preference
        )
        liveTranscriptDidChange(result.text)
        return result
    }

    func cancelStreaming() {
        guard let activeSession else { return }
        self.activeSession = nil
        Task { await activeSession.cancel() }
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
        if R2T2Paths.modelFolderExists == false {
            do {
                guard try await modelInstaller.installIfNeeded(progress: { [weak self] message in
                    self?.onModelReadinessChange?(.preparing)
                    AppLogger.log("R2T2: \(message)")
                }) != nil else {
                    let message = "The R2T2 model is not installed. Retry model preparation to download it."
                    onModelReadinessChange?(.failed(message))
                    throw TranscriptionError.modelUnavailable(message)
                }
            } catch let error as TranscriptionError {
                onModelReadinessChange?(.failed(error.localizedDescription))
                throw error
            } catch {
                let message = "Could not download the R2T2 model: \(error.localizedDescription)"
                onModelReadinessChange?(.failed(message))
                throw TranscriptionError.modelUnavailable(message)
            }
        }

        if let validationError = R2T2Paths.validationError() {
            onModelReadinessChange?(.failed(validationError))
            throw TranscriptionError.modelUnavailable(validationError)
        }

        let makeRuntime = self.makeRuntime
        let task = Task.detached(priority: .userInitiated) {
            try makeRuntime(R2T2Paths.modelURL, R2T2Paths.projectorURL)
        }
        loadingTask = task
        defer { loadingTask = nil }

        do {
            let loaded = try await task.value
            runtime = loaded
            onModelReadinessChange?(.ready)
            AppLogger.log("R2T2: Q4_K_M model and Q8_0 audio projector loaded with Metal")
            return loaded
        } catch {
            let message = Self.readinessFailureMessage(for: error)
            onModelReadinessChange?(.failed(message))
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

/// The stream actor owns ordering and coalesces work if a decode is slower than the microphone.
private actor R2T2StreamSession {
    let language: DictationRecognitionLanguage
    let chineseScriptPreference: ChineseScriptPreference

    private let runtime: any R2T2Runtime
    private let chunkSamples: Int
    private let normalize: @Sendable (String) -> String
    private let onStableTranscript: @Sendable (String) -> Void
    private var samples: [Float] = []
    private var stableText = ""
    private var lastSubmittedSampleCount = 0
    private var processingTask: Task<Void, Never>?
    private var isFinishing = false
    private var isCancelled = false
    private var partialError: Error?

    init(
        runtime: any R2T2Runtime,
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference,
        chunkSamples: Int,
        normalize: @escaping @Sendable (String) -> String,
        onStableTranscript: @escaping @Sendable (String) -> Void
    ) {
        self.runtime = runtime
        self.language = language
        self.chineseScriptPreference = chineseScriptPreference
        self.chunkSamples = chunkSamples
        self.normalize = normalize
        self.onStableTranscript = onStableTranscript
    }

    func append(_ newSamples: [Float]) {
        guard !isCancelled, !newSamples.isEmpty else { return }
        samples.append(contentsOf: newSamples)
        schedulePartialIfNeeded()
    }

    func finish() async throws -> String {
        guard !isCancelled else {
            throw TranscriptionError.failed("R2T2 streaming session was cancelled")
        }
        isFinishing = true
        while let processingTask {
            await processingTask.value
            self.processingTask = nil
        }
        if let partialError {
            AppLogger.log("R2T2: partial decode failed before finalization: \(partialError)")
        }
        guard samples.isEmpty == false else { return "" }
        let final = try await runtime.transcribe(
            samples: samples,
            language: language,
            isFinal: true
        )
        let normalized = normalize(final)
        if normalized.isEmpty == false {
            stableText = normalized
            onStableTranscript(stableText)
        }
        return final
    }

    func cancel() {
        isCancelled = true
        processingTask?.cancel()
        processingTask = nil
        samples.removeAll(keepingCapacity: false)
    }

    private func schedulePartialIfNeeded() {
        guard !isFinishing,
              !isCancelled,
              partialError == nil,
              processingTask == nil,
              samples.count - lastSubmittedSampleCount >= chunkSamples else {
            return
        }

        let snapshot = samples
        lastSubmittedSampleCount = snapshot.count
        processingTask = Task { [runtime, language, normalize, weak self] in
            do {
                let raw = try await runtime.transcribe(
                    samples: snapshot,
                    language: language,
                    isFinal: false
                )
                await self?.partialFinished(normalize(raw))
            } catch {
                await self?.partialFailed(error)
            }
        }
    }

    private func partialFinished(_ candidate: String) {
        processingTask = nil
        guard !isCancelled, !isFinishing else { return }
        guard candidate.isEmpty == false else {
            schedulePartialIfNeeded()
            return
        }

        stableText = Self.appendOnlyStablePrefix(previous: stableText, candidate: candidate)
        onStableTranscript(stableText)
        schedulePartialIfNeeded()
    }

    private func partialFailed(_ error: Error) {
        processingTask = nil
        partialError = error
        AppLogger.log("R2T2: partial decode failed: \(error.localizedDescription)")
    }

    private static func appendOnlyStablePrefix(previous: String, candidate: String) -> String {
        guard previous.isEmpty == false else { return candidate }
        guard candidate.hasPrefix(previous) else {
            let previousScalars = Array(previous)
            let candidateScalars = Array(candidate)
            let commonCount = zip(previousScalars, candidateScalars)
                .prefix { $0 == $1 }
                .count
            return String(previousScalars.prefix(commonCount))
        }
        return candidate
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
        language: DictationRecognitionLanguage,
        isFinal _: Bool
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

        var pieces = ""
        for _ in 0..<512 {
            let token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocabulary, token) { break }
            pieces += tokenPiece(token)

            var mutableToken = token
            let batch = withUnsafeMutablePointer(to: &mutableToken) {
                llama_batch_get_one($0, 1)
            }
            guard llama_decode(context, batch) == 0 else {
                throw TranscriptionError.failed("llama.cpp failed while decoding R2T2 text.")
            }
        }
        return pieces
    }

    private func tokenPiece(_ token: Int32) -> String {
        var buffer = [Int8](repeating: 0, count: 256)
        let count = buffer.withUnsafeMutableBufferPointer { buffer in
            llama_token_to_piece(vocabulary, token, buffer.baseAddress, Int32(buffer.count), 0, false)
        }
        guard count > 0 else { return "" }
        return String(decoding: buffer.prefix(Int(count)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
