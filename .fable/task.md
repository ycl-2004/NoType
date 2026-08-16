# Current Task: Compare Local Models and Surface Model Readiness

## Goal

Produce an auditable old-versus-Turbo model report and make the app's Diagnostics menu show the real local-model readiness state without requiring the debug log.

## Acceptance Criteria

- A verified Excel workbook compares model structure, speed, memory, operational reliability, and disk footprint with native charts and formulas.
- Old and Turbo performance measurements use the same input and disclose warm/cold-cache conditions.
- Operational success rate is distinguished from transcript accuracy; WER/CER is reported only when reference text exists.
- Related installed apps, release artifacts, local model copies, and identifiable Core ML caches are inventoried; only explicitly authorized stale temporary caches are deleted.
- Diagnostics visibly distinguishes preparing, ready, and failed model states using the actual WhisperKit loading lifecycle.
- Diagnostics provides useful first-launch guidance and an actionable failure message without requiring the debug log.
- Automated tests and workbook inspection/rendering verify the deliverables.

## Requirements List (Append Only)

1. Create a complete comparison chart or Excel report for the current Turbo model versus the previous model.
2. Compare model architecture and practical advantages.
3. Run an A/B speed test and compare memory/resource behavior.
4. Evaluate whether transcription succeeds reliably and report a success rate where measurable.
5. Inspect project-related caches, previous app copies, and previous model copies consuming local disk space.
6. Do not delete audited files or caches as part of the analysis.
7. Add a Diagnostics section that shows whether the local model is preparing, ready, or failed without opening the debug log.
8. Explain the long first launch visually and show a useful error state when model preparation fails.
9. Delete only the stale interrupted Core ML temporary caches while preserving completed reusable caches.

## Decision Log

- Treat operational success rate and text accuracy as separate measurements; do not infer WER/CER without reference transcripts.
- Use real pipeline lifecycle events for Diagnostics and avoid a fabricated percentage because Core ML does not expose reliable specialization progress.
- Keep the model status inside the existing Diagnostics submenu so the normal menu remains compact.
- Keep all disk-audit actions read-only; present cleanup candidates for later user authorization.
- After explicit user authorization, remove only `.tmp.<old PID>.bundle` cache directories and retain completed `.bundle` caches.
- Treat replacing the app bundle separately from a normal restart: the installed build created a new Core ML cache identity once, while the immediately following ordinary restart reused it.

## Evidence

- Seven stale Core ML temporary bundles were verified against exited PIDs and deleted, reducing the NoType cache from 7,266,876 KiB to 561,440 KiB; cache files are rebuildable but the deleted temporary directories are not recoverable.
- Installing the rebuilt app created eight new completed bundles and reached `WhisperKit: pipeline loaded successfully` after 118 seconds; a subsequent ordinary restart reached Ready in the same log second. Current cache: 704,712 KiB, 40 completed bundles, zero temporary bundles.
- `swift test` passed 107 tests in 8 suites on 2026-08-16.
- `scripts/build_release.sh` produced a signed NoType 0.3.0 app/archive; the installed binary SHA-256 matches the release binary and `codesign --verify --deep --strict` passed.
- The workbook at `outputs/notype-model-analysis-20260816/NoType-Local-Model-Analysis-2026-08-16.xlsx` contains seven rendered sheets; inspection found zero formula errors and all sheets passed visual QA.
- Diagnostics readiness and retry behavior are covered by AppState, coordinator, and menu lifecycle tests. Automated Computer Use could not attach to the windowless menu-bar agent, so no UI screenshot is claimed.
