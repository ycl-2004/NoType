# ADR-003: Surface the Actual Local Model Readiness Lifecycle

## Status

Accepted

## Date

2026-08-16

## Context

NoType preloads its bundled WhisperKit/Core ML model after launch. A cached load
can complete in about a second, but first-time Core ML specialization can take
one or two minutes. Previously the only observable evidence was a debug-log line,
`WhisperKit: pipeline loaded successfully`. A first-time user could therefore
assume the app was stuck or repeatedly restart it, interrupting specialization
and leaving large temporary Core ML cache directories behind.

Core ML does not expose a reliable percentage for all model-loading and device-
specialization stages. A synthetic progress bar would imply precision that the
app does not have.

## Decision

Track a small readiness state machine in application state:

- **Waiting** before background preparation starts.
- **Preparing** while WhisperKit is validating or loading the pipeline.
- **Ready** only after the pipeline instance has loaded successfully.
- **Failed** with the actual validation or loading reason.

The WhisperKit engine publishes lifecycle changes from the same `loadPipeline()`
path used by both launch prewarming and real transcription. Diagnostics renders
the state with a native symbol, plain-language first-launch guidance, and a retry
action after failure. The normal top-level menu remains compact.

Do not show a percentage. “Preparing” is an honest indeterminate state until
WhisperKit returns a loaded pipeline.

## Alternatives Considered

### Parse the debug log in the menu

The exact success line exists, but log parsing duplicates internal state and can
lag, fail after log rotation, or report a previous process. Publishing lifecycle
events directly is simpler and authoritative.

### Show an estimated percentage or countdown

Core ML specialization duration varies by model cache, OS version, hardware, and
compute configuration. No stable progress signal exists for every stage, so an
estimate would frequently jump or be wrong.

### Put model status in the top-level menu

That would make first launch more visible but permanently adds noise after the
model is ready. The existing Diagnostics submenu is the appropriate place for a
state users inspect only when setup or transcription is uncertain.

## Consequences

- Users can distinguish a long first preparation from a failure without opening
  the log.
- Failed preparation remains visible and actionable instead of being overwritten
  by an unconditional “ready” message.
- Alternate transcription engines that do not publish lifecycle events are
  treated as ready when their best-effort `prewarm()` call returns.
- Completed Core ML caches remain system-managed. NoType does not delete valid
  caches; macOS may invalidate or evict them after model, configuration, OS, or
  storage changes.
- A normal app or Mac restart can reuse a completed cache, but replacing the app
  bundle may create a new cache identity and require one fresh specialization.

## References

- [Apple: Improve Core ML integration with async prediction](https://developer.apple.com/videos/play/wwdc2023/10049/?time=429)
- [Apple: MLModel](https://developer.apple.com/documentation/coreml/mlmodel)
