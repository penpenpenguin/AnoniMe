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
- 僅輸出一行，不要解釋、不加標題。
- 以逗號分隔共 6 欄，欄位依序為：姓名、Email、手機、地址、生日、身分證。
- **每一欄的字元總數（包含空白與標點）必須與輸入完全相同**。
- 姓名：常見台灣姓名（繁體中文）。
- Email：結構正確但不存在（使用 example.com 皆可），但總長度要與原本完全一致。
- 手機：台灣格式 09xx-xxx-xxx，總長度要一致。
- 地址：保留縣市與區的合理樣式，街道門牌可換，但總長度要一致。
- 生日：有效日期、年齡 18~65 歲、格式 YYYY-MM-DD，長度要一致。
- 身分證：1 個大寫英文字母 + 9 位數字（總長度 10），可用任意合法組合，但長度要一致。
- 在輸出前，請先把輸入與輸出都以逗號 split，逐欄位檢查長度；有任何一欄不一致就重新生成，直到全部一致為止。
- 不要保留輸入中的任何原始值。
                        """)

# 3. 建立上下文
def build_context():
    examples = fetch_random_users(5)
    examples_block = "API EXAMPLES (僅格式參考):\n" + "\n".join(examples)
    return "\n\n".join([RULES, examples_block])

context = build_context()

# 4. 呼叫本地模型
resp = requests.post(
    "http://localhost:11434/api/chat",
    json={
        "model": "llama3.2:latest",
        "messages": [
            {"role": "system", "content": "你是一個資料去識別化專家"},
            {"role": "user", "content": f"""請依照以下 CONTEXT 生成假資料。

CONTEXT:
{context}

TASK:
將下列資料替換成假資料，並符合以上所有規則：
{INPUT_RECORD}
"""}],
        "stream": False
    },
    timeout=600
)

data = resp.json()
print("輸入：", INPUT_RECORD)
print("輸出：", data["message"]["content"])
