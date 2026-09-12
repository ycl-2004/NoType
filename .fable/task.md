# Current Task: Optional bottom-center voice overlay

## Goal
Deliver the approved A layout in the native app, driven by real microphone levels and dictation outcomes.

## Requirements (append only)
1. Dark capsule, thin blue outline, bottom-center placement matching the approved preview.
2. Immediately show recording for the whole recording; waveform responds to microphone volume.
3. Show transcription, insertion, copied/inserted outcomes and failures; every status is under five characters.
4. Persist an on/off setting for the overlay.
5. Preserve input focus and existing insertion/clipboard behavior.
6. Verify native appearance, lifecycle, relevant tests, and a distributable local app build.
7. Added: separately configurable completion and failure duration, default 1.5 seconds, 0–5 seconds; zero hides that category.
8. Clarified: adjust only result duration; recording appears immediately, no appearance delay.
9. Added: install the verified update into `/Applications/NoType.app` and restart it.
10. Added: use English-first menu copy (`English`, `Show Voice Overlay`, and `Overlay Timing`), remove the redundant active-recording helper line, and accept custom 0–5 second result durations.
11. Added: commit the completed changes and push them to the current GitHub branch.

## Decisions
- Use AppKit nonactivating click-through NSPanel and a compact SwiftUI view.
- Sample AVAudioRecorder meters on its actor; publish levels without rebuilding menus.
- Separate transient feedback from the dictation state; settings update the existing countdown and never resurrect expired feedback.
- User screenshot and approved A preview define the design; do not introduce a new visual direction.
- Prior assistant incorrectly invoked a Superpowers preview despite the user's default ban; continue direct execution and do not extend that workflow.
- Initial scope was implementation and local build; the user subsequently authorized installation
  in `/Applications/NoType.app`, then explicitly authorized commit and push.

## Evidence
- Apple documentation verified for AVAudioRecorder metering, nonactivating panels, click-through windows, full-screen collection behavior.
- Previous task record preserved verbatim in history.md.
- Final unfiltered `swift test`: 146 tests in 23 suites passed
  in 5.708 seconds on 2026-09-11. Includes delivery outcome feedback, metering visibility,
  persisted defaults/zero/cap, menu actions, focus preservation, immediate display, expiry while
  disabled, live timing changes, and cancellation both before and during a previous result's fade.
- Actual NSHostingView captures opened and visually inspected in `outputs/voice-overlay-qa/`:
  recording, transcribing, inserted, copied, insertionFailed. Improved processing icon contrast
  after the first capture; final capture and test run include the updated view.
- `./scripts/build_app.sh`: release build succeeded (8.91s), asset catalog compiled,
  and `codesign --verify --deep --strict` passed for `dist/NoType.app`.
- Build approval was initially blocked by quota on automatic approval review; after the user's
  continue instruction, the same reviewed local build succeeded. No bypass was used.

## Completed — 2026-09-11
- Requirements 1–8 implemented and verified to the scope above.
- README, CHANGELOG, known issue #7, and ADR-009 updated.
- Initial delivery supplied `dist/NoType.app` without replacing the installed version.

## Installation follow-up — 2026-09-11
- Requirement 9 complete: backed up the old installed app at
  `/private/tmp/notype-before-overlay.TxepGC/NoType.app`; compared it byte-for-byte before replacement.
- Confirmed the previous process had no recording file open; quit it gracefully before replacing.
- Signed the new bundle with the user's Apple Development identity (team BQYHJCCRMP),
  installed it into `/Applications/NoType.app`, and verified exact bundle equality with `dist`.
- Strict signature verification passed. New installed process PID 29613 is running from
  `/Applications/NoType.app/Contents/MacOS/noType`.
- Fresh launch of the updated bundle succeeded with process PID 33111 from
  `/Applications/NoType.app/Contents/MacOS/noType`. Strict signature verification and exact
  bundle comparison against `dist/NoType.app` passed. This verifies launch; it does not assert
  live microphone permissions.
- Previous version was ad-hoc signed, so the change to developer signing can require renewed
  macOS permissions. This was disclosed before installation; no permission databases were changed.

## English copy and commit follow-up — 2026-09-11
- Requirement 10 complete: recognition language now displays `English` while Chinese remains
  `中文优先`; overlay controls are `Show Voice Overlay` and `Overlay Timing`; the redundant
  active-recording helper line was removed; completion and failure durations accept custom values
  from 0 to 5 seconds, with 0 hiding that result category.
- Added validation for decimal and comma-decimal input, bounds, invalid input, menu labels, and
  recognition language copy. The full suite passed after this change.
- Requirement 11 complete: commit `3bf24d8` (`feat: add configurable voice overlay`) was pushed
  successfully to `origin/feat/new_models`.

## Verification limits
- Microphone input is wired to the real AVAudioRecorder API; pipeline tests use a metered stub.
  Live speech/shortcut/insertion in external apps was not exercised with the new bundle.
- Multiple-monitor placement was verified with coordinates; full-screen and physical
  multiple-monitor behavior were configured but not manually exercised.
