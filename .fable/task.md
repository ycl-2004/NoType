# Current Task: Replace Whisper with Qwen3-ASR INT8

## Goal

Replace the local WhisperKit/Core ML transcription path with the official sherpa-onnx
Qwen3-ASR 0.6B INT8 offline recognizer for testing, while preserving SwiftPM, local model
download/install behavior, and the `TranscriptResult` output contract.

## Acceptance Criteria

- The local multilingual engine is Qwen3-ASR 0.6B INT8 through the official sherpa-onnx Swift API.
- The model is downloaded locally from the official sherpa-onnx release archive and validated by
  its expected files before loading.
- `TranscriptResult(text:rawText:)`, post-processing, readiness reporting, and local-only behavior
  remain intact.
- WhisperKit is no longer a runtime or SwiftPM dependency, and stale Whisper model/install paths
  are removed from the active app and packaging flow.
- SenseVoice remains available as its existing optional sherpa-onnx engine.
- Engine routing, menu labels, model management, and persisted engine choices refer to Qwen3-ASR
  rather than Whisper.
- Tests and a release build pass; documentation and changelog describe the new model and its
  approximate 1 GB download.

## Requirements List (Append Only)

1. Replace the current Whisper local engine with the official sherpa-onnx Qwen3-ASR 0.6B INT8
   offline model.
2. Keep the existing Swift implementation surface where practical.
3. Keep local model download and readiness reporting behavior.
4. Keep the `TranscriptResult` output protocol and transcript post-processing.
5. Remove the WhisperKit dependency and active Whisper files/references.
6. Preserve SenseVoice as a separate optional local engine.
7. Update tests, user-facing labels, packaging scripts, README, and changelog consistently.
8. Verify with the repository's documented unfiltered test command and a release build.
9. Recheck the latest checkout, install the verified app in `/Applications/NoType.app`, then commit and push the current branch.

## Decision Log

- Use sherpa-onnx `1.13.7`, already locked by the package, because its official Swift wrapper
  exposes `sherpaOnnxOfflineQwen3ASRModelConfig` and the Qwen3-ASR INT8 model layout.
- Use one Qwen3 recognizer decode per clip. Qwen3-ASR performs multilingual recognition itself;
  the old Whisper prompt/fallback/scoring chain is model-specific and should not be carried over.
- Keep the existing shared `~/Documents/huggingface/models/k2-fsa` location used by SenseVoice,
  adding a Qwen3-specific directory so model deletion remains narrowly scoped.
- Keep `ModelInstallLocation` only if the active installation flow still needs the user's shared vs
  private choice; otherwise remove the Whisper-specific choice rather than presenting a false UI.

## Evidence

- Official sherpa-onnx docs list the Qwen3-ASR 0.6B INT8 archive and its four required model
  components: `conv_frontend.onnx`, `encoder.int8.onnx`, `decoder.int8.onnx`, and `tokenizer`.
- The local sherpa-onnx 1.13.7 checkout contains the matching Swift example and wrapper API.
- Current worktree was clean before this task.

## Outstanding

- Real-device transcription quality and latency still need measurement after the model is installed.
  Nothing in this task verified how Qwen3-ASR actually transcribes; the acceptance criteria above
  cover the swap, not the result.
- Known issue #11 is worse under Qwen3-ASR and unmeasured: reaching the local model through `Auto`
  for the first time is now a ~1 GB download rather than a two-second model load.

## Completed (2026-09-09)

- Delivery verification: 131 tests in 21 suites passed, including an opt-in real Qwen3
  production-path transcription using the installed model and its raokouling sample converted
  to the recorder's 16 kHz mono format. Logs: `/tmp/notype-e2e.log`.
- `scripts/build_app.sh` passed; app signature verified. Installed bundle matches `dist/NoType.app`
  byte-for-byte. Installed process started successfully and logged Qwen3 recognizer loaded/model ready.
- Previous installed app retained at `/private/tmp/notype-installed-backup.lPKHid/NoType.app`.
- This smoke test establishes successful local inference, not transcription accuracy across all
  languages or a complete live microphone/shortcut/insertion validation.

- Fixed two dropped string interpolations (`Qwen3ASRPathsTests` expected base path,
  SenseVoice audio-load error message) — the test failure was the only red in the suite.
- Removed dead `DictationRecognitionLanguage.whisperLanguageCode` and rewrote the comments that
  still described Whisper mechanics as current behavior.
- Removed Whisper bundling from `build_app.sh` and `build_release.sh` (`INCLUDE_MODEL`,
  `WHISPER_MODEL_DIR`, `WHISPER_TOKENIZER_DIR`). Release builds now start from a clean release
  directory, because `build_app.sh` copies every `*.bundle` it finds and stale WhisperKit-era
  bundles were being signed into the app.
- Deleted `Vendor/WhisperKit-main/` (277 files). This resolved known issue #8 — `swift test --filter`
  was verified working, followed by a passing unfiltered run.
- Documented the swap: new ADR-008, ADR-002/005/006 marked superseded, README, CHANGELOG,
  CLAUDE.md, and `docs/known-issues.md` reconciled with the code that now exists.
