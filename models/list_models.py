import os, requests
from dotenv import load_dotenv

load_dotenv(override=True)

base = os.getenv("AIHUB_BASE", "https://playground.core42.ai")
url = os.getenv("AIHUB_MODELS_URL") or f"{base.rstrip('/')}/apis/v2/models"
auth_mode = os.getenv("AIHUB_AUTH", "bearer").lower()  # 與 core42_ping 同步
key = os.getenv("AIHUB_API_KEY", "")

headers = {"Content-Type": "application/json"}
if auth_mode == "x-api-key":
    headers["x-api-key"] = key
elif auth_mode == "token":
    headers["Authorization"] = f"Token {key}"
else:
    headers["Authorization"] = f"Bearer {key}"

print(f"[GET] {url}\nauth={auth_mode}")
resp = requests.get(url, headers=headers, timeout=30)
print("\nStatus:", resp.status_code)
print(resp.text)
