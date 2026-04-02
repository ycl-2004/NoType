# Shortcut Management Design

**Date:** 2026-04-02
**Status:** Approved in brainstorming
**Goal:** Let users quickly control shortcut behavior from the menu bar by managing the dictation shortcut and recognition-mode shortcut independently.

## Problem

The app is evolving from a single global shortcut into a small shortcut system:

- `Command + Shift + H` for starting and stopping dictation
- `Command + Shift + Y` for cycling recognition mode

Once there are multiple global shortcuts, users need control. A heavy user may want both enabled all the time. Another user may want only dictation enabled and recognition-mode switching disabled to avoid collisions or accidental mode changes.

The current menu only exposes a static line showing the dictation shortcut. That line is informative, but it is not actionable and it does not scale to multiple shortcuts.

## User Experience Goals

The shortcut experience should feel:

- fast
- obvious
- low-friction
- consistent with the rest of the menu structure

The user should be able to answer these questions quickly:

1. which shortcuts exist?
2. are they currently enabled?
3. can I toggle them without leaving the menu?

## Approved Scope

This is a first-phase shortcut management feature.

It should include:

- two shortcuts
  - dictation shortcut
  - recognition-mode shortcut
- independent enable / disable control for each
- a dedicated `Shortcuts` submenu in the menu bar

It should not include:

- custom key recording
- arbitrary shortcut remapping
- conflict detection UI
- preferences window

Those can be future phases if needed.

## Menu Structure

Replace the current static shortcut display line with a submenu:

- `Shortcuts >`

Inside that submenu, show two direct action rows:

- `Dictation Shortcut: Command + Shift + H`
- `Recognition Mode Shortcut: Command + Shift + Y`

Each row is directly clickable and toggles the enabled state of that shortcut.

This matches the user's preferred interaction model:

- no extra nested submenu per shortcut
- no separate `Enabled` row under each shortcut
- the row itself acts as the control

## Disabled-State Presentation

When a shortcut is disabled, its row should show `Disabled` instead of the key combination.

Examples:

- enabled: `Dictation Shortcut: Command + Shift + H`
- disabled: `Dictation Shortcut: Disabled`

- enabled: `Recognition Mode Shortcut: Command + Shift + Y`
- disabled: `Recognition Mode Shortcut: Disabled`

This is clearer than simply removing a checkmark while still showing the key. The user can understand the active state in one glance without interpretation.

## State Signaling

Each shortcut row should also use standard macOS menu item state:

- checked when enabled
- unchecked when disabled

This creates two reinforcing signals:

- the title text says whether the shortcut is active or disabled
- the menu checkmark confirms the current state

## Interaction Model

Behavior when the user clicks a shortcut row:

1. toggle the enabled state
2. persist the new state
3. immediately register or unregister the matching global hotkey
4. update the menu text and checkmark
5. optionally update the debug/status message for quick confirmation

The change should be immediate. The user should not need to relaunch the app.

## Shortcut Definitions

Phase one assumes fixed key combinations:

- Dictation shortcut: `Command + Shift + H`
- Recognition-mode shortcut: `Command + Shift + Y`

These are visible in the menu when enabled.

The recognition-mode shortcut cycles:

- `Auto -> 中文优先 -> 英文优先 -> Auto`

The menu bar mode marker system added earlier provides immediate visual confirmation after each cycle.

## Information Architecture Recommendation

Keep shortcut management close to the other frequently used controls:

- `Recognition`
- `Chinese Script`
- `Success Status`
- `Shortcuts`
- `Permissions`

This keeps the menu coherent:

- recognition settings live together
- output behavior lives together
- shortcut behavior has one clear home

The old single static shortcut line should be removed because it becomes redundant once the submenu exists.

## Data Model Recommendation

Persist enable / disable state separately for each shortcut.

Suggested model shape:

- dictation shortcut enabled: `Bool`
- recognition-mode shortcut enabled: `Bool`

This should live in app state or a closely related settings layer so menu rendering and hotkey registration both read from the same source of truth.

## Registration Behavior

At app startup:

- register the dictation shortcut only if its enabled setting is `true`
- register the recognition-mode shortcut only if its enabled setting is `true`

At runtime:

- toggling off should unregister that specific hotkey immediately
- toggling on should register that specific hotkey immediately

The two shortcuts must be independent. Disabling one must not affect the other.

## Architectural Direction

The current global hotkey implementation is centered around a single shortcut manager. To support this feature cleanly, the architecture should move toward one of these patterns:

1. a multi-shortcut hotkey manager that registers named shortcuts
2. two small hotkey manager instances managed by app setup

For phase one, the simpler path is acceptable as long as:

- each shortcut has independent lifecycle control
- menu state and registration state stay in sync
- the design can later expand to custom keybindings without major rework

## Feedback Behavior

When the user toggles a shortcut, the app should provide lightweight confirmation through existing debug/status text.

Examples:

- `Dictation shortcut enabled`
- `Dictation shortcut disabled`
- `Recognition mode shortcut enabled`
- `Recognition mode shortcut disabled`

This helps users trust that the change took effect immediately.

## Non-Goals

Phase one should not attempt to solve:

- user-defined remapping
- keyboard recording UI
- duplicate-shortcut warnings
- shortcut import/export
- advanced modifier customization

The right first step is to make shortcut availability controllable, not infinitely configurable.

## Success Criteria

The feature is successful if a user can:

1. open the menu
2. enter `Shortcuts`
3. understand which two shortcuts exist
4. see whether each is active
5. toggle either one with a single click
6. immediately use or stop using that shortcut without relaunching the app

The result should feel like a natural extension of the app's existing menu-driven controls, not like a separate settings system bolted on later.
