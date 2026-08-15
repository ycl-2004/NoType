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

## Decision Log

- Use semantic tag `v0.3.0` so the release tag matches the product version rather than reusing a date-based tag.
- Keep the 0.2.0 release available until the 0.3.0 upload and public metadata have been verified.
- Treat the GitHub sidebar description as the requested “About”; the menu-bar-only app has no separate About surface.
- Use build number `3` with marketing version `0.3.0`.

## Evidence

- `App_icon.png` is a 2048×2048 sRGB PNG containing the approved new icon.
- `swift test`: 104 tests in 8 suites passed after the 0.3.0 version and packaging edits on 2026-08-14.
- `./scripts/build_app.sh`: produced a signed NoType 0.3.0 build (build 3) with `AppIcon.icns` and `Assets.car`.
- The packaged `AppIcon.icns` was extracted and visually confirmed to match the approved icon.
- Existing GitHub latest release is `NoType 0.2.0` at tag `build-2026-08-14`, with ZIP and checksum assets.
- Existing GitHub About description is `Im just lazy that dont wanna type in box` and needs replacement.
