# NoType

macOS 菜单栏听写工具。按快捷键说话，转写后插入当前光标位置。语音全程不离开本机。
Swift 6.1 + SwiftPM，无 Xcode 工程文件。仓库目录名是 `Typeless`，产品名是 `NoType`。

## 跑起来

```bash
swift build          # 构建
swift test           # 全量测试，约 1 秒
./scripts/build_app.sh   # 打成 dist/NoType.app
```

`swift test --filter` 现在可以用。它以前会弄坏构建（原 known-issues #8），根因是
`Vendor/WhisperKit-main/` 被拉进依赖图；那个目录已随 WhisperKit 一起删除。

## 技术栈与结构

三个转写引擎，`RoutingTranscriptionEngine` 按次路由：

- **macOS Speech**（`SpeechTranscriber`，需 macOS 26）：快约 10 倍，但**一个实例只能绑一个
  locale，无法检测语言**（SDK 硬限制，见 ADR-004）。
- **Qwen3-ASR 0.6B INT8**（sherpa-onnx + ONNX）：多语种本地模型，自己检测语言，一次解码。
- **SenseVoice Small**（sherpa-onnx + ONNX，支持中文、粤语、英语、日语、韩语）。
- **`Auto (中英混说)` 使用所选的本地模型**；只有选择 macOS Speech 时才为混合语言回退到
  Qwen3-ASR。

```
Sources/Typeless/
  Coordinator/    听写状态机
  Transcription/  三个引擎 + 路由 + 模型安装 + 后处理
  Audio/          AVAudioRecorder，16kHz 单声道 WAV
  Accessibility/  插入文本，失败退回剪贴板
  Hotkey/         全局快捷键与双击修饰键
```

## 约定

- **模型不进仓库，也不进 app bundle。** Qwen3-ASR 和 SenseVoice 各自首次使用时下载到
  `~/Documents/huggingface/models/k2-fsa/` 下一个固定目录。放在 bundle 外是为了让替换 app
  不会移动模型路径。见 ADR-008、ADR-006。
- **删除模型只删除 NoType 自己下载的那两个目录。** 菜单里的模型管理不会调用 macOS Speech
  的系统资产 API，也不会碰 app bundle 或同目录下其他 Hugging Face 模型。
- 覆盖 `/Applications` 前必须用开发证书签名，否则 designated requirement 变化，
  麦克风/辅助功能/语音识别权限全部重置。
- 改动前先读 `docs/known-issues.md`——里面记着已知缺陷和**明确决定不修的理由**，
  别把有意为之的行为当 bug 修掉。
- 决策写成 ADR 放 `docs/decisions/`，用户可见的变更写 `CHANGELOG.md`。

## 当前状态

已发布 0.3.0。`[Unreleased]` 中：三引擎路由、本地模型就绪状态、用户自定义快捷键，以及
**用 Qwen3-ASR 0.6B INT8 替换 Whisper**（ADR-008）——WhisperKit 依赖和 `Vendor/` 目录
已删除，release 不再打包模型。

**Qwen3-ASR 的实际转写质量和延迟还没在设备上测过**，这是这条分支收尾前最该做的事。
之后最有价值的是**流式转写**：目前是批处理，全部解码时间都落在用户松手之后，等待随
说话时长线性增长；竞品边说边解码所以等待恒定。见 known-issues #7。
