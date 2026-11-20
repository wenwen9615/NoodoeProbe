# Noodoe Probe

給 KYMCO Noodoe 儀表使用的 iOS **唯讀探針**，用來確認儀表在 iPhone 端實際的連線行為。
**不會寫入任何指令或特徵值**，只做列出、讀取與記錄。

## 功能
- **配件（ExternalAccessory / iAP2）**：列出已連線配件的名稱、製造商、型號、序號、韌體、硬體版本與 `protocolStrings`；可對 `sunray.control` / `sunray.data` 開啟「只收不送」的被動監聽，以十六進位記錄收到的資料。
- **BLE**：掃描（可用名稱過濾，預設 `Noodoe`）、顯示廣播內容（含 Solicited Service UUID）、連線後列出所有服務與特徵值、讀取、訂閱通知；Device Information 會自動讀取並解碼（含 PnP ID 的廠商 ID）。「查詢系統已連線」可找出被 iOS 系統（ANCS）佔用而不再廣播的裝置。
- **記錄**：所有事件都有時間戳，可複製或分享；同時寫入 App 的 Documents 資料夾（可從「檔案」App 取得 `probe-*.log`）。

## 取得未簽名 IPA（GitHub Actions）
1. 在 GitHub 建一個新 repo，把這個資料夾的內容推上去（含 `.github`）。
2. 推到 `main` 後，Actions 會自動執行「Build unsigned IPA」；也可在 Actions 頁手動執行（workflow_dispatch）。
3. 完成後到該次執行頁面下方的 **Artifacts** 下載 `NoodoeProbe-unsigned-ipa`，解壓得到 `NoodoeProbe-unsigned.ipa`。
4. 推 `v1.0` 之類的 tag，IPA 會另外附在 Releases。
5. 用你慣用的側載工具簽署並安裝。

## 建議測試流程（原廠儀表）
1. **完全關閉**原廠 Noodoe App（從多工畫面滑掉），避免搶同一條連線。
2. iOS「設定 > 藍牙」與 `KYMCO Noodoe` 完成配對並連線。
3. 開啟本 App →「配件」分頁，確認列出儀表與其協定字串，必要時開啟被動監聽。
4. 「BLE」分頁：按「查詢系統已連線的 BLE 裝置」或掃描 `Noodoe ANCS`，連線後檢視服務；Device Information 的 PnP ID、版本字串會自動讀取。
5. **測完務必按「中斷連線」**，讓系統把 ANCS 連線拿回去，否則儀表可能暫時收不到通知。
6. 到「記錄」分頁分享記錄檔。分享前請確認內容沒有你不想公開的資訊（序號、位址等）。

## 已知限制
- ExternalAccessory 只會列出**支援 Info.plist 內宣告協定字串**的配件；目前宣告 `sunray.control`、`sunray.data`（來自官方 App 2.2.1）。看不到配件時，可能是協定字串不同。
- 儀表可能要等手機先送握手指令才會回應，被動監聽不一定收得到資料。
- 讀取「所有可讀特徵值」若碰到需要加密的特徵值，iOS 可能跳出配對要求，請拒絕。
- 這份專案是在沒有 Swift 編譯器的環境撰寫的，**尚未編譯過**；第一次建置若失敗，請把 Actions 的錯誤訊息貼出來修正。
