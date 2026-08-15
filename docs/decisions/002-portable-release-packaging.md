# ADR-002: Bundle the Whisper Model in the First Public Release

## Status

Accepted — implemented in NoType 0.2.0

## Date

2026-08-14

## Context

The development build used an absolute model path under the original developer's home directory. The app bundle itself was only about 7.4 MB, while the active WhisperKit/Core ML `large-v3` model occupied about 1.5 GB. A friend downloading that app would start successfully but fail when transcription tried to load the missing model.

The first public release needs to be usable by a non-developer without Swift, a repository checkout, a setup script, or a manually prepared Hugging Face cache.

## Decision

Bundle the converted WhisperKit `large-v3` model and tokenizer inside the release app, then distribute the app as a ZIP GitHub Release asset. At runtime, NoType looks for the bundled model and tokenizer first and keeps the original absolute path only as a developer fallback for local builds without bundled resources.

The release script:

- Builds the current checkout in release configuration.
- Copies the model and tokenizer into the app resources.
- Applies an ad-hoc signature by default and verifies the whole bundle.
- Creates an architecture- and version-labelled ZIP plus a SHA-256 checksum.

The model is intentionally not committed to Git. GitHub Release assets carry the large binary separately from source history.

The decision was first implemented for [NoType 0.2.0](https://github.com/ycl-2004/NoType/tree/build-2026-08-14), built from commit `07c6364`. Its ZIP was approximately 1.4 GB and contained the approximately 1.5 GB model bundle plus tokenizer. That release was later superseded by [NoType 0.3.0](https://github.com/ycl-2004/NoType/releases/tag/v0.3.0), which keeps the same self-contained packaging model.

## Alternatives Considered

### Download the model on first launch

This would make the initial app smaller, but requires network/download UI, retry and corruption handling, model versioning, and a first-run state machine. The bundled archive is simpler and gives friends an offline-capable first run.

### Ask friends to run a setup script

This keeps the app bundle small but is not a normal macOS installation experience and introduces Swift/Python/path/permission failure modes. It is unsuitable for the first friend-facing release.

### Commit the model to the repository

This would make every clone and Git history unnecessarily large. Release assets are the appropriate place for a 1.5 GB binary.

### Ship a Developer ID/notarized app immediately

This is the correct eventual public distribution path, but no valid signing identity is currently installed in the build environment. The first release documents the ad-hoc signing limitation rather than pretending the archive is notarized.

## Consequences

- The download is large, approximately 1.5 GB before ZIP compression.
- The published ZIP is approximately 1.4 GB and the extracted app is approximately 1.5 GB; users should keep roughly 4 GB free during download and extraction.
- The first release is simple, self-contained, and does not need runtime model downloads.
- A future runtime-download design may reduce download size but will require an explicit download manager and versioned model endpoint.
- Public distribution still needs Developer ID signing and notarization to remove the Gatekeeper warning.

## Verification

- `swift test`: 78 tests in 8 suites passed.
- `./scripts/build_release.sh`: completed from commit `07c6364`.
- `codesign --verify --deep --strict`: passed for the app bundle.
- The ZIP checksum matched the published GitHub Release asset digest.

## References

- [Apple: Developer ID](https://developer.apple.com/support/developer-id/)
- [Apple: Distributing software on macOS](https://developer.apple.com/macos/distribution/)
- [GitHub: About releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
