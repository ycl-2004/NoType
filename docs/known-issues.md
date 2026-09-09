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

### 1. Decoder prompt is written but never reaches the model

`WhisperKitTranscriptionEngine.makeDecodingOptions(for:tokenizer:)` hardcodes `promptTokens: nil`.
`promptText(for:)` and `encodedPromptTokens(for:tokenizer:)` exist and are unit-tested, but no
production path calls them, and `makeDecodingOptions` accepts a `tokenizer` argument it never uses.
The current tests assert `promptTokens == nil`, so the gap is locked in rather than flagged.

The consequence is that the "do not translate" instruction never reaches the decoder. Observed in
the debug log on 2026-08-15:

```
attempt forcedEnglish raw result: Ok ok, now you're good.
```

The speaker had said 「OK OK 现在好吗」. The model translated instead of transcribing.

**Direction.** Two separate changes are needed, and doing only the first is not worth much:

1. Pass encoded prompt tokens through `DecodingOptions`.
2. Rewrite the prompt text itself. WhisperKit injects prompts as
   `[<|startofprev|>] + promptTokens + prefillTokens` (`TextDecoder.swift`), meaning Whisper reads
   the prompt as *the previously transcribed passage*, not as an instruction. Imperative phrasing
   ("Do not translate. 不要翻译。") is therefore close to inert. What works is an **exemplar**: a
   short sample of the desired output style, e.g. a sentence that naturally code-switches and
   contains the proper nouns the user says often.

**Risks — this is the one change that can make things worse.**

- Supplying `promptTokens` **disables the prefill KV cache** (`TextDecoder.swift`, guarded by
  `options?.promptTokens == nil`). Transcription latency was recently reduced from ~5s to ~1s, and
  some of that would be given back. The cost must be measured, not assumed.
- A badly written prompt actively degrades output, because the model continues the *style* of what
  it believes it just transcribed.
- The effect cannot be verified by unit tests. It needs real-device A/B against recorded samples,
  and the change should be prepared for rollback.

### 2. Voice-activity detection is only used to trim the tail

The silent-tail case described here is now handled. `TrailingSilenceTrimmer` runs WhisperKit's
`EnergyVAD` over the clip and drops everything after the last frame with speech in it, keeping 0.5s
of padding and only acting when at least 1.0s would be removed. Verified on a 34.3s recording
ending in 6s of silence: 5.50s trimmed, 28.8s transcribed, same transcript, and the clip stayed
inside one 30s window instead of spilling into a second.

Three deliberate limits remain:

- **Only the tail.** Trimming the head or the middle risks clipping real speech, and "I spoke and
  nothing happened" is a worse failure than a stray closing phrase.
- **A clip the detector cannot hear is passed through untouched**, not discarded. Quiet speech
  still reaches the model; genuine silence is already handled by the empty-transcript path.
- **The 0.02 energy threshold is `EnergyVAD`'s default and has been validated against digital
  silence only.** Whether it treats a real noisy room as silence is not yet measured. If a user
  reports a clipped final word, this threshold is the first thing to check.

**Still uncovered.** Nothing skips transcription outright for a clip with no speech-level audio
anywhere; such a clip is still decoded, and the sign-off hallucination is caught downstream by
post-processing rather than prevented.

### 3. Repetition detection only sees adjacent single tokens

`repeatedFragmentPenalty(in:)` compares neighbouring whitespace-separated tokens, so `so so so so`
scores but `thank you thank you thank you` scores zero — phrase-level looping, the more typical
shape of a Whisper decode loop, is invisible.

This penalty feeds two places: candidate scoring in `selectBestTranscript`, and the looping guard
in `canStopAfterAttempt`. A missed loop can therefore both win selection and be accepted as
conclusive.

**Direction.** Extend detection to repeated n-grams, not just repeated unigrams.

**Risk.** The function is part of scoring, so changing its output shifts which candidate wins in
mixed mode. The existing selection tests are the guard rail and must keep passing.

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

### 5. No custom vocabulary

Proper nouns and technical terms the user says regularly have no way to be corrected. A hardcoded
list (`slack`, `figma`, `notion`, `github`, `zoom`, `amy`) exists in `analyzeTranscript`, but it
only contributes to *scoring* — it never repairs a misrecognised term.

**Direction.** A user-editable term list, applied in two places: seeded into the decoder prompt
(depends on item 1) and used for post-hoc replacement.

### 6. No LLM post-processing

Output is cleaned by regular expressions only. There is no punctuation repair, sentence
segmentation, or spoken-to-written conversion.

**Risk.** This is the largest possible quality gain and the largest change in the product's nature:
a remote model breaks the "everything runs locally" property that the README states, and a local
model adds materially to latency and bundle size. Not a change to make casually.

### 12. Chunked decoding costs some punctuation

`chunkingStrategy: .vad` decodes each chunk independently, so the decoder loses the preceding text
it would otherwise be conditioned on. Measured across an 11-clip A/B on 2026-09-08:

| Clip | Similarity | What differed |
| --- | --- | --- |
| Nine clips up to 28s | identical | nothing |
| 85s | 97.8% | punctuation, and one 他们/它们 |
| 154s | 98.5% | punctuation only — about 13 fewer commas in 667 characters |

No word or character content was lost at any length. The stray spaces this also introduced are
fixed in `TranscriptPostProcessor`; the missing commas are not, and are the standing cost of the
8–20% speed-up on clips over 30s.

**Direction.** If punctuation matters more than the speed-up, `chunkingStrategy` back to `.none` is
a one-line change. A better fix would seed each chunk with the tail of the previous chunk's
transcript as `promptTokens`, which collides with issue #1 and its prefill-cache cost.

---

## Open: session behaviour

### 7. No history, no in-progress feedback, no cancel, no streaming

- Only `lastTranscriptPreview` survives, truncated to 120 characters. A transcript that is inserted
  into the wrong place or overwritten cannot be recovered.
- While recording there is no level meter, waveform, or elapsed time, so there is no confirmation
  that audio is being captured.
- Recording can only be stopped-and-transcribed. There is no way to abandon a session.
- Transcription is batch-only; nothing appears until the whole clip is processed.

**Direction.** These are independent features rather than defects. Cancellation is the cheapest and
probably the most useful of the four.

---

### 11. Whisper is not prewarmed when it is only reached through `Auto`

`RoutingTranscriptionEngine.prewarm()` warms the engine the *current* settings resolve to. With
`Engine: macOS Speech` and a single-language recognition mode selected at launch, that is the Apple
engine — but `Auto (中英混说)` overrides the preference and always routes to Whisper, so switching to
`Auto` after launch meets a cold model.

Observed on 2026-09-08 with exactly that configuration:

```
02:26:24 Routing.prewarm: preparing macOS on-device speech
02:30:25 Routing: Auto mixed ... resolved to bundled Whisper model
02:30:25 WhisperKit: loading validated local model ...
02:30:27 WhisperKit: pipeline loaded successfully
```

Two seconds, paid once per launch, by a user whose preference says they want the fast engine. The
lazy load is deliberate — the comment on `prewarm()` says a user who stays on macOS Speech should
never pay for the bundled model — but it did not anticipate "prefers macOS Speech *and* uses Auto",
which is a normal combination rather than an edge case.

**Direction.** Warm Whisper in the background as well whenever the app is reachable from `Auto`,
accepting a second model resident in memory. Alternatively warm it lazily on the first switch to
`Auto` rather than on the first dictation after it.

---

## Open: engineering hygiene

### 8. `swift test --filter` breaks the build

Running `swift test --filter <name>` creates a separate `.build` directory under
`Vendor/WhisperKit-main/` and pulls the vendored test targets into the build graph. Those targets
do not compile (`Bundle.module` is inaccessible from them), so the whole suite then fails with
`error: fatalError` — including subsequent unfiltered runs.

**Recovery.** `rm -rf Vendor/WhisperKit-main/.build`, then run `swift test` with no filter.

**Direction.** Until this is addressed, run the suite unfiltered. Filtering by test name is not
usable in this repository.

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
