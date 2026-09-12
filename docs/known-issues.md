# Known issues and future directions

This document records defects and gaps that are understood but deliberately **not** being fixed
right now. It is a backlog of directions, not a commitment or a schedule.

Everything here came out of a full review of the dictation pipeline on 2026-08-15. The items that
review found and that *were* fixed are listed at the bottom for context; the open items are
described in enough detail that the work can be picked up later without repeating the diagnosis.

Each entry records the evidence, so a future change can be judged against the same observation
rather than a fresh guess.

---

## Open: transcription quality

### 2. Voice-activity detection is only used to trim the tail

The silent-tail case described here is now handled. `TrailingSilenceTrimmer` runs `AudioEnergyVAD`
over the clip and drops everything after the last frame with speech in it, keeping 0.5s
of padding and only acting when at least 1.0s would be removed. Verified on a 34.3s recording
ending in 6s of silence: 5.50s trimmed, 28.8s transcribed, same transcript, and the clip stayed
inside one 30s window instead of spilling into a second. The 30s-window argument was Whisper's;
under Qwen3-ASR the saving is simply the decode time the silent tail would have cost.

Three deliberate limits remain:

- **Only the tail.** Trimming the head or the middle risks clipping real speech, and "I spoke and
  nothing happened" is a worse failure than a stray closing phrase.
- **A clip the detector cannot hear is passed through untouched**, not discarded. Quiet speech
  still reaches the model; genuine silence is already handled by the empty-transcript path.
- **The 0.02 energy threshold carried over from WhisperKit's `EnergyVAD` default and has been
  validated against digital silence only.** Whether it treats a real noisy room as silence is not yet measured. If a user
  reports a clipped final word, this threshold is the first thing to check.

**Still uncovered.** Nothing skips transcription outright for a clip with no speech-level audio
anywhere; such a clip is still decoded, and the sign-off hallucination is caught downstream by
post-processing rather than prevented.

**The same detector now also picks split points.** `AudioChunker` reuses `AudioEnergyVAD` to find
where to cut a long recording, so the 0.02 threshold above governs both trimming and splitting. A
threshold that treats a noisy room as speech would produce hard cuts at the chunk limit instead of
cuts at pauses — degraded, but not lost audio.

### 4. A transcript consisting only of a hallucination is still inserted

`removeTrailingHallucinatedClosers(from:)` intentionally refuses to strip a closer when nothing
would remain (`guard prefix.isEmpty == false`). Observed on 2026-08-15:

```
selected best transcript from 1 attempts using forcedChinese; raw="谢谢大家"
```

Deleting it would produce an empty transcript. That path is now safe — an empty transcript no
longer touches the clipboard — so the guard could be revisited, but the interaction between the two
behaviours needs to be thought through rather than flipped.

**Direction.** Treat a transcript that is *entirely* a known hallucination as "no speech detected"
and report it as such, instead of inserting the phrase.

### 6. No LLM post-processing

Output is cleaned by regular expressions only. There is no punctuation repair, sentence
segmentation, or spoken-to-written conversion.

**Risk.** This is the largest possible quality gain and the largest change in the product's nature:
a remote model breaks the "everything runs locally" property that the README states, and a local
model adds materially to latency and bundle size. Not a change to make casually.

---

## Open: session behaviour

### 7. No history, no cancel, no streaming

- Only `lastTranscriptPreview` survives, truncated to 120 characters. A transcript that is inserted
  into the wrong place or overwritten cannot be recovered.
- In-progress feedback is now available through the optional bottom-center voice overlay, with
  a waveform driven by microphone levels, processing status, and configurable result duration.
  There is still no elapsed-time display.
- Recording can only be stopped-and-transcribed. There is no way to abandon a session.
- Transcription is batch-only; nothing appears until the whole clip is processed.

**Direction.** These are independent features rather than defects. Cancellation is the cheapest and
probably the most useful of the remaining three.

---

### 11. The local model is not prewarmed when it is only reached through `Auto`

`RoutingTranscriptionEngine.prewarm()` warms the engine the *current* settings resolve to. With
`Engine: macOS Speech` and a single-language recognition mode selected at launch, that is the Apple
engine — but `Auto (中英混说)` overrides the preference and always routes to Qwen3-ASR, so switching
to `Auto` after launch meets a cold model.

Observed on 2026-09-08 with exactly that configuration, on the Whisper engine this issue was first
found against:

```
02:26:24 Routing.prewarm: preparing macOS on-device speech
02:30:25 Routing: Auto mixed ... resolved to bundled Whisper model
02:30:25 WhisperKit: loading validated local model ...
02:30:27 WhisperKit: pipeline loaded successfully
```

Two seconds there, paid once per launch, by a user whose preference says they want the fast engine.
The lazy load is deliberate — the comment on `prewarm()` says a user who stays on macOS Speech
should never pay for a large local model — but it did not anticipate "prefers macOS Speech *and*
uses Auto", which is a normal combination rather than an edge case.

**Worse under Qwen3-ASR, and not yet measured.** The cold path is no longer a two-second model load:
if no model is installed it is a roughly 1 GB download. What that costs on the first `Auto`
dictation needs measuring on the device before this is prioritised.

**Direction.** Warm the local model in the background as well whenever it is reachable from `Auto`,
accepting a second model resident in memory. Alternatively warm it lazily on the first switch to
`Auto` rather than on the first dictation after it.

---

## Open: engineering hygiene

### 9. Test runs write into the real debug log

`AppLogger` resolves a single fixed path (`<temp>/notype-debug.log`) with no injection point, so a
`swift test` run interleaves fixture data — including `clip recorded at /tmp/fake.wav` lines — with
genuine on-device entries. Reading the log by timestamp can therefore surface events that never
happened on the device.

**Direction.** Make the log destination injectable and point tests at a temporary path.

### 10. `AudioSessionError.invalidInputFormat` is never thrown

`DictationCoordinator.startDictation()` catches it and maps it to a specific user-facing error, but
`AudioRecorder` has no path that throws it. A genuine input-format problem currently falls through
to the generic recorder-failure branch.

**Direction.** Either detect the condition in `AudioRecorder` and throw it, or delete the dead
handling so the error surface reflects reality.

---

## Resolved in the same review

Listed only so the open items above are not read as the complete picture.

| Issue | Resolution |
| --- | --- |
| Every dictation ran all three transcription attempts | Attempts stop as soon as a result is conclusive; measured ~5s → ~1s |
| Model loaded lazily on first dictation (~2s stall) | Loaded in the background at launch, with in-flight de-duplication |
| Recorded WAV files were never deleted | Written to a dedicated subdirectory, deleted after use, orphans cleared at launch |
| `like` / `you know` / `i mean` removed unconditionally | Removed only with a pause on both sides, or trailing for the latter two |
| Subtitle sign-off hallucinations survived filtering | Leading-separator requirement dropped and phrase variants covered |
| An empty transcript overwrote the clipboard | Empty transcripts end the session without touching the clipboard |
| Mistriggers and forgotten sessions | Clips under 0.3s skip transcription; recording stops itself after 5 minutes |

---

## Closed by the Qwen3-ASR engine swap

Replacing WhisperKit with the sherpa-onnx Qwen3-ASR 0.6B INT8 offline model deleted the code these
entries described. They are listed by their original numbers so the gaps above are not read as
missing entries.

| Issue | Why it is gone |
| --- | --- |
| 1. Decoder prompt written but never reaches the model | Qwen3-ASR takes one decode per clip. `DecodingOptions`, `promptTokens`, and the prompt text are all removed. |
| 3. Repetition detection only sees adjacent single tokens | `repeatedFragmentPenalty`, `selectBestTranscript`, and `canStopAfterAttempt` scored between multiple Whisper attempts. There is now one attempt. |
| 5. No custom vocabulary | Still true as a *feature* gap, but the hardcoded scoring list it described (`analyzeTranscript`) is gone. sherpa-onnx exposes a `hotwords` field on the Qwen3-ASR config, currently passed as empty — that is where this would now be built. |
| 8. `swift test --filter` breaks the build | Caused by the vendored `Vendor/WhisperKit-main/` checkout being pulled into the build graph. That directory is deleted; `swift test --filter` was verified working on 2026-09-09. |
| 12. Chunked decoding costs some punctuation | **Still open, and it applies again.** Listed here in error: chunking was removed with WhisperKit, then restored as `AudioChunker` on 2026-09-09 because Qwen3-ASR cannot decode past ~30s at all. Chunks are still decoded independently, so the punctuation cost the original entry measured is still paid on recordings over 24s. See [ADR-008](decisions/008-qwen3-asr-replaces-whisper.md). |
