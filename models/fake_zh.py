import os
import requests
import textwrap
import re
from dotenv import load_dotenv
from providers import get_chat_client

load_dotenv(override=True)

def fetch_random_users(count=5):
    url = f"https://randomuser.me/api/?results={count}&nat=tw"
    r = requests.get(url, timeout=60)
    r.raise_for_status()
    users = r.json()["results"]
    lines = []
    for u in users:
        name = f"{u['name']['last']}{u['name']['first']}"
        email = u['email']
        phone = f"09{u['cell'][-8:].replace('-', '')}"
        address = f"台北市中正區{u['location']['street']['name']}{u['location']['street']['number']}號"
        birthday = u['dob']['date'][:10]
        id_number = "A123456789"
        lines.append(f"{name},{email},{phone},{address},{birthday},{id_number}")
    return lines

ZH_PROFILE = textwrap.dedent("""\
LOCALE PROFILE（台灣）：
- 姓名：常見中文姓氏 + 2~3 字名字（繁體）。
- 手機：09xx-xxx-xxx（半形數字與連字號）。
- 地址：使用繁體中文，格式「縣市+區+路/街/大道+門牌號」，常見縣市可選：台北市、新北市、桃園市、台中市、台南市、高雄市、基隆市、新竹市。
- 生日：YYYY-MM-DD。
- 身分證：一個英文字母 + 9 位數字（僅格式正確即可）。
- 內容以繁體中文撰寫；除 Email 外避免英文字母。
""")

RULES = textwrap.dedent("""\
規則：
1. 將所有欄位改為合理但不存在的假資料。
2. 保持欄位數與逗號分隔相同（不可新增/刪除欄位）。
3. 僅輸出一行，無任何多餘說明。
4. 每一個欄位都必須與原值不同，不得重複任何原本內容。
5. 姓名需同時更換「姓氏與名字」，不可僅改一個字。
6. Email 的使用者名稱或網域至少其一不同（建議兩者都不同）。
7. 手機至少 4 碼不同；生日日期必須不同；身分證字號必須不同。
""")

def _digits(s: str) -> str:
    return "".join(ch for ch in s if ch.isdigit())

def _email_parts(s: str):
    s = s.strip()
    if "@" not in s: return s, ""
    a, b = s.split("@", 1)
    return a, b

FIELD_NAMES = ["姓名","Email","手機","地址","生日","身分證"]

def validate_changed_zh(original: str, new: str):
    """回傳 (ok, not_changed_msgs:list[str])"""
    o = [x.strip() for x in original.split(",")]
    n = [x.strip() for x in new.split(",")]
    if len(o) != len(n):
        return False, [f"欄位數不一致（原有 {len(o)}、新有 {len(n)}）"]
    issues = []

    # 姓名：完全不同，且姓氏不同
    if o[0] == n[0]:
        issues.append("姓名未變更")
    else:
        if o[0] and n[0] and o[0][0] == n[0][0]:
            issues.append("姓名的姓氏未更換")

    # Email：local 或 domain 至少一個不同
    oa, od = _email_parts(o[1])
    na, nd = _email_parts(n[1])
    if o[1].lower() == n[1].lower() or (oa.lower() == na.lower() and od.lower() == nd.lower()):
        issues.append("Email 未變更（或使用者名稱/網域皆相同）")

    # 手機：至少 4 碼不同
    odig, ndig = _digits(o[2]), _digits(n[2])
    diff_digits = sum(1 for a, b in zip(odig, ndig) if a != b)
    if odig == ndig or diff_digits < 4:
        issues.append("手機變更幅度不足（至少 4 碼不同）")

    # 地址：整欄不同
    if o[3] == n[3]:
        issues.append("地址未變更")

    # 生日：不同
    if o[4] == n[4]:
        issues.append("生日未變更")

    # 身分證：不同
    if o[5] == n[5]:
        issues.append("身分證未變更")

    return (len(issues) == 0), issues

def build_context():
    examples = fetch_random_users(5)
    examples_block = "API EXAMPLES（僅格式參考）:\n" + "\n".join(examples)
    return "\n\n".join([ZH_PROFILE, RULES, examples_block])

def generate_fake_zh(input_record: str) -> str:
    context = build_context()
    system_prompt = "你是台灣在地資料去識別化專家，請嚴格依 LOCALE PROFILE 與 規則 產生結果。"
    user_prompt = f"""請依照以下 CONTEXT 生成假資料。
- 必須更改姓名（含姓氏）、Email、手機、地址、生日、身分證。
- 僅允許一行輸出，欄位數與逗號位置保持一致。

CONTEXT:
{context}

TASK:
將下列資料替換成假資料（只輸出一行）：
{input_record}
"""
    client = get_chat_client()
    out = client.chat(system_prompt, user_prompt)

    ok, issues = validate_changed_zh(input_record, out)
    if not ok:
        repair_prompt = user_prompt + f"""

注意：以下欄位仍未符合規則，請更正後重新輸出一行，且不要解釋：
- {", ".join(issues)}
原始資料：{input_record}
你剛才的輸出：{out}
請輸出修正版（只允許一行）。
"""
        out = client.chat(system_prompt, repair_prompt)

        # 第二次再驗一次；若仍不符就直接回傳（避免無限重試）
        ok2, issues2 = validate_changed_zh(input_record, out)
        if not ok2:
            out = client.chat(system_prompt, repair_prompt + "\n再次修正，務必使每一欄都與原值不同。")

    return out

if __name__ == "__main__":
    print("[ENV] PROVIDER=", os.getenv("PROVIDER"))
    print("[ENV] AIHUB_FULL_URL=", os.getenv("AIHUB_FULL_URL"))
    print("[ENV] AIHUB_AUTH=", os.getenv("AIHUB_AUTH"))
    INPUT_RECORD = "陳偉倫,wei.lun@example.com,0912-345-678,台北市中正區信義路1段1號,1988-05-21,A123456789"
    out = generate_fake_zh(INPUT_RECORD)
    print("輸入：", INPUT_RECORD)
    print("輸出：", out)
