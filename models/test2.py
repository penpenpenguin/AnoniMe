import requests
import textwrap
from providers import get_chat_client

# 將要轉換的原始資料抽成變數，之後只需要改這裡
INPUT_RECORD = "Michael Brown,michael.brown@gmail.com,(312) 555-0199,5678 Oak Street, Chicago, IL 60605,1990-07-15,987-65-4321"

# 1. 用 API 當 RAG 知識來源（假資料範本）
# 來源 https://randomuser.me/
def fetch_random_users(count=6, nat="us"):
    url = f"https://randomuser.me/api/?results={count}&nat={nat}"
    try:
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        users = r.json()["results"]
    except Exception:
        # 網路失敗時提供固定樣本，避免整體流程中斷
        return [
            "John Carter,jcarter@example.com,(202) 555-0101,1200 Pine Street, Seattle, WA 98101,1991-08-12,111-22-3333",
            "Emma Davis,edavis@example.com,(415) 555-0123,742 Maple Avenue, Denver, CO 80203,1987-02-25,222-33-4444",
        ]

    lines = []
    for u in users:
        name = f"{u['name']['first']} {u['name']['last']}"
        email = u['email']
        phone = u['phone']  # 可能不是 (XXX) XXX-XXXX，但可作為格式參考
        street = f"{u['location']['street']['number']} {u['location']['street']['name']}"
        city_state_zip = f"{u['location']['city']}, {u['location']['state']} {u['location']['postcode']}"
        address = f"{street}, {city_state_zip}"
        birthday = u['dob']['date'][:10]
        ssn = "123-45-6789"  # 放假 SSN（僅作參考樣式）
        lines.append(f"{name},{email},{phone},{address},{birthday},{ssn}")
    return lines

# 2. 規則
RULES = textwrap.dedent("""\
    RULES:
    - Preserve per-field length EXACTLY, INCLUDING spaces and punctuation.
    - Email: keep TOTAL length equal to original; you may adjust local-part or choose a same-length domain.
    - US phone: format like (XXX) XXX-XXXX with the SAME total length.
    - SSN: XXX-XX-XXXX (fake).
    - Address: city/state realistic; house/street can change; but each comma-separated field must keep identical length.
    - If any field mismatches length, adjust with equal-length synonyms (e.g., 'Elm'→'Oak') or tiny spacing changes (no extra commas).
""")

CHECK_TIPS = textwrap.dedent("""\
    CHECK TIPS:
    - Split by commas and compare len() for each segment (including spaces & punctuation).
    - If email length mismatches, tweak local-part or pick a same-length domain.
    - Before returning, re-check lengths; if mismatch, fix and try again.
""")

# 3. 建立幾個範例
def build_context():
    examples = fetch_random_users(6, "us")
    examples_block = "API EXAMPLES (reference format only):\n" + "\n".join(examples)
    return "\n\n".join([RULES, CHECK_TIPS, examples_block])

# 4. 完整上下文
context = build_context()

system_prompt = "You are a data anonymization expert."
user_prompt = f"""You MUST follow the CONTEXT strictly.

CONTEXT:
{context}

TASK:
Here is a record containing real personal information (Name, Email, Phone, Address, Birthday, SSN).

Please replace it with **realistic but fake US-based data** following these rules:
1. Name: Common American first and last name.
2. Email: Correct structure but use 'example.com' domain (keep TOTAL length equal to the original).
3. Phone: US format (XXX) XXX-XXXX.
4. Address: Keep city and state names realistic, but randomize street and house number.
5. Birthday: Valid date, age between 18 and 65.
6. SSN: US format XXX-XX-XXXX (fake).
7. Ensure the output matches the same field count, order, and separator as the input.
8. Output only the fake data, nothing else.
9. **For every field, keep the number of characters EXACTLY the same as the original INCLUDING spaces and punctuation to avoid layout issues.**
10. Output exactly ONE single line. No headings, no explanations, no extra candidates.
11. Transform ONLY the single record under "Data to convert".

Example:
Input:  John Smith,john.smith@megamail.com,(202) 555-0199,1234 Elm Street, Springfield, IL 62704,1988-05-21,123-45-6789
Output: Mark Green,mark.green@fakemail.com,(415) 238-7491,8452 Oak Avenue, Los Angeles, CA 90017,1992-11-30,987-65-4321

Data to convert:
{INPUT_RECORD}
"""

# 使用抽象的 Chat 客戶端（可切換 Ollama / Qualcomm AI Hub）
client = get_chat_client()
output = client.chat(system_prompt, user_prompt)

print("輸入："+ INPUT_RECORD)
print("輸出："+ output)