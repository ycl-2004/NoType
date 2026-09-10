<p align="center">
  <img src="App_icon.png" alt="NoType logo" width="120" height="120">
</p>

<h1 align="center">NoType</h1>

<p align="center">
  <strong>Private, local dictation for macOS — speak naturally and keep typing.</strong>
</p>

<p align="center">
  <a href="https://github.com/ycl-2004/NoType/releases/latest"><img src="https://img.shields.io/github/v/release/ycl-2004/NoType?label=release&color=111111" alt="Latest release"></a>
  <a href="https://github.com/ycl-2004/NoType/releases"><img src="https://img.shields.io/github/downloads/ycl-2004/NoType/total?label=downloads&color=111111" alt="Total downloads"></a>
  <img src="https://img.shields.io/badge/macOS-15.0%2B-111111?logo=apple&logoColor=white" alt="macOS 15.0 or later">
  <img src="https://img.shields.io/badge/Mac-Apple%20Silicon-111111?logo=apple&logoColor=white" alt="Apple Silicon Mac">
  <img src="https://img.shields.io/badge/Swift-sherpa--onnx%20%C2%B7%20ONNX%20Runtime-F05138?logo=swift&logoColor=white" alt="Built with Swift, sherpa-onnx, and ONNX Runtime">
</p>

<p align="center">
  <a href="https://github.com/ycl-2004/NoType/releases/latest/download/NoType-0.3.0-arm64.zip"><strong>⬇ Download for macOS</strong></a>
  ·
  <a href="https://github.com/ycl-2004/NoType/releases">Releases</a>
  ·
  <a href="#features">Features</a>
  ·
  <a href="#privacy">Privacy</a>
  ·
  <a href="#build-from-source">Build from source</a>
</p>

NoType is a native macOS menu-bar dictation app. Focus a text field, start
dictation, speak, and stop — NoType transcribes your voice locally and inserts
the result back into the app you were using.

Three on-device engines are available, and NoType picks between them per dictation:

- **macOS Speech** (macOS 26 or later) uses the on-device recognizer built into
  the system. It is roughly an order of magnitude faster than a local model,
  never translates, and never invents subtitle sign-offs — but it transcribes one
  chosen language at a time.
- **Qwen3-ASR 0.6B INT8** is the multilingual local model, run through
  sherpa-onnx. It detects the spoken language on its own, which is what makes
  mixed Chinese-and-English dictation work. It is downloaded once into the shared
  `~/Documents/huggingface/models/k2-fsa` folder when you first use it.
- **SenseVoice Small** is an optional local ONNX model for Chinese, Cantonese,
  English, Japanese, and Korean. It is downloaded once into the shared
  `~/Documents/huggingface/models/k2-fsa` folder when you select it.

None of the engines sends audio anywhere. There is no account and no remote
transcription API.

## Quick start

1. **[Download `NoType-0.3.0-arm64.zip`](https://github.com/ycl-2004/NoType/releases/latest/download/NoType-0.3.0-arm64.zip)** and unzip it. No speech model is bundled — the app downloads one on first use.
2. Move `NoType.app` to `/Applications`. On first launch, Control-click the app and choose **Open** — the current build is ad-hoc signed and not yet Apple-notarized.
3. Allow **Microphone** access for recording and **Accessibility** access for global shortcuts and direct text insertion. On macOS 26 or later, also allow **Speech Recognition** so NoType can use the system's on-device recognizer.

Then focus any text field and double-tap **Command** to start. Double-tap it
again to stop, transcribe, and insert the result.

Preparation depends on which engine the current settings use. macOS Speech
downloads a system language model the first time a language is used, which takes
seconds. Qwen3-ASR downloads its roughly 1 GB ONNX archive on first use, and
SenseVoice its roughly 230 MB one, if they are not already in the shared Hugging
Face folder. Open **NoType → Diagnostics** to see **Speech Model: Preparing**,
**Ready**, or **Failed** without reading the debug log. A downloaded model is
shared across NoType builds and stays put when you replace the app. Use **Engine
→ Manage Downloaded Models** to remove NoType's downloaded Qwen3-ASR or
SenseVoice copies when you no longer need them.

If Control-click → **Open** is unavailable, clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/NoType.app
open /Applications/NoType.app
```

### System requirements

- Apple Silicon Mac (`arm64`)
- macOS 15.0 or later; **macOS 26 or later** to use the macOS Speech engine
- About 3 GB of free space for the app and one downloaded local model
- Microphone permission for recording
- Accessibility permission for global keyboard shortcuts and direct insertion
- Speech Recognition permission for the macOS Speech engine (macOS 26 or later)

## Why NoType

- **Your voice stays on your Mac.** All three engines run on-device; temporary recordings are deleted after each attempt.
- **Chinese and English can share a sentence.** Auto mixed recognition is designed for code-switching, with Chinese-first and English-first modes when you want a stronger bias.
- **Speed where it is available.** On macOS 26, single-language dictation goes through the system recognizer and finishes in a fraction of the time a local model needs.
- **Choose the trade-off.** Qwen3-ASR and SenseVoice are both downloaded on demand and reused from the shared Hugging Face folder, so the app itself stays small.
- **It returns to the right place.** NoType remembers the focused input where dictation began. If that target changes, it keeps the transcript on the clipboard instead of inserting into the wrong field.
- **It stays out of the way.** No windows are required for normal use; status, modes, permissions, shortcuts, and diagnostics live in the menu bar.

## Features

**Dictation**

- Start and stop from anywhere with a customizable keyboard shortcut. The default is Double Command; regular keys, modifier combinations, and left/right modifier keys are supported.
- Automatic five-minute recording limit prevents an abandoned session from running indefinitely.
- Very short accidental recordings are ignored instead of being sent through transcription.
- The transcription model is prepared in the background after launch to reduce first-use waiting.
- Diagnostics shows whether the local model is preparing, ready, or failed and offers a retry when preparation cannot complete.

**Engine**

- Choose **macOS Speech (fast)**, **Qwen3-ASR 0.6B INT8**, or **SenseVoice Small** from the menu bar; the choice persists across launches.
- **Auto (中英混说)** uses the selected local model. If macOS Speech is selected, the menu shows the mixed-language override as `macOS Speech → Qwen3-ASR 0.6B INT8`.
- 中文优先 and 英文优先 honour the selected engine.
- On macOS 15 the choice is unavailable and everything uses Qwen3-ASR.
- A local model is loaded only when a dictation actually needs it, so staying on macOS Speech avoids both local model startup costs.
- **Manage Downloaded Models** appears under the engine menu. It removes only NoType's exact Qwen3-ASR and SenseVoice download folders after confirmation; macOS Speech assets are left to macOS.

**Recognition**

- **Auto (中英混说)** for natural mixed Chinese and English speech.
- **中文优先** and **英文优先** for language-biased recognition.
- Follow-model, Simplified Chinese, or Traditional Chinese output preferences.
- An optional shortcut cycles recognition modes without opening the menu. It is off by default.

**Text delivery**

- Insert and copy, insert only, or copy only after a successful transcription.
- Direct Accessibility insertion with a paste fallback for apps that do not expose a compatible text field. Terminal, Ghostty, and iTerm2 use paste into the original focused terminal; changing tabs or fields prevents fallback into a different target.
- Captured-target protection prevents a completed transcript from landing in a different chat or document.
- Clipboard-preserving fallback when insert-only mode needs to simulate a paste.

**Menu bar controls**

- Live idle, recording, transcribing, inserting, and error states.
- Recognition and Chinese-script markers visible in the menu-bar icon.
- Configurable dictation and recognition-mode shortcuts that persist across launches.
- Permission status, the latest diagnostic event, and direct access to the local debug log. Logs retain the newest five days and are trimmed whenever NoType logs activity or accesses the log.

## Usage

1. Put the cursor where the transcript should appear.
2. Double-tap **Command** to start recording.
3. Speak normally. Mixed Chinese and English is supported in the default mode.
4. Double-tap **Command** again to stop.
5. NoType transcribes locally, returns to the captured app, and inserts or copies the transcript according to your selected success mode.

Open the menu-bar icon to change the engine, recognition mode, Chinese script,
output behavior, shortcuts, or permissions.

| Recognition mode | macOS Speech selected | Qwen3-ASR selected | SenseVoice Small selected |
| --- | --- | --- | --- |
| Auto (中英混说) | Qwen3-ASR 0.6B INT8 | Qwen3-ASR 0.6B INT8 | SenseVoice Small |
| 中文优先 | macOS Speech | Qwen3-ASR 0.6B INT8 | SenseVoice Small |
| 英文优先 | macOS Speech | Qwen3-ASR 0.6B INT8 | SenseVoice Small |

Shortcuts are configured under **Shortcuts** in the menu bar. Choose **Add Shortcut…** to record a regular key, any combination of Command, Option, Control, Shift, and Fn, or a modifier by itself. Each action can have multiple shortcuts, and each shortcut can respond to one press or two quick presses.

The defaults are:

| Action | Default | Other choices |
| --- | --- | --- |
| Start / stop dictation | Double Command | Any recorded shortcut, Disabled |
| Cycle recognition mode | Off | Any recorded shortcut |

## Privacy

- Speech recognition runs locally, either through sherpa-onnx and the ONNX Runtime or the on-device recognizer built into macOS.
- NoType does not use a remote transcription API.
- Qwen3-ASR and SenseVoice each download their own model, once, only when selected, and only from the official sherpa-onnx release archive. The macOS Speech engine may ask macOS to install a system language model the first time a language is used; that model is managed by macOS, shared with every app, and stored outside the app bundle. No audio is ever uploaded.
- Temporary audio is removed after transcription succeeds or fails.
- There are no accounts, analytics, or telemetry in the app.
- Microphone access is used only for active dictation.
- Accessibility access is used for global keyboard shortcuts, focused-target capture, and text insertion.
- The clipboard is touched only when the selected output mode or an insertion fallback requires it.

## Current release

NoType `0.3.0` is available as an Apple Silicon archive from the
[`v0.3.0`](https://github.com/ycl-2004/NoType/releases/tag/v0.3.0)
release.

| Artifact | Purpose |
| --- | --- |
| `NoType-0.3.0-arm64.zip` | Ready-to-run app; the speech model is downloaded on first use |
| `NoType-0.3.0-arm64.zip.sha256` | SHA-256 checksum for download verification |

Speech models are not committed to this repository and are no longer bundled in
the archive. NoType fetches one from the official sherpa-onnx release on first
use. `0.3.0` predates that change and still ships with the model included; see
the [changelog](CHANGELOG.md) for what changed since.

## FAQ

<details>
<summary>macOS says NoType cannot be opened because the developer cannot be verified</summary>

The current release is ad-hoc signed and not Apple-notarized. Control-click
`NoType.app`, choose **Open**, and confirm once. You can also run the `xattr`
command shown in [Quick start](#quick-start).

</details>

<details>
<summary>Why can the first dictation take a while?</summary>

The first time you use a local engine, NoType downloads its model — roughly 1 GB
for Qwen3-ASR, roughly 230 MB for SenseVoice. NoType keeps running while this
happens and shows the real state under **Diagnostics → Speech Model**. The
download goes into `~/Documents/huggingface/models/k2-fsa`, so it is shared
across NoType builds and is not repeated when you replace the app. After that,
loading the model takes seconds.

</details>

<details>
<summary>How much will NoType actually download?</summary>

The app itself is small. A local engine adds its model the first time you use it:
roughly 1 GB for Qwen3-ASR 0.6B INT8, roughly 230 MB for SenseVoice Small. You
only pay for the engines you actually select, the download happens once per Mac
rather than once per app version, and nothing is downloaded at all if you stay on
macOS Speech. The trade is that a brand-new install needs a network connection
before its first local dictation; every dictation after that is fully offline.

</details>

<details>
<summary>Where do local models get stored, and can I remove them?</summary>

Both local models live under one shared folder, at one fixed path each:

```text
~/Documents/huggingface/models/k2-fsa/
  sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25/
  sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17/
```

NoType never creates a second copy in Application Support or inside the app
bundle, so replacing the app leaves your downloads alone and a development
machine keeps one copy rather than one per build.

**Engine → Manage Downloaded Models** removes exactly those two folders after
confirmation. It does not remove macOS Speech assets, the signed app bundle, or
unrelated Hugging Face models sitting in the same directory.

</details>

<details>
<summary>Which engine should I use?</summary>

Leave the engine on **macOS Speech (fast)** if you are on macOS 26. Single-language
dictation then finishes almost instantly, and Auto still falls back to Qwen3-ASR
on its own, so mixed Chinese-and-English speech keeps working.

Switch to **Qwen3-ASR 0.6B INT8** if you want every mode to use the same engine,
if you are comparing output quality between the two, or if the system recognizer
mishandles vocabulary you use often.

Choose **SenseVoice Small** when you want a smaller optional local model for
Chinese, Cantonese, English, Japanese, or Korean. It is a useful comparison
target for Chinese and multilingual dictation, but its quality and speed on this
app's longer recordings still need to be measured on your Mac.

</details>

<details>
<summary>Why does Auto ignore my engine choice?</summary>

Auto asks the engine to work out which language is being spoken. Qwen3-ASR and
SenseVoice can do that. The macOS recognizer is built for one language at a time,
so forcing Auto through it would apply a single language to the whole recording
and transliterate the rest — Chinese spoken into an English model comes back as
pinyin.

NoType routes Auto to Qwen3-ASR only when macOS Speech is selected and says so in
the menu: `Engine: macOS Speech (fast) → Qwen3-ASR 0.6B INT8`.

</details>

<details>
<summary>Does the macOS Speech engine need me to stay in a text field like system dictation?</summary>

No. System dictation types into whatever control has focus, which is why it keeps
you on one screen. NoType uses the same underlying recognizer through
`SpeechAnalyzer`, which takes audio in and hands text back, so NoType still
decides where the transcript lands. Start dictation, switch apps, stop, and the
result goes to the captured field or your clipboard exactly as before.

</details>

<details>
<summary>Why does NoType need Microphone and Accessibility permission?</summary>

**Microphone** permission lets NoType record while dictation is active.
**Accessibility** permission lets it observe global keyboard shortcuts,
remember the focused input, and insert the finished transcript. Copy-only output
still needs Microphone access but does not require direct text insertion.

**Speech Recognition** permission is required only by the macOS Speech engine on
macOS 26 or later. Recognition still happens on-device; the permission gates
access to the system recognizer, not a network service. The Qwen3-ASR and
SenseVoice engines do not use it.

</details>

<details>
<summary>What happens if I switch chats or text fields while NoType is transcribing?</summary>

NoType tries to return to the input captured when dictation started. If that
specific target is no longer available, it copies the transcript instead of
risking insertion into a different conversation or document.

</details>

<details>
<summary>How do I uninstall NoType?</summary>

Quit NoType from the menu-bar icon, then move `/Applications/NoType.app` to the
Trash. You can revoke its permissions under **System Settings → Privacy &
Security → Microphone / Accessibility**.

</details>

## Build from source

<details>
<summary>Requirements, build commands, and release packaging</summary>

Requirements:

- macOS 15.0 or later
- Apple Silicon for the current release-packaging path
- Swift 6.1 or a compatible Xcode toolchain

Run the test suite:

```bash
swift test
```

Note that `swift test --filter` is usable again since the vendored WhisperKit
checkout was removed; it used to break the build outright.

Build a local app bundle:

```bash
./scripts/build_app.sh
```

This creates `dist/NoType.app`. No model is copied into it — `Qwen3ASRPaths` and
`SenseVoicePaths` each resolve one fixed directory under
`~/Documents/huggingface/models/k2-fsa/`, and the app downloads into it on first
use. Keeping models outside the bundle means replacing the app never moves a
model path, and a development machine stores one copy rather than one per build.

Build the release archive:

```bash
./scripts/build_release.sh
```

The packaging script builds the current checkout, signs the whole app bundle, and
creates:

```text
dist/NoType.app
dist/NoType-0.3.0-arm64.zip
dist/NoType-0.3.0-arm64.zip.sha256
```

The default signature is ad-hoc. To use an installed Developer ID identity:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./scripts/build_release.sh
```

The script verifies the signature with `codesign --verify --deep --strict`.
Notarization is not automated yet; consult Apple's macOS distribution guidance
before treating a build as a public, notarized release.

</details>

## Project layout

- `Sources/Typeless/Audio/` — microphone capture and temporary recorded clips.
- `Sources/Typeless/Transcription/` — the three engines, the router that chooses between them, model installers, and transcript cleanup.
- `Sources/Typeless/Accessibility/` — focused-target capture, direct insertion, clipboard handling, and paste fallback.
- `Sources/Typeless/Coordinator/` — dictation state transitions and orchestration.
- `Sources/Typeless/App/` — menu-bar UI, permissions, diagnostics, and app lifecycle.
- `Sources/Typeless/Hotkey/` — shortcut recording, AppKit event monitoring, and press-style detection.
- `Tests/TypelessTests/` — unit coverage for transcription, coordination, shortcuts, state, permissions, and menu presentation.
- `Packaging/Info.plist` — app identity, version, permissions text, and minimum macOS version.
- `scripts/` — local app and self-contained release builds.
- `docs/decisions/` — product and engineering decision records.

## Known limitations

- The downloadable release supports Apple Silicon only.
- macOS 15.0 or later is required.
- The current public build is ad-hoc signed and not notarized.
- There is no in-app updater; new versions are installed manually.
- Both local models are downloaded on first use rather than bundled, so a new install needs a network connection before its first local dictation.
- Qwen3-ASR replaced Whisper recently. Its transcription quality and latency on this app's recordings have not yet been measured on-device against the engine it replaced.
- SenseVoice supports Chinese, Cantonese, English, Japanese, and Korean. The upstream direct inference path documents a 30-second input limit; NoType's longer-recording path still needs real-device validation.
- The macOS Speech engine requires macOS 26 or later and cannot detect the spoken language, so Auto uses Qwen3-ASR when macOS Speech is selected.
- The macOS Speech engine has no custom-vocabulary list yet, so proper nouns spoken inside another language can be transliterated rather than spelled.

## Documentation

- [Changelog](CHANGELOG.md) — shipped user-facing changes.
- [Known issues](docs/known-issues.md) — understood limitations and future directions.
- [ADR-001: Configurable shortcut input](docs/decisions/001-configurable-shortcut-input.md) — the original shortcut design, now superseded.
- [ADR-002: Portable release packaging](docs/decisions/002-portable-release-packaging.md) — why releases originally bundled the model instead of downloading it at runtime. Superseded by ADR-008.
- [ADR-003: Local model readiness](docs/decisions/003-local-model-readiness.md) — why Diagnostics reports Preparing / Ready / Failed rather than a percentage.
- [ADR-004: Two-engine routing](docs/decisions/004-two-engine-routing.md) — why the original two engines are kept and why macOS Speech mixed mode uses the multilingual local model.
- [ADR-005: Model location strategy](docs/decisions/005-model-location-strategy.md) — why install locations were searched before the app bundle, and why a download asked first. Superseded by ADR-008.
- [ADR-006: SenseVoice engine and model storage](docs/decisions/006-sensevoice-engine-and-model-storage.md) — why SenseVoice is additive, where its one shared model lives, and why model deletion cannot touch macOS Speech.
- [ADR-007: User-recorded shortcuts](docs/decisions/007-user-recorded-shortcuts.md) — how arbitrary shortcuts, left/right modifiers, multiple bindings, and defaults work.
- [ADR-008: Qwen3-ASR replaces Whisper](docs/decisions/008-qwen3-asr-replaces-whisper.md) — why the local engine changed, why no model is bundled any more, and what is still unmeasured.

## Third-party terms

Both local engines run through the
[sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) Swift package and its ONNX
Runtime dependency, and use model archives published by the sherpa-onnx project:
Qwen3-ASR 0.6B INT8 and SenseVoice Small. Earlier versions of NoType used
WhisperKit, which is no longer a dependency.
