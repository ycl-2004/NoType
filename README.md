# NoType

NoType is a native macOS menu-bar dictation app powered by local WhisperKit/Core ML transcription. It records speech, transcribes it offline with Whisper `large-v3`, and inserts or copies the result.

## Download a release

Download the latest `NoType-<version>-arm64.zip` from [GitHub Releases](https://github.com/ycl-2004/NoType/releases), unzip it, and move `NoType.app` to `/Applications`.

The release archive includes the approximately 1.5 GB WhisperKit `large-v3` Core ML model and tokenizer. Friends do not need to clone the repository, install Swift, create a Hugging Face folder, or run a setup script. The first launch also does not need to download the model.

Requirements:

- Apple Silicon Mac (`arm64`)
- macOS 15.0 or newer
- Approximately 2 GB of free disk space for the app and bundled model
- Microphone permission for recording
- Accessibility permission for inserting text into other apps

The current public build is ad-hoc signed because this project does not yet have a Developer ID certificate. macOS may show an unidentified-developer warning. If that happens, use Control-click → Open once, or allow the app in System Settings → Privacy & Security. A future public-quality release should use Developer ID signing and notarization.

## Build locally

Run the tests:

```sh
swift test
```

Build the small app bundle used for local development:

```sh
./scripts/build_app.sh
```

This creates `dist/NoType.app` without copying the model. It is useful for code/build checks, but it will use the developer's local model path at runtime.

Build the friend-downloadable release archive:

```sh
./scripts/build_release.sh
```

The release script bundles the model and tokenizer from the current checkout's default local paths, creates `dist/NoType-0.2.0-arm64.zip`, and writes a matching `.sha256` checksum file. Override the source locations when needed:

```sh
WHISPER_MODEL_DIR="/path/to/openai_whisper-large-v3-v20240930" \
WHISPER_TOKENIZER_DIR="/path/to/whisper-large-v3" \
./scripts/build_release.sh
```

Do not commit the model into Git. Upload the generated ZIP and checksum as GitHub Release assets instead.

## Release checklist

1. Confirm the checkout contains the intended latest commit.
2. Run `swift test`.
3. Run `./scripts/build_release.sh`.
4. Verify the checksum and `codesign --verify --deep --strict dist/NoType.app`.
5. Create a dated GitHub Release and upload the ZIP plus `.sha256` file.

## Architecture

- `Sources/Typeless/Audio`: microphone capture.
- `Sources/Typeless/Transcription`: WhisperKit/Core ML transcription and transcript processing.
- `Sources/Typeless/Accessibility`: focused-text capture and insertion fallbacks.
- `Sources/Typeless/App`: menu-bar UI and application lifecycle.
- `scripts/build_release.sh`: repeatable model-bundled release packaging.

See [ADR-002](docs/decisions/002-portable-release-packaging.md) for the distribution trade-offs.
