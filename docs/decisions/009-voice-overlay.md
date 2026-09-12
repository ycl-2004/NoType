# ADR-009: Optional voice overlay with independent result timing

## Status

Accepted — 2026-09-11

## Context

The menu icon is easy to miss while speaking. The user approved a small dark capsule at the
bottom center, with a thin blue border, real audio response, and status text shorter than five
characters. They subsequently requested configurable result duration and clarified that recording
must appear immediately, with no appearance-delay control.

## Decision

Use a 160 × 40 pt SwiftUI capsule hosted in an AppKit nonactivating NSPanel. Position it 20 pt
above the starting screen's visible bottom edge, so a visible Dock is respected. Keep that screen
for the session; recompute placement when display parameters change. The panel joins Spaces and
full-screen apps, cannot become key or main, and passes mouse input through.

`VoiceOverlayStatus` is separate from `DictationState`: the coordinator becomes idle as soon as
delivery finishes, while a transient result remains readable. The actual outcome selects
`已插入` or `已复制`, including the existing changed-target clipboard fallback. Failure text is
brief; the menu retains the detailed error. Combined copy-and-insert uses `已插入` on success.
The paste fallback still reports success when its existing event-posting operation completes;
this feature does not add target-app acknowledgement of a simulated paste.

Enable `AVAudioRecorder` metering only while the overlay is enabled and recording. Refresh before
reading average dBFS, normalize -55…0 dBFS into 0…1, and publish the last five samples at 20 Hz.
Serialize recorder operations on its actor. Meter samples bypass the menu refresh callback.
Reduced Motion uses a static icon and removes waveform/fade animation.

Persist a master visibility switch and separate completion/failure durations. Let the user enter
any value from 0 to 5 seconds, with 1.5 seconds as both defaults. Zero suppresses only the selected category.
The neutral `未听清` result uses completion timing. Recording, transcription, insertion, and
copying have no timeout; they follow actual work. Durations include the final 180 ms fade.
Updating a duration uses elapsed time from the original result; starting new work cancels old
dismissal tasks. Results expire while disabled, so re-enabling cannot revive stale feedback.

## Trade-offs

The display is chosen from the pointer location when recording starts, which also supports starting
from the menu on a secondary display. It stays put while speaking. It is intentionally not draggable.
The waveform gate is visual only and never filters recorded audio. Timing and feedback preferences
affect presentation only, preserving existing text delivery and clipboard behavior.

## References

- [Apple: nonactivatingPanel](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel)
- [Apple: ignoresMouseEvents](https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents)
- [Apple: fullScreenAuxiliary](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreenauxiliary)
- [Apple: updateMeters](https://developer.apple.com/documentation/avfaudio/avaudiorecorder/updatemeters())
- [Apple: isMeteringEnabled](https://developer.apple.com/documentation/avfaudio/avaudiorecorder/ismeteringenabled)
- [Apple: accessibilityReduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion)
