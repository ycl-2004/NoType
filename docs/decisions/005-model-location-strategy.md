# ADR-005: Resolve the Whisper Model From a Stable Shared Location

## Status

Accepted

## Date

2026-09-04

## Context

`LocalWhisperPaths` originally preferred the copy inside the app bundle and fell
back to a hardcoded developer path. Two costs followed from that order.

**Core ML specialization is cached per model path.** Replacing the app bundle
moves the path, so the cache is discarded and the model is specialized again.
Measured on this Mac after one rebuild:

| Model location | Time to load |
| --- | --- |
| Inside the app bundle, path moved by the rebuild | **4m13s** |
| Fixed location outside the bundle, path unchanged | **2–4s** |

During that first four-minute wait the app reported only `Local Model:
Preparing…`, which reads as a hang and was reported as one.

**Every build kept its own 1.5 GB copy.** A snapshot of this machine found six
copies of the same model — app bundle, build output, an app backup, a superseded
non-turbo variant, and the shared download — for 9 GB of duplicates.

Separately, the 1.4 GB release archive is a real barrier to distribution, and
`WhisperKit.download(variant:downloadBase:)` can fetch the model at runtime into
a caller-chosen directory.

## Decision

**Search install locations before the app bundle**, and recompute the path rather
than caching it, so a model downloaded during a launch is visible to the load
that follows:

1. `~/Documents/huggingface/…` — shared with other WhisperKit apps
2. `~/Library/Application Support/NoType/…` — private to NoType
3. `NoType.app/Contents/Resources/…` — present only in a bundling release

The shared paths are derived from `homeDirectoryForCurrentUser`, replacing the
hardcoded `/Users/yichenlin/…` string, so a second account resolves to its own
copy.

**When no location has the model, ask before downloading.** A 1.5 GB file must
not land somewhere the user did not choose, so `WhisperModelInstaller` presents
the two install locations with their trade-offs and a "Not Now" option, then
passes the chosen directory to `WhisperKit.download(downloadBase:)`. A missing
model is no longer a dead end; it is a prompt.

Error messages name the shared path rather than the resolved one, because a
signed app bundle is not somewhere a user can place a model.

## Consequences

- A lightweight build is now viable: 10 MB instead of 1.5 GB, with the model
  fetched on first use. Bundling releases still work and are still what makes the
  app self-contained for someone with no prior install.
- Rebuilding the app no longer discards the Core ML cache, because the model path
  no longer moves.
- A development machine keeps one copy of the model instead of one per build.
- A bundling release carries a copy that is ignored whenever an install location
  already has one. That is the intended trade: a redundant 1.5 GB inside the
  bundle costs disk, while a moving model path costs four minutes on every
  update.
- The download path is only exercised when no model is present, so it needs
  deliberate testing — renaming the install directory is the way to reach it.

## Verification

With a decoy model directory placed inside `NoType.app/Contents/Resources/`, the
app still resolved to `~/Documents/huggingface/…`, confirming the search order.

With the install directory renamed away, a launch prompted for a location,
downloaded 1.5 GB into the chosen folder, and loaded from it.
