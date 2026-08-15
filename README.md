# NoType

NoType is a native macOS menu-bar dictation app. It records speech locally, transcribes it with WhisperKit/Core ML, and inserts or copies the result into the focused app.

The current release runs the multilingual Whisper `large-v3` model locally. NoType does not send recordings to a remote transcription API, and the friend-downloadable build includes the model so a separate model setup is not required.

[Latest release](https://github.com/ycl-2004/NoType/releases/tag/build-2026-08-14) · [Direct download](https://github.com/ycl-2004/NoType/releases/latest/download/NoType-0.2.0-arm64.zip) · [SHA-256](https://github.com/ycl-2004/NoType/releases/latest/download/NoType-0.2.0-arm64.zip.sha256)

## Current release

NoType `0.2.0` was built from commit `07c6364` and published as GitHub release `build-2026-08-14`.

The release archive is:

- `NoType-0.2.0-arm64.zip`, approximately 1.4 GB to download.
- Approximately 1.5 GB after extraction because it contains the Core ML model.
- Accompanied by `NoType-0.2.0-arm64.zip.sha256`.

The archive contains both the WhisperKit `large-v3` Core ML model and its tokenizer. The model is not committed to Git; it is distributed as a GitHub Release asset instead.

## Install for friends

Friends do not need to clone the repository, install Swift, install Python, create a Hugging Face directory, run a script, or download Whisper separately.

1. Download the [latest NoType ZIP](https://github.com/ycl-2004/NoType/releases/latest/download/NoType-0.2.0-arm64.zip).
2. Open the ZIP and move `NoType.app` to `/Applications`.
3. Launch NoType from Applications.
4. Allow microphone access when macOS asks.
5. Allow NoType under System Settings → Privacy & Security → Accessibility so it can observe the global modifier shortcut and insert text into other apps.

The first transcription uses the model already inside the app. The app is configured with `download: false`; if the bundled model is missing or damaged, it reports a model error instead of silently downloading another copy.

### Gatekeeper note

The current release is ad-hoc signed because no Developer ID certificate is configured for this project yet. macOS may show an unidentified-developer warning. If that happens, Control-click `NoType.app`, choose Open, and confirm once. The eventual public-distribution path is Developer ID signing followed by notarization; see Apple's [Developer ID guidance](https://developer.apple.com/support/developer-id/).

### System requirements

The current release requires:

- Apple Silicon (`arm64`). Intel Macs are not supported by this archive.
- macOS 15.0 or newer.
- At least about 4 GB of free space during download and extraction.
- Microphone permission for recording.
- Accessibility permission for the full dictation workflow.

## Using NoType

The default dictation trigger is Double Command. It can be changed from the menu bar under Shortcuts to:

- Double Command
- Double Option
- Command + Shift + H
- Disabled

Recognition-mode cycling defaults to Command + Shift + Y and can be changed to Command + Option + Y, Control + Option + Y, or Disabled. Shortcut choices are stored per user and take effect immediately.

The app supports mixed, Chinese, and English recognition modes, Chinese script preferences, transcript insertion/copy behavior, and a Diagnostics submenu for the latest debug event and log access.

## Privacy and model behavior

- Transcription runs locally through WhisperKit/Core ML.
- The release app contains the model and tokenizer needed for its first transcription.
- No runtime model download is required by the release build.
- Audio is recorded only when dictation is active and is processed by the local transcription pipeline.
- Accessibility is used for focused-target capture and text insertion; it is not a replacement for microphone permission.

## Developer quick start

The project uses Swift Package Manager and requires macOS 15.0 or newer.

Run the test suite:

```sh
swift test
```

Build the small local app bundle:

```sh
./scripts/build_app.sh
```

This creates `dist/NoType.app` without copying the 1.5 GB model. It is useful for compile and bundle checks. When run locally without bundled resources, the app falls back to the developer model path configured in `LocalWhisperPaths.swift`.

Build the friend-downloadable release archive:

```sh
./scripts/build_release.sh
```

The release script builds the current checkout, bundles the model and tokenizer, signs the entire app bundle, creates a ZIP, and writes a SHA-256 file. By default it expects the developer's local model directories:

```text
/Users/yichenlin/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-large-v3-v20240930
/Users/yichenlin/Documents/huggingface/models/openai/whisper-large-v3
```

Use explicit paths on another build machine:

```sh
WHISPER_MODEL_DIR="/path/to/openai_whisper-large-v3-v20240930" \
WHISPER_TOKENIZER_DIR="/path/to/whisper-large-v3" \
./scripts/build_release.sh
```

The output names are derived from `Packaging/Info.plist` and the current architecture:

```text
dist/NoType.app
dist/NoType-0.2.0-arm64.zip
dist/NoType-0.2.0-arm64.zip.sha256
```

The default signature is ad-hoc. If a valid Developer ID identity is installed, pass it through to the packaging script:

```sh
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./scripts/build_release.sh
```

The script verifies the signature with `codesign --verify --deep --strict`. Notarization is not automated yet; use Apple's [macOS distribution documentation](https://developer.apple.com/macos/distribution/) before treating a build as a public-quality signed release.

## Release checklist

Before publishing a new release:

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Packaging/Info.plist`.
2. Confirm the intended source commit is checked out and the worktree is clean.
3. Run `swift test`.
4. Run `./scripts/build_release.sh` with the intended model and tokenizer paths.
5. Verify the model resource, tokenizer, checksum, app version, and whole-bundle signature.
6. Prefer Developer ID signing and notarization for releases intended beyond personal/friend testing.
7. Create a dated GitHub Release and upload both the ZIP and `.sha256` file.
8. Test the downloaded archive on a clean Apple Silicon Mac before sharing it widely.

Do not commit the model into Git. Release assets are the intended home for the large binary.

## Architecture

- `Sources/Typeless/Audio`: microphone capture and recorded clips.
- `Sources/Typeless/Transcription`: WhisperKit/Core ML loading, language selection, fallback attempts, and transcript post-processing.
- `Sources/Typeless/Accessibility`: focused-target capture, direct insertion, clipboard handling, and paste fallback.
- `Sources/Typeless/Coordinator`: dictation state transitions and orchestration.
- `Sources/Typeless/App`: menu-bar UI, permissions, diagnostics, and application lifecycle.
- `Sources/Typeless/Hotkey`: Carbon key combinations and modifier double-tap detection.
- `Packaging/Info.plist`: app identity, version, permissions text, and macOS minimum version.
- `scripts/build_app.sh`: local app-bundle build.
- `scripts/build_release.sh`: model-bundled release packaging.

## Known limitations

- The current release is Apple Silicon only.
- There is no in-app updater; users download each new release manually.
- The model is currently fixed to Whisper `large-v3`; runtime model switching is not exposed.
- The first public release is ad-hoc signed rather than Developer ID signed and notarized.
- A clean-machine smoke test is part of the release checklist but is not performed by the packaging script itself.

## Documentation and decisions

- [CHANGELOG](CHANGELOG.md): shipped changes by release.
- [Known issues](docs/known-issues.md): understood defects and future directions that are not currently being worked on.
- [ADR-001: Configurable shortcut input](docs/decisions/001-configurable-shortcut-input.md): why shortcuts use curated choices and double-tap monitors.
- [ADR-002: Portable release packaging](docs/decisions/002-portable-release-packaging.md): why the first release bundles the model instead of downloading it at runtime.

## License and attribution

The repository includes the WhisperKit dependency under `Vendor/WhisperKit-main/LICENSE`. Review the dependency and model terms before redistributing NoType beyond personal or friend testing, and preserve the relevant notices in any wider distribution process.
