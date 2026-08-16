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

- Pending: current diff review, tests, rebuilt bundle/archive, installation, commit, and push.
