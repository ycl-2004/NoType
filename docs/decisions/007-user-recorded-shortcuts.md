# ADR-007: User-Recorded Shortcuts

## Status

Accepted

## Date

2026-09-09

## Context

The first shortcut configuration exposed a short list of fixed combinations. That list could not cover different keyboard layouts, left/right modifier preferences, regular-key combinations, or users who wanted more than one way to start the same action. Recognition-mode cycling also needed to be optional because it can be accidental when enabled by default.

## Decision

Store an ordered array of shortcut bindings for dictation and another for recognition-mode cycling. A binding contains:

- a regular key, optionally with Command, Option, Control, Shift, or Fn;
- a modifier by itself, such as Command or Left Option; and
- single-press or double-press activation.

Record modifier side identity from AppKit `flagsChanged` events. Generic modifiers remain available for the default Double Command binding and match either physical side; a recorded Left Command and Right Command are separate bindings. Reject duplicate or overlapping gestures when adding a shortcut, including a generic modifier that would overlap a side-specific version.

Use AppKit local and global event monitors for both regular-key and modifier-only bindings. This is required for Fn and for retaining left/right identity. Double presses are recognized within a short time window and are cancelled by another key or mouse press. The existing dictation and recognition-mode actions remain the callbacks; shortcut handling does not change transcription or insertion.

Dictation starts with exactly one binding: Double Command. Recognition-mode shortcuts start empty. Existing fixed shortcut preferences are ignored so a previous preset cannot silently re-enable a shortcut that is now meant to be off. Users can add, remove, or disable all bindings independently from the menu bar.

Warn before accepting a regular key without a modifier because it can interfere with typing in another app. Allow it after the user explicitly chooses **Use Anyway**.

## Consequences

- The menu bar supports the user’s actual keyboard instead of a fixed preset list.
- Multiple shortcuts can invoke the same action, and both actions can be disabled independently.
- Shortcut monitoring uses the Accessibility permission already required for global input and text insertion.
- AppKit event monitoring has a larger input surface than Carbon hotkey registration, so the monitor cancels pending double presses when unrelated keyboard or mouse input occurs.

## Sources

- [Apple NSEvent documentation](https://developer.apple.com/documentation/appkit/nsevent)
- [Apple modifier flags](https://developer.apple.com/documentation/appkit/nsevent/modifierflags-swift.struct)
- [Apple keyCode](https://developer.apple.com/documentation/appkit/nsevent/keycode)
