<p align="center">
  <img src="App_Icon.png" alt="NoType logo" width="120" height="120">
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
  <img src="https://img.shields.io/badge/Swift-llama.cpp%20%C2%B7%20Metal-F05138?logo=swift&logoColor=white" alt="Built with Swift, llama.cpp, and Metal">
</p>

<p align="center">
  <a href="https://github.com/ycl-2004/NoType/releases/latest/download/NoType-0.4.0-arm64.zip"><strong>⬇ Download for macOS</strong></a>
  ·
  <a href="https://github.com/ycl-2004/NoType/releases">Releases</a>
  ·
  <a href="#features">Features</a>
  ·
  <a href="#privacy">Privacy</a>
  ·
  <a href="#build-from-source">Build from source</a>
  ·
  <a href="README.zh-TW.md">繁體中文</a>
</p>

NoType is a native macOS menu-bar dictation app. Focus a text field, start
dictation, speak, and stop — NoType transcribes your voice locally and inserts
the result back into the app you were using.

Two on-device engines are available, and NoType picks between them per dictation:

- **R2T2 Streaming** is the local model: Confucius4-R2T2, NetEase Youdao's
  streaming speech model trained from Qwen3-ASR-1.7B, run as a Q4_K_M GGUF with a
  Q8_0 audio projector through llama.cpp and Metal. It detects the spoken
  language on its own, which is what makes mixed Chinese-and-English dictation
  work, and it transcribes while you speak, so most of the work is done before
  you stop. The text stays in NoType's buffer until you stop; it is never typed
  into the focused field part-way. Its files are downloaded once into
  `~/Documents/huggingface/models/mradermacher/Confucius4-R2T2-GGUF`.
- **macOS Speech** (macOS 26 or later) uses the on-device recognizer built into
  the system. It needs no download and is faster still for single-language
  dictation, but it transcribes one chosen language at a time, so Auto always
  uses R2T2.

None of the engines sends audio anywhere. There is no account and no remote
transcription API.

## Quick start

1. **[Download `NoType-0.4.0-arm64.zip`](https://github.com/ycl-2004/NoType/releases/latest/download/NoType-0.4.0-arm64.zip)** and unzip it. No speech model is bundled — the app downloads one on first use.
2. Move `NoType.app` to `/Applications`. On first launch, Control-click the app and choose **Open** — the current build is ad-hoc signed and not yet Apple-notarized.
3. Allow **Microphone** access for recording and **Accessibility** access for global shortcuts and direct text insertion. On macOS 26 or later, also allow **Speech Recognition** so NoType can use the system's on-device recognizer.

Then focus any text field and double-tap **Command** to start. Double-tap it
again to stop, transcribe, and insert the result.

R2T2 is the default engine. On first launch NoType downloads its roughly 1.5 GB
model-plus-projector package into the shared Hugging Face folder and checks it
against the publisher's SHA-256 hashes; later launches reuse it. macOS Speech
downloads a system language model the first time a language is used, which takes
seconds. Open **NoType → Diagnostics** to see **Speech Model: Preparing**,
**Ready**, or **Failed** without reading the debug log. The downloaded model is
shared across NoType builds and stays put when you replace the app. Use **Engine
→ Manage Downloaded Models** to remove it when you no longer need it.

If Control-click → **Open** is unavailable, clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/NoType.app
open /Applications/NoType.app
```

### System requirements

- Apple Silicon Mac (`arm64`)
- macOS 15.0 or later; **macOS 26 or later** to use the macOS Speech engine
- About 2 GB of free space for the app and the R2T2 model
- Microphone permission for recording
- Accessibility permission for global keyboard shortcuts and direct insertion
- Speech Recognition permission for the macOS Speech engine (macOS 26 or later)

## Why NoType

- **Your voice stays on your Mac.** Both engines run on-device; temporary recordings are deleted after each attempt.
- **Chinese and English can share a sentence.** Auto mixed recognition is designed for code-switching, with Chinese-first and English-first modes when you want a stronger bias.
- **Speed where it is available.** On macOS 26, single-language dictation goes through the system recognizer and finishes in a fraction of the time a local model needs.
- **Most of the work happens while you talk.** R2T2 transcribes during recording, so the wait after you stop stays short however long you spoke.
- **It returns to the right place.** NoType remembers the focused input where dictation began. If that target changes, it keeps the transcript on the clipboard instead of inserting into the wrong field.
- **It stays out of the way.** No windows are required for normal use; status, modes, permissions, shortcuts, and diagnostics live in the menu bar.

## Features

**Dictation**

- Start and stop from anywhere with a customizable keyboard shortcut. The default is Double Command; regular keys, modifier combinations, and left/right modifier keys are supported.
- Press **Esc** while recording or transcribing to cancel: the recording is deleted, nothing is inserted, and the clipboard is left alone. NoType consumes that Esc press, so it does not also reach the focused app; Esc with Command, Option, Control, or Shift passes through.
- Automatic five-minute recording limit prevents an abandoned session from running indefinitely.
- Very short accidental recordings are ignored instead of being sent through transcription.
- The transcription model is prepared in the background after launch to reduce first-use waiting.
- Diagnostics shows whether the local model is preparing, ready, or failed and offers a retry when preparation cannot complete.

**Engine**

- Choose **R2T2 Streaming** or **macOS Speech (fast)** from the menu bar; the choice persists across launches. New installs start on R2T2.
- R2T2 starts transcribing 320 ms into a recording and decodes anything longer than 24 seconds in segments cut at pauses. The live preview is overlay-only and may still revise; stopping uses the same captured-target protection and output modes as macOS Speech.
- **Auto (中英混說)** always uses R2T2. If macOS Speech is selected, the menu shows the override as `macOS Speech (fast) → R2T2 Streaming`, and the dictation still streams.
- 中文優先 and English honour the selected engine.
- On macOS 15 macOS Speech is unavailable and every mode uses R2T2.
- R2T2 is loaded only when a dictation needs it, so staying on macOS Speech for single-language modes avoids its startup cost.
- **Edit Hotwords…** under the engine menu opens a plain text file (`~/Library/Application Support/NoType/hotwords.txt`) with one term per line. R2T2 receives the list at the start of each dictation, which helps with distinctive names and technical terms. Words that sound like ordinary words may still be misheard, and common words in the list can be inserted where you did not say them.
- **Manage Downloaded Models** appears under the engine menu. It removes only NoType's R2T2 download folder after confirmation; macOS Speech assets are left to macOS.

**Recognition**

- **Auto (中英混說)** for natural mixed Chinese and English speech.
- **中文優先** and **English** for language-biased recognition.
- Follow-model, Simplified Chinese, or Traditional Chinese output preferences.
- An optional shortcut cycles recognition modes without opening the menu. It is off by default.

**Text delivery**

- Insert and copy, insert only, or copy only after a successful transcription.
- Direct Accessibility insertion with a paste fallback for apps that do not expose a compatible text field. Terminal, Ghostty, and iTerm2 use paste into the original focused terminal; changing tabs or fields prevents fallback into a different target.
- Captured-target protection prevents a completed transcript from landing in a different chat or document.
- Clipboard-preserving fallback when insert-only mode needs to simulate a paste.

**Menu bar controls**

- Live idle, recording, transcribing, inserting, and error states.
- **Show Voice Overlay** toggles a compact, dark capsule at the bottom center of the screen where dictation starts. While recording it shows only a waveform that responds to microphone volume, or the waveform and the newest live text when **Show Live Transcript** is on. It sizes itself to its content, stays visible through transcription, and never takes keyboard focus.
- **Overlay Timing** lets you enter separate completion and failure feedback durations from 0 to 5 seconds, defaulting to 1.5 seconds for both. Zero hides that category; recording and transcription remain visible while active. Settings persist and changes apply to the current countdown. Short labels include `转写中…`, `已插入`, `已复制`, `已取消`, and `插入失败`; detailed errors remain in the menu.
- **Show Live Transcript** optionally displays R2T2's newest in-progress text in the recording overlay. It is display-only and does not change the captured target or insertion timing.
- Recognition and Chinese-script markers visible in the menu-bar icon.
- Configurable dictation and recognition-mode shortcuts that persist across launches.
- Permission status, the latest diagnostic event, and direct access to the local debug log. Logs retain the newest five days and are trimmed whenever NoType logs activity or accesses the log.

## Usage

1. Put the cursor where the transcript should appear.
2. Double-tap **Command** to start recording.
3. Speak normally. Mixed Chinese and English is supported in the default mode.
4. Double-tap **Command** again to stop, or press **Esc** to cancel without inserting anything.
5. NoType transcribes locally, returns to the captured app, and inserts or copies the transcript according to your selected success mode.

Open the menu-bar icon to change the engine, recognition mode, Chinese script,
output behavior, overlay visibility and timing, shortcuts, or permissions.

| Recognition mode | R2T2 selected | macOS Speech selected |
| --- | --- | --- |
| Auto (中英混說) | R2T2 | R2T2 |
| 中文優先 | R2T2 | macOS Speech |
| English | R2T2 | macOS Speech |

On macOS 15, every row uses R2T2.

Shortcuts are configured under **Shortcuts** in the menu bar. Choose **Add Shortcut…** to record a regular key, any combination of Command, Option, Control, Shift, and Fn, or a modifier by itself. Each action can have multiple shortcuts, and each shortcut can respond to one press or two quick presses.

The defaults are:

| Action | Default | Other choices |
| --- | --- | --- |
| Start / stop dictation | Double Command | Any recorded shortcut, Disabled |
| Cycle recognition mode | Off | Any recorded shortcut |

## Privacy

- Speech recognition runs locally, either through llama.cpp with Metal or the on-device recognizer built into macOS.
- NoType does not use a remote transcription API.
- R2T2 downloads its model files once, from a pinned revision of the [Confucius4-R2T2 GGUF files](https://huggingface.co/mradermacher/Confucius4-R2T2-GGUF) on Hugging Face, and only into NoType's shared `~/Documents/huggingface` model folder. The macOS Speech engine may ask macOS to install a system language model the first time a language is used. No audio is ever uploaded.
- Temporary audio is removed after transcription succeeds or fails.
- There are no accounts, analytics, or telemetry in the app.
- Microphone access is used only for active dictation.
- Accessibility access is used for global keyboard shortcuts, focused-target capture, and text insertion.
- The clipboard is touched only when the selected output mode or an insertion fallback requires it.

## Current release

NoType `0.4.0` is available as an Apple Silicon archive from the
[`v0.4.0`](https://github.com/ycl-2004/NoType/releases/tag/v0.4.0)
release.

| Artifact | Purpose |
| --- | --- |
| `NoType-0.4.0-arm64.zip` | Ready-to-run app; the speech model is downloaded on first use |
| `NoType-0.4.0-arm64.zip.sha256` | SHA-256 checksum for download verification |

Speech models are not committed to this repository and are not bundled in the
archive. 0.4.0 predates the engines described above: its local engines are
Qwen3-ASR 0.6B INT8 and SenseVoice Small, downloaded from the sherpa-onnx GitHub
releases, and it has no R2T2. R2T2 as the only local engine is unreleased; see
the [changelog](CHANGELOG.md).

## FAQ

<details>
<summary>macOS says NoType cannot be opened because the developer cannot be verified</summary>

The current release is ad-hoc signed and not Apple-notarized. Control-click
`NoType.app`, choose **Open**, and confirm once. You can also run the `xattr`
command shown in [Quick start](#quick-start).

</details>

<details>
<summary>Why can the first dictation take a while?</summary>

The first time R2T2 is used, NoType downloads its model — roughly 1.5 GB — and
checks it against the publisher's SHA-256 hashes. NoType keeps running while this
happens and shows the real state under **Diagnostics → Speech Model**. The
download goes into `~/Documents/huggingface/models/mradermacher/Confucius4-R2T2-GGUF`,
so it is shared across NoType builds and is not repeated when you replace the app.
After that, a launch only loads the model; the files are hashed again only when
they change on disk.

</details>

<details>
<summary>How much will NoType actually download?</summary>

The app itself is small. R2T2 adds roughly 1.5 GB the first time it is used. The
download happens once per Mac rather than once per app version, and nothing is
downloaded at all if you select macOS Speech and only use 中文優先 or English.
The trade is that a brand-new install needs a network connection before its first
R2T2 dictation; every dictation after that is fully offline.

</details>

<details>
<summary>Where do local models get stored, and can I remove them?</summary>

The R2T2 model lives in one shared Hugging Face folder:

```text
~/Documents/huggingface/models/mradermacher/
  Confucius4-R2T2-GGUF/
```

NoType never creates a second copy in Application Support or inside the app
bundle, so replacing the app leaves your downloads alone and a development
machine keeps one copy rather than one per build.

**Engine → Manage Downloaded Models** removes exactly that folder after
confirmation. It does not remove macOS Speech assets, the signed app bundle, or
unrelated Hugging Face models sitting in the same directory. Downloaders reject
paths outside `~/Documents/huggingface`, including symlinks that resolve outside it.

</details>

<details>
<summary>Which engine should I use?</summary>

Use **R2T2 Streaming**, the default. It handles every mode, including mixed
Chinese and English, and does most of its work while you speak.

Switch to **macOS Speech (fast)** on macOS 26 if you mostly dictate in one
language and want the system recognizer for 中文優先 and English. Auto still uses
R2T2, so mixed speech keeps working.

</details>

<details>
<summary>Why does Auto ignore my engine choice?</summary>

Auto asks the engine to work out which language is being spoken. R2T2 can do
that. The macOS recognizer is built for one language at a time,
so forcing Auto through it would apply a single language to the whole recording
and transliterate the rest — Chinese spoken into an English model comes back as
pinyin.

NoType routes Auto to R2T2 when macOS Speech is selected and says so in the menu:
`Engine: macOS Speech (fast) → R2T2 Streaming`.

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
access to the system recognizer, not a network service. R2T2 does not use it.

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

## Resource management

R2T2 commits bounded audio segments and reuses their results; only the current tail is previewed.
Long recordings are split rather than silently returned at a token limit. The current engine stays
loaded; using a different engine releases the previous model, so switching back costs a cold load.
R2T2 downloads are pinned and checked against publisher SHA-256 hashes before loading. Diagnostics
explain how to remove and retry a damaged download.

Debug logs are capped at 2 MiB, with up to five days retained. Temporary recordings are deleted
after each attempt, including capture failures. Changed-target clipboard fallback is unchanged;
clipboard managers may retain copied transcripts.

After finishing development tests and packaging, run `./scripts/clean_development.sh` to remove
build caches and old release ZIPs while keeping `dist/NoType.app` and shared models. The next build
recreates caches and may redownload dependencies. See [ADR-011](docs/decisions/011-r2t2-resource-and-reliability.md)
for the behavior, tradeoffs and real-model validation.

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

This creates `dist/NoType.app`. No model is copied into it — `R2T2Paths` resolves
one fixed directory under `~/Documents/huggingface/models/mradermacher/`, and the
app downloads into it on first use. Keeping models outside the bundle means replacing the app never moves a
model path, and a development machine stores one copy rather than one per build.

Build the release archive:

```bash
./scripts/build_release.sh
```

The packaging script builds the current checkout, signs the whole app bundle, and
creates:

```text
dist/NoType.app
dist/NoType-0.4.0-arm64.zip
dist/NoType-0.4.0-arm64.zip.sha256
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
- `Sources/Typeless/Transcription/` — the two engines, the router that chooses between them, the model installer, segment joining, and transcript cleanup.
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
- The R2T2 model is downloaded on first use rather than bundled, so a new install needs a network connection before its first R2T2 dictation.
- Hotwords help R2T2 with distinctive names and terms but not with terms that sound like ordinary words, such as "parser" heard as "parse".
- Recordings longer than 24 seconds are decoded in segments. Punctuation at a cut is approximated: a segment's closing `。` becomes `，`.
- The macOS Speech engine requires macOS 26 or later and cannot detect the spoken language, so Auto uses R2T2 when macOS Speech is selected.
- The macOS Speech engine has no custom-vocabulary list yet, so proper nouns spoken inside another language can be transliterated rather than spelled.

## Documentation

- [Changelog](CHANGELOG.md) — shipped user-facing changes.
- [Known issues](docs/known-issues.md) — understood limitations and future directions.
- [ADR-001: Configurable shortcut input](docs/decisions/001-configurable-shortcut-input.md) — the original shortcut design, now superseded.
- [ADR-002: Portable release packaging](docs/decisions/002-portable-release-packaging.md) — why releases originally bundled the model instead of downloading it at runtime. Superseded by ADR-008.
- [ADR-003: Local model readiness](docs/decisions/003-local-model-readiness.md) — why Diagnostics reports Preparing / Ready / Failed rather than a percentage.
- [ADR-004: Two-engine routing](docs/decisions/004-two-engine-routing.md) — why the original two engines are kept and why macOS Speech mixed mode uses the multilingual local model.
- [ADR-005: Model location strategy](docs/decisions/005-model-location-strategy.md) — why install locations were searched before the app bundle, and why a download asked first. Superseded by ADR-008.
- [ADR-006: SenseVoice engine and model storage](docs/decisions/006-sensevoice-engine-and-model-storage.md) — the shared model folder and why model deletion cannot touch macOS Speech. The SenseVoice engine itself was removed by ADR-012.
- [ADR-007: User-recorded shortcuts](docs/decisions/007-user-recorded-shortcuts.md) — how arbitrary shortcuts, left/right modifiers, multiple bindings, and defaults work.
- [ADR-008: Qwen3-ASR replaces Whisper](docs/decisions/008-qwen3-asr-replaces-whisper.md) — why no model is bundled, and the measurements behind the 24-second segment limit. The Qwen3-ASR engine itself was removed by ADR-012.
- [ADR-009: Optional voice overlay](docs/decisions/009-voice-overlay.md) — the target-safe overlay, waveform, and result timing behavior.
- [ADR-010: R2T2 streaming engine](docs/decisions/010-r2t2-streaming-engine.md) — internal streaming, the 320 ms first cadence, and strict Hugging Face model storage.
- [ADR-011: R2T2 resources and reliability](docs/decisions/011-r2t2-resource-and-reliability.md) — bounded segments, preview back-off, pinned and verified model files.
- [ADR-012: R2T2 is the only local engine](docs/decisions/012-r2t2-only-local-engine.md) — why Qwen3-ASR and SenseVoice were removed and how saved preferences migrate.
- [ADR-013: R2T2 prompt template and hotword list](docs/decisions/013-r2t2-prompt-and-hotwords.md) — the trained prompt layout, the hotword file, and the measurements behind both.

## Third-party terms

R2T2 runs through the [llama.cpp](https://github.com/ggml-org/llama.cpp)
XCFramework and uses GGUF conversions, published by mradermacher, of the
[Confucius4-R2T2](https://github.com/netease-youdao/Confucius4-R2T2) model. The
model weights are under the NetEase Model Use License Agreement; the R2T2 code is
Apache 2.0. WhisperKit and sherpa-onnx are no longer dependencies.
