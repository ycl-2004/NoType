# Changelog

All notable user-facing changes to NoType are recorded here.

## [Unreleased]

### Added

- Added transcription through the on-device speech engine built into macOS 26, selectable as **Engine → macOS Speech (fast)** in the menu bar. It does not translate, does not emit subtitle sign-off hallucinations, and returns a transcript far sooner than the bundled model. Like the bundled model, it runs entirely on the Mac.
- Added an engine choice that persists across launches. When macOS Speech is selected, **Auto (中英混说) uses Whisper** because the system recognizer cannot detect the spoken language; the menu shows this as `Engine: macOS Speech (fast) → Bundled Whisper` when it applies. See [ADR-004](docs/decisions/004-two-engine-routing.md).
- Added **SenseVoice Small** as a third selectable local engine through sherpa-onnx. It supports Chinese, Cantonese, English, Japanese, and Korean, keeps one ONNX model copy under `~/Documents/huggingface/models/k2-fsa`, and is loaded only when selected. See [ADR-006](docs/decisions/006-sensevoice-engine-and-model-storage.md).
- Added **Manage Downloaded Models** under the engine menu. Deletion is confirmed before removing NoType's downloaded Whisper or SenseVoice folders; macOS Speech system assets and unrelated Hugging Face models are never targeted.
- Added a prompt asking where to install the Whisper model when no copy is found, offering a shared folder (`~/Documents/huggingface`, reused by other WhisperKit apps) or a private one (`~/Library/Application Support/NoType`, removed with the app). Nothing is downloaded until the location is chosen. See [ADR-005](docs/decisions/005-model-location-strategy.md).
- Added a live local-model status section to Diagnostics with Preparing, Ready, and Failed states, first-launch guidance, failure details, and retry support without requiring the debug log.
- Added user-recorded shortcuts for dictation and recognition-mode cycling. Each action can have multiple shortcuts, each shortcut can use a regular key or modifier combination with single or double press activation, and left/right modifier keys are kept distinct. Dictation defaults to Double Command; recognition-mode shortcuts are off by default.

### Changed

- Debug logs retain only the newest five days. Expired entries are removed on logging and when opening Diagnostics.

- The Whisper model is now resolved from an install location before the copy inside the app, and the location is derived from the current user's home directory instead of a hardcoded path. Replacing the app no longer moves the model path, which is what previously discarded the Core ML specialization cache.
- Switched local and bundled WhisperKit builds to the `_turbo` Core ML package, which includes `TextDecoderContextPrefill` for faster decoder prefill while keeping transcription fully local.
- Updated the build scripts and developer model path to use the same `_turbo` package consistently.

### Fixed

- Fixed insertion in Terminal and Ghostty: use paste for terminal input and permit fallback when the captured field remains focused. Changed targets still retain the transcript in the clipboard.

- Fixed a lockout where pressing the dictation shortcut a second time while the microphone permission check was still running started a second session. The first began recording and the second failed, overwriting the running session's state with an error, after which every press restarted instead of stopping — the recorder kept running while the menu bar reported "No audio captured", and only relaunching recovered it. A recorder left running by any earlier failure is now discarded instead of blocking every later dictation.
- Fixed a crash the first time macOS asked for Speech Recognition permission.
- Starting a recording and then not speaking now ends the session quietly instead of reporting an error, matching how the bundled model already handled silence.
- WhisperKit's verbose logging is off. It logged every predicted token through `os_log`, which put the text of every dictation into the system log where `log show` would hand it back — the app's own debug log is now the only place dictation is recorded.
- Fixed stray spaces appearing between Chinese characters. Chunked decoding leaves a space where it split the audio, and written Chinese has no word spacing, so those spaces were never spoken. Measured on a 154s clip: seven of them, now zero. Spaces next to Latin text are kept, because they are doing real work in the mixed sentences this app exists for.

### Performance

- Whisper now bounds the worst case for a single dictation. A window that trips WhisperKit's quality checks used to be re-decoded at up to six temperatures; it is capped at three. This is a ceiling, not a speed-up: an 11-clip A/B — including 3 dB SNR noise and 8% amplitude, where transcription visibly degraded — never triggered a single fallback, because the thresholds sit far from ordinary dictation (worst measured compression ratio 1.45 against a 2.4 trigger, worst average log probability -0.329 against -1.0). The debug log now reports both, so real usage can settle whether the ceiling is ever reached.
- Clips longer than one 30s window are now split on silence and decoded concurrently. Measured 6.08s to 4.83s on an 85s clip and 14.46s to 13.28s on a 154s clip. Shorter clips are unaffected — they take the single-window path either way. The trade-off is punctuation: chunks are decoded independently, so the 154s clip came back with about 13 fewer commas out of 667 characters. No word or character content changed across the whole A/B.
- Silence after the last word is trimmed before transcription rather than decoded. A 34.3s recording ending in 6s of silence now hands 28.8s to the model, and stays inside one 30s window instead of spilling into a second.
- The debug log now records per-attempt decode time, real-time factor, token count, compression ratio, and whether a temperature fallback fired, so a slow dictation can be attributed without attaching a profiler.

- Loading the Whisper model after an app update no longer re-runs Core ML specialization: measured at 4m13s before, and 2–4s after, on the same Mac and model.
- Single-language dictation through the macOS Speech engine returned a final transcript 0.083s after speech ended on a 10.6s Chinese clip, against roughly 1s for the bundled model.
- A seven-run alternating local A/B benchmark measured median `fullPipeline` time at `0.515s` for `_turbo` versus `0.828s` for the previous package (`-38%`), with encoding improving from `0.638s` to `0.345s` (`-46%`). See [the benchmark result](docs/benchmarks/2026-08-16-turbo-model-ab.png).

## [0.3.0] - 2026-08-14

Release: [v0.3.0](https://github.com/ycl-2004/NoType/releases/tag/v0.3.0)

### Added

- Added a new Orbit-inspired YC app icon that visualizes microphone input, a speech waveform, and text output.
- Added background model preloading after launch to reduce the delay before the first dictation.

### Changed

- Conclusive transcription attempts now skip unnecessary language fallbacks, reducing avoidable processing time.
- Transcript cleanup more carefully removes filler sounds and hallucinated closing phrases without deleting ordinary speech.
- The release version is now `0.3.0` with build number `3`.

### Fixed

- Very short accidental recordings and empty cleaned transcripts now finish without overwriting the clipboard.
- Temporary recordings are deleted after both successful and failed transcriptions, and orphaned clips are cleaned up at launch.
- Completed transcripts are not redirected into a different chat or text field when the original input target has changed.

### Verification

- 104 tests passed across 8 suites.
- Release ZIP, packaged icon, bundled model/tokenizer, whole-bundle signature, and SHA-256 checksum verified.
- Release ZIP SHA-256: `9599c4fea1965dee27fc47940c6c8ff2db3ebd8bad1bf0e9a88ee8d6ce2d52e5`.

### Known limitations

- The release is Apple Silicon-only and requires macOS 15.0 or newer.
- The current build is ad-hoc signed; Developer ID signing and notarization are still pending.
- There is no automatic in-app updater.

## [0.2.0] - 2026-08-14

Source tag: [build-2026-08-14](https://github.com/ycl-2004/NoType/tree/build-2026-08-14) — superseded by NoType 0.3.0.

### Added

- Bundled the WhisperKit/Core ML `large-v3` model and tokenizer in the friend-downloadable release archive.
- Added a repeatable release script that produces an app bundle, ZIP archive, and SHA-256 checksum.
- Added configurable dictation triggers: Double Command, Double Option, Command + Shift + H, and Disabled.
- Added configurable recognition-mode shortcuts and an independent Disabled option.
- Added modifier double-tap detection with cancellation when another input interrupts the sequence.
- Added a Diagnostics submenu for the latest debug event and log access.

### Changed

- The app now resolves bundled model resources before the developer-only local fallback path.
- The main menu no longer displays the last transcript preview or raw diagnostic path.
- Shortcut choices persist across launches and update registration immediately.
- The release version is now `0.2.0`.

### Verification

- 78 tests passed across 8 suites.
- Release ZIP and whole-bundle signature verified.
- Release ZIP SHA-256: `58aa8bd17e75f0e1636ea8e7cf8df9bca5937498af25b7fe1b22cce08e636569`.

### Known limitations

- The release is Apple Silicon-only and requires macOS 15.0 or newer.
- The current build is ad-hoc signed; Developer ID signing and notarization are still pending.
- There is no automatic in-app updater.
