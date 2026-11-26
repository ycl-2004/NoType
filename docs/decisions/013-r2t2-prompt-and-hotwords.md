# ADR-013: R2T2 prompt template and hotword list

## Status

Accepted — 2026-11-26.

## Context

NoType sent R2T2 the prompt `<|im_start|>user\n<__media__>Transcribe audio to text.<|im_end|>`.
R2T2's chat template (Qwen3-ASR's, from the model card's `chat_template.json`) renders context such
as hotwords in the system turn, renders only audio in the user turn, and forces a language by
pre-filling `language X<asr_text>` in the assistant turn. The instruction text sat where the model
was never trained to read text.

Real dictations misheard names and technical terms: Ghostty → ghosty, Claude Code → cloudcall,
千问 → 全文, R2T2 → r two t two, LLM → like. A Q8_0 model made the same errors (known-issues #5).

## Decision

- Build the prompt as the template does: system turn with the hotword context (empty when there is
  none), user turn with only the audio marker, and `language Chinese<asr_text>` or
  `language English<asr_text>` pre-filled for the forced modes. `Auto` pre-fills nothing.
- Read hotwords from `~/Library/Application Support/NoType/hotwords.txt`, one term per line, `#`
  comments ignored, at the start of each dictation. **Engine → Edit Hotwords…** creates the file
  with brief instructions if missing and opens it. The app ships no terms.
- Send the terms under a 「热词：」 header, one per line, capped at 1,000 characters because every
  decode, including each live preview, carries them.

## Measurement

Five passages read aloud (8–23 s, 388 reference characters, punctuation and case ignored), decoded
offline through NoType's segment decoder and post-processor with Q4_K_M, best of two runs. Terms:
Ghostty, Claude Code, Codex, Grok, R2T2, parser, NoType, 千问, Qwen, LLM, 语义清洗, HTML, DMA.

| Prompt | CER | Time, all 5 | Passage 2 |
| --- | --- | --- | --- |
| Previous (user-turn instruction) | 4.4% | 6.44 s | ghosty, cloudcall |
| Template, no hotwords | 4.1% | 6.52 s | ghosty, cloudcode |
| Template, terms on one comma-separated line | 4.1% | 6.92 s | ghosty, cloud code |
| **Template, 「热词：」 + one term per line** | **3.6%** | 7.28 s | **ghostty**, claud code |
| Explicit `<|audio_start|>` markers, no hotwords | 3.6% | 6.62 s | ghosty, cloudcode |
| Explicit markers + one term per line | 3.6% | 6.92 s | ghostty, claud code |

The chosen layout also restored DMA and CPU capitalisation. It did not fix parser → parse or
NoType → no type, and it inserted no listed term into passages that lacked one. Explicit audio
markers changed results only within noise; whether mtmd already adds them was not checked, so the
prompt keeps the bare marker that has always worked.

### Forced Chinese mode

The same five passages with the same hotwords, 中文优先 (`language Chinese<asr_text>` pre-filled)
against Auto:

| Mode | CER | CER with case | Time, all 5 |
| --- | --- | --- | --- |
| Auto (中英混说) | 3.6% | 8.5% | 8.13 s |
| 中文优先 | 3.4% | 3.6% | 7.36 s |

With the language fixed, the hotwords took effect: Ghostty, Claude Code, NoType, HTML, Q4, Q8 and
GB came out exactly as listed. The pure English passage was identical in both modes, and English
words inside Chinese sentences were not translated. English mode on Chinese speech also returned
Chinese rather than a translation. parser still came out as Parse.

## Consequences

- Gains are real but small: terms whose pronunciation is distinctive improve; terms that sound like
  ordinary words do not.
- Every decode spends a few dozen extra prompt tokens on the list; measured cost was about 5%.
- A long or common-word list could bias output; the file's header says so, and the cap bounds it.
- The forced-language modes now use the template's language prefix instead of an English
  instruction. For a speaker who mostly speaks Chinese with English terms, 中文优先 recognised
  the hotwords far better than Auto on this sample; five passages from one speaker are not a
  general result.
