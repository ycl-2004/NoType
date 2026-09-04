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
  <img src="https://img.shields.io/badge/Swift-WhisperKit%20%C2%B7%20Core%20ML-F05138?logo=swift&logoColor=white" alt="Built with Swift, WhisperKit, and Core ML">
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

Two on-device engines are available, and NoType picks between them per dictation:

- **macOS Speech** (macOS 26 or later) uses the on-device recognizer built into
  the system. It is roughly an order of magnitude faster than the bundled model,
  never translates, and never invents subtitle sign-offs — but it transcribes one
  chosen language at a time.
- **Bundled Whisper** ships inside the app as the multilingual `large-v3` model
  and its tokenizer. It detects the spoken language on its own, which is what
  makes mixed Chinese-and-English dictation work.

Neither engine sends audio anywhere. There is no account and no remote
transcription API.

## Quick start

1. **[Download `NoType-0.3.0-arm64.zip`](https://github.com/ycl-2004/NoType/releases/latest/download/NoType-0.3.0-arm64.zip)** and unzip it. The archive is about 1.4 GB because the local speech model is included.
2. Move `NoType.app` to `/Applications`. On first launch, Control-click the app and choose **Open** — the current build is ad-hoc signed and not yet Apple-notarized.
3. Allow **Microphone** access for recording and **Accessibility** access for global shortcuts and direct text insertion. On macOS 26 or later, also allow **Speech Recognition** so NoType can use the system's on-device recognizer.

Then focus any text field and double-tap **Command** to start. Double-tap it
again to stop, transcribe, and insert the result.

Preparation depends on which engine the current settings use. macOS Speech
downloads a system language model the first time a language is used, which takes
seconds. Whisper needs Core ML to specialize the model for this Mac, which takes
a few minutes the first time a given copy of the model is used. If no Whisper
model is installed at all, NoType asks where to download it first. Open **NoType →
Diagnostics** to see **Local Model: Preparing**, **Ready**, or **Failed** without
reading the debug log. Completed Whisper specialization is cached across app
launches and Mac restarts.

If Control-click → **Open** is unavailable, clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/NoType.app
open /Applications/NoType.app
```

### System requirements

- Apple Silicon Mac (`arm64`)
- macOS 15.0 or later; **macOS 26 or later** to use the macOS Speech engine
- About 4 GB of free space during download and extraction
- Microphone permission for recording
- Accessibility permission for global double-tap shortcuts and direct insertion
- Speech Recognition permission for the macOS Speech engine (macOS 26 or later)

## Why NoType

- **Your voice stays on your Mac.** Both engines run on-device; temporary recordings are deleted after each attempt.
- **Chinese and English can share a sentence.** Auto mixed recognition is designed for code-switching, with Chinese-first and English-first modes when you want a stronger bias.
- **Speed where it is available.** On macOS 26, single-language dictation goes through the system recognizer and finishes in a fraction of the time the bundled model needs.
- **The model arrives ready.** The release contains the `large-v3` model and tokenizer, so first use does not depend on a separate setup or download.
- **It returns to the right place.** NoType remembers the focused input where dictation began. If that target changes, it keeps the transcript on the clipboard instead of inserting into the wrong field.
- **It stays out of the way.** No windows are required for normal use; status, modes, permissions, shortcuts, and diagnostics live in the menu bar.

## Features

**Dictation**

- Start and stop from anywhere with Double Command, Double Option, or Command + Shift + H.
- Automatic five-minute recording limit prevents an abandoned session from running indefinitely.
- Very short accidental recordings are ignored instead of being sent through transcription.
- The transcription model is prepared in the background after launch to reduce first-use waiting.
- Diagnostics shows whether the local model is preparing, ready, or failed and offers a retry when preparation cannot complete.

**Engine**

- Choose **macOS Speech (fast)** or **Bundled Whisper** from the menu bar; the choice persists across launches.
- **Auto (中英混说) always uses Whisper**, whichever engine is selected, because only Whisper detects the spoken language. The menu shows the override as `macOS Speech → Bundled Whisper` when it applies.
- 中文优先 and 英文优先 honour the selected engine.
- On macOS 15 the choice is unavailable and everything uses the bundled model.
- Whisper is loaded only when a dictation actually needs it, so staying on macOS Speech avoids the bundled model's startup cost entirely.

**Recognition**

- **Auto (中英混说)** for natural mixed Chinese and English speech.
- **中文优先** and **英文优先** for language-biased recognition.
- Follow-model, Simplified Chinese, or Traditional Chinese output preferences.
- A separate shortcut cycles recognition modes without opening the menu.

**Text delivery**

- Insert and copy, insert only, or copy only after a successful transcription.
- Direct Accessibility insertion with a paste fallback for apps that do not expose a compatible text field.
- Captured-target protection prevents a completed transcript from landing in a different chat or document.
- Clipboard-preserving fallback when insert-only mode needs to simulate a paste.

**Menu bar controls**

- Live idle, recording, transcribing, inserting, and error states.
- Recognition and Chinese-script markers visible in the menu-bar icon.
- Configurable dictation and recognition-mode shortcuts that persist across launches.
- Permission status, the latest diagnostic event, and direct access to the local debug log.

## Usage

1. Put the cursor where the transcript should appear.
2. Double-tap **Command** to start recording.
3. Speak normally. Mixed Chinese and English is supported in the default mode.
4. Double-tap **Command** again to stop.
5. NoType transcribes locally, returns to the captured app, and inserts or copies the transcript according to your selected success mode.

Open the menu-bar icon to change the engine, recognition mode, Chinese script,
output behavior, shortcuts, or permissions.

| Recognition mode | macOS Speech selected | Bundled Whisper selected |
| --- | --- | --- |
| Auto (中英混说) | Bundled Whisper | Bundled Whisper |
| 中文优先 | macOS Speech | Bundled Whisper |
| 英文优先 | macOS Speech | Bundled Whisper |

The default shortcuts are:

| Action | Default | Other choices |
| --- | --- | --- |
| Start / stop dictation | Double Command | Double Option, Command + Shift + H, Disabled |
| Cycle recognition mode | Command + Shift + Y | Command + Option + Y, Control + Option + Y, Disabled |

## Privacy

- Speech recognition runs locally, either through WhisperKit and Core ML or through the on-device recognizer built into macOS.
- NoType does not use a remote transcription API.
- The release build does not download a Whisper model at runtime. The macOS Speech engine may ask macOS to install a system language model the first time a language is used; that model is managed by macOS, shared with every app, and stored outside the app bundle.
- Temporary audio is removed after transcription succeeds or fails.
- There are no accounts, analytics, or telemetry in the app.
- Microphone access is used only for active dictation.
- Accessibility access is used for the global modifier shortcut, focused-target capture, and text insertion.
- The clipboard is touched only when the selected output mode or an insertion fallback requires it.

## Current release

NoType `0.3.0` is available as an Apple Silicon archive from the
[`v0.3.0`](https://github.com/ycl-2004/NoType/releases/tag/v0.3.0)
release.

| Artifact | Purpose |
| --- | --- |
| `NoType-0.3.0-arm64.zip` | Ready-to-run app with the Whisper model and tokenizer included |
| `NoType-0.3.0-arm64.zip.sha256` | SHA-256 checksum for download verification |

The app is approximately 1.5 GB after extraction. The model is distributed as a
GitHub Release asset and is intentionally not committed to this repository.

## FAQ

<details>
<summary>macOS says NoType cannot be opened because the developer cannot be verified</summary>

The current release is ad-hoc signed and not Apple-notarized. Control-click
`NoType.app`, choose **Open**, and confirm once. You can also run the `xattr`
command shown in [Quick start](#quick-start).

</details>

<details>
<summary>Why can the first launch take a minute or two?</summary>

The model is bundled, so NoType does not download anything. Core ML may still
specialize the model for the current Mac the first time that model and compute
configuration are used. NoType keeps running while this happens and shows the
real state under **Diagnostics → Local Model**. Once Ready, the completed Core ML
cache normally survives app launches and Mac restarts. An OS update, model
change, app-bundle replacement, compute-configuration change, low-disk cleanup,
or manual cache removal can require specialization again.

</details>

<details>
<summary>Why is the download so large?</summary>

NoType includes the Whisper `large-v3` `_turbo` Core ML package and its tokenizer.
The package includes an optional decoder-prefill model that reduces startup
decoding work. This makes the archive much larger, but it also means
transcription works locally on first launch without downloading a model or
sending speech to a server.

</details>

<details>
<summary>Where does the Whisper model get stored, and can I choose?</summary>

NoType looks for the model in three places, in this order:

1. `~/Documents/huggingface/…` — shared with other WhisperKit apps
2. `~/Library/Application Support/NoType/…` — private to NoType
3. inside `NoType.app` itself — only present in a release that bundles it

If none of them has it, NoType asks where to put it before downloading, so a
1.5 GB file never lands somewhere you did not choose. Pick the shared folder if
you run other WhisperKit tools and would rather not keep two copies; pick
NoType's own folder if you want the model removed when you delete the app.

Install locations are searched **before** the copy inside the app, so a model you
downloaded stays in use across app updates — and keeps its Core ML specialization
cache, which is what makes launches take seconds instead of minutes.

</details>

<details>
<summary>Which engine should I use?</summary>

Leave the engine on **macOS Speech (fast)** if you are on macOS 26. Single-language
dictation then finishes almost instantly, and Auto still falls back to Whisper on
its own, so mixed Chinese-and-English speech keeps working.

Switch to **Bundled Whisper** if you want every mode to use the same engine, if
you are comparing output quality between the two, or if the system recognizer
mishandles vocabulary you use often.

</details>

<details>
<summary>Why does Auto ignore my engine choice?</summary>

Auto asks the engine to work out which language is being spoken. Only Whisper can
do that. The macOS recognizer is built for one language at a time, so forcing Auto
through it would apply a single language to the whole recording and transliterate
the rest — Chinese spoken into an English model comes back as pinyin.

Rather than degrade quietly, NoType routes Auto to Whisper and says so in the
menu: `Engine: macOS Speech (fast) → Bundled Whisper`.

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
**Accessibility** permission lets it observe the global modifier shortcut,
remember the focused input, and insert the finished transcript. Copy-only output
still needs Microphone access but does not require direct text insertion.

**Speech Recognition** permission is required only by the macOS Speech engine on
macOS 26 or later. Recognition still happens on-device; the permission gates
access to the system recognizer, not a network service. The bundled Whisper
engine does not use it.

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
- A local WhisperKit Core ML model and tokenizer for a self-contained release

Run the test suite:

```bash
swift test
```

Build a small local app bundle:

```bash
./scripts/build_app.sh
```

This creates `dist/NoType.app` without copying the large model — about 10 MB
instead of 1.5 GB.

`LocalWhisperPaths.swift` resolves the model by checking a shared location first
and the app bundle second:

1. `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-large-v3-v20240930_turbo`
2. the copy inside `NoType.app/Contents/Resources/`

**The shared location wins even when the bundle has its own copy**, and that
order is deliberate. Core ML caches its model specialization per model path, so a
path that moves into a replaced app bundle throws the cache away: a rebuild
measured 4m13s to reload the model, against 4s when the path held still. Keeping
the model in one fixed place outside the bundle also means a development machine
stores one 1.5 GB copy rather than one per build.

Release builds still bundle the model, because an installed copy is what makes
the app self-contained for someone who has no `~/Documents/huggingface` at all.

Build the self-contained release archive:

```bash
WHISPER_MODEL_DIR="/path/to/openai_whisper-large-v3-v20240930_turbo" \
WHISPER_TOKENIZER_DIR="/path/to/whisper-large-v3" \
./scripts/build_release.sh
```

The packaging script builds the current checkout, bundles the model and
tokenizer, signs the whole app bundle, and creates:

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
- `Sources/Typeless/Transcription/` — both engines, the router that chooses between them, and transcript cleanup.
- `Sources/Typeless/Accessibility/` — focused-target capture, direct insertion, clipboard handling, and paste fallback.
- `Sources/Typeless/Coordinator/` — dictation state transitions and orchestration.
- `Sources/Typeless/App/` — menu-bar UI, permissions, diagnostics, and app lifecycle.
- `Sources/Typeless/Hotkey/` — Carbon shortcuts and modifier double-tap detection.
- `Tests/TypelessTests/` — unit coverage for transcription, coordination, shortcuts, state, permissions, and menu presentation.
- `Packaging/Info.plist` — app identity, version, permissions text, and minimum macOS version.
- `scripts/` — local app and self-contained release builds.
- `docs/decisions/` — product and engineering decision records.

## Known limitations

- The downloadable release supports Apple Silicon only.
- macOS 15.0 or later is required.
- The current public build is ad-hoc signed and not notarized.
- There is no in-app updater; new versions are installed manually.
- The release model is fixed to Whisper `large-v3`; Whisper model switching is not exposed in the app.
- The macOS Speech engine requires macOS 26 or later and cannot detect the spoken language, so Auto always uses Whisper.
- The macOS Speech engine has no custom-vocabulary list yet, so proper nouns spoken inside another language can be transliterated rather than spelled.

## Documentation

- [Changelog](CHANGELOG.md) — shipped user-facing changes.
- [Known issues](docs/known-issues.md) — understood limitations and future directions.
- [ADR-001: Configurable shortcut input](docs/decisions/001-configurable-shortcut-input.md) — why NoType uses curated shortcuts and modifier double-taps.
- [ADR-002: Portable release packaging](docs/decisions/002-portable-release-packaging.md) — why releases bundle the model instead of downloading it at runtime.
- [ADR-003: Local model readiness](docs/decisions/003-local-model-readiness.md) — why Diagnostics reflects the actual Core ML loading lifecycle without a percentage.
- [ADR-004: Two-engine routing](docs/decisions/004-two-engine-routing.md) — why both engines are kept and why Auto always uses Whisper.
- [ADR-005: Model location strategy](docs/decisions/005-model-location-strategy.md) — why install locations are searched before the app bundle, and why a download asks first.

## Third-party terms

NoType uses WhisperKit. Its license is included at
[`Vendor/WhisperKit-main/LICENSE`](Vendor/WhisperKit-main/LICENSE).
