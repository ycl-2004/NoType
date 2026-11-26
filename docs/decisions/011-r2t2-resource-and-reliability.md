# ADR-011: Bounded R2T2 work and verified local resources

## Status
Accepted — 2026-09-22. Supersedes ADR-010's cumulative-prefix scheduling and append-only-preview claims.

## Context
The first R2T2 implementation cleared its KV cache and decoded the whole accumulated recording
on each preview and again at stop. Its 512-token output cap returned truncated text as success,
and independently scheduled audio callback Tasks could reach the session after finalization.
The user requested fixes and development-artifact cleanup while preserving the current clipboard
fallback, temporary-audio cleanup, and five-minute recording limit.

## Decision
- Keep llama.cpp b11102 and the existing model quantizations. Use the existing VAD-assisted
  AudioChunker to commit segments no longer than 24 seconds. Decode completed segments once,
  retain their text, and preview only the current tail. No native R2T2 KV-state support is claimed.
- Preserve the first 320 ms preview; subsequent preview intervals grow from at least two seconds
  to half the current tail duration. With live previews disabled, only segment/final work is done.
  An exact complete preview is reused at stop. Preview text may revise; committed text is retained.
- Queue audio through a single AsyncStream consumer. The recording lock covers publication so
  stop can close the stream and drain all accepted chunks before finalization. No text is inserted live.
- Reserve context room for up to 1,024 output tokens. Reaching a context/output limit retries smaller
  audio segments; if even a one-second segment cannot finish, fail visibly without inserting partial text.
  Detokenize complete token sequences so UTF-8 characters split across tokens are not corrupted.
- Propagate streaming capture/write errors at stop, reset recorder state, and delete the partial WAV
  even when no RecordedAudioClip can be returned. The coordinator fails without changing the clipboard.
- Keep only the currently resolved engine cached. Activating a different engine releases previous
  router references; an in-flight stream remains alive until completion. Switching back incurs a cold load.
- Keep debug logs at most 2 MiB. Retain five days, pruning at first use, hourly, or when the size cap
  is approached; size pressure can evict younger entries. Tests use separate process-specific temp logs.
- Pin R2T2 to Hugging Face revision `a5b8b2d84b7a429ba758ec3a67b89602540fb34a`.
  Verify size and publisher SHA-256 before installing, using 1 MiB reads off the main actor. Before a
  cold runtime load, hash again only when a file's identity (device, file number, size, modification
  time) differs from the one last verified for that digest; the result is kept in user defaults.
  Corrupt/incomplete installed files fail with explicit removal/retry guidance.
  Use unique staging directories so simultaneous downloads do not delete one another's staging files.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| Q4_K_M model | 1107405568 | `d2b05e834988852106f816919293d3a51e4039b44fb5c4e074fa913f083f2c6e` |
| Q8_0 projector | 355709696 | `4fd02f8bb9fdf8792ba05e4fd433a40a3296ec299ca4fa5c46ae8f068740654c` |

## Tradeoffs and boundaries
Independent segments can lose punctuation or a word boundary at a hard cut with no pause. This
uses the same conservative split policy as the other local engines; it avoids whole-clip truncation
but is not a guarantee of transcription accuracy. The energy threshold remains heuristic.

Hashing both files at utility priority kept every launch in "Preparing" for about 35 s, so an
unchanged file is trusted by identity. A re-download, partial write or replaced file changes that
identity and is hashed; damage that leaves size, file number and modification time intact is not
detected, and the check is not a defense against someone who can already write the user's files. The selected
model stays loaded for responsiveness. Cache clearing between independent prompts is still required;
removing it without matching audio embeddings and prompt positions would corrupt inference.

Clipboard behavior is intentionally unchanged. A changed original target copies the transcript;
clipboard history/sync tools can retain it. Audio cleanup, the 300-second cap, shortcut behavior,
and all three output modes are preserved.

## Validation
- Unit/regression tests cover five minutes of audio with exact sample conservation and bounded
  decode windows, ordered final drain, exact-preview reuse, preview backoff, limit retry/failure,
  cancellation, capture failure cleanup/restart, clipboard preservation, model hashes, log limits
  and engine release. Native microphones are not required by these tests.
- Opt-in real-model test used locally synthesized English audio. A cold preparation precedes timing:
  11.688 s of speech decoded in 1.686 s; 46.753 s of accelerated streaming replay completed in 4.347 s.
  All four repeated sentences and final codes survived. These are fixture-specific timings, not a
  before/after benchmark or real-time microphone stop latency. No user audio was read.
- Both model files already installed on the development Mac matched the publisher hashes.

Reproduce the real-model check (Samantha must already be installed):

```sh
say -v Samantha -r 150 -o /tmp/notype-r2t2.aiff 'The silver telescope is ready. We are testing local speech recognition on this computer. Please keep the complete sentence and all of the final words. The final code is seven nine three.'
afconvert -f WAVE -d LEI16@16000 -c 1 /tmp/notype-r2t2.aiff /tmp/notype-r2t2.wav
NOTYPE_R2T2_E2E_CLIP=/tmp/notype-r2t2.wav swift test --filter R2T2EndToEndTests
```

## Development cleanup
Run `./scripts/clean_development.sh` after tests/builds finish. It removes `.build` (including
redownloadable dependency artifacts) and old `dist/NoType-*-arm64.zip` archives/checksums.
It preserves `dist/NoType.app`, the installed app, shared models, source and QA outputs.
The next build must recreate caches and may download pinned dependencies again.

## Sources
- [llama.cpp b11102 API](https://github.com/ggml-org/llama.cpp/blob/b11102/include/llama.h): context size and full-sequence detokenization. Verified against the installed XCFramework headers.
- [b11102 mtmd helper](https://github.com/ggml-org/llama.cpp/blob/b11102/tools/mtmd/mtmd-helper.h): prompt token counting.
- [Swift AsyncStream continuation](https://developer.apple.com/documentation/swift/asyncstream/continuation): ordered asynchronous consumption of callback-produced values.
- [CryptoKit SHA256](https://developer.apple.com/documentation/cryptokit/sha256): incremental hashing.
- [Publisher model metadata](https://huggingface.co/api/models/mradermacher/Confucius4-R2T2-GGUF?blobs=true): revision and LFS hashes, retrieved 2026-09-22.
