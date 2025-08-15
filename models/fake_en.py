import requests
import textwrap
from providers import get_chat_client
import os
from dotenv import load_dotenv

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"), override=True)

def fetch_random_users(count=6, nat="us"):
    url = f"https://randomuser.me/api/?results={count}&nat={nat}"
    try:
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        users = r.json()["results"]
    except Exception:
        return [
            "John Carter,jcarter@example.com,(202) 555-0101,1200 Pine Street, Seattle, WA 98101,1991-08-12,111-22-3333",
            "Emma Davis,edavis@example.com,(415) 555-0123,742 Maple Avenue, Denver, CO 80203,1987-02-25,222-33-4444",
        ]

    lines = []
    for u in users:
        name = f"{u['name']['first']} {u['name']['last']}"
        email = u['email']
        phone = u['phone']
        street = f"{u['location']['street']['number']} {u['location']['street']['name']}"
        city_state_zip = f"{u['location']['city']}, {u['location']['state']} {u['location']['postcode']}"
        address = f"{street}, {city_state_zip}"
        birthday = u['dob']['date'][:10]
        ssn = "123-45-6789"
        lines.append(f"{name},{email},{phone},{address},{birthday},{ssn}")
    return lines

RULES = textwrap.dedent("""\
    RULES:
    - Keep field COUNT and separators identical (commas in same places).
    - Change EVERY field; none may keep the original value.
    - Name: use a different first AND last name (ASCII).
    - Email: change local-part or domain (prefer both).
    - US phone: format (AAA) NXX-XXXX; at least 4 digits must differ from original.
    - Address: realistic US address, different from original.
    - Birthday: must be different from original.
    - SSN: XXX-XX-XXXX; must differ from original.
    - Output exactly ONE line, no explanations.
""")

# 新增一些小工具與驗證
def _digits(s: str) -> str:
    return "".join(ch for ch in s if ch.isdigit())

def _email_parts(s: str):
    s = s.strip()
    if "@" not in s: return s, ""
    a, b = s.split("@", 1)
    return a, b

def validate_changed_en(original: str, new: str):
    """Return (ok, issues)"""
    o = [x.strip() for x in original.split(",")]
    n = [x.strip() for x in new.split(",")]
    if len(o) != len(n):
        return False, [f"Field count mismatch ({len(o)} vs {len(n)})"]
    issues = []
    # Name
    if o[0].lower() == n[0].lower():
        issues.append("Name unchanged")
    # Email
    oa, od = _email_parts(o[1]); na, nd = _email_parts(n[1])
    if o[1].lower() == n[1].lower() or (oa.lower() == na.lower() and od.lower() == nd.lower()):
        issues.append("Email unchanged")
    # Phone: 至少 4 碼不同
    odig, ndig = _digits(o[2]), _digits(n[2])
    diff = sum(1 for a, b in zip(odig, ndig) if a != b)
    if odig == ndig or diff < 4:
        issues.append("Phone changed too little")
    # Address
    if o[3].lower() == n[3].lower():
        issues.append("Address unchanged")
    # Birthday
    if o[4] == n[4]:
        issues.append("Birthday unchanged")
    # SSN
    if o[5] == n[5]:
        issues.append("SSN unchanged")
    return (len(issues) == 0), issues

CHECK_TIPS = textwrap.dedent("""\
    CHECK TIPS:
    - Split by commas and ensure same number of fields.
    - Before returning, quickly sanity-check formats (phone/SSN/state/ZIP).
""")

EN_PROFILE = textwrap.dedent("""\
    LOCALE PROFILE (US):
    - Names: typical US first + last (ASCII only).
    - Phone: use valid-looking US area codes (avoid 555 unless necessary).
    - Address: "<house number> <street name> <suffix>" with suffix from [St, Ave, Rd, Blvd, Dr, Ln, Way, Ct, Pl],
      then "City, ST ZIP" with USPS 2-letter state code. Prefer a city different from the source.
    - ZIP: 5 digits.
    - Email: providers like gmail.com, outlook.com, yahoo.com, proton.me.
    - Do NOT use any Chinese characters.
""")

def build_context():
    examples = fetch_random_users(6, "us")
    examples_block = "API EXAMPLES (reference format only):\n" + "\n".join(examples)
    return "\n\n".join([EN_PROFILE, RULES, CHECK_TIPS, examples_block])

def generate_fake_en(input_record: str) -> str:
    context = build_context()
    system_prompt = "You are a US PII anonymization specialist. Follow LOCALE PROFILE and RULES strictly."
    user_prompt = f"""Replace the following record with realistic but fake US-based data.
- Change ALL fields (name, email, phone, address, birthday, ssn).
- Keep the same number of fields and comma separators.
- Output exactly ONE line. No extra text.

CONTEXT:
{context}

Data to convert:
{input_record}
"""
    client = get_chat_client()
    out = client.chat(system_prompt, user_prompt)

    ok, issues = validate_changed_en(input_record, out)
    if not ok:
        repair_prompt = user_prompt + f"""

The following fields still failed the rules, fix them and return ONE line only:
- {", ".join(issues)}
Original: {input_record}
Your previous output: {out}
"""
        out = client.chat(system_prompt, repair_prompt)

        # 再驗一次；仍不符再強化一次提示（最多 2 次）
        ok2, issues2 = validate_changed_en(input_record, out)
        if not ok2:
            out = client.chat(system_prompt, repair_prompt + "\nEnsure EVERY field differs from the original, especially Birthday and SSN.")

    return out

if __name__ == "__main__":
    print("[ENV] PROVIDER=", os.getenv("PROVIDER"))
    print("[ENV] AIHUB_FULL_URL=", os.getenv("AIHUB_FULL_URL"))
    print("[ENV] AIHUB_AUTH=", os.getenv("AIHUB_AUTH"))
    INPUT_RECORD = "Michael Brown,michael.brown@gmail.com,(312) 555-0199,5678 Oak Street, Chicago, IL 60605,1990-07-15,987-65-4321"
    out = generate_fake_en(INPUT_RECORD)
    print("輸入：", INPUT_RECORD)
    print("輸出：", out)