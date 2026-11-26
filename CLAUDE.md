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

两个转写引擎，`RoutingTranscriptionEngine` 按次路由：

- **R2T2 Streaming**（默认，唯一的本地模型。Confucius4-R2T2 Q4_K_M GGUF + Q8_0 投影器，
  llama.cpp + Metal）：有道在 Qwen3-ASR-1.7B 上训练的流式模型。边录边转，文字只进内部
  缓冲，松手后走同一个插入流程；录音超过 24 秒按停顿切段。见 ADR-010、ADR-011、ADR-012。
- **macOS Speech**（`SpeechTranscriber`，需 macOS 26）：单语言更快、不用下载，但**一个实例
  只能绑一个 locale，无法检测语言**（SDK 硬限制，见 ADR-004）。
- **`Auto (中英混说)` 和 macOS 15 上的所有模式都走 R2T2**，且照样流式。Qwen3-ASR 和
  SenseVoice 已删除，旧偏好值读成 R2T2（ADR-012）。

```
Sources/Typeless/
  Coordinator/    听写状态机
  Transcription/  两个引擎 + 路由 + 模型安装 + 分段拼接 + 后处理
  Audio/          AVAudioRecorder / AVAudioEngine（流式），16kHz 单声道 WAV
  Accessibility/  插入文本，失败退回剪贴板
  Hotkey/         全局快捷键、双击修饰键；录音和转写期间 Esc 取消（CGEventTap）
```

## 约定

- **模型不进仓库，也不进 app bundle。** R2T2 首次使用时下载到
  `~/Documents/huggingface/models/mradermacher/Confucius4-R2T2-GGUF/`（Hugging Face 固定
  revision，校验发布方 SHA-256）。放在 bundle 外是为了让替换 app 不会移动模型路径。
- **删除模型只删除 NoType 自己下载的 R2T2 目录。** 菜单里的模型管理不会调用 macOS Speech
  的系统资产 API，也不会碰 app bundle 或同目录下其他 Hugging Face 模型。
- 覆盖 `/Applications` 前必须用开发证书签名，否则 designated requirement 变化，
  麦克风/辅助功能/语音识别权限全部重置。本机用 YC 自己账号的证书「Apple Development …
  (5AGX9CFNPL)」，团队 BQYHJCCRMP：
  `CODESIGN_IDENTITY=68E2393709CD7141C4791351A029F486D4E7E60E ./scripts/build_app.sh`，
  然后退出 NoType、用 `dist/NoType.app` 替换 `/Applications/NoType.app` 再打开。
- 改动前先读 `docs/known-issues.md`——里面记着已知缺陷和**明确决定不修的理由**，
  别把有意为之的行为当 bug 修掉。
- 决策写成 ADR 放 `docs/decisions/`，用户可见的变更写 `CHANGELOG.md`。

## 当前状态

已发布 0.4.0（本地引擎还是 Qwen3-ASR 和 SenseVoice）。`main` 上的未发布改动见
`CHANGELOG.md` 的 Unreleased：R2T2 成为唯一本地引擎、热词、Esc 取消、浮窗简化、分段标点
修复、R2T2 启动校验按文件身份缓存。`/Applications` 里装的是 `main` 当前代码的开发证书签名版。

日常使用的引擎是 R2T2：2026-11-26 一次 86 秒听写，松手后约 1 秒插入（日志秒级精度）。
已实测、不再重做的两件事：苹果系统模型做语义清洗不够用（known-issues #6）；Q8 不比 Q4 准，
错误集中在专有名词（known-issues #5）。

R2T2 提示词按模型自己的聊天模板构造，热词来自 `~/Library/Application Support/NoType/hotwords.txt`
（ADR-013）。实测「中文优先」模式下热词效果明显好于 Auto，专有名词和大小写基本都对；parser
在两种模式下都还会错（known-issues #5）。改提示词或热词格式时，用 known-issues #5 里的 5 段
录音做前后对比。

识别后的文字替换表（错写法 → 正确写法）暂缓：YC 从 2026-11-26 起用「中文优先」+ 热词观察几天，
攒到 3–5 个热词修不好、每次错法都一样的词再做。get、parse、全文这类本身是常用词的错写法不能
进替换表，会误改正常的话。
