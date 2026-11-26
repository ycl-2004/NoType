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
  <img src="https://img.shields.io/badge/Swift-llama.cpp%20%C2%B7%20Metal-F05138?logo=swift&amp;logoColor=white" alt="使用 Swift、llama.cpp 與 Metal 建構">
</p>

<p align="center">
  <a href="https://github.com/ycl-2004/NoType/releases/latest/download/NoType-0.5.0-arm64.zip"><strong>⬇ 下載 macOS 版</strong></a>
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

NoType 目前提供兩個裝置端引擎，會在每次聽寫時選擇其中一個：

- **R2T2 Streaming** 是本機模型：網易有道以 Qwen3-ASR-1.7B 訓練的串流語音模型
  Confucius4-R2T2，以 Q4_K_M GGUF 加 Q8_0 音訊投影器，透過 llama.cpp 與 Metal 執行。它會自行
  判斷說話語言，因此可以處理中英混說；而且邊說邊轉寫，停止前大部分工作已經完成。文字在你停止前
  只留在 NoType 的緩衝區，不會中途輸入到聚焦的欄位。模型只下載一次，放在
  `~/Documents/huggingface/models/mradermacher/Confucius4-R2T2-GGUF`。
- **macOS Speech**（macOS 26 或更高版本）使用系統內建的裝置端辨識器。不需要下載，單一語言聽寫
  更快；代價是一次只能辨識一種指定語言，所以 Auto 一律使用 R2T2。

兩個引擎都不會把音訊傳到任何地方。NoType 沒有帳號，也沒有遠端轉寫 API。

## 快速開始

1. **[下載 `NoType-0.5.0-arm64.zip`](https://github.com/ycl-2004/NoType/releases/latest/download/NoType-0.5.0-arm64.zip)** 並解壓縮。套件不內含語音模型，App 會在第一次使用時下載。
2. 將 `NoType.app` 移到 `/Applications`。第一次啟動時，請按住 Control 點按 App，選擇**開啟**——目前版本是 ad-hoc 簽名，尚未經 Apple 公證。
3. 授予錄音所需的**麥克風**權限，以及全域快捷鍵和直接插入文字所需的**輔助使用**權限。macOS 26 或更高版本還要授予**語音辨識**權限，NoType 才能使用系統的裝置端辨識器。

接著把游標放進任意文字欄位，連按兩下 **Command** 開始。再連按兩下即可停止、轉寫並插入結果。

R2T2 是預設引擎。第一次啟動時，NoType 會把約 1.5 GB 的模型與投影器下載到共用的 Hugging Face 資料夾，並用發佈者的 SHA-256 校驗；之後的啟動直接沿用。macOS Speech 會在第一次使用某種語言時下載系統語言模型，通常只需幾秒。開啟 **NoType → 診斷**，即可看到 **Speech Model: Preparing**、**Ready** 或 **Failed**，不必讀除錯日誌。下載的模型由不同 NoType 版本共用，替換 App 時仍會保留。日後不需要時，可用 **Engine → Manage Downloaded Models** 移除。

如果 Control 點按後沒有**開啟**選項，請手動清除隔離標記：

```bash
xattr -dr com.apple.quarantine /Applications/NoType.app
open /Applications/NoType.app
```

### 系統需求

- Apple Silicon Mac（`arm64`）
- macOS 15.0 或更高版本；使用 macOS Speech 引擎需要 macOS 26 或更高版本
- 約 2 GB 可用空間，用於 App 與 R2T2 模型
- 錄音需要麥克風權限
- 全域鍵盤快捷鍵與直接插入文字需要輔助使用權限
- macOS Speech 引擎在 macOS 26 或更高版本需要語音辨識權限

## 為什麼是 NoType

- **語音留在你的 Mac 上。** 兩個引擎都在裝置端執行；每次嘗試結束後會刪除暫存錄音。
- **中文和英文可以出現在同一句話裡。** 自動混合辨識專門處理語碼切換，也提供中文優先與英文優先模式，讓你在需要時加強偏向。
- **能快就快。** 在 macOS 26 上，單一語言的聽寫會交給系統辨識器，完成時間只需本機模型的一小部分。
- **說話時就在工作。** R2T2 在錄音期間轉寫，所以不論說多久，停止後的等待都很短。
- **回到正確位置。** NoType 會記住聽寫開始時的文字輸入目標。如果目標改變，則把轉寫結果留在剪貼簿，不會插入錯誤的欄位。
- **不打擾工作。** 一般使用不需要開啟視窗；狀態、模式、權限、快捷鍵與診斷都在選單列中完成。

## 功能

**聽寫**

- 從任何 App 以可自訂的鍵盤快捷鍵開始與停止。預設是連按兩下 Command，也支援一般按鍵、修飾鍵組合，以及左右修飾鍵。
- 錄音或轉寫時按 **Esc** 取消：錄音會刪除、不插入任何文字，剪貼簿也不變。NoType 會攔下這次 Esc，不會同時傳給目前的 App；搭配 Command、Option、Control 或 Shift 的 Esc 則照常傳遞。
- 五分鐘自動錄音上限，避免遺留的工作階段無限執行。
- 太短的誤觸錄音會直接忽略，不會送進轉寫流程。
- App 啟動後會在背景準備轉寫模型，減少第一次使用的等待時間。
- 診斷頁會顯示本機模型正在準備、已就緒或失敗；準備失敗時可以直接重試。

**引擎**

- 從選單列選擇 **R2T2 Streaming** 或 **macOS Speech (fast)**；選擇會跨次啟動保留。全新安裝預設使用 R2T2。
- R2T2 在錄音 320 毫秒後開始轉寫；超過 24 秒的錄音會在停頓處切段解碼。即時預覽只顯示在浮層，內容仍可能修正；停止後與 macOS Speech 使用同一套捕獲目標保護與輸出模式。
- **Auto (中英混說)** 一律使用 R2T2。如果選擇 macOS Speech，選單會顯示覆寫路徑：`macOS Speech (fast) → R2T2 Streaming`，這次聽寫仍會串流轉寫。
- **中文優先** 和 English 會遵循選定的引擎。
- 在 macOS 15 上，macOS Speech 選項不可用，所有模式都使用 R2T2。
- 只有真正需要 R2T2 的聽寫才會載入模型；單一語言模式持續使用 macOS Speech 時，不會承擔它的啟動成本。
- 引擎選單下的 **Edit Hotwords…** 會開啟一個純文字檔（`~/Library/Application Support/NoType/hotwords.txt`），一行一個詞。每次聽寫開始時 R2T2 會讀取這份清單，對獨特的人名與技術詞彙有幫助；發音接近一般詞彙的詞仍可能聽錯，清單裡的常用詞也可能在你沒說時被插入。
- **Manage Downloaded Models** 位於引擎選單下。確認後只會移除 NoType 自己下載的 R2T2 資料夾；macOS Speech 資產交由 macOS 管理。

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
- **Show Voice Overlay** 可在開始聽寫的螢幕底部中央顯示精簡的深色膠囊。錄音時只顯示隨麥克風音量變化的波形；開啟 **Show Live Transcript** 時，會在波形旁顯示最新的即時文字。膠囊寬度隨內容調整，持續顯示到轉寫完成，不會取得鍵盤焦點。
- **Overlay Timing** 可分別設定完成與失敗提示的顯示時間，範圍為 0 到 5 秒，預設都是 1.5 秒。設為 0 會隱藏該類提示；錄音和轉寫進行時仍會顯示。設定會保留，修改後也會套用到目前的倒數。短標籤包括 `转写中…`、`已插入`、`已复制`、`已取消` 和 `插入失败`；詳細錯誤仍會留在選單中。
- 選單列圖示顯示辨識狀態與中文字形標記。
- **Show Live Transcript** 可在錄音浮層中顯示 R2T2 最新的即時文字。只用於顯示，不會改變捕獲目標或插入時機。
- 聽寫與辨識模式快捷鍵可自訂，並會跨次啟動保留。
- 可查看權限狀態、最近一次診斷事件和本機除錯日誌。日誌只保留最近五天；每次 NoType 寫入活動或開啟日誌時都會修剪。

## 使用方式

1. 把游標放在要插入轉寫結果的位置。
2. 連按兩下 **Command** 開始錄音。
3. 自然說話。預設模式支援中英混說。
4. 再連按兩下 **Command** 停止；或按 **Esc** 取消，不插入任何文字。
5. NoType 在本機轉寫，回到捕獲的 App，並依照你選定的成功模式插入或複製結果。

點選選單列圖示可變更引擎、辨識模式、中文字形、輸出方式、浮層顯示與時間、快捷鍵和權限。

| 辨識模式 | 選擇 R2T2 | 選擇 macOS Speech |
| --- | --- | --- |
| Auto (中英混說) | R2T2 | R2T2 |
| 中文優先 | R2T2 | macOS Speech |
| English | R2T2 | macOS Speech |

在 macOS 15 上，每一列都使用 R2T2。

快捷鍵位於選單列的 **Shortcuts** 下。選擇 **Add Shortcut…**，即可錄製一般按鍵、Command、Option、Control、Shift、Fn 的任意組合，或單獨的修飾鍵。每個動作可以設定多個快捷鍵，每個快捷鍵也可以設定單擊或快速連按兩下。

預設值如下：

| 動作 | 預設值 | 其他選項 |
| --- | --- | --- |
| 開始／停止聽寫 | 連按兩下 Command | 任意已錄製快捷鍵、停用 |
| 循環切換辨識模式 | 關閉 | 任意已錄製快捷鍵 |

## 隱私

- 語音辨識完全在本機執行，使用 llama.cpp 與 Metal，或 macOS 內建的裝置端辨識器。
- NoType 不使用遠端轉寫 API。
- R2T2 只下載一次模型，來源是 Hugging Face 上固定版本的 [Confucius4-R2T2 GGUF 檔案](https://huggingface.co/mradermacher/Confucius4-R2T2-GGUF)，只存放在 NoType 共用的 `~/Documents/huggingface` 模型資料夾。macOS Speech 第一次使用某種語言時，可能請 macOS 安裝系統語言模型；該模型由 macOS 管理、與所有 App 共用，並儲存在 App 外部。音訊永遠不會上傳。
- 轉寫成功或失敗後會刪除暫存音訊。
- App 沒有帳號、分析或遙測。
- 麥克風只在正在聽寫時使用。
- 輔助使用權限用於全域鍵盤快捷鍵、捕獲聚焦目標與插入文字。
- 剪貼簿只在你選擇的輸出模式或插入退回路徑需要時使用。

## 目前版本

NoType `0.5.0` 已在 [`v0.5.0`](https://github.com/ycl-2004/NoType/releases/tag/v0.5.0) 發佈，提供 Apple Silicon 封存檔。

| 產物 | 用途 |
| --- | --- |
| `NoType-0.5.0-arm64.zip` | 可直接執行的 App；語音模型會在第一次使用時下載 |
| `NoType-0.5.0-arm64.zip.sha256` | 用於驗證下載內容的 SHA-256 校驗檔 |

語音模型不會提交到此儲存庫，也不會打包進封存檔。NoType 會在第一次啟動時，從 Hugging Face 上固定版本下載 R2T2 模型。從 0.4.0 升級時，Qwen3-ASR 與 SenseVoice 會由 R2T2 取代，請見 [變更記錄](CHANGELOG.md) 與 [發佈說明](docs/releases/0.5.0.md)。

## 常見問題

<details>
<summary>macOS 顯示無法開啟 NoType，因為無法驗證開發者</summary>

目前發佈版是 ad-hoc 簽名，尚未經 Apple 公證。按住 Control 點按 `NoType.app`，選擇**開啟**並確認一次。也可以執行[快速開始](#快速開始)中的 `xattr` 指令。

</details>

<details>
<summary>為什麼第一次聽寫可能需要等待？</summary>

第一次使用 R2T2 時，NoType 會下載約 1.5 GB 的模型，並用發佈者的 SHA-256 校驗。下載期間 NoType 仍會執行，並在 **診斷 → Speech Model** 顯示實際狀態。模型會放在 `~/Documents/huggingface/models/mradermacher/Confucius4-R2T2-GGUF`，因此不同 NoType 版本共用同一份下載內容，替換 App 時不會重複下載。之後每次啟動只載入模型；只有檔案在磁碟上改變時才會重新雜湊。

</details>

<details>
<summary>NoType 實際會下載多少內容？</summary>

App 本身很小。R2T2 會在第一次使用時加入約 1.5 GB。每台 Mac 只下載一次，不會每個 App 版本各下載一份；如果選擇 macOS Speech 且只使用中文優先或 English，則完全不會下載。代價是全新安裝在第一次 R2T2 聽寫前需要網路連線；之後每次聽寫都可完全離線。

</details>

<details>
<summary>本機模型儲存在哪裡？可以移除嗎？</summary>

R2T2 模型位於共用的 Hugging Face 資料夾，使用固定路徑：

```text
~/Documents/huggingface/models/mradermacher/
  Confucius4-R2T2-GGUF/
```

NoType 不會在 Application Support 或 App bundle 中建立第二份副本，因此替換 App 不會影響下載內容；開發機器也只保留一份，而不是每次建構一份。

**Engine → Manage Downloaded Models** 會在確認後精確移除這個資料夾。不會移除 macOS Speech 資產、已簽名的 App bundle，或同一資料夾中的其他 Hugging Face 模型。

</details>

<details>
<summary>我應該使用哪個引擎？</summary>

使用預設的 **R2T2 Streaming**。它處理所有模式，包括中英混說，而且大部分工作在你說話時就完成了。

如果你在 macOS 26 上大多只說一種語言，想讓中文優先與 English 交給系統辨識器，可以切換到 **macOS Speech (fast)**。Auto 仍會使用 R2T2，所以中英混說照常運作。

</details>

<details>
<summary>為什麼 Auto 會忽略我的引擎選擇？</summary>

Auto 會要求引擎自行判斷說話語言。R2T2 可以做到；macOS 辨識器則一次只針對一種語言，因此強行用它處理 Auto 會把整段錄音套用單一語言，其他內容可能被音譯成拼音。

當你選擇 macOS Speech 時，NoType 會把 Auto 路由到 R2T2，並在選單顯示：`Engine: macOS Speech (fast) → R2T2 Streaming`。

</details>

<details>
<summary>使用 macOS Speech 時，是否必須一直留在文字欄位？</summary>

不需要。系統聽寫會輸入到當下取得焦點的控制項，所以它會把你留在同一個畫面。NoType 透過 `SpeechAnalyzer` 使用同一個底層辨識器，由 NoType 自己決定轉寫結果落點。開始聽寫後可以切換 App，再停止；結果仍會送到捕獲的欄位或剪貼簿。

</details>

<details>
<summary>為什麼 NoType 需要麥克風和輔助使用權限？</summary>

**麥克風**權限讓 NoType 在聽寫進行時錄音。**輔助使用**權限讓它觀察全域鍵盤快捷鍵、記住聚焦輸入、插入完成的轉寫結果。只複製輸出仍需要麥克風，但不需要直接插入文字。

macOS 26 或更高版本的 macOS Speech 引擎另需要**語音辨識**權限。辨識仍在裝置端進行；該權限控制的是系統辨識器的存取，不是網路服務。R2T2 不使用此權限。

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

這會建立 `dist/NoType.app`。模型不會複製進 App；`R2T2Paths` 會解析到 `~/Documents/huggingface/models/mradermacher/` 下的固定資料夾，第一次使用時才下載。模型放在 bundle 外，替換 App 時不會移動模型路徑；開發機器也只保留一份，而不是每個建構各一份。

建立發佈封存檔：

```bash
./scripts/build_release.sh
```

封裝腳本會建構目前 checkout、簽名整個 App bundle，並建立：

```text
dist/NoType.app
dist/NoType-0.5.0-arm64.zip
dist/NoType-0.5.0-arm64.zip.sha256
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
- `Sources/Typeless/Transcription/` — 兩個引擎、引擎路由、模型安裝器、分段拼接與轉寫清理。
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
- R2T2 模型在第一次使用時下載，而不是打包進 App；全新安裝在第一次 R2T2 聽寫前需要網路連線。
- 熱詞對獨特的人名與技術詞彙有幫助，但對發音接近一般詞彙的詞沒有效果，例如 parser 仍會聽成 parse。
- 超過 24 秒的錄音會分段解碼，切點處的標點是近似的：段尾的 `。` 會改成 `，`。
- macOS Speech 引擎需要 macOS 26 或更高版本，且無法判斷說話語言；選擇 macOS Speech 時，Auto 會使用 R2T2。
- macOS Speech 目前沒有自訂詞彙表；在另一種語言中說出專有名詞時，可能會被音譯，而不是按預期拼寫。

## 文件

- [變更記錄](CHANGELOG.md) — 已發佈的使用者可見變更。
- [已知問題](docs/known-issues.md) — 已理解的限制與未來方向。
- [ADR-001：可自訂快捷鍵輸入](docs/decisions/001-configurable-shortcut-input.md) — 最初的快捷鍵設計，目前已被取代。
- [ADR-002：可攜式發佈封裝](docs/decisions/002-portable-release-packaging.md) — 最初把模型打包而非執行時下載的原因，目前已被 ADR-008 取代。
- [ADR-003：本機模型就緒狀態](docs/decisions/003-local-model-readiness.md) — 為什麼診斷頁顯示 Preparing／Ready／Failed，而不是百分比。
- [ADR-004：雙引擎路由](docs/decisions/004-two-engine-routing.md) — 最初兩個引擎的保留原因，以及 macOS Speech 混合模式使用多語言本機模型的原因。
- [ADR-005：模型位置策略](docs/decisions/005-model-location-strategy.md) — 為什麼會先搜尋安裝位置，及下載前為何需要詢問；目前已被 ADR-008 取代。
- [ADR-006：SenseVoice 引擎與模型儲存](docs/decisions/006-sensevoice-engine-and-model-storage.md) — 共用模型資料夾，以及刪除模型不能碰 macOS Speech 的原因。SenseVoice 引擎本身已由 ADR-012 移除。
- [ADR-007：使用者錄製的快捷鍵](docs/decisions/007-user-recorded-shortcuts.md) — 任意快捷鍵、左右修飾鍵、多重綁定與預設值的運作方式。
- [ADR-008：Qwen3-ASR 取代 Whisper](docs/decisions/008-qwen3-asr-replaces-whisper.md) — 模型不打包的原因，以及 24 秒分段上限背後的量測。Qwen3-ASR 引擎本身已由 ADR-012 移除。
- [ADR-009：可選的語音浮層](docs/decisions/009-voice-overlay.md) — 不搶焦點的浮層、波形與結果顯示時間。
- [ADR-010：R2T2 串流引擎](docs/decisions/010-r2t2-streaming-engine.md) — 內部串流、首次 320 毫秒的節奏，以及嚴格的 Hugging Face 模型儲存。
- [ADR-011：R2T2 資源與可靠性](docs/decisions/011-r2t2-resource-and-reliability.md) — 有界分段、預覽退避、固定版本並校驗的模型檔。
- [ADR-012：R2T2 是唯一本機引擎](docs/decisions/012-r2t2-only-local-engine.md) — 移除 Qwen3-ASR 與 SenseVoice 的原因，以及舊偏好如何遷移。
- [ADR-013：R2T2 提示詞格式與熱詞清單](docs/decisions/013-r2t2-prompt-and-hotwords.md) — 模型訓練時的提示詞格式、熱詞檔，以及背後的量測。

## 第三方條款

R2T2 透過 [llama.cpp](https://github.com/ggml-org/llama.cpp) XCFramework 執行，使用 mradermacher 發佈的 [Confucius4-R2T2](https://github.com/netease-youdao/Confucius4-R2T2) GGUF 轉換檔。模型權重採用 NetEase Model Use License Agreement；R2T2 程式碼採用 Apache 2.0。WhisperKit 與 sherpa-onnx 已不再是相依套件。

## 授權

此儲存庫目前沒有 `LICENSE` 檔案。在作者補充授權條款前，不應假定可以複製、修改、再發佈、重新命名或商業使用此專案。
