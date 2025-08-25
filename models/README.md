# AnoniMe（Core42 / Ollama）操作指南

本專案可透過 Core42 Playground（OpenAI 介面相容的 REST API）或本機 Ollama 進行推論。支援繁中/英文輸入。

## 1) 快速開始（Core42 REST，建議用於應用程式）
- 建議使用獨立虛擬環境（.venv-app），已安裝 requests 與 python-dotenv。
- 建立或更新 `.env`（放在專案根目錄）：
  ```
  PROVIDER=qualcomm
  AIHUB_API_KEY=<你的 Core42 API Key>
  AIHUB_AUTH=bearer
  AIHUB_FULL_URL=https://playground.core42.ai/apis/v2/chat/completions
  AIHUB_MODEL=Llama-3.1-8B
  ```
  注意：Core42 要用 Authorization: Bearer <key>，路徑必須是 /apis/v2/chat/completions。
  
  需要設定：$env:AIHUB_FULL_URL = "https://playground.core42.ai/apis"


- 連線自測（確認 token/URL 正確）：
  ```
  python .\core42_ping.py
  ```
  看到 200 即成功。

- 執行英文範例（US 假資料）：
  ```
  python .\fake_en.py
  ```

- 執行中文範例（台灣格式；若要走 Core42，亦可把 test.py 換成用 providers/REST 的版本，或改用 test2.py 並用中文提示）：
  ```
  python .\fake_zh.py
  ```

## 2) 中文輸入示例
你可以直接用中文 system/user 提示：
```python
from providers import get_chat_client

client = get_chat_client()
system = "你是一位資料去識別化專家"
user = "請將下列資料全改為合理假資料，維持欄位數與分隔符號；直接回一行：\n王小明,xm.wang@example.com,0912-345-678,台北市中正區信義路一段1號,1995-03-02,A123456789"
print(client.chat(system, user))
```

## 3) 切換到本機 Ollama（選用）
- 將 `.env` 改成：
  ```
  PROVIDER=ollama
  OLLAMA_URL=http://localhost:11434
  OLLAMA_MODEL=llama3.2:latest
  ```
- 執行：
  ```
  python .\fake_en.py
  ```

## 4) 疑難排解
- 401 Unauthorized：
  - 核對 `.env` 的 AIHUB_API_KEY 是否最新，AIHUB_AUTH=bearer（Core42 多數為 bearer）。
- 404 Not Found：
  - 確認使用 `AIHUB_FULL_URL=https://playground.core42.ai/apis/v2/chat/completions`（不是只有 /apis/v2）。
- 200 但輸出不符規則（例如 SSN 未更換）：
  - 強化提示或在程式端檢查到未更換時重試（test2.py 可依註解範例加入檢查）。

## 5) 安全
- 別將 `.env` 入庫；洩漏的 API Key 請至 Core42 後台撤銷並重生。
