# Completed Task: Cleaner Menu and Configurable Shortcuts

## Goal

Make NoType's menu bar UI quieter and its activation shortcuts configurable without changing the audio, WhisperKit, transcription, or insertion behavior.

## Acceptance Criteria

- The main menu no longer displays the last transcript preview.
- Debug text and the log path remain available for testing without occupying the main menu.
- Dictation can be started and stopped with the same double-tap trigger.
- The dictation trigger can be selected from Double Command, Double Option, or the legacy Command-Shift-H shortcut.
- The recognition-mode shortcut can be disabled or selected from multiple key combinations.
- Shortcut choices persist across app launches and update registration immediately.
- Existing audio, WhisperKit, transcription selection, and text insertion files remain unchanged.
- Automated tests and a release build pass.

## Requirements List (Append Only)

1. Simplify the menu bar UI shown in the supplied screenshot.
2. Remove Last Transcript from the menu.
3. Keep Debug and Log available for testing, but remove them from the normal main-menu scan path.
4. Support double-tapping Command to both start and stop dictation.
5. Allow an alternative dictation trigger instead of forcing one hardcoded shortcut.
6. Make the recognition-mode shortcut selectable instead of hardcoded.
7. Do not modify WhisperKit or transcription behavior.
8. Limit changes to activation/shortcut handling and the menu UI.
9. Allow dictation activation and recognition-mode shortcuts to be disabled independently to avoid conflicts with other apps.
10. Keep dictation activation enabled by default for new installations.
11. Ensure the packaged app has a valid whole-bundle signature before replacing the installed version.

## Decision Log

- Use a Diagnostics submenu rather than a build-only UI so diagnostics stay reachable in the same installed app.
- Use curated native shortcut choices rather than an arbitrary key recorder; this keeps the menu compact and avoids invalid/conflicting single-key shortcuts.
- Default new installations to Double Command while preserving the legacy enabled/disabled preference during migration.
- Use AppKit local/global event monitors for modifier double-taps and keep Carbon hotkeys for key-combination choices.
- Include an explicit Disabled option for both shortcut categories and unregister only the affected listener immediately.
- Default dictation activation to Double Command; Disabled remains an explicit user choice.

## Evidence

- `swift test`: 78 tests in 8 suites passed on 2026-08-13.
- `bash scripts/build_app.sh`: release build passed and the generated `dist/NoType.app` signature verified on 2026-08-14.

---

# Current Task: NoType 0.2.0 Documentation Refresh

## Goal

Bring the project documentation into alignment with the published NoType 0.2.0 release, including friend installation, bundled-model behavior, developer workflows, release operations, limitations, and current architecture.

## Acceptance Criteria

- README contains a reliable direct download link for the published release and exact install steps.
- README clearly states that the model/tokenizer are bundled and that friends do not run a setup script.
- README documents system requirements, permissions, disk space, Gatekeeper behavior, architecture limits, and known limitations.
- README documents test, local build, release build, checksum, signing, and release-upload workflows without developer-only assumptions being presented as friend setup.
- CHANGELOG records the shipped 0.2.0 changes.
- ADR-002 records the published release evidence and remaining notarization follow-up.
- Documentation links and version/release references are internally consistent.

## Requirements List (Append Only)

1. Update the project's README comprehensively for the current release.
2. Update related project documentation that is now stale or incomplete.
3. Explain the friend installation path separately from the developer/build path.
4. Record what is included in the ZIP and what remains unfinished for formal public distribution.
5. Preserve historical design documents and avoid rewriting completed implementation plans.

## Decision Log

- Keep the root README as the canonical user/developer entry point.
- Add a concise CHANGELOG instead of duplicating release notes across multiple documents.
- Update ADR-002 with shipped-release evidence while preserving its original decision and alternatives.

## Evidence

- Published release: `build-2026-08-14` / `NoType 0.2.0`.
- Direct asset: `NoType-0.2.0-arm64.zip`.
- Published release source baseline: `07c6364` on `main` and `origin/main`.
- Root README, CHANGELOG, and ADR-002 updated; all added external links returned HTTP 200 on 2026-08-14.

---

# Completed Task: Portable NoType Release

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

---
