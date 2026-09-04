# ADR-004: Route Each Dictation to the Engine That Can Handle It

## Status

Accepted

## Date

2026-09-04

## Context

macOS 26 exposes the recognizer behind system dictation as `SpeechAnalyzer` and
`SpeechTranscriber`. Unlike system dictation, which types into whatever control
holds focus, the API takes audio in and returns a string, so NoType keeps
deciding where the transcript goes. That makes it a genuine alternative to the
bundled Whisper model rather than a different product.

Measured on the same 10.6s Chinese clip, on this Mac:

| Engine | Wait after speech ends | Compute for the clip |
| --- | --- | --- |
| `SpeechTranscriber` | 0.083s | 0.27s |
| `DictationTranscriber` | 0.35s | 1.40s |
| Bundled Whisper `large-v3_turbo` | — | ~1s (per `docs/known-issues.md`) |

`SpeechTranscriber` also avoids four defects tracked in `docs/known-issues.md`:
it does not translate instead of transcribing (#1), ships its own VAD model (#2),
does not emit subtitle sign-off hallucinations (#4), and reports results
progressively rather than only in a batch (#7).

It has one disqualifying limitation. A transcriber is constructed for exactly one
locale, and `selectedLocales` accepts a single entry — **the engine cannot detect
which language is being spoken.** Whisper can, and that detection is the entire
basis of the `Auto (中英混说)` recognition mode.

This was not theoretical. With the system's preferred language set to `en-CA`,
running a Chinese recording through `Auto` on `SpeechTranscriber` produced:

```
,,,,,,,,,,,,,, Fang Hui, hai, shi, fang Hui, di, wu, shi, fang, Hui, shi.
```

An English model transliterating Chinese into pinyin. Silent, total degradation.

## Decision

Keep both engines and route per dictation, in `TranscriptionEngineChoice.resolvedEngine(for:)`:

- The user picks a preferred engine in the menu bar, persisted across launches.
- `中文优先` and `英文优先` honour that preference.
- **`Auto` always uses Whisper**, whatever the preference says, because only
  Whisper detects the spoken language.
- macOS 15 has no `SpeechAnalyzer`; the choice is disabled and everything uses
  the bundled model.

`RoutingTranscriptionEngine` builds each engine on first use. A user who stays on
macOS Speech never loads the bundled model, which is what makes the fast path
worth having — loading Whisper costs seconds and gigabytes.

The override is stated rather than hidden. When `Auto` overrides the preference
the menu reads `Engine: macOS Speech (fast) → Bundled Whisper`.

## Consequences

- Single-language dictation is roughly an order of magnitude faster on macOS 26,
  and stops translating and hallucinating sign-offs.
- Mixed-language dictation is unchanged, with Whisper's existing trade-offs.
- The app now needs Speech Recognition permission on macOS 26. Recognition is
  still on-device; the permission gates the system recognizer, not a network call.
- Two engines mean two sets of behaviour to keep aligned. One divergence already
  shipped and was corrected: silence made the Apple engine throw, lighting up an
  error state, where the Whisper path reported "nothing to insert" and stayed
  idle. Empty transcripts now mean the same thing on both paths.
- Proper nouns spoken inside another language are transliterated by the locked
  locale — `GitHub` became `Gthob`, `Whisper` became `画师`. `AnalysisContext
  .contextualStrings` accepts a phrase list and is the intended fix; it is not
  implemented yet.

## Alternatives considered

**Replace Whisper entirely.** Rejected: it would delete `Auto`, the default mode,
and drop macOS 15 support.

**Run two `SpeechTranscriber` instances and compare confidence.** Rejected as
speculative — it doubles the work per dictation to reconstruct a capability
Whisper already provides, and does nothing for a sentence that switches language
mid-way, which is exactly the case `Auto` exists for.

**Map `Auto` to the system's preferred language.** This is what the first
implementation did, and it produced the pinyin transcript above.
