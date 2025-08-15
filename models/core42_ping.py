import os, requests
from dotenv import load_dotenv
load_dotenv(override=True)

url = os.environ["AIHUB_FULL_URL"]
key = os.environ["AIHUB_API_KEY"]
model = os.environ.get("AIHUB_MODEL", "Llama-3.1-8B")

def try_mode(mode: str):
    headers = {"Content-Type":"application/json"}
    if mode == "x-api-key":
        headers["x-api-key"] = key
    elif mode == "token":
        headers["Authorization"] = f"Token {key}"
    else:
        headers["Authorization"] = f"Bearer {key}"
    print(f"TRY {mode.upper()} -> {url}")
    r = requests.post(url, headers=headers,
        json={"model": model, "messages":[{"role":"user","content":"ping"}], "stream": False},
        timeout=30)
    print(r.status_code, r.text[:400], "\n")
    return 200 <= r.status_code < 300

for m in [os.getenv("AIHUB_AUTH","bearer"), "bearer", "token", "x-api-key"]:
    if try_mode(m):
        break