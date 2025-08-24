from __future__ import annotations

import os, re, json, time, random
from typing import Dict, Tuple, List
from pathlib import Path

# 可用時載入 chat client
try:
    from models.providers import get_chat_client
except Exception:
    get_chat_client = None  # type: ignore

# 環境設定
DEBUG = os.getenv("AI_REPLACER_DEBUG", "0").lower() not in ("", "0", "false", "no")
USE_LLM = os.getenv("AI_REPLACER_USE_LLM", "0").lower() not in ("", "0", "false", "no")
LLM_TYPES = {t.strip().upper() for t in os.getenv("AI_REPLACER_LLM_TYPES", "PERSON").split(",") if t.strip()}

def dprint(*args, **kwargs):
    if DEBUG:
        print("[AI_REPLACER]", *args, **kwargs)

# 型別正規化
TYPE_ALIASES = {
    "EMAIL": "EMAIL_ADDRESS",
    "E_MAIL": "EMAIL_ADDRESS",
    "PHONE": "PHONE_NUMBER",
    "TEL": "PHONE_NUMBER",
    "DATE": "DATE_TIME",
}
def normalize_type(t: str) -> str:
    t = (t or "").strip().upper()
    return TYPE_ALIASES.get(t, t)

# 驗證/樣式工具
EMAIL_RX = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
SSN_RX   = re.compile(r"\b\d{3}-\d{2}-\d{4}\b")
PHONE_RX = re.compile(r"\+?\d[\d\-\s().]{6,}\d")
DATE_YMD = re.compile(r"^\d{4}-\d{2}-\d{2}$")
_DIGITS  = "0123456789"

def shape_digits_like(s: str) -> str:
    return "".join(random.choice(_DIGITS) if c.isdigit() else c for c in s)

def fake_date_like(raw: str) -> str:
    m = re.fullmatch(r"(\d{4})-(\d{2})-(\d{2})", raw)
    if m:
        y = random.randint(1950, 2010)
        mth = random.randint(1, 12)
        day = random.randint(1, 28)
        return f"{y:04d}-{mth:02d}-{day:02d}"
    return shape_digits_like(raw)

def fake_email_like(raw: str) -> str:
    m = re.match(r"^([^@\s]+)@([^@\s]+)$", raw)
    if not m:
        return shape_digits_like(raw)
    user, domain = m.group(1), m.group(2)
    new_user = re.sub(r"[^a-z0-9._-]", "", (user or "user").lower()) or f"user{random.randint(1000,9999)}"
    parts = domain.split(".")
    tld = parts[-1] if len(parts) > 1 else "com"
    new_domain = random.choice(["example", "protonmail", "outlook", "gmail", "yahoo"])
    return f"{new_user}@{new_domain}.{tld}"

def fake_ssn_like(raw: str) -> str:
    if re.fullmatch(r"\d{3}-\d{2}-\d{4}", raw):
        a = random.randint(100, 899)
        b = random.randint(10, 99)
        c = random.randint(1000, 9999)
        return f"{a:03d}-{b:02d}-{c:04d}"
    return shape_digits_like(raw)

def _is_email(s: str) -> bool:
    return bool(EMAIL_RX.match(s.strip()))

def _is_phone_like(s: str) -> bool:
    digits = sum(c.isdigit() for c in s)
    return digits >= 7 and bool(PHONE_RX.search(s))

# 單檔規則替換（提供給 class 與 _postprocess 共用，避免循環依賴）
def _rule_fake_value(et: str, raw: str) -> str:
    et = normalize_type(et)
    if et == "EMAIL_ADDRESS":
        return fake_email_like(raw)
    if et == "PHONE_NUMBER":
        return shape_digits_like(raw)
    if et == "DATE_TIME":
        return fake_date_like(raw)
    if et in ("ID_NUMBER", "NATIONAL_ID", "TW_ID_NUMBER", "US_SSN"):
        return fake_ssn_like(raw)
    return shape_digits_like(raw)

def _postprocess(et: str, raw: str, rep: str) -> str:
    et = normalize_type(et)
    rep = (rep or "").strip()
    if not rep or rep == raw or "\n" in rep:
        return _rule_fake_value(et, raw)
    if et == "EMAIL_ADDRESS" and not _is_email(rep):
        return fake_email_like(raw)
    if et == "PHONE_NUMBER" and not _is_phone_like(rep):
        return shape_digits_like(raw)
    if et == "DATE_TIME" and not DATE_YMD.match(rep):
        return fake_date_like(raw)
    if et in ("ID_NUMBER", "NATIONAL_ID", "TW_ID_NUMBER", "US_SSN") and not SSN_RX.match(rep):
        return fake_ssn_like(raw)
    if et == "EMAIL_ADDRESS":
        parts = re.findall(r"[^@\s]+@[^@\s]+\.[^@\s]+", rep)
        return parts[0] if parts else fake_email_like(raw)
    if et == "PHONE_NUMBER":
        return shape_digits_like(raw)
    return rep

def _pattern_pass(text: str) -> str:
    def repl_email(m): return fake_email_like(m.group(0))
    def repl_phone(m): return shape_digits_like(m.group(0))
    def repl_ssn(m):   return fake_ssn_like(m.group(0))
    out = EMAIL_RX.sub(repl_email, text)
    out = PHONE_RX.sub(repl_phone, out)
    out = SSN_RX.sub(repl_ssn, out)
    return out

class AIReplacer:
    def __init__(self, model: str | None = None, retries: int = 1, backoff: float = 1.5) -> None:
        self.model = model
        self.retries = int(retries)
        self.backoff = float(backoff)
        self.cache: Dict[Tuple[str, str], str] = {}
        self.client = get_chat_client() if (USE_LLM and get_chat_client) else None

        # 磁碟快取
        root = Path(__file__).resolve().parents[1]
        self.cache_path = root / ".cache" / "ai_replacer_cache.json"
        self.cache_path.parent.mkdir(parents=True, exist_ok=True)
        self._load_cache()

    def _load_cache(self):
        try:
            if self.cache_path.exists():
                data = json.loads(self.cache_path.read_text(encoding="utf-8"))
                for k, v in data.items():
                    et, raw = k.split("||", 1)
                    self.cache[(et, raw)] = v
        except Exception:
            pass

    def _save_cache(self):
        try:
            data = {f"{k[0]}||{k[1]}": v for k, v in self.cache.items()}
            self.cache_path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        except Exception:
            pass

    def _rule_fake(self, et: str, raw: str, ctx: str) -> str:
        return _rule_fake_value(et, raw)

    def _should_use_llm(self, et: str) -> bool:
        return bool(self.client) and normalize_type(et) in LLM_TYPES

    def _llm_fake_batch(self, items: List[Tuple[str, str]], contexts: Dict[Tuple[str, str], str]) -> Dict[Tuple[str, str], str]:
        if not items:
            return {}
        # 批次提示，回傳 JSON 物件：{"replacements":[{"i":0,"replacement":"..."}]}
        payload = [{"i": i, "entity_type": et, "raw": raw, "ctx": contexts.get((et, raw), "")}
                   for i, (et, raw) in enumerate(items)]
        system = ("You replace sensitive text with realistic but fake values. "
                  "Respond ONLY JSON: {\"replacements\":[{\"i\":0,\"replacement\":\"...\"}, ...]}")
        user = "Generate replacements for each item:\n" + json.dumps(payload, ensure_ascii=False)

        delay = 0.0
        for attempt in range(self.retries + 1):
            if delay: time.sleep(delay)
            try:
                resp = self.client.chat(system, user, stream=False)  # 保守，不傳 extra_params 以避免相容性問題
                data = json.loads(resp if isinstance(resp, str) else json.dumps(resp))
                out: Dict[Tuple[str, str], str] = {}
                for it in data.get("replacements", []):
                    if not isinstance(it, dict) or "i" not in it: 
                        continue
                    idx = int(it["i"])
                    if 0 <= idx < len(items):
                        et, raw = items[idx]
                        rep = _postprocess(et, raw, it.get("replacement", ""))
                        out[(et, raw)] = rep
                # 未回者用規則補齊
                for et, raw in items:
                    out.setdefault((et, raw), self._rule_fake(et, raw, contexts.get((et, raw), "")))
                return out
            except Exception as e:
                dprint("LLM 批次失敗:", e)
                delay = self.backoff if delay == 0.0 else delay * self.backoff

        # 全失敗 → 規則
        return {(et, raw): self._rule_fake(et, raw, contexts.get((et, raw), "")) for et, raw in items}

    def ensure_cached(self, needed: List[Tuple[str, str]], contexts: Dict[Tuple[str, str], str]) -> None:
        to_query = [(et, raw) for et, raw in needed
                    if self._should_use_llm(et) and (et, raw) not in self.cache]
        if not to_query:
            return
        batch = self._llm_fake_batch(to_query, contexts)
        self.cache.update(batch)
        self._save_cache()

    def replace_one(self, entity_type: str, raw_text: str, context: str = "") -> str:
        et = normalize_type(entity_type)
        key = (et, raw_text)
        if key in self.cache:
            return self.cache[key]
        if not self._should_use_llm(et):
            rep = self._rule_fake(et, raw_text, context)
        else:
            rep = self._llm_fake_batch([key], {key: context})[key]
        rep = _postprocess(et, raw_text, rep)
        self.cache[key] = rep
        self._save_cache()
        return rep

_global_ai = AIReplacer(model=None)

def replace_one(entity_type: str, raw_text: str, context: str = "") -> str:
    return _global_ai.replace_one(entity_type, raw_text, context)

def replace_entities(text: str, entities: List[dict], ctx_window: int = 30) -> str:
    if not text:
        return text
    ents = list(entities or [])
    # 先收集唯一 (et, raw) 與上下文 → 批次預先快取
    uniq: List[Tuple[str, str]] = []
    ctx_map: Dict[Tuple[str, str], str] = {}
    seen: set = set()
    for ent in ents:
        st, ed = int(ent.get("start", 0)), int(ent.get("end", 0))
        if st < 0 or ed > len(text) or st >= ed:
            continue
        raw = text[st:ed]
        et = normalize_type(ent.get("entity_type", ""))
        key = (et, raw)
        if key not in seen:
            seen.add(key)
            uniq.append(key)
            ctx_map[key] = text[max(0, st - ctx_window): min(len(text), ed + ctx_window)]
    _global_ai.ensure_cached(uniq, ctx_map)

    # 右到左替換，避免索引位移
    out = text
    for ent in sorted(ents, key=lambda e: int(e.get("start", 0)), reverse=True):
        st, ed = int(ent["start"]), int(ent["end"])
        if st < 0 or ed > len(out) or st >= ed:
            dprint("skip invalid span:", ent); continue
        raw = out[st:ed]
        et = ent.get("entity_type", "")
        ctx = out[max(0, st - ctx_window): min(len(out), ed + ctx_window)]
        fake_val = _global_ai.replace_one(et, raw, ctx)
        out = out[:st] + fake_val + out[ed:]
    # 補救（偵測漏標）
    out = _pattern_pass(out)
    return out