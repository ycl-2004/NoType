# ADR-010: Experimental R2T2 streaming engine

## Status

Accepted — 2026-09-22. Scheduling and preview semantics superseded by [ADR-011](011-r2t2-resource-and-reliability.md);
the experimental label and the separate menu section removed by [ADR-012](012-r2t2-only-local-engine.md).

## Context

NoType's existing interaction is deliberately target-safe: dictation captures the focused input at
start, and the final transcript goes through the existing Accessibility insert, paste fallback, and
clipboard behavior. If the original target changes, NoType keeps the transcript on the clipboard
instead of inserting into whichever app happens to be focused later.

Confucius4-R2T2 is designed for streaming transcription. The first NoType integration needs to
preserve the target-safe interaction while gaining the latency benefit of doing recognition during
recording. The first model package is the Hugging Face Q4_K_M GGUF text model with its Q8_0
multimodal audio projector.

## Decision

Add **R2T2 Streaming (Experimental)** as a separate engine choice. It uses:

- `Confucius4-R2T2.Q4_K_M.gguf`
- `Confucius4-R2T2.mmproj-Q8_0.gguf`
- llama.cpp's XCFramework and Metal backend
- 16 kHz mono float audio chunks, initially 320 ms

The user-facing interaction remains unchanged:

```text
start → capture target → record + stream internally → stop → finalize → Insert / Copy pipeline
```

The microphone path uses an `AVAudioEngine` tap for R2T2 and keeps a 16 kHz WAV clip for the same
cleanup and lifecycle guarantees as offline recording. A stream actor owns ordering, accumulates
audio, coalesces decode work when a decode is slower than the microphone, and exposes only an
append-only stable prefix. Since llama.cpp's current multimodal API provides audio chunks but not
R2T2's native stateful streaming API, this first runtime decodes cumulative prefixes. The runtime
is behind a protocol so a true stateful backend can replace that fallback without changing the
coordinator or output contract.

Partial text is never inserted into a textbox. The optional voice overlay may display the stable
preview, controlled by **Show Live Transcript**. On stop, the final result passes through
`TranscriptPostProcessor`, then through the existing Insert + Copy, Insert Only, or Copy Only mode.
The captured target and changed-target clipboard fallback are unchanged.

Every downloadable model uses the shared Hugging Face root:

```text
~/Documents/huggingface/
  models/k2-fsa/…                          # Qwen3-ASR and SenseVoice
  models/mradermacher/Confucius4-R2T2-GGUF/ # R2T2 GGUF + projector
```

Downloaders validate the configured path, staging path, and resolved filesystem path before
creating or replacing model folders. A symlink that resolves outside `~/Documents/huggingface`
is rejected.

## Trade-offs

- 320 ms reduces callback/decode overhead compared with 160 ms, at the cost of a slightly less
  immediate preview. 160 ms remains a benchmark candidate.
- Cumulative prefix decoding is more expensive than a native R2T2 state machine. It is accepted
  for the experimental first version because it preserves the correct product semantics and keeps
  the backend replaceable.
- The R2T2 model package is large and downloaded on demand; it is not bundled in the app.
- The llama.cpp multimodal API is experimental and may require a runtime update if its C API changes.

## References

- [Confucius4-R2T2 GGUF model](https://huggingface.co/mradermacher/Confucius4-R2T2-GGUF)
- [Official Confucius4-R2T2 repository](https://github.com/netease-youdao/Confucius4-R2T2)
- [llama.cpp multimodal documentation](https://github.com/ggml-org/llama.cpp/blob/master/docs/multimodal.md)
- [llama.cpp mtmd C header](https://github.com/ggml-org/llama.cpp/blob/master/tools/mtmd/mtmd.h)
