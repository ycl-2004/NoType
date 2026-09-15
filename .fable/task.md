# Current Task: Self-healing global shortcuts

## Goal
Keep NoType's global shortcuts responsive in the background and recover automatically when macOS drops a modifier release event.

## Requirements (append only)
1. Remove the permanent `activeModifiers` ghost-key lockout without requiring an app restart.
2. Reconcile tracked modifier state with AppKit's current hardware modifier state during shortcut handling.
3. Add a low-cost watchdog that can clear stale modifier state while preserving valid long-held modifier combinations.
4. Measure modifier-only double taps from the first release to the second press, with a slightly more forgiving duration window.
5. Keep shortcut monitoring active after launch and reduce background throttling with a retained, correctly ended activity assertion.
6. Add regression coverage for dropped releases and the revised double-tap timing.
7. Update the shortcut decision record and changelog with the implemented behavior and sources.
8. Run targeted and unfiltered tests, inspect the final diff, and report any unrelated failures honestly.

## Decisions
- Keep AppKit local/global event monitors because the app supports Fn and left/right modifier identity; do not expand this fix into a Carbon hotkey rewrite.
- Use `NSEvent.modifierFlags` for recovery because Apple documents it as current modifier state independent of delivered events.
- Reconcile by modifier family. AppKit exposes the family flag, so a missing family flag can clear a stale left/right entry, while a present family flag preserves valid long-held combinations.
- Poll every 250ms on the main actor. The watchdog is a recovery path, not an aggressive timeout on real modifier presses.
- Retain `ProcessInfo.beginActivity`'s token and end it during application termination.
- Leave the Ghostty paste fallback unchanged in this minimal fix; its synthetic Command+V is input that should cancel a pending shortcut pair, while the permanent lockout is owned by `ShortcutMonitor` state.

## Evidence
- Apple documentation verified for AppKit global/local monitors, current modifier flags, and `ProcessInfo` activity tokens.
- `swift test --filter ShortcutMonitorTests`: 2 tests passed, including same-family recovery after a dropped Left Command release and release-to-press double-tap timing.
- Initial unfiltered `swift test` compiled the change and passed the new code's build, but failed in the existing `VoiceOverlayWindowTests.editingDurationExpiresExistingResultAndDoesNotReviveIt` timing case; this is being rerun separately before delivery.

## Outstanding
- Complete the unfiltered test rerun and inspect the final worktree/diff.
- Build the app if the repository's normal app build is available and report its result.
