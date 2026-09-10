# ADR-008: Replace WhisperKit with sherpa-onnx Qwen3-ASR 0.6B INT8

## Status

Accepted — supersedes [ADR-002](002-portable-release-packaging.md),
[ADR-005](005-model-location-strategy.md), and the Whisper half of
[ADR-006](006-sensevoice-engine-and-model-storage.md)

## Date

2026-09-09

## Context

NoType's multilingual local engine was WhisperKit `large-v3-turbo` on Core ML. It worked, but it
carried a large amount of model-specific machinery that the rest of the app had to accommodate:

- **Three decode attempts per dictation.** `transcriptionAttempts(for:)` ran auto-detect, forced
  Chinese, and forced English, then scored the candidates against each other. Roughly 500 lines of
  the test suite existed to pin that scoring down.
- **A prompt path that never reached the model.** Known issue #1: `promptTokens` was hardcoded to
  `nil`, so the "do not translate" instruction was inert, and fixing it would have disabled the
  prefill KV cache.
- **Subtitle sign-off hallucinations.** Known issue #2 and #4 both trace back to Whisper's training
  data appending 「谢谢大家」 and "thank you" to utterances that trail into silence.
- **1.5 GB in the release archive.** ADR-002 bundled the model so a friend's first run worked
  offline; the published 0.2.0 ZIP was about 1.4 GB. ADR-005 then had to add a search order and an
  install-location prompt so that replacing the app did not move the model path and discard the
  Core ML specialization cache — measured at 4m13s to re-specialize versus 2–4s warm.
- **A 3.7 MB vendored checkout.** `Vendor/WhisperKit-main/` broke `swift test --filter` outright
  (known issue #8) by pulling non-compiling test targets into the build graph.

ADR-006 had already added SenseVoice Small through sherpa-onnx and proved that a lazily downloaded
ONNX model in a shared directory works well. The official sherpa-onnx 1.13.7 Swift wrapper also
exposes `sherpaOnnxOfflineQwen3ASRModelConfig`, and Qwen3-ASR 0.6B performs multilingual
recognition itself rather than needing a per-language attempt chain.

## Decision

**Replace the Whisper engine with Qwen3-ASR 0.6B INT8 through the same sherpa-onnx package
SenseVoice already uses.** `TranscriptionEngineChoice.bundledWhisper` becomes `.qwen3ASR`; the
routing rule is otherwise unchanged, so macOS Speech still hands mixed speech to the local model
because its recognizer is bound to one locale.

**One recognizer, one decode per chunk.** Qwen3-ASR detects the spoken language on its own. The
attempt chain, candidate scoring, prompt construction, and temperature-fallback capping were all
Whisper-shaped and are deleted rather than ported. VAD chunking was deleted with them and then
restored as `AudioChunker` once measurement showed the model cannot decode past roughly 30s at all
— see the alternatives below. The selected recognition mode
is still passed to `TranscriptPostProcessor` for the Chinese-script preference.

**No model in the app bundle.** Both local models are now downloaded on first use into
`~/Documents/huggingface/models/k2-fsa/`, matching what ADR-006 established for SenseVoice:

```text
~/Documents/huggingface/models/k2-fsa/
  sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25/
    conv_frontend.onnx
    encoder.int8.onnx
    decoder.int8.onnx
    tokenizer/
```

The installer downloads the official sherpa-onnx release archive to a temporary file, extracts to a
temporary directory, validates all four components, and only then moves the exact versioned folder
into place. An interrupted attempt is cleaned up on the next one.

This removes the reason ADR-002 and ADR-005 existed. `INCLUDE_MODEL`, `WHISPER_MODEL_DIR`,
`WHISPER_TOKENIZER_DIR`, the bundle search order, and the shared-versus-private install prompt are
all deleted. The release script now packages the app as built.

**Delete the vendored WhisperKit checkout.** It is no longer a SwiftPM dependency, and removing it
fixes known issue #8 as a side effect.

## Consequences

- The release archive drops from roughly 1.4 GB to the size of the app itself. The first run of
  either local model now requires a download — about 1 GB for Qwen3-ASR — where a bundled release
  previously worked offline out of the box. This is the trade ADR-002 explicitly declined in 2026-08
  and is being accepted now that a working lazy-download path already exists for SenseVoice.
- Core ML specialization no longer applies at all, so the 4m13s cold-path failure ADR-005 was
  written to avoid cannot recur.
- `swift test --filter` works again.
- The engine is CPU-provider ONNX. Execution-provider tuning is deliberately deferred until there
  are measurements to tune against.
- The subtitle sign-off filter in `TranscriptPostProcessor` is kept even though the model that
  motivated it is gone. Whether Qwen3-ASR produces the same closers is unmeasured, and the filter
  only strips a known phrase from the very end.
- Recordings past 24s now cost one decode per chunk. Short dictation, the common case, is
  unaffected and keeps the single-decode path.
- Chunks are decoded independently, so punctuation at a chunk boundary is not conditioned on the
  preceding text — the same trade the Whisper VAD path made, recorded then as known issue #12.
- **Real-device transcription quality is still not fully measured.** This ADR records the
  swap, not a verdict on it. Known issue #11 in particular is worse under Qwen3-ASR: the cold
  `Auto` path is now a download rather than a two-second load.

## Alternatives considered

### Keep Whisper alongside Qwen3-ASR as a fourth engine

Rejected for now. ADR-006 made exactly this argument for SenseVoice and it was right there, but
Whisper is the engine being replaced rather than compared. Keeping it would mean keeping the whole
attempt chain, the vendored checkout, and the bundling scripts alive to serve a path the user is
moving away from. The Git history holds it if the measurements come back badly.

### Keep bundling a model in the release

Rejected. Bundling only made sense when the model could not be fetched at runtime. SenseVoice has
demonstrated the download path for a release cycle, and a 1.4 GB archive was the single largest
barrier to distribution noted in ADR-002's own consequences.

### Port the attempt chain and scoring to Qwen3-ASR

Rejected. Those attempts existed because a Whisper decode had to be told which language to expect.
Qwen3-ASR returns a detected language with the transcript, so running three decodes would triple
the latency to re-derive something the model already reports.

### Drop VAD chunking along with the rest of the Whisper decode machinery

**Reversed on 2026-09-09, after measurement.** This ADR originally treated `chunkingStrategy: .vad`
as Whisper-specific and deleted it. That was wrong: chunking is not a property of Whisper, it is a
property of every utterance-level recognizer, and Qwen3-ASR needs it more than Whisper did.

Measured against the model's own sample files, at `max_total_len` from 512 through 4096:

| Audio | Expected | Best observed at any setting |
| --- | --- | --- |
| 8s | 22 chars | 30 chars, correct |
| 31s | 179 chars | 160 chars, correct |
| 63s | 628 chars | 220 chars — 65% missing |
| 124s | 840 chars | 1369 chars at 2048; 6693 chars over 428s at 4096 |
| 191s | 2672 chars | 83 chars, or the single token `language` |
| 275s | 3448 chars | 1406 chars — 59% missing |

Raising `max_total_len` is not a fix. It moves the failure rather than removing it: at 512 a long
clip returns the stray token `language`, and at 4096 a 124s clip runs away to eight times its true
length and takes 428 seconds. The model's own 51s sample fails at the default setting, which rules
out the test audio as the cause.

`AudioChunker` therefore splits any recording past 24s on its longest pause and decodes each segment
separately. `max_total_len` is raised to 1024 as headroom for one dense chunk — in the same sweep,
raising it cost nothing on short clips: identical text and identical decode time at every setting.

## Verification

- `swift build`: succeeded.
- `swift test`: 122 tests in 19 suites passed, unfiltered.
- `swift test --filter Qwen3ASRPathsTests`: passed, and a subsequent unfiltered run also passed —
  the failure mode recorded as known issue #8 no longer reproduces.
- Unit tests assert the official archive URL, the four expected model components, the shared
  install path, and the INT8 package check.
- A real model download is intentionally not part of this source change. The installer path should
  be exercised on the target Mac by selecting Qwen3-ASR once.

## References

- [sherpa-onnx Qwen3-ASR documentation](https://k2-fsa.github.io/sherpa/onnx/qwen3-asr/index.html)
- [ADR-006: SenseVoice as a shared optional local engine](006-sensevoice-engine-and-model-storage.md)
