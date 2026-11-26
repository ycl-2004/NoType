# ADR-012: R2T2 is the only local engine

## Status

Accepted — 2026-11-26. Supersedes the engine parts of [ADR-006](006-sensevoice-engine-and-model-storage.md)
and [ADR-008](008-qwen3-asr-replaces-whisper.md), and the experimental status in
[ADR-010](010-r2t2-streaming-engine.md).

## Context

NoType carried three local engines: Qwen3-ASR 0.6B INT8 and SenseVoice Small through sherpa-onnx,
and R2T2 through llama.cpp. The user dictates with R2T2 daily and has stopped using the other two;
neither model was installed on the development Mac. In an 86-second mixed Chinese and English
dictation on 2026-11-26, R2T2 inserted the transcript about one second after stop (log timestamps
have one-second resolution).

Qwen3-ASR filled three roles: a selectable engine, the `Auto` fallback when macOS Speech is
selected, and the only engine on macOS 15. R2T2 is trained from Qwen3-ASR-1.7B, the larger model of
the same family, and its llama.cpp framework targets macOS 13.3, below NoType's macOS 15 minimum,
so it can take all three roles. SenseVoice was only ever a comparison engine.

## Decision

- Remove the Qwen3-ASR and SenseVoice engines, their installers, paths, tests and the sherpa-onnx
  package dependency. Keep macOS Speech: it is part of the system and needs no download.
- R2T2 is the default engine and is no longer labelled experimental. The engine menu lists
  `R2T2 Streaming` first and `macOS Speech (fast)` second, with no separate section.
- `Auto`, and every mode on a Mac without macOS Speech, resolves to R2T2. The router streams
  whenever a dictation resolves to R2T2, so the macOS Speech + `Auto` fallback streams too.
- Saved preferences `qwen3ASR`, `senseVoice` and `bundledWhisper` load as R2T2. Model folders the
  removed engines downloaded under `~/Documents/huggingface/models/k2-fsa/` are left in place;
  Manage Downloaded Models no longer lists them.
- Keep `AudioChunker`'s 24-second limit, which was measured on Qwen3-ASR 0.6B and has not been
  measured on R2T2.

## Consequences

- There is no second local engine to fall back to or compare against. A broken llama.cpp update
  or model file leaves macOS Speech single-language modes as the only working path.
- A new install downloads about 1.46 GB at first launch instead of nothing on macOS 26.
- The 0.4.0 release still ships Qwen3-ASR and SenseVoice; this change applies from the next
  release.
- Model files left by the removed engines are not cleaned up automatically.
- sherpa-onnx had also been supplying the rpath through which the executable found
  `llama.framework`. Without it the app aborted at launch ("Library not loaded"), so
  `Package.swift` now sets `@executable_path` explicitly and `scripts/build_app.sh` refuses to
  sign a bundle whose executable lacks it.

## Verification

- `swift build` and `swift test`: 177 tests in 28 suites passed after the removal.
- The app bundle shrank from 60 MB to 23 MB; the executable from 39 MB to 1.2 MB.
- Installed in `/Applications` signed with the development certificate: launched, prepared R2T2,
  and quit without a crash report (2026-11-26).
- Routing tests cover the R2T2 default, migration of the three removed raw values, `Auto` falling
  back to R2T2 while streaming, and the engine menu without an experimental section.
