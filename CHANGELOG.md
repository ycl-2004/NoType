# Changelog

All notable user-facing changes to NoType are recorded here.

## [0.4.0] - 2026-09-11

Release: [v0.4.0](https://github.com/ycl-2004/NoType/releases/tag/v0.4.0)

### Added

- Added an optional bottom-center voice overlay with a live microphone waveform, compact Chinese status labels, and brief copy/insert/error feedback. **Show Voice Overlay** controls visibility; **Overlay Timing** accepts separate completion and failure durations from 0 to 5 seconds (0 hides that category, defaults are 1.5 seconds). Recording appears immediately and remains visible until stopped; preferences persist across launches. The panel does not take keyboard focus or intercept clicks. See [ADR-009](docs/decisions/009-voice-overlay.md).
- Added transcription through the on-device speech engine built into macOS 26, selectable as **Engine → macOS Speech (fast)** in the menu bar. It does not translate, does not emit subtitle sign-off hallucinations, and returns a transcript far sooner than the local model. Like the local model, it runs entirely on the Mac.
- Added an engine choice that persists across launches. When macOS Speech is selected, **Auto (中英混说) uses Qwen3-ASR** because the system recognizer cannot detect the spoken language; the menu shows this as `Engine: macOS Speech (fast) → Qwen3-ASR 0.6B INT8` when it applies. See [ADR-004](docs/decisions/004-two-engine-routing.md).
- Added **SenseVoice Small** as a third selectable local engine through sherpa-onnx. It supports Chinese, Cantonese, English, Japanese, and Korean, keeps one ONNX model copy under `~/Documents/huggingface/models/k2-fsa`, and is loaded only when selected. See [ADR-006](docs/decisions/006-sensevoice-engine-and-model-storage.md).
- Added **Manage Downloaded Models** under the engine menu. Deletion is confirmed before removing NoType's downloaded Qwen3-ASR or SenseVoice folders; macOS Speech system assets and unrelated Hugging Face models are never targeted.
- Added a live local-model status section to Diagnostics with Preparing, Ready, and Failed states, first-launch guidance, failure details, and retry support without requiring the debug log.
- Added user-recorded shortcuts for dictation and recognition-mode cycling. Each action can have multiple shortcuts, each shortcut can use a regular key or modifier combination with single or double press activation, and left/right modifier keys are kept distinct. Dictation defaults to Double Command; recognition-mode shortcuts are off by default.

### Changed

- Debug logs retain only the newest five days. Expired entries are removed on logging and when opening Diagnostics.

- **Replaced the bundled Whisper engine with Qwen3-ASR 0.6B INT8** through sherpa-onnx, the same package SenseVoice already uses. It detects the spoken language itself, so a dictation is now one decode instead of up to three attempts scored against each other. Select it as **Engine → Qwen3-ASR 0.6B INT8**; a saved `Bundled Whisper` preference migrates to it automatically. See [ADR-008](docs/decisions/008-qwen3-asr-replaces-whisper.md).
- **No model ships inside the app any more.** Qwen3-ASR downloads about 1 GB on first use into `~/Documents/huggingface/models/k2-fsa`, alongside SenseVoice, instead of being bundled into a roughly 1.4 GB release archive. The download is shared across NoType builds and survives replacing the app.
- Removed the WhisperKit dependency and the vendored `Vendor/WhisperKit-main` checkout. `swift test --filter` works again as a result.
- Recordings longer than 24 seconds are split on the longest pause and transcribed a segment at a time. Qwen3-ASR is an utterance-level recognizer: measured against its own sample files, a 63s clip returned 35% of its transcript and a 191s clip returned a single stray token, at every context-length setting tried. Shorter dictation is unaffected and still takes the single-decode path.

### Fixed

- Fixed a crash when recording custom keyboard shortcuts and corrected F1–F20 key labels.

- Fixed insertion in Terminal and Ghostty: use paste for terminal input and permit fallback when the captured field remains focused. Changed targets still retain the transcript in the clipboard.

- Fixed a lockout where pressing the dictation shortcut a second time while the microphone permission check was still running started a second session. The first began recording and the second failed, overwriting the running session's state with an error, after which every press restarted instead of stopping — the recorder kept running while the menu bar reported "No audio captured", and only relaunching recovered it. A recorder left running by any earlier failure is now discarded instead of blocking every later dictation.
- Fixed a crash the first time macOS asked for Speech Recognition permission.
- Starting a recording and then not speaking now ends the session quietly instead of reporting an error, matching how the local model already handled silence.
- Fixed stray spaces appearing between Chinese characters. Written Chinese has no word spacing, so a space with a Han character on either side was never spoken. Measured on a 154s clip when this was found: seven of them, now zero. Spaces next to Latin text are kept, because they are doing real work in the mixed sentences this app exists for.

### Performance

- Silence after the last word is trimmed before transcription rather than decoded. A 34.3s recording ending in 6s of silence now hands 28.8s to the model.
- The debug log now records the detected language, decode time, audio duration, and real-time factor for each dictation, so a slow one can be attributed without attaching a profiler.

- Single-language dictation through the macOS Speech engine returned a final transcript 0.083s after speech ended on a 10.6s Chinese clip, against roughly 1s for the local model it was measured against.

### Verification

- 146 tests passed across 23 suites.
- Release app version `0.4.0` (`CFBundleVersion` 4) passed whole-bundle signature verification.
- Release ZIP passed archive integrity verification.
- Release ZIP SHA-256: `b28cce7882df56e4341eebe73a8ef6581590bd21dfdf973c9b2ee97d6590f86f`.

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
