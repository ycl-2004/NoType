# Current Task: Portable NoType Release

## Goal

Ship the latest `main` build as a friend-downloadable macOS release that includes the WhisperKit `large-v3` model and works without the developer's absolute model path or a setup script.

## Acceptance Criteria

- The app resolves a bundled WhisperKit model and tokenizer before any developer-only fallback path.
- A release build bundles the current Core ML `large-v3` model and tokenizer into the app archive.
- Friends can download and install the release without running a script or creating a Hugging Face directory.
- The release artifact is built from the latest commit and includes a checksum.
- README explains download, install, permissions, model size, supported macOS/architecture, and Gatekeeper/signing limitations.
- The packaging decision and future signed/notarized distribution path are documented in an ADR.
- Automated tests, release build, bundle verification, and archive verification pass.

## Requirements List (Append Only)

1. Make a downloadable NoType ReleaseVersion for friends.
2. Ensure the release contains the latest changes from yesterday's commit.
3. Determine whether friends need to run a script and remove that requirement if possible.
4. Ensure the Whisper model is available to a fresh installation.
5. Explain the remaining permissions and macOS security steps honestly.
6. Keep the release process repeatable for future updates.

## Decision Log

- Bundle the model and tokenizer in the first friend-facing ZIP; defer runtime model downloading until there is a need for smaller initial downloads or model updates.
- Use ad-hoc signing for this build because no valid signing identity is installed; document Developer ID signing and notarization as the public-distribution follow-up.

## Evidence

- Latest source commit is `dae6eb5` on `main` and `origin/main`.
- Current active Core ML model directory is `openai_whisper-large-v3-v20240930` and occupies about 1.5GB.
- Existing `dist/NoType.app` is only about 7.4MB and currently cannot work on another Mac because the model path is hard-coded to the developer machine.
- `swift test`: 78 tests in 8 suites passed on 2026-08-14.
- `./scripts/build_release.sh`: built `dist/NoType-0.2.0-arm64.zip`; bundled model/tokenizer, SHA-256, and whole-bundle signature all verified on 2026-08-14.
