# muiltAI_pii_replace.py
import json, os, hashlib, random, string, re
from typing import List, Dict, Tuple, Optional
from faker_models.presidio_replacer_plus import replace_pii as _presidio_replace

# --- helpers: clean, fallback, safe chat ---
TAG_RX = re.compile(r"^\s*\[\d+\]\s*[A-Z_]+:\s*")  # e.g. "[1] ORGANIZATION: "

def _clean_line(s: str) -> str:
    s = TAG_RX.sub("", s or "")
    s = s.strip().strip('"').strip("'")
    return s

def _fallback_like(e_type: str, raw: str) -> str:
    # 人名/組織/地點 → 擾動字母，保留空白/標點
    if e_type in ("PERSON", "ORGANIZATION", "LOCATION"):
        return "".join((random.choice(string.ascii_letters) if ch.isalpha() else ch) for ch in raw)
    # 數字型 → 按原格式隨機化數字
    if any(t in e_type for t in ("ID", "NUMBER", "DATE", "TIME", "PHONE", "CREDIT", "NHS")):
        return "".join((random.choice(string.digits) if ch.isdigit() else ch) for ch in raw)
    # 最弱保底：反轉避免與原字相同
    return raw[::-1] if raw else raw

def _safe_chat(chat_client, system_prompt: str, user_prompt: str, batch, timeout_sec: int = 10) -> str:
    import time
    t0 = time.time()
    try:
        out = chat_client.chat(system_prompt, user_prompt)
        if time.time() - t0 > timeout_sec:
            raise TimeoutError(f"model timeout after {timeout_sec}s")
        return out if isinstance(out, str) else str(out)
    except Exception as e:
        print(f"[Warn ] 模型失敗或逾時: {e}")
        # 逐項 fallback：回傳與 batch 等行數
        return "\n".join(_fallback_like(t, r) for _, t, r in batch)


# ----------- 生成快取 -----------
class MappingStore:
    def __init__(self, path: Optional[str] = None):
        self.path = path or os.path.expanduser("~/.pii_map.json")
        try:
            self._data = json.load(open(self.path, "r", encoding="utf-8"))
        except Exception:
            self._data = {}

    def _key(self, e_type, raw):
        return hashlib.sha256(f"{e_type}::{raw}".encode("utf-8")).hexdigest()[:32]

    def get(self, e_type, raw):
        return self._data.get(self._key(e_type, raw))

    def put(self, e_type, raw, val):
        self._data[self._key(e_type, raw)] = val
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        json.dump(self._data, open(self.path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
        return val


# 批次處理類別
PRESIDIO_TYPES = {
    "EMAIL_ADDRESS",
    "PHONE_NUMBER", "TW_PHONE_NUMBER",
    "DATE_TIME", "DATE", "TIME", "DURATION_TIME",
    "CREDIT_CARD",
    "IP_ADDRESS", "URL", "MAC_ADDRESS",
    "TW_ID_NUMBER", "UNIFIED_BUSINESS_NO", "TW_HEALTH_INSURANCE", "TW_PASSPORT_NUMBER",
    "UK_NHS",
    }
# 欄位標籤，不要丟給模型
ORG_FIELD_WHITELIST = {
    "social security number",
    "unified business no",
    "passport number",
    "health insurance id",
    "date of birth",
    "phone",
    "email",
    "address",
}
MODEL_TYPES = {"PERSON", "LOCATION", "ORGANIZATION"}


def _presidio_replace_one(e_type: str, raw: str) -> str:
    """呼叫replace_pii，但只替換這個 raw 片段。"""
    tmp_text = raw
    tmp_spans = [{"entity_type": e_type, "start": 0, "end": len(raw), "raw_txt": raw, "score": 1.0}]
    try:
        return _presidio_replace(tmp_text, tmp_spans)
    except Exception:
        return raw  # 保底，避免炸掉

# ----------- 模型批次 prompt -----------
SYSTEM_PROMPT = (
    "You anonymize sensitive strings. Return EXACTLY one line per item, in order.\n"
    "- Each line = the replacement ONLY (no index, no labels, no quotes).\n"
    "- Keep language the same as raw; length within ±2 characters.\n"
    "- Preserve format/pattern (e.g., IDs look like IDs), but the value MUST be different.\n"
    "- If you can't change safely, minimally perturb (e.g., swap letters/digits) to differ.\n"
)

def build_user_prompt(batch):
    # [(idx, e_type, raw), ...]
    lines = ["Items to replace (one replacement per line, in order):"]
    for _, e_type, raw in batch:
        lines.append(f"type={e_type}; raw={raw}")
    return "\n".join(lines)


# ----------- 替換-----------
def replace_entities(text: str, spans: List[Dict], chat_client, mapping: Optional[MappingStore] = None,
                     batch_size: int = 30, debug: bool = True) -> str:
    mapping = mapping or MappingStore()
    prepared: Dict[int, str] = {}
    need_model: List[Tuple[int, str, str]] = []

    if debug:
        print("\n[Step 0] 原始文字：", text)
        print("[Step 0] 偵測到的 spans：")
        for s in spans:
            print("  -", s)

    # 2) 路由與快取
    for i, s in enumerate(spans):
        e_type = s.get("entity_type")
        start, end = int(s["start"]), int(s["end"])
        raw = s.get("raw_txt") or text[start:end]

        cached = mapping.get(e_type, raw)
        if cached:
            prepared[i] = cached
            if debug: print(f"[Route] 命中快取 #{i}: {raw!r} -> {cached!r}")
            continue

        # 跳過常見欄位名稱（不要把「Social Security Number」當 ORGANIZATION 去改）
        if (e_type == "ORGANIZATION") and (raw.strip().lower() in ORG_FIELD_WHITELIST):
            if debug: print(f"[Skip  ] 欄位名略過：{raw!r}")
            continue

        if e_type in PRESIDIO_TYPES:
            rep = _presidio_replace_one(e_type, raw)
            mapping.put(e_type, raw, rep)
            prepared[i] = rep
            if debug: print(f"[Local ] presidio 替換 #{i}: {e_type} {raw!r} -> {rep!r}")

        else:
            need_model.append((i, e_type, raw))
            if debug: print(f"[Model ] 加入模型批次 #{i}: {e_type} {raw!r}")

    # 3) 模型批次
    for j in range(0, len(need_model), batch_size):
        batch = need_model[j:j + batch_size]
        if not batch: break
        user_prompt = build_user_prompt(batch)
        

        if debug:
            print("\n[Model] 發送批次：")
            print(user_prompt)

        # 呼叫後
        out = _safe_chat(chat_client, SYSTEM_PROMPT, user_prompt, batch, timeout_sec=10)

        # 解析 → 一行對一項
        lines = [ _clean_line(l) for l in out.strip().splitlines() ]

        # 如果行數不足，補到跟 batch 一樣多（用 fallback）
        while len(lines) < len(batch):
            lines.append("")

        for line, (i, e_type, raw) in zip(lines, batch):
            rep = (line or "").strip()

            # 若模型回了標籤/保留原字/空字 → 改用保底
            if not rep or rep == raw or re.search(r"\b(ORGANIZATION|LOCATION|PERSON)\b", rep, re.I):
                rep = _fallback_like(e_type, raw)

            mapping.put(e_type, raw, rep)
            prepared[i] = rep
            if debug:
                print(f"[Model] 批次結果 #{i}: {raw!r} -> {rep!r}")

    # 4) 右→左替換
    new_text = text
    for i, s in sorted(enumerate(spans), key=lambda x: int(x[1]["start"]), reverse=True):
        if i not in prepared: continue
        start, end = int(s["start"]), int(s["end"])
        before = new_text
        new_text = new_text[:start] + prepared[i] + new_text[end:]
        if debug:
            print(f"[Apply ] #{i} 位置({start},{end})：{before!r} -> {new_text!r}")

    if debug:
        print("\n[Done ] 最終輸出：", new_text)

    return new_text

