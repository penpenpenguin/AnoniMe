import os
import requests
import textwrap

# 測試用真實資料
INPUT_RECORD = "陳偉倫,wei.lun@example.com,0912-345-678,台北市中正區信義路1段1號,1988-05-21,A123456789"

# 1. 用 API 當 RAG 假資料範本
def fetch_random_users(count=5):
    url = f"https://randomuser.me/api/?results={count}&nat=tw"
    r = requests.get(url, timeout=60)
    r.raise_for_status()
    users = r.json()["results"]
    lines = []
    for u in users:
        name = f"{u['name']['last']}{u['name']['first']}"  # 中文姓+名
        email = u['email']
        phone = f"09{u['cell'][-8:].replace('-', '')}"  # 模擬台灣手機
        address = f"台北市中正區{u['location']['street']['name']}{u['location']['street']['number']}號"
        birthday = u['dob']['date'][:10]
        id_number = "A123456789"  # 固定範例格式
        lines.append(f"{name},{email},{phone},{address},{birthday},{id_number}")
    return lines

# 2. 規則
RULES = textwrap.dedent("""\
RULES:
1.將所有資料列的真實內容替換成合理的假資料
2.中文姓名用常見的中文姓氏與名字組合
3.Email 使用結構正確但不存在的地址（例如 xxx@example.com）
4.手機號碼用台灣格式（09xx-xxx-xxx）
5.地址保留縣市與區的格式，但街道門牌隨機
6.生日用合理的日期（18~65 歲之間）
7.身分證號符合台灣格式（英文+9位數字）
8.生成的假資料要確保格式與原資料一致（字數、格式、分隔符號相同）
9.請直接回傳替換後的 內容，不要多餘解說。 
""")

# 3. 建立上下文
def build_context():
    examples = fetch_random_users(5)
    examples_block = "API EXAMPLES (僅格式參考):\n" + "\n".join(examples)
    return "\n\n".join([RULES, examples_block])

context = build_context()

def call_aihub(messages):
    endpoint = os.getenv("AIHUB_ENDPOINT", "https://app.aihub.qualcomm.com").rstrip("/")
    path = os.getenv("AIHUB_CHAT_PATH", "/api/v1/chat/completions")
    model = os.getenv("AIHUB_MODEL", "llama-v3.1-8b-instruct")
    api_key = os.environ["AIHUB_API_KEY"]
    auth = os.getenv("AIHUB_AUTH", "bearer").lower()
    headers = {"Content-Type": "application/json"}
    if auth == "x-api-key":
        headers["x-api-key"] = api_key
    else:
        headers["Authorization"] = f"Bearer {api_key}"
    r = requests.post(f"{endpoint}{path}",
                      json={"model": model, "messages": messages, "stream": False},
                      headers=headers, timeout=120)
    r.raise_for_status()
    data = r.json()
    # 兼容 OpenAI 風格與常見變體
    try:
        return data["choices"][0]["message"]["content"]
    except Exception:
        if "message" in data and "content" in data["message"]:
            return data["message"]["content"]
        if "text" in data:
            return data["text"]
        raise RuntimeError(f"Unexpected response: {data}")

def call_ollama(messages):
    r = requests.post("http://localhost:11434/api/chat",
                      json={"model": "llama3.2:latest", "messages": messages, "stream": False},
                      timeout=120)
    r.raise_for_status()
    return r.json()["message"]["content"]

messages = [
    {"role": "system", "content": "你是一個資料去識別化專家"},
    {"role": "user", "content": f"""請依照以下 CONTEXT 生成假資料。

CONTEXT:
{context}

TASK:
將下列資料替換成假資料，並符合以上所有規則：
{INPUT_RECORD}
"""},
]

provider = os.getenv("PROVIDER", "ollama").lower()
out = call_aihub(messages) if provider == "qualcomm" else call_ollama(messages)

print("輸入：", INPUT_RECORD)
print("輸出：", out)
