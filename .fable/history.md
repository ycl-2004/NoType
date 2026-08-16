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

# Current Task: Ship WhisperKit Turbo Model Update

## Goal

Record, verify, install, commit, and push the current local WhisperKit `_turbo` model update, including its measured A/B result.

## Acceptance Criteria

- The `_turbo` model path and prefill behavior are documented in the changelog and developer build instructions.
- The A/B benchmark image is stored under `docs/benchmarks/` and referenced from the changelog.
- The rebuilt `dist/NoType.app` and release archive contain the `_turbo` model package and `TextDecoderContextPrefill.mlmodelc`.
- Swift tests and relevant package/bundle checks pass.
- The verified current app is installed at `/Applications/NoType.app`.
- Only the intended current changes are committed and pushed to the current GitHub branch.

## Requirements List (Append Only)

1. Add the current `_turbo` model update to the changelog if appropriate.
2. Move and commit `_Turbo_Model.png` as a documented benchmark result.
3. Rebuild or verify the current `dist` version before installation.
4. Install the current app to `/Applications/NoType.app`.
5. Commit and push the current related changes.

## Decision Log

- Store the benchmark at `docs/benchmarks/2026-08-16-turbo-model-ab.png` because it is a dated performance artifact, not a product asset.
- Treat `_turbo` as one selectable local Whisper model pipeline with a `TextDecoderContextPrefill` helper, not as a second user-facing model choice.
- Rebuild the release artifact because the existing `dist` archive still contains the previous non-`_turbo` model directory.
- Do not open a pull request because the user requested commit and push, not PR creation.

## Evidence

- `swift test`: 104 tests in 8 suites passed on 2026-08-16.
- `./scripts/build_release.sh`: rebuilt `dist/NoType.app` and `NoType-0.3.0-arm64.zip` from the current checkout with the `_turbo` model package.
- The rebuilt app is `0.3.0` build `3`, passes `codesign --verify --deep --strict`, and contains `TextDecoderContextPrefill.mlmodelc`.
- The rebuilt archive checksum is `0706baa656d25c8f3c6872c73c90be361fd66ad631f3b80a8982ab5d5b9ff7a2`.
- `/Applications/NoType.app` was replaced with the verified bundle and contains all four `_turbo` Core ML submodels.
- Commit `97c8f75` was pushed successfully to `origin/main`.

---

# Completed Task: NoType 0.3.0 Icon and Release

## Goal

Ship the Orbit-inspired YC icon and all post-0.2.0 reliability improvements as a verified NoType 0.3.0 release, then install the same build locally and retire the superseded 0.2.0 release.

## Acceptance Criteria

- The new microphone → waveform → document icon is the canonical tracked app icon and is packaged in the app bundle.
- App metadata, README, changelog, release notes, assets, and public release title consistently identify NoType 0.3.0.
- The complete Swift test suite, release build, bundle signature, packaged resources, archive checksum, and archive extraction verify successfully.
- `/Applications/NoType.app` is replaced by the verified 0.3.0 build, and obsolete local NoType app backups are removed.
- GitHub publishes NoType 0.3.0 with the ZIP and checksum as the latest release before the superseded 0.2.0 release is deleted.
- The GitHub repository About description accurately explains the app.

## Requirements List (Append Only)

1. Replace all old NoType app icon use with the newest approved icon.
2. Build and install a fresh local NoType app without changing app behavior.
3. Remove old local NoType app bundles and backups while keeping the latest installed app under `/Applications`.
4. Publish a new release named NoType 0.3.0.
5. Replace the existing NoType 0.2.0 release only after the new release is verified.
6. Review and update the GitHub repository About description if it is stale.
7. Keep the microphone, waveform, document, and YC visual meaning in the new icon.
8. Make the 0.3.0 Release Notes professional and grounded in the latest verified behavior and current feature set.

## Decision Log

- Use semantic tag `v0.3.0` so the release tag matches the product version rather than reusing a date-based tag.
- Keep the 0.2.0 release available until the 0.3.0 upload and public metadata have been verified.
- Treat the GitHub sidebar description as the requested “About”; the menu-bar-only app has no separate About surface.
- Use build number `3` with marketing version `0.3.0`.
- Delete the superseded 0.2.0 GitHub Release after verifying 0.3.0, but retain its historical `build-2026-08-14` source tag.

## Evidence

- `App_icon.png` is a 2048×2048 sRGB PNG containing the approved new icon.
- `swift test`: 104 tests in 8 suites passed after the 0.3.0 version and packaging edits on 2026-08-14.
- `./scripts/build_app.sh`: produced a signed NoType 0.3.0 build (build 3) with `AppIcon.icns` and `Assets.car`.
- The packaged `AppIcon.icns` was extracted and visually confirmed to match the approved icon.
- Existing GitHub latest release is `NoType 0.2.0` at tag `build-2026-08-14`, with ZIP and checksum assets.
- Existing GitHub About description is `Im just lazy that dont wanna type in box` and needs replacement.
- `/Applications/NoType.app` reports version `0.3.0`, build `3`, passes whole-bundle signature verification, contains the approved packaged icon, and is the only matching app in `/Applications`.
- The running process resolves to `/Applications/NoType.app/Contents/MacOS/noType`.
- `NoType-0.3.0-arm64.zip` is 1,498,180,858 bytes; its checksum is `9599c4fea1965dee27fc47940c6c8ff2db3ebd8bad1bf0e9a88ee8d6ce2d52e5`.
- The release archive extracted successfully; version, signature, model, tokenizer, and packaged icon all verified.
- GitHub published `NoType 0.3.0` at `v0.3.0` as Latest, with both assets uploaded and the server-reported ZIP digest matching the local checksum.
- The public direct-download URL resolves with HTTP 200 and the expected 1,498,180,858-byte content length.
- The superseded 0.2.0 Release was deleted after verification; its source tag remains available.
- GitHub About now reads `Private, local macOS dictation powered by WhisperKit — speak naturally and keep typing.`
- Obsolete local NoType app backup, legacy app ZIP, and 0.2.0 release artifacts were removed after the verified 0.3.0 replacements existed.

---

# Current Task: Commit Dictation Robustness Fixes

## Goal

Review and commit the current dictation robustness changes while ensuring today's Git history contains no prohibited third-party attribution records.

## Acceptance Criteria

- Current tracked and untracked changes are reviewed before staging.
- All commits reachable from today's refs are checked for prohibited attribution metadata.
- Any matching attribution is removed before the new commit; clean history is left unchanged.
- The complete Swift test suite passes.
- The resulting commit contains the intended dictation fixes, tests, and documentation only.

## Requirements List (Append Only)

1. Inspect and summarize the current code changes.
2. Check today's commits for any prohibited third-party attribution records.
3. Remove those records if present; otherwise do not rewrite history.
4. Verify the current changes before committing them.
5. Create a Git commit for the reviewed changes.

## Decision Log

- Treat “today” as 2026-08-14 in the repository's configured America/Vancouver working timezone.
- Scan all refs, full commit messages, authors, committers, and Git notes rather than checking subjects alone.
- Leave history untouched because the attribution scan returned no matches.
- Use the repository-documented unfiltered `swift test` command because filtered runs are a known issue.

## Evidence

- Five commits were reachable from all refs since 2026-08-14 00:00:00 -0700.
- Case-insensitive scans for the prohibited attribution markers returned no matches.
- `git diff --check` passed before staging.
- `swift test`: 104 tests in 8 suites passed on 2026-08-14.

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
