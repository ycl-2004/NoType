# NoType resource cleanup and R2T2 reliability fixes

## Goal
Fix findings from the app audit and prioritize removal of generated development artifacts.

## Requirements (append-only)
1. Remove regenerable development outputs; preserve source, model files, user changes, and installed app until replacement is verified.
2. Prevent silent R2T2 output truncation; support long recordings with bounded segments.
3. Reduce cumulative repeated inference, order/drain incoming audio on stop, reuse completed work.
4. Surface capture/write errors and discard incomplete audio safely.
5. Bound log size and throttle retention scans; isolate test logging.
6. Pin and verify R2T2 model files using publisher SHA-256 metadata.
7. Release unused engines while keeping the current engine hot.
8. Preserve temporary recording cleanup, the 300-second limit, original-target clipboard fallback and existing output modes.
9. Verify fixes, build a usable app, document tradeoffs and actual cleanup results.

## Decisions
- Bounded 24-second VAD-assisted segments reuse the existing AudioChunker. Tail previews start at 320 ms and back off; exact final preview reused. No unsafe removal of llama KV clearing.
- A single AsyncStream consumer replaces per-callback Tasks. Stop drains queued samples before finalization.
- Decode limit triggers subdivision, irreducible failures report error rather than incomplete success. Detokenize the full byte sequence to preserve split UTF-8 characters.
- R2T2 revision a5b8b2d84b7a429ba758ec3a67b89602540fb34a and both LFS SHA-256 values retrieved from publisher API; local model hashes match.
- Release previous engine on resolving a different engine; keep active streaming engine alive. No idle unload/reload of the user's current model.
- User explicitly authorized cleanup and fixes. No superpowers or Partner workflow used; no delegation.

## Evidence so far
- Before: .build 4.7 GiB, dist 76 MiB, /Applications/NoType.app 60 MiB, models 1.4 GiB.
- Removed .build/index-build (1.8 GiB) and .build/out (1.1 GiB); .build now 1.8 GiB before new builds.
- First 34 targeted tests passed.
- Full suite after fixes: 168 tests / 28 suites passed, /tmp/notype-fixes-full-tests.log.
- git diff --check passed.

## Completed — 2026-09-22
- Final full regression: 171 tests / 30 suites passed, /tmp/notype-fixes-final-tests.log.
- Added direct capture-error cleanup/restart test and test-host log isolation check. The latter exposed SwiftPM's new `swiftpm-testing-helper` host; detection was corrected and the full suite rerun successfully.
- Real model: 11.688s synthetic speech in 1.686s; 46.753s accelerated streaming replay in 4.347s. All four sentence/end-code repetitions preserved. /tmp/notype-r2t2-e2e.log.
- ./scripts/build_app.sh passed; build log /tmp/notype-fixed-build.log. Release bundle signature verified.
- Confirmed no temporary WAV before replacement, installed and launched /Applications/NoType.app. Process 98960 initially observed. Production log shows verified model loaded and ready at 2026-09-22T16:00:45Z.
- Installed and dist main executables match SHA-256 8e762640a9711a371480989aa7465421f6b234c5cfe00801555a0f9be5647a4e.
- Removed all .build caches and old release ZIP/checksum after verification. Final dist 60 MiB; shared models remain 1.4 GiB. About 4.7 GiB of original build data plus 15 MiB old ZIP removed (new build intermediates removed as well).
- Added ADR-011, updated README, changelog, known issues and ADR-010 supersession. Added repeatable cleanup script.
- Preserved .superpowers/ and outputs/voice-overlay-qa/ user files. No commit, push, external publication or model deletion.

## Verification limits
- Synthetic English real-model tests and five-minute sample-conservation unit tests are not real microphone, battery, or long-running memory-leak benchmarks.
- Segment boundaries can affect punctuation or words when there is no pause. Native stateful R2T2 KV reuse remains unsupported; bounded segment reuse is implemented instead.
- The selected model intentionally remains resident. Initial repaired app snapshot RSS ~2.32 GiB, CPU 0.3%, not evidence of leak absence.
