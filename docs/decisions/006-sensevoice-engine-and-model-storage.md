# ADR-006: Add SenseVoice as a Shared Optional Local Engine

- Status: Accepted
- Date: 2026-09-09

## Context

NoType already supports macOS Speech and WhisperKit. Whisper is the existing
multilingual fallback for mixed Chinese and English, while macOS Speech is fast
but must be configured for one locale. We want a third local engine that can be
tested against Whisper without changing the existing macOS Speech path or
shipping another large model inside every app build.

The official [SenseVoice model card](https://huggingface.co/FunAudioLLM/SenseVoiceSmall/blob/main/README.md)
lists Chinese, Cantonese, English, Japanese, and Korean support. The official
[sherpa-onnx SenseVoice documentation](https://github.com/k2-fsa/sherpa/blob/master/docs/source/onnx/sense-voice/index.rst)
provides a native Swift integration path and macOS support. Its documented
archive includes the quantized ONNX model and tokenizer, with a much smaller
download than the bundled Whisper package.

## Decision

Add `SenseVoice Small` as an independent `TranscriptionEngine` implemented with
the `sherpa-onnx` Swift package. It is created lazily by
`RoutingTranscriptionEngine`, so selecting macOS Speech does not load either
local model. SenseVoice uses the selected recognition mode as its language hint:
`auto`, `zh`, or `en`. The CPU provider is the baseline for this comparison;
execution-provider tuning can follow measured results.

Download the official sherpa-onnx archive only when SenseVoice is selected and
the model is absent. Install exactly one copy at:

```text
~/Documents/huggingface/models/k2-fsa/
  sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17/
    model.int8.onnx
    tokens.txt
```

The installer downloads to a temporary file, extracts to a temporary directory,
validates both expected files, and then moves only the exact versioned model
folder into place. Existing unrelated files in `~/Documents/huggingface` are
left alone. An interrupted download or extraction is cleaned up on the next
attempt.

Add **Engine → Manage Downloaded Models** to the menu bar. The action requires
the app to be idle, shows a confirmation alert, and removes only these
NoType-managed paths:

- Whisper folders under the shared Hugging Face directory and NoType Application
  Support directory.
- The one SenseVoice folder above.

The app bundle is excluded because a signed release may contain bundled Whisper.
macOS Speech is also excluded: its system assets are owned by macOS, and NoType
does not call `SpeechTranscriber`, `AssetInventory`, or any other system asset
deletion API.

## Consequences

- Whisper and SenseVoice can be compared from the same menu without replacing
  the established Whisper or macOS Speech implementation.
- The SenseVoice download is shared across NoType builds and stays out of the
  signed app bundle. A first-use download is required when it is not already
  present.
- The user can reclaim NoType's downloaded model storage from the menu. The
  delete action cannot clean up unrelated Hugging Face repositories or macOS
  Speech assets.
- SenseVoice's upstream direct inference path documents a 30-second input limit.
  NoType currently passes its trimmed recording to sherpa-onnx as one clip, so
  recordings longer than that need real-device validation before we claim parity
  with Whisper's long-recording behavior.
- The model remains an ONNX runtime dependency in the app even when the user
  stays on macOS Speech; the model files themselves are downloaded lazily.

## Alternatives considered

### Replace Whisper with SenseVoice

Rejected. It would remove the established Whisper fallback, change the default
mixed-language behavior, and make the comparison harder to interpret.

### Put SenseVoice inside the app bundle

Rejected. It increases every release's size and creates a second copy on a
machine that already uses the shared Hugging Face folder.

### Reuse macOS Speech model management for deletion

Rejected. Those assets are system-managed and shared with other apps. NoType has
no ownership over them and must leave them untouched.

## Verification

- Unit tests assert the stable SenseVoice path, official archive URL, language
  mapping, and managed deletion paths.
- The full SwiftPM build and unfiltered test suite are the required checks.
- A real model download is intentionally not performed as part of the source
  change; the installer path is exercised through validation and should be
  tested on the target Mac by selecting SenseVoice once.
