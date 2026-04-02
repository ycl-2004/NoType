# Menu Bar Mode Visibility Design

**Date:** 2026-04-02
**Status:** Approved in brainstorming
**Goal:** Make the current recognition mode and Chinese script preference visible from the menu bar icon without forcing the user to open the menu.

## Problem

The current menu bar presentation makes recording state obvious, but it does not make configuration state obvious.

Today the user can quickly tell when noType is recording because the icon switches to a strong highlighted state. However, the user cannot tell at a glance:

- whether dictation is currently in `Auto`, `中文优先`, or `英文优先`
- whether Chinese output is set to `简体` or `繁體`

That means users must repeatedly open the menu to confirm settings before speaking. This creates avoidable friction and makes mistakes feel arbitrary when the output script or recognition mode is not what the user expected.

## User Experience Goals

The menu bar icon should communicate two things clearly:

1. whether dictation is currently active
2. what recognition mode is currently selected

When Chinese output is relevant, it should also communicate the current script preference.

The design should stay compact and quiet enough for the macOS menu bar:

- no large text labels in the menu bar
- no wide status item that pushes other icons around
- no extra bright or colorful badges during recording
- no visual treatment that competes with the recording highlight

## Approved Direction

Use a single compact microphone icon with lightweight corner markers.

### Primary Icon

The main icon remains the microphone-based status symbol that already exists.

It continues to carry the global operational state:

- idle: standard microphone
- recording: current highlighted recording state
- transcribing: waveform
- inserting: arrow-style progress state
- error: error symbol

This preserves the strongest existing affordance in the product: recording is immediately obvious.

### Top-Right Marker: Recognition Mode

Add a small, restrained marker in the top-right corner of the icon area:

- `A` for `Auto`
- `中` for `中文优先`
- `EN` for `英文优先`

This marker answers the most important pre-dictation question: what recognition mode am I about to use?

The marker should be:

- small
- monochrome
- readable but not bold
- aligned consistently regardless of mode

The marker does not replace the microphone. It supplements it.

### Bottom-Right Marker: Chinese Script Preference

Show a second lightweight marker in the bottom-right corner only when Chinese script output matters.

Use:

- `简` for Simplified Chinese
- `繁` for Traditional Chinese

Visibility rules:

- show for `Auto`
- show for `中文优先`
- hide for `英文优先`

Reasoning:

- `Auto` can still output Chinese, so script preference matters there
- `中文优先` obviously needs script visibility
- `英文优先` does not need extra script noise in the common case

This keeps the icon informative without turning it into a dense dashboard.

## Recording-State Behavior

Do not add extra badge emphasis during recording.

The current highlighted recording state is already strong enough. Additional badge brightening, colored chips, or larger overlays would make the icon feel crowded and visually noisy.

Approved behavior:

- keep the current strong recording highlight
- keep the corner markers visible
- do not enlarge or recolor the markers just because recording started

This preserves a clean hierarchy:

- main icon color/state = "the app is recording"
- small corner markers = "the app is configured this way"

## Visual Style

The icon treatment should feel minimal and native to macOS:

- compact square footprint
- grayscale or template-style markers in idle states
- subtle contrast choices that still survive menu bar translucency
- no extra borders unless required for legibility
- no colored script/mode chips

The visual impression should be:

- informative
- calm
- professional
- immediately scannable

## Recommended Implementation Approach

Render a composed icon image programmatically instead of switching between a large number of static asset files.

Recommended structure:

1. start with the existing SF Symbol base icon for each app state
2. draw the top-right mode marker using a very small text glyph
3. conditionally draw the bottom-right script marker
4. keep marker placement and sizing centralized in one icon composition helper

This is preferable to pre-rendered assets because:

- the state space is already combinatorial
- text markers are easy to update centrally
- layout tuning will likely require iteration
- dynamic rendering adapts better to different symbol states

## Component Design

Introduce a dedicated menu bar icon presenter or renderer responsible for:

- mapping app state to base symbol
- mapping recognition language to top-right marker
- mapping script preference to optional bottom-right marker
- generating the final `NSImage`

Keep this logic out of the broader menu-building function so menu rendering and icon rendering stay separate.

## Accessibility and Fallbacks

The button tooltip should continue to expose readable status text for users who rely on hover text.

If marker rendering ever fails, the system should gracefully fall back to the base status icon instead of blocking the menu bar item from rendering.

## Non-Goals

This design does not include:

- a wide text label in the menu bar
- showing the full words `Auto`, `Chinese`, `English`, `Simplified`, or `Traditional`
- a new preferences window
- animated badges
- colored mode markers

## Success Criteria

The design is successful if a user can glance at the menu bar and answer, without opening the menu:

- am I in `Auto`, `中文优先`, or `英文优先`?
- if Chinese matters, am I using `简体` or `繁體`?
- is the app idle, recording, transcribing, inserting, or in error?

The menu should still exist for changing settings, but it should no longer be required for constant mode confirmation.
