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
under R2T2 the saving is simply the decode time the silent tail would have cost. Only R2T2's
non-streaming path trims: a streamed dictation, the normal case, decodes its silent tail.

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

### 5. No custom vocabulary

Names and technical terms are often misheard (「千问」, "LLM", "HTML" in real dictations on
2026-11-26). The R2T2 model card documents context and hotword hints, passed as system-turn text;
NoType passes none. NoType also writes its instruction ("Transcribe audio to text.") into the user
turn, which R2T2's chat template does not render, so the model was never trained with text there.

**A higher-precision model is not the fix (measured 2026-11-26).** Five passages read aloud by the
user (8–23 s, Voice Memos, converted to 16 kHz mono), decoded offline through NoType's segment
decoder and post-processor, best of two runs:

| Model | CER (388 chars, punctuation ignored) | Decode time, all 5 |
| --- | --- | --- |
| Q4_K_M (in use) | 4.4% (17) | 6.44 s |
| Q8_0 | 3.9% (15) | 7.83 s |

The two-character gap is noise (Q8 gained on one clip and inserted a word in another), Q8 is about
20% slower and needs about 0.7 GB more memory, so NoType stays on Q4_K_M. Both models made the same
errors, and they are vocabulary errors: Ghostty → ghosty, Claude Code → cloudcall / cloudcode,
parser → parse, NoType → no type, 远场 → 原厂.

Reference texts, kept so the same recordings can judge a vocabulary change:

1. 今天下午三点我们要跟产品团队开会，主要讨论下个月的上线计划，还有用户反馈里提到的几个问题。
2. 我刚刚在 Ghostty 里面用 Claude Code 跑了一下测试，有两个 test 失败了，都是 HTML 解析的问题，你帮我看一下是不是 parser 的 bug。
3. 操作系统这一章主要讲 DMA、中断和虚拟内存，DMA 的作用是让外设直接访问内存，不需要 CPU 一个字节一个字节地搬数据。
4. Can you check whether the API returns a 404 when the token expires, and if so, add a retry with exponential backoff.
5. 我想把 NoType 的识别模型从 Q4 换成 Q8 试试看，因为社区有人测过，Q8 在远场的准确率比 Q4 高不少，而且速度差不多。不过 Q8 的文件大概一点八 GB，内存会多占零点七 GB 左右，所以我想先用几段固定的录音做对比，看看错字率到底差多少，再决定要不要换。如果差别不大，我们就继续用 Q4，省一点内存。

The recordings are the user's and are not in the repository.

**Direction.** Move the instruction out of the user turn and add a user vocabulary as system-turn
context, then compare against real recordings, such as the five above, before keeping either change.

### 6. No LLM post-processing

Output is cleaned by regular expressions only. There is no punctuation repair, sentence
segmentation, or spoken-to-written conversion.

**Risk.** This is the largest possible quality gain and the largest change in the product's nature:
a remote model breaks the "everything runs locally" property that the README states, and a local
model adds materially to latency and bundle size. Not a change to make casually.

**Apple's on-device model is not good enough (tested 2026-11-26).** The Foundation Models system
model is available on the development Mac and supports Simplified Chinese, so it costs no download
and no NoType memory. On 7 real dictations (20–487 characters), greedy decoding, three prompts:
a plain rule list removed a meaningful opening sentence and changed what 「把它去掉」 referred to; a
"never change meaning" list kept content but left most 然后 and repeats in long dictations; adding
three worked examples improved short inputs only. Every prompt turned 「做做看」 into 「做看」.
Cleanup ran at roughly 60 characters per second (0.7 s for 20 characters, 8 s for 487), on top of
the R2T2 stop latency. Dedicated dictation-cleanup models found at the same time (S1-mini,
Superflow, Rillo, SpeakoFlow Mini) are English-only; Spokenly Cleanup 1 lists Chinese at lower
quality. Cleanup is not being pursued until a Chinese-capable option is cheap in memory and latency.

---

## Open: session behaviour

### 7. No history

- Only `lastTranscriptPreview` survives, truncated to 120 characters. A transcript that is inserted
  into the wrong place or overwritten cannot be recovered.
- In-progress feedback is available through the optional bottom-center voice overlay, with
  a waveform driven by microphone levels, processing status, and configurable result duration.
  R2T2 can also show its newest in-progress text there, but there is no elapsed-time display.
- A session can be abandoned with Esc while recording or transcribing. R2T2 stops at its next
  cancellation check. Whether macOS Speech stops early has not been checked; if it finishes its
  decode, the result is discarded, and the next dictation can start once that decode returns.

**Direction.** History is an independent feature rather than a defect. R2T2 deliberately keeps live
text out of the focused field; all engines still finalize through the same output pipeline.

---

### 11. The local model is not prewarmed when it is only reached through `Auto`

`RoutingTranscriptionEngine.prewarm()` warms the engine the *current* settings resolve to. With
`Engine: macOS Speech` and a single-language recognition mode selected at launch, that is the Apple
engine — but `Auto (中英混说)` overrides the preference and always routes to R2T2, so switching
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

**Not yet measured under R2T2.** The cold path is a model load of unmeasured length, or a roughly
1.5 GB download if the model is not installed. What that costs on the first `Auto` dictation needs
measuring on the device before this is prioritised.

**Direction.** Warm the local model in the background as well whenever it is reachable from `Auto`,
accepting a second model resident in memory. Alternatively warm it lazily on the first switch to
`Auto` rather than on the first dictation after it.

---

### 12. Segment cuts cost some punctuation

Recordings over 24 seconds are decoded as independent segments (`AudioChunker`), so a segment
cannot see the text that follows it. In an 86s dictation on 2026-11-26 all three cuts landed
mid-sentence and each produced a full stop plus a stray space. `TranscriptSegmentJoiner` now turns a
closing `。` at a cut into `，` and removes the space; a real sentence end at a cut becomes a comma.
The 24s limit was measured on Qwen3-ASR 0.6B (ADR-008) and has not been measured on R2T2; a longer
limit would mean fewer cuts.

---

## Open: engineering hygiene

### Resolved on 2026-09-22: logging and streaming input errors

Tests now use process-specific diagnostic logs. Production logs are capped at 2 MiB and scanned
at most hourly unless size pressure requires maintenance. The streaming recorder validates input
format and propagates capture/write errors on stop, deleting incomplete audio and preventing its
insertion. See [ADR-011](decisions/011-r2t2-resource-and-reliability.md).

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
entries described; Qwen3-ASR was later removed in turn (ADR-012). Open items 5 and 12 above keep
their original numbers.

| Issue | Why it is gone |
| --- | --- |
| 1. Decoder prompt written but never reaches the model | Qwen3-ASR takes one decode per clip. `DecodingOptions`, `promptTokens`, and the prompt text are all removed. |
| 3. Repetition detection only sees adjacent single tokens | `repeatedFragmentPenalty`, `selectBestTranscript`, and `canStopAfterAttempt` scored between multiple Whisper attempts. There is now one attempt. |
| 8. `swift test --filter` breaks the build | Caused by the vendored `Vendor/WhisperKit-main/` checkout being pulled into the build graph. That directory is deleted; `swift test --filter` was verified working on 2026-09-09. |
