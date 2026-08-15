# Current Task: NoType 0.3.0 Icon and Release

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
