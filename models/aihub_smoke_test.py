import os, json, requests

API_KEY = os.getenv("AIHUB_API_KEY", "")
ENDPOINT = os.getenv("AIHUB_ENDPOINT", "https://api.aihub.qualcomm.com").rstrip("/")
PATHS = [os.getenv("AIHUB_CHAT_PATH", "/v1/chat/completions"), "/chat/completions", "/v1/completions"]
MODELS = [os.getenv("AIHUB_MODEL", "llama-v3.1-8b-instruct"),
          "meta/llama-v3.1-8b-instruct",
          "llama_v3_1_8b_instruct"]  # 最後這個是 SDK 模組名，REST 多半不接受

if not API_KEY:
    print("請先設定 AIHUB_API_KEY")
    raise SystemExit(1)

headers = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}

for path in PATHS:
    url = ENDPOINT + path
    for model in MODELS:
        payload = {
            "model": model,
            "messages": [{"role": "user", "content": "ping"}],
            "stream": False
        }
        print(f"\n試: {url} | model={model}")
        try:
            r = requests.post(url, headers=headers, json=payload, timeout=60)
            print("HTTP", r.status_code)
            print(r.text[:800])
            if r.ok:
                print("\n成功！請在環境變數使用：")
                print(f'AIHUB_ENDPOINT="{ENDPOINT}"')
                print(f'AIHUB_CHAT_PATH="{path}"')
                print(f'AIHUB_MODEL="{model}"')
                raise SystemExit(0)
        except requests.RequestException as e:
            print("錯誤：", e)

print("\n全部嘗試仍失敗。請到 AI Hub Playground 的 API Sample 對照「Base URL / Path / model」後更新環境變數。")