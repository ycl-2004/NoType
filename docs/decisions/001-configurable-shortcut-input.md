# ADR-001: Configurable Shortcut Input Without Changing Dictation

## Status

Accepted

## Date

2026-08-13

## Context

NoType originally registered two fixed Carbon hotkeys:

- Command-Shift-H toggled dictation.
- Command-Shift-Y cycled recognition mode.

Fixed global shortcuts are easy to implement, but they can collide with other applications and do not support a low-friction modifier double tap. The menu also exposed transcript previews, debug messages, and the full log path at its top level, making a frequently opened control surface unnecessarily noisy.

The dictation pipeline is already stable and must remain independent from this work. Shortcut configuration should only decide when to call the existing `DictationCoordinator.toggleDictation()` method.

## Decision

Use two independent persisted shortcut choices:

- Dictation defaults to `Double Command` and can be changed to `Double Option`, the legacy Command-Shift-H combination, or `Disabled`.
- Recognition-mode cycling defaults to Command-Shift-Y and can be changed to Command-Option-Y, Control-Option-Y, or `Disabled`.

Use AppKit local and global event monitors for double modifier taps. The detector cancels a pending tap sequence when another keyboard or mouse input occurs, which prevents ordinary Command-based shortcuts from being interpreted as dictation taps. Continue using Carbon hotkey registration for ordinary key combinations.

Both shortcut categories unregister and re-register independently when their selection changes. A disabled choice registers nothing. Existing boolean preferences migrate by preserving enabled versus disabled state; an enabled legacy dictation shortcut migrates to the new Double Command default.

Keep the main menu focused on current status and user actions. Do not render the transcript preview there. Move the last debug event and log access into a `Diagnostics` submenu.

## Alternatives Considered

### Arbitrary shortcut recorder

This offers maximum flexibility but requires a separate capture UI, validation, conflict presentation, and serialization of arbitrary key codes. It is more interface and failure surface than the current menu-bar utility needs. Curated choices plus an explicit Disabled option solve the known conflicts with less complexity.

### Replace all shortcut handling with event monitors

Event monitors can observe arbitrary key input, but Carbon hotkeys already provide reliable system-wide delivery for modifier-plus-key combinations. Keeping Carbon for those combinations limits the new event-monitor surface to the modifier double-tap behavior that requires it.

### Remove diagnostics entirely

This would make the menu shortest but would slow down local testing and troubleshooting. A Diagnostics submenu keeps the information available without placing it in the normal scan path.

## Consequences

- Double Command remains observable rather than suppressing Command events, so normal application shortcuts continue to work.
- System-wide event monitoring relies on the Accessibility permission NoType already uses for text insertion.
- Curated choices are intentionally less flexible than arbitrary recording; add a recorder later only if real usage shows the presets and Disabled option are insufficient.
- Audio recording, WhisperKit loading, candidate transcription, post-processing, and insertion behavior are unchanged.

## Sources

- Apple AppKit local event monitors: https://developer.apple.com/documentation/appkit/nsevent/addlocalmonitorforevents%28matching%3Ahandler%3A%29
- Apple AppKit global event monitors: https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents%28matching%3Ahandler%3A%29
- Apple AppKit modifier-change events: https://developer.apple.com/documentation/appkit/nsevent/eventtype/flagschanged
