# NoType

macOS 菜单栏听写工具。按快捷键说话，转写后插入当前光标位置。语音全程不离开本机。
Swift 6.1 + SwiftPM，无 Xcode 工程文件。仓库目录名是 `Typeless`，产品名是 `NoType`。

## 跑起来

```bash
swift build          # 构建
swift test           # 全量测试，约 1 秒
./scripts/build_app.sh   # 打成 dist/NoType.app
```

**`swift test --filter` 会弄坏构建**（known-issues #8）。它会在 `Vendor/WhisperKit-main/`
下另建一个 `.build`，把无法编译的 vendored 测试目标拉进依赖图，之后连不带 filter 的
`swift test` 也一起失败。恢复：`rm -rf Vendor/WhisperKit-main/.build`。
**一律不带 filter 跑全量。** 用 `swift build --package-path Vendor/... --scratch-path` 也
救不了，SwiftPM 仍会在包根建 `.build`，用完要手动删。

## 技术栈与结构

三个转写引擎，`RoutingTranscriptionEngine` 按次路由：

- **macOS Speech**（`SpeechTranscriber`，需 macOS 26）：快约 10 倍，但**一个实例只能绑一个
  locale，无法检测语言**（SDK 硬限制，见 ADR-004）。
- **Bundled Whisper**（WhisperKit + Core ML，`large-v3-turbo`，float16 未量化）。
- **SenseVoice Small**（sherpa-onnx + ONNX，支持中文、粤语、英语、日语、韩语）。
- **`Auto (中英混说)` 使用所选的本地模型**；只有选择 macOS Speech 时才为混合语言回退到 Whisper。

```
Sources/Typeless/
  Coordinator/    听写状态机
  Transcription/  三个引擎 + 路由 + 后处理
  Audio/          AVAudioRecorder，16kHz 单声道 WAV
  Accessibility/  插入文本，失败退回剪贴板
  Hotkey/         全局快捷键与双击修饰键
Vendor/WhisperKit-main/   vendored 依赖，不要改
```

## 约定

- **下载的模型不进仓库。** Whisper 的共享下载目录 `~/Documents/huggingface` 排在 app
  bundle **之前**；SenseVoice 只下载到 `~/Documents/huggingface/models/k2-fsa`。bundle
  内路径每次重建都变，会作废 Core ML 特化缓存（实测 4s → 4m13s）。见 ADR-005、ADR-006。
- **删除模型只删除 NoType 自己下载的目录。** 菜单里的模型管理不会调用 macOS Speech
  的系统资产 API，也不会修改 app bundle 或其他 Hugging Face 模型。
- **本地安装不要 `INCLUDE_MODEL=1`**，那是发给别人的 release 才用的（ADR-002）。
- 覆盖 `/Applications` 前必须用开发证书签名，否则 designated requirement 变化，
  麦克风/辅助功能/语音识别权限全部重置。
- 改动前先读 `docs/known-issues.md`——里面记着已知缺陷和**明确决定不修的理由**，
  别把有意为之的行为当 bug 修掉。
- 决策写成 ADR 放 `docs/decisions/`，用户可见的变更写 `CHANGELOG.md`。

## 当前状态

已发布 0.3.0。`[Unreleased]` 中：三引擎路由、本地模型就绪状态、以及一批 Whisper 延迟
优化（尾部静音裁剪、VAD 分块、温度回退封顶）。

下一步最有价值的是**流式转写**：目前是批处理，全部解码时间都落在用户松手之后，
等待随说话时长线性增长；竞品边说边解码所以等待恒定。见 known-issues #7。
