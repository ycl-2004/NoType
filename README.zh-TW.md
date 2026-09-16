<p align="center">
  <img src="App_Icon.png" alt="NoType 圖示" width="120" height="120">
</p>

<h1 align="center">NoType</h1>

<p align="center">
  <strong>macOS 上的私密本機聽寫工具——自然說話，繼續打字。</strong>
</p>

<p align="center">
  <a href="https://github.com/ycl-2004/NoType/releases/latest"><img src="https://img.shields.io/github/v/release/ycl-2004/NoType?label=release&amp;color=111111" alt="最新版本"></a>
  <a href="https://github.com/ycl-2004/NoType/releases"><img src="https://img.shields.io/github/downloads/ycl-2004/NoType/total?label=downloads&amp;color=111111" alt="累計下載"></a>
  <img src="https://img.shields.io/badge/macOS-15.0%2B-111111?logo=apple&amp;logoColor=white" alt="macOS 15.0 或更高版本">
  <img src="https://img.shields.io/badge/Mac-Apple%20Silicon-111111?logo=apple&amp;logoColor=white" alt="Apple Silicon Mac">
  <img src="https://img.shields.io/badge/Swift-sherpa--onnx%20%C2%B7%20ONNX%20Runtime-F05138?logo=swift&amp;logoColor=white" alt="使用 Swift、sherpa-onnx 與 ONNX Runtime 建構">
</p>

<p align="center">
  <a href="https://github.com/ycl-2004/NoType/releases/latest/download/NoType-0.4.0-arm64.zip"><strong>⬇ 下載 macOS 版</strong></a>
  ·
  <a href="https://github.com/ycl-2004/NoType/releases">版本發佈</a>
  ·
  <a href="#功能">功能</a>
  ·
  <a href="#隱私">隱私</a>
  ·
  <a href="#從原始碼建構">從原始碼建構</a>
  ·
  <a href="README.md">English</a>
</p>

NoType 是原生 macOS 選單列聽寫工具。先將游標放進文字欄位，開始聽寫、說話、停止；NoType
會在本機把語音轉成文字，再插回你正在使用的 App。

NoType 目前提供三個裝置端引擎，會在每次聽寫時選擇其中一個：

- **macOS Speech**（macOS 26 或更高版本）使用系統內建的裝置端辨識器。速度大約比本機模型快一個
  數量級，不會翻譯，也不會自行補上字幕式結尾；代價是一次只能辨識一種指定語言。
- **Qwen3-ASR 0.6B INT8** 是透過 sherpa-onnx 執行的多語言本機模型。它會自行判斷說話語言，
  因此可以處理中英混說。第一次使用時，模型會下載到共用的
  `~/Documents/huggingface/models/k2-fsa` 資料夾。
- **SenseVoice Small** 是可選的本機 ONNX 模型，支援中文、粵語、英文、日文與韓文。選用後會下載
  到共用的 `~/Documents/huggingface/models/k2-fsa` 資料夾。

三個引擎都不會把音訊傳到任何地方。NoType 沒有帳號，也沒有遠端轉寫 API。

## 快速開始

1. **[下載 `NoType-0.4.0-arm64.zip`](https://github.com/ycl-2004/NoType/releases/latest/download/NoType-0.4.0-arm64.zip)** 並解壓縮。套件不內含語音模型，App 會在第一次使用時下載。
2. 將 `NoType.app` 移到 `/Applications`。第一次啟動時，請按住 Control 點按 App，選擇**開啟**——目前版本是 ad-hoc 簽名，尚未經 Apple 公證。
3. 授予錄音所需的**麥克風**權限，以及全域快捷鍵和直接插入文字所需的**輔助使用**權限。macOS 26 或更高版本還要授予**語音辨識**權限，NoType 才能使用系統的裝置端辨識器。

接著把游標放進任意文字欄位，連按兩下 **Command** 開始。再連按兩下即可停止、轉寫並插入結果。

實際準備時間取決於目前使用的引擎。macOS Speech 會在第一次使用某種語言時下載系統語言模型，通常只需幾秒。Qwen3-ASR 第一次使用時會下載約 1 GB 的 ONNX 封存檔；SenseVoice 若尚未存在共用 Hugging Face 資料夾，會下載約 230 MB。開啟 **NoType → 診斷**，即可看到 **Speech Model: Preparing**、**Ready** 或 **Failed**，不必讀除錯日誌。下載的模型由不同 NoType 版本共用，替換 App 時仍會保留。日後不需要時，可用 **Engine → Manage Downloaded Models** 移除 NoType 下載的 Qwen3-ASR 或 SenseVoice 副本。

如果 Control 點按後沒有**開啟**選項，請手動清除隔離標記：

```bash
xattr -dr com.apple.quarantine /Applications/NoType.app
open /Applications/NoType.app
```

### 系統需求

- Apple Silicon Mac（`arm64`）
- macOS 15.0 或更高版本；使用 macOS Speech 引擎需要 macOS 26 或更高版本
- 約 3 GB 可用空間，用於 App 與一個下載的本機模型
- 錄音需要麥克風權限
- 全域鍵盤快捷鍵與直接插入文字需要輔助使用權限
- macOS Speech 引擎在 macOS 26 或更高版本需要語音辨識權限

## 為什麼是 NoType

- **語音留在你的 Mac 上。** 三個引擎都在裝置端執行；每次嘗試結束後會刪除暫存錄音。
- **中文和英文可以出現在同一句話裡。** 自動混合辨識專門處理語碼切換，也提供中文優先與英文優先模式，讓你在需要時加強偏向。
- **能快就快。** 在 macOS 26 上，單一語言的聽寫會交給系統辨識器，完成時間只需本機模型的一小部分。
- **自己選擇取捨。** Qwen3-ASR 與 SenseVoice 都按需下載，並從共用的 Hugging Face 資料夾重複使用，所以 App 本身可以保持精簡。
- **回到正確位置。** NoType 會記住聽寫開始時的文字輸入目標。如果目標改變，則把轉寫結果留在剪貼簿，不會插入錯誤的欄位。
- **不打擾工作。** 一般使用不需要開啟視窗；狀態、模式、權限、快捷鍵與診斷都在選單列中完成。

## 功能

**聽寫**

- 從任何 App 以可自訂的鍵盤快捷鍵開始與停止。預設是連按兩下 Command，也支援一般按鍵、修飾鍵組合，以及左右修飾鍵。
- 五分鐘自動錄音上限，避免遺留的工作階段無限執行。
- 太短的誤觸錄音會直接忽略，不會送進轉寫流程。
- App 啟動後會在背景準備轉寫模型，減少第一次使用的等待時間。
- 診斷頁會顯示本機模型正在準備、已就緒或失敗；準備失敗時可以直接重試。

**引擎**

- 從選單列選擇 **macOS Speech (fast)**、**Qwen3-ASR 0.6B INT8** 或 **SenseVoice Small**；選擇會跨次啟動保留。
- **Auto (中英混說)** 使用選定的本機模型。如果選擇 macOS Speech，選單會顯示混合語言覆寫路徑：`macOS Speech → Qwen3-ASR 0.6B INT8`。
- **中文優先** 和 English 會遵循選定的引擎。
- 在 macOS 15 上，macOS Speech 選項不可用，所有模式都使用 Qwen3-ASR。
- 只有真正需要本機模型的聽寫才會載入模型；持續使用 macOS Speech 時不會承擔本機模型的啟動成本。
- **Manage Downloaded Models** 位於引擎選單下。確認後只會移除 NoType 自己下載的 Qwen3-ASR 與 SenseVoice 資料夾；macOS Speech 資產交由 macOS 管理。

**辨識**

- **Auto (中英混說)** 適合自然的中英混合語音。
- **中文優先** 與 **English** 適合有明確語言偏向的辨識。
- 可選擇跟隨模型、簡體中文或繁體中文輸出字形。
- 可選用快捷鍵循環切換辨識模式，不必開啟選單；預設關閉。

**文字傳送**

- 成功轉寫後可選擇插入並複製、只插入，或只複製。
- 透過輔助使用直接插入；遇到不提供相容文字欄位的 App 時，會退回貼上。Terminal、Ghostty 和 iTerm2 會貼回原本聚焦的終端機；如果你在此期間切換分頁或欄位，NoType 會避免貼到另一個目標。
- 捕獲目標保護可防止完成的轉寫結果落入另一個聊天或文件。
- 只插入模式需要模擬貼上時，會保留原本的剪貼簿內容。

**選單列控制**

- 即時顯示閒置、錄音、轉寫、插入與錯誤狀態。
- **Show Voice Overlay** 可在開始聽寫的螢幕底部中央顯示精簡的深色膠囊。錄音時立即出現，會回應麥克風音量，並持續顯示到轉寫完成，不會取得鍵盤焦點。
- **Overlay Timing** 可分別設定完成與失敗提示的顯示時間，範圍為 0 到 5 秒，預設都是 1.5 秒。設為 0 會隱藏該類提示；錄音和轉寫進行時仍會顯示。設定會保留，修改後也會套用到目前的倒數。短標籤包括 `輸入中…`、`轉寫中…`、`已插入`、`已複製` 和 `插入失敗`；詳細錯誤仍會留在選單中。
- 選單列圖示顯示辨識狀態與中文字形標記。
- 聽寫與辨識模式快捷鍵可自訂，並會跨次啟動保留。
- 可查看權限狀態、最近一次診斷事件和本機除錯日誌。日誌只保留最近五天；每次 NoType 寫入活動或開啟日誌時都會修剪。

## 使用方式

1. 把游標放在要插入轉寫結果的位置。
2. 連按兩下 **Command** 開始錄音。
3. 自然說話。預設模式支援中英混說。
4. 再連按兩下 **Command** 停止。
5. NoType 在本機轉寫，回到捕獲的 App，並依照你選定的成功模式插入或複製結果。

點選選單列圖示可變更引擎、辨識模式、中文字形、輸出方式、浮層顯示與時間、快捷鍵和權限。

| 辨識模式 | 選擇 macOS Speech | 選擇 Qwen3-ASR | 選擇 SenseVoice Small |
| --- | --- | --- | --- |
| Auto (中英混說) | Qwen3-ASR 0.6B INT8 | Qwen3-ASR 0.6B INT8 | SenseVoice Small |
| 中文優先 | macOS Speech | Qwen3-ASR 0.6B INT8 | SenseVoice Small |
| English | macOS Speech | Qwen3-ASR 0.6B INT8 | SenseVoice Small |

快捷鍵位於選單列的 **Shortcuts** 下。選擇 **Add Shortcut…**，即可錄製一般按鍵、Command、Option、Control、Shift、Fn 的任意組合，或單獨的修飾鍵。每個動作可以設定多個快捷鍵，每個快捷鍵也可以設定單擊或快速連按兩下。

預設值如下：

| 動作 | 預設值 | 其他選項 |
| --- | --- | --- |
| 開始／停止聽寫 | 連按兩下 Command | 任意已錄製快捷鍵、停用 |
| 循環切換辨識模式 | 關閉 | 任意已錄製快捷鍵 |

## 隱私

- 語音辨識完全在本機執行，使用 sherpa-onnx 與 ONNX Runtime，或 macOS 內建的裝置端辨識器。
- NoType 不使用遠端轉寫 API。
- Qwen3-ASR 與 SenseVoice 各自只在被選用時，從 sherpa-onnx 官方發佈封存檔下載一次模型。macOS Speech 第一次使用某種語言時，可能請 macOS 安裝系統語言模型；該模型由 macOS 管理、與所有 App 共用，並儲存在 App 外部。音訊永遠不會上傳。
- 轉寫成功或失敗後會刪除暫存音訊。
- App 沒有帳號、分析或遙測。
- 麥克風只在正在聽寫時使用。
- 輔助使用權限用於全域鍵盤快捷鍵、捕獲聚焦目標與插入文字。
- 剪貼簿只在你選擇的輸出模式或插入退回路徑需要時使用。

## 目前版本

NoType `0.4.0` 已在 [`v0.4.0`](https://github.com/ycl-2004/NoType/releases/tag/v0.4.0) 發佈，提供 Apple Silicon 封存檔。

| 產物 | 用途 |
| --- | --- |
| `NoType-0.4.0-arm64.zip` | 可直接執行的 App；語音模型會在第一次使用時下載 |
| `NoType-0.4.0-arm64.zip.sha256` | 用於驗證下載內容的 SHA-256 校驗檔 |

語音模型不會提交到此儲存庫，也不會打包進封存檔。NoType 會在第一次使用時從 sherpa-onnx 官方發佈下載選定的模型。引擎與模型的最新變更請見 [變更記錄](CHANGELOG.md)。

## 常見問題

<details>
<summary>macOS 顯示無法開啟 NoType，因為無法驗證開發者</summary>

目前發佈版是 ad-hoc 簽名，尚未經 Apple 公證。按住 Control 點按 `NoType.app`，選擇**開啟**並確認一次。也可以執行[快速開始](#快速開始)中的 `xattr` 指令。

</details>

<details>
<summary>為什麼第一次聽寫可能需要等待？</summary>

第一次使用本機引擎時，NoType 會下載其模型：Qwen3-ASR 約 1 GB，SenseVoice 約 230 MB。下載期間 NoType 仍會執行，並在 **診斷 → Speech Model** 顯示實際狀態。模型會放在 `~/Documents/huggingface/models/k2-fsa`，因此不同 NoType 版本共用同一份下載內容，替換 App 時不會重複下載。之後載入模型只需幾秒。

</details>

<details>
<summary>NoType 實際會下載多少內容？</summary>

App 本身很小。本機引擎只會在第一次使用時加入模型：Qwen3-ASR 0.6B INT8 約 1 GB，SenseVoice Small 約 230 MB。只會下載你實際選用的引擎，每台 Mac 每個模型只下載一次，不會每個 App 版本各下載一份；如果始終使用 macOS Speech，則完全不會下載本機模型。代價是全新安裝在第一次本機聽寫前需要網路連線；之後每次聽寫都可完全離線。

</details>

<details>
<summary>本機模型儲存在哪裡？可以移除嗎？</summary>

兩個本機模型都位於同一個共用資料夾，各自使用固定路徑：

```text
~/Documents/huggingface/models/k2-fsa/
  sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25/
  sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17/
```

NoType 不會在 Application Support 或 App bundle 中建立第二份副本，因此替換 App 不會影響下載內容；開發機器也只保留一份，而不是每次建構一份。

**Engine → Manage Downloaded Models** 會在確認後精確移除這兩個資料夾。不會移除 macOS Speech 資產、已簽名的 App bundle，或同一資料夾中的其他 Hugging Face 模型。

</details>

<details>
<summary>我應該使用哪個引擎？</summary>

如果你使用 macOS 26，將引擎留在 **macOS Speech (fast)** 即可。單一語言聽寫幾乎立即完成，而 Auto 仍會自行退回 Qwen3-ASR，所以中英混說仍能正常運作。

如果你希望所有模式都使用同一引擎、想比較兩者的輸出品質，或系統辨識器經常誤判你使用的專有詞彙，請切換到 **Qwen3-ASR 0.6B INT8**。

如果你想要較小的可選本機模型，用於中文、粵語、英文、日文或韓文，可以選擇 **SenseVoice Small**。它適合拿來比較中文與多語言聽寫，但在此 App 的較長錄音上的品質與速度，仍需要在你的 Mac 上實測。

</details>

<details>
<summary>為什麼 Auto 會忽略我的引擎選擇？</summary>

Auto 會要求引擎自行判斷說話語言。Qwen3-ASR 與 SenseVoice 可以做到；macOS 辨識器則一次只針對一種語言，因此強行用它處理 Auto 會把整段錄音套用單一語言，其他內容可能被音譯成拼音。

當你選擇 macOS Speech 時，NoType 會把 Auto 路由到 Qwen3-ASR，並在選單顯示：`Engine: macOS Speech (fast) → Qwen3-ASR 0.6B INT8`。

</details>

<details>
<summary>使用 macOS Speech 時，是否必須一直留在文字欄位？</summary>

不需要。系統聽寫會輸入到當下取得焦點的控制項，所以它會把你留在同一個畫面。NoType 透過 `SpeechAnalyzer` 使用同一個底層辨識器，由 NoType 自己決定轉寫結果落點。開始聽寫後可以切換 App，再停止；結果仍會送到捕獲的欄位或剪貼簿。

</details>

<details>
<summary>為什麼 NoType 需要麥克風和輔助使用權限？</summary>

**麥克風**權限讓 NoType 在聽寫進行時錄音。**輔助使用**權限讓它觀察全域鍵盤快捷鍵、記住聚焦輸入、插入完成的轉寫結果。只複製輸出仍需要麥克風，但不需要直接插入文字。

macOS 26 或更高版本的 macOS Speech 引擎另需要**語音辨識**權限。辨識仍在裝置端進行；該權限控制的是系統辨識器的存取，不是網路服務。Qwen3-ASR 與 SenseVoice 不使用此權限。

</details>

<details>
<summary>轉寫時切換聊天或文字欄位會怎麼樣？</summary>

NoType 會嘗試回到聽寫開始時捕獲的輸入目標。如果該目標已不存在，就複製轉寫結果，而不冒險把文字插入另一個對話或文件。

</details>

<details>
<summary>如何解除安裝 NoType？</summary>

從選單列圖示退出 NoType，再把 `/Applications/NoType.app` 移到垃圾桶。你可以在**系統設定 → 隱私權與安全性 → 麥克風／輔助使用**中撤銷權限。

</details>

## 從原始碼建構

<details>
<summary>需求、建構指令與發佈封裝</summary>

需求：

- macOS 15.0 或更高版本
- 目前發佈封裝流程需要 Apple Silicon
- Swift 6.1 或相容的 Xcode 工具鏈

執行測試套件：

```bash
swift test
```

自 WhisperKit vendor checkout 移除後，`swift test --filter` 已恢復可用；過去它會直接破壞建構。

建立本機 App bundle：

```bash
./scripts/build_app.sh
```

這會建立 `dist/NoType.app`。模型不會複製進 App；`Qwen3ASRPaths` 與 `SenseVoicePaths` 都會解析到 `~/Documents/huggingface/models/k2-fsa/` 下的固定資料夾，第一次使用時才下載。模型放在 bundle 外，替換 App 時不會移動模型路徑；開發機器也只保留一份，而不是每個建構各一份。

建立發佈封存檔：

```bash
./scripts/build_release.sh
```

封裝腳本會建構目前 checkout、簽名整個 App bundle，並建立：

```text
dist/NoType.app
dist/NoType-0.4.0-arm64.zip
dist/NoType-0.4.0-arm64.zip.sha256
```

預設簽名是 ad-hoc。若要使用已安裝的 Developer ID 身分：

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./scripts/build_release.sh
```

腳本會使用 `codesign --verify --deep --strict` 驗證簽名。公證流程目前尚未自動化；要把建構當成公開、公證版本前，請另外遵循 Apple 的 macOS 發佈指引。

</details>

## 專案結構

- `Sources/Typeless/Audio/` — 麥克風擷取與暫存錄音片段。
- `Sources/Typeless/Transcription/` — 三個引擎、引擎路由、模型安裝器與轉寫清理。
- `Sources/Typeless/Accessibility/` — 聚焦目標擷取、直接插入、剪貼簿處理與貼上退回。
- `Sources/Typeless/Coordinator/` — 聽寫狀態轉移與流程協調。
- `Sources/Typeless/App/` — 選單列 UI、權限、診斷與 App 生命週期。
- `Sources/Typeless/Hotkey/` — 快捷鍵錄製、AppKit 事件監看與按鍵方式判斷。
- `Tests/TypelessTests/` — 轉寫、協調、快捷鍵、狀態、權限與選單呈現的單元測試。
- `Packaging/Info.plist` — App 身分、版本、權限說明與最低 macOS 版本。
- `scripts/` — 本機 App 與自包含發佈建構腳本。
- `docs/decisions/` — 產品與工程決策記錄。

## 已知限制

- 可下載的發佈版目前只支援 Apple Silicon。
- 需要 macOS 15.0 或更高版本。
- 目前公開建構是 ad-hoc 簽名，尚未經 Apple 公證。
- App 內沒有自動更新器；新版本需要手動安裝。
- 兩個本機模型都在第一次使用時下載，而不是打包進 App；全新安裝在第一次本機聽寫前需要網路連線。
- Qwen3-ASR 最近取代 Whisper；它在此 App 錄音上的轉寫品質與延遲，尚未與被取代的引擎做裝置端比較。
- SenseVoice 支援中文、粵語、英文、日文與韓文。上游直接推論路徑記載 30 秒輸入上限；NoType 的較長錄音流程仍需要真機驗證。
- macOS Speech 引擎需要 macOS 26 或更高版本，且無法判斷說話語言；選擇 macOS Speech 時，Auto 會使用 Qwen3-ASR。
- macOS Speech 目前沒有自訂詞彙表；在另一種語言中說出專有名詞時，可能會被音譯，而不是按預期拼寫。

## 文件

- [變更記錄](CHANGELOG.md) — 已發佈的使用者可見變更。
- [已知問題](docs/known-issues.md) — 已理解的限制與未來方向。
- [ADR-001：可自訂快捷鍵輸入](docs/decisions/001-configurable-shortcut-input.md) — 最初的快捷鍵設計，目前已被取代。
- [ADR-002：可攜式發佈封裝](docs/decisions/002-portable-release-packaging.md) — 最初把模型打包而非執行時下載的原因，目前已被 ADR-008 取代。
- [ADR-003：本機模型就緒狀態](docs/decisions/003-local-model-readiness.md) — 為什麼診斷頁顯示 Preparing／Ready／Failed，而不是百分比。
- [ADR-004：雙引擎路由](docs/decisions/004-two-engine-routing.md) — 最初兩個引擎的保留原因，以及 macOS Speech 混合模式使用多語言本機模型的原因。
- [ADR-005：模型位置策略](docs/decisions/005-model-location-strategy.md) — 為什麼會先搜尋安裝位置，及下載前為何需要詢問；目前已被 ADR-008 取代。
- [ADR-006：SenseVoice 引擎與模型儲存](docs/decisions/006-sensevoice-engine-and-model-storage.md) — SenseVoice 為何採附加方式加入、共用模型的位置，以及刪除模型不能碰 macOS Speech 的原因。
- [ADR-007：使用者錄製的快捷鍵](docs/decisions/007-user-recorded-shortcuts.md) — 任意快捷鍵、左右修飾鍵、多重綁定與預設值的運作方式。
- [ADR-008：Qwen3-ASR 取代 Whisper](docs/decisions/008-qwen3-asr-replaces-whisper.md) — 本機引擎更換原因、模型不再打包的原因，以及仍未測量的部分。

## 第三方條款

兩個本機引擎都透過 [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) Swift 套件及其 ONNX Runtime 相依套件執行，並使用 sherpa-onnx 專案發佈的模型封存檔：Qwen3-ASR 0.6B INT8 與 SenseVoice Small。NoType 舊版本曾使用 WhisperKit，目前已不再是相依套件。

## 授權

此儲存庫目前沒有 `LICENSE` 檔案。在作者補充授權條款前，不應假定可以複製、修改、再發佈、重新命名或商業使用此專案。
