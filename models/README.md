# AnoniMe 模型整合（Ollama / Qualcomm AI Hub）

## 取得 AI Hub 參數（最重要）
1. 登入 https://aihub.qualcomm.com
2. 打開你要用的模型 → Playground 或 Hosted Inference
3. 點 API/Code sample，記下：
   - Base URL（Endpoint）→ 貼到 AIHUB_ENDPOINT（例如：https://api.aihub.qualcomm.com）
   - Path（如果有顯示）→ 貼到 AIHUB_CHAT_PATH（例如：/v1/chat/completions）
   - "model" 欄位字串 → 貼到 AIHUB_MODEL（例如：llama-3-8b-instruct）
4. 建立 API Key → 貼到 AIHUB_API_KEY

## 快速設定（PowerShell）
- 僅在目前視窗生效（建議先測）
  ```
  $env:PROVIDER="qualcomm"
  $env:AIHUB_API_KEY="<你的_API_Key>"
  $env:AIHUB_ENDPOINT="<你的_Base_URL>"
  $env:AIHUB_MODEL="<你的_Model_ID>"
  $env:AIHUB_CHAT_PATH="/v1/chat/completions"   # 若 API Sample 不同，請改
  ```
- 永久設定（需重開終端機）
  ```
  setx PROVIDER "qualcomm"
  setx AIHUB_API_KEY "<你的_API_Key>"
  setx AIHUB_ENDPOINT "<你的_Base_URL>"
  setx AIHUB_MODEL "<你的_Model_ID>"
  setx AIHUB_CHAT_PATH "/v1/chat/completions"
  ```

## 連線自測（可選）
```
curl -X POST "$env:AIHUB_ENDPOINT$env:AIHUB_CHAT_PATH" ^
  -H "Authorization: Bearer $env:AIHUB_API_KEY" ^
  -H "Content-Type: application/json" ^
  -d "{""model"": ""$env:AIHUB_MODEL"", ""messages"": [{""role"": ""user"", ""content"": ""hello""}]}"
```

## 執行
```
pip install -r requirements.txt
python .\test2.py
```

## 切回本機 Ollama（若需要）
```
$env:PROVIDER="ollama"
$env:OLLAMA_URL="http://localhost:11434"
$env:OLLAMA_MODEL="llama3.2:latest"
python .\test2.py
```
