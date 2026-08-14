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
