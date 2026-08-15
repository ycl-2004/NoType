# Changelog

All notable user-facing changes to NoType are recorded here.

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
