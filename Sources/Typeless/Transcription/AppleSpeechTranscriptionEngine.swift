import AVFoundation
import Foundation
import Speech

/// Transcribes using the on-device engine that sits behind macOS dictation, exposed as
/// `SpeechAnalyzer` + `SpeechTranscriber` in macOS 26.
///
/// This is not system dictation. System dictation types into whatever control has focus, which is
/// why it forces the user to stay on one screen. This API takes audio in and hands a string back,
/// so NoType keeps deciding where the transcript lands — the shortcut can be pressed from anywhere.
///
/// Measured against the bundled Whisper model on the same clip: it does not translate, does not
/// emit subtitle sign-offs, and finishes far faster (roughly 0.03x real time).
@available(macOS 26.0, *)
@MainActor
final class AppleSpeechTranscriptionEngine: TranscriptionEngine, LocalModelReadinessReporting {
    var onModelReadinessChange: ((LocalModelReadiness) -> Void)?

    /// Locales whose assets are installed *and* reserved for this app. The system may evict a
    /// locale that nobody reserved, so readiness is tracked per locale rather than once per launch.
    private var readyLocales: Set<Locale> = []

    /// Asset downloads are slow and must not run twice for the same locale when two dictations
    /// overlap, so an in-flight preparation is shared rather than restarted.
    private var preparationTasks: [Locale: Task<Void, Error>] = [:]

    func transcribe(
        _ clip: RecordedAudioClip,
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference
    ) async throws -> TranscriptResult {
        let locale = await Self.resolveLocale(for: language, chineseScriptPreference: chineseScriptPreference)
        try await prepare(locale)

        let transcriber = SpeechTranscriber(locale: locale, preset: Self.preset)
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        // The results sequence must be consumed while the analyzer runs; draining it afterwards
        // would deadlock against an analyzer that is waiting for its output to be read.
        let collector = Task {
            var segments: [AttributedString] = []
            for try await result in transcriber.results where result.isFinal {
                segments.append(result.text)
            }
            return segments
        }

        do {
            let file = try Self.openClip(clip)
            _ = try await analyzer.analyzeSequence(from: file)
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        } catch {
            collector.cancel()
            AppLogger.log("AppleSpeech: analysis failed for \(locale.identifier): \(error.localizedDescription)")
            throw TranscriptionError.failed("Apple speech analysis failed: \(error.localizedDescription)")
        }

        // Long clips arrive as several final segments, one per sentence group. Keeping only the
        // last one would silently drop everything the user said before the final sentence.
        let segments = try await collector.value
        let rawText = segments
            .map { String($0.characters) }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Silence is not a failure. The coordinator already reports an empty transcript as
        // "nothing to insert" and leaves the clipboard alone; throwing here instead would light up
        // a red error state every time the user starts a recording and decides not to speak.
        guard rawText.isEmpty == false else {
            AppLogger.log("AppleSpeech: \(locale.identifier) heard no speech in \(segments.count) segment(s)")
            return TranscriptResult(text: "", rawText: "")
        }

        let cleanedText = TranscriptPostProcessor.clean(
            rawText,
            preferredLanguage: language,
            chineseScriptPreference: chineseScriptPreference
        )
        AppLogger.log(
            "AppleSpeech: \(locale.identifier) transcribed \(segments.count) segment(s); " +
            "raw=\"\(rawText)\" cleaned=\"\(cleanedText)\""
        )
        return TranscriptResult(text: cleanedText, rawText: rawText)
    }

    /// Downloads and reserves the assets for the language the user currently has selected, so the
    /// first dictation does not stall on a model download.
    func prewarm() async {
        let locale = await Self.resolveLocale(for: .mixed, chineseScriptPreference: .followModel)
        do {
            try await prepare(locale)
        } catch {
            // Best effort: a real dictation will surface the failure with proper error handling.
            AppLogger.log("AppleSpeech.prewarm: \(error.localizedDescription)")
        }
    }

    // MARK: - Asset preparation

    private func prepare(_ locale: Locale) async throws {
        guard readyLocales.contains(locale) == false else { return }

        if let inFlight = preparationTasks[locale] {
            try await inFlight.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            try await self.performPreparation(locale)
        }
        preparationTasks[locale] = task
        defer { preparationTasks[locale] = nil }

        do {
            try await task.value
            readyLocales.insert(locale)
            onModelReadinessChange?(.ready)
        } catch {
            onModelReadinessChange?(.failed(Self.readinessFailureMessage(for: error)))
            throw error
        }
    }

    private func performPreparation(_ locale: Locale) async throws {
        onModelReadinessChange?(.preparing)

        let authorization = await Self.requestAuthorization()
        guard authorization == .authorized else {
            AppLogger.log("AppleSpeech: speech recognition not authorized (status=\(authorization.rawValue))")
            throw TranscriptionError.modelUnavailable(
                "Speech Recognition permission is required. Grant it in System Settings › Privacy & Security › Speech Recognition."
            )
        }

        let transcriber = SpeechTranscriber(locale: locale, preset: Self.preset)
        let installed = await SpeechTranscriber.installedLocales
        if installed.contains(where: { $0.identifier == locale.identifier }) == false {
            AppLogger.log("AppleSpeech: downloading on-device assets for \(locale.identifier)")
            guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
                throw TranscriptionError.modelUnavailable(
                    "macOS has no on-device speech model available for \(locale.identifier)."
                )
            }
            try await request.downloadAndInstall()
            AppLogger.log("AppleSpeech: installed on-device assets for \(locale.identifier)")
        }

        // Without a reservation the system is free to evict the locale to reclaim disk space,
        // which would turn a later dictation into a surprise download.
        _ = try? await AssetInventory.reserve(locale: locale)
    }

    // MARK: - Locale selection

    /// Whisper detects the spoken language on its own; this engine cannot — a transcriber is built
    /// for exactly one locale. `.mixed` therefore resolves to the user's own preferred language
    /// rather than to a detector, and the chosen locale still transcribes foreign words it hears.
    nonisolated static func resolveLocale(
        for language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference
    ) async -> Locale {
        let supported = await SpeechTranscriber.supportedLocales

        switch language {
        case .chinese:
            return resolve(preferring: chineseCandidates(for: chineseScriptPreference), in: supported)
        case .english:
            return resolve(preferring: ["en-US", "en-GB"], in: supported)
        case .mixed:
            let preferred = Locale.preferredLanguages + ["zh-CN", "en-US"]
            return resolve(preferring: preferred, in: supported)
        }
    }

    nonisolated static func chineseCandidates(for preference: ChineseScriptPreference) -> [String] {
        switch preference {
        case .traditional:
            // Hong Kong Cantonese is a poor stand-in for spoken Mandarin, so zh-TW leads and
            // zh-CN backstops: post-processing converts the script if the locale is unavailable.
            ["zh-TW", "zh-HK", "zh-CN"]
        case .simplified, .followModel:
            ["zh-CN", "zh-TW"]
        }
    }

    private nonisolated static func resolve(preferring identifiers: [String], in supported: [Locale]) -> Locale {
        for identifier in identifiers {
            let candidate = Locale(identifier: identifier)
            if let match = matching(candidate, in: supported) {
                return match
            }
        }
        return matching(Locale(identifier: "en-US"), in: supported) ?? Locale(identifier: "en-US")
    }

    /// Matches on language plus region when the region is supported, and falls back to any locale
    /// sharing the language code — so a user set to `zh-Hans-SG` still lands on a Chinese model.
    private nonisolated static func matching(_ candidate: Locale, in supported: [Locale]) -> Locale? {
        if let exact = supported.first(where: { $0.identifier(.bcp47) == candidate.identifier(.bcp47) }) {
            return exact
        }
        guard let languageCode = candidate.language.languageCode?.identifier else { return nil }
        if let regionMatch = supported.first(where: {
            $0.language.languageCode?.identifier == languageCode
                && $0.region?.identifier == candidate.region?.identifier
        }) {
            return regionMatch
        }
        return supported.first { $0.language.languageCode?.identifier == languageCode }
    }

    // MARK: - Audio

    /// `analyzeSequence(from:)` converts the file to whatever the analyzer needs, and NoType
    /// already records 16 kHz mono PCM — the format the analyzer asks for — so this is a plain open.
    private static func openClip(_ clip: RecordedAudioClip) throws -> AVAudioFile {
        try AVAudioFile(forReading: clip.fileURL)
    }

    // MARK: - Configuration

    /// The clip is already complete by the time this engine runs, so volatile partial results would
    /// only add work. `.transcription` reports finished segments and nothing else.
    private static let preset: SpeechTranscriber.Preset = .transcription

    /// `nonisolated` is load-bearing. TCC delivers this callback on a background queue, so a
    /// closure that inherited the engine's `@MainActor` isolation trips Swift's executor assertion
    /// and traps. The crash only appears the very first time a user is asked for the permission,
    /// which is exactly when it must not happen.
    private nonisolated static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        let current = SFSpeechRecognizer.authorizationStatus()
        guard current == .notDetermined else { return current }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private static func readinessFailureMessage(for error: Error) -> String {
        if case let TranscriptionError.modelUnavailable(reason) = error {
            return reason
        }
        return error.localizedDescription
    }
}
