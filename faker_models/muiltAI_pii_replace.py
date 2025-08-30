# muiltAI_pii_replace.py  — 改用 KuwaClient，不再載本地 HF 模型
import os, json, hashlib
from typing import List, Dict, Tuple, Optional
import asyncio
import types


# 你原本的 presidio 替換器
from faker_models.presidio_replacer_plus import replace_pii as _presidio_replace

# 讀 .env（若沒有也能跑，只是拿不到環境變數）
try:
    from dotenv import load_dotenv, find_dotenv
    load_dotenv(find_dotenv())
except Exception:
    pass

# ====== Kuwa Client（依你要求的匯入方式）======
import sys
sys.path.append(r"C:\kuwa\GenAI OS\src\library\client\src\kuwa")
from client.base import KuwaClient  # noqa: E402


# ---------- 用 Kuwa 的聊天客戶端（同步介面，配合 _safe_chat 使用）----------
class KuwaChatClient:
    """
    用 Kuwa 的 OpenAI-Compatible 端點做一次問答，回傳文字。
    會使用 .env 的 KUWA_BASE_URL / KUWA_API_KEY / KUWA_MODEL。
    """

    def __init__(
        self,
        base_url: Optional[str] = None,
        api_key: Optional[str] = None,
        model: Optional[str] = None,
        temperature: float = 0.8,
        max_tokens: int = 64,
    ):
        self.base_url = (base_url or os.getenv("KUWA_BASE_URL", "")).rstrip("/")
        self.api_key = api_key or os.getenv("KUWA_API_KEY", "")
        self.model = model or os.getenv("KUWA_MODEL", "")
        self.temperature = temperature
        self.max_tokens = max_tokens

        if not self.base_url or not self.api_key:
            raise RuntimeError(
                "缺少 KUWA_BASE_URL / KUWA_API_KEY。請在 .env 依 Kuwa 介面填寫完整 Base URL（含埠與 /v1*）。"
            )
        if not self.model:
            raise RuntimeError("缺少 KUWA_MODEL，請先用 /models 清單對到正確 id 再填。")

        # KuwaClient 會幫你打到 <base_url>/chat/completions
        self._client = KuwaClient(
            base_url=self.base_url,
            model=self.model,          # 預設模型
            auth_token=self.api_key,
        )



    def chat(self, system_prompt: str, user_prompt: str) -> str:
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]
        resp = self._client.chat_complete(
            messages=messages,
            streaming=False,
        )

        # 如果 resp 是 async generator，收集所有 chunk
        if isinstance(resp, types.AsyncGeneratorType):
            async def collect():
                result = ""
                async for chunk in resp:
                    result += chunk
                return result
            text = asyncio.run(collect())
        elif isinstance(resp, str):
            text = resp
        elif isinstance(resp, dict):
            text = (
                resp.get("content")
                or resp.get("message")
                or (resp.get("choices", [{}])[0].get("message", {}) or {}).get("content", "")
                or ""
            )
        else:
            text = getattr(resp, "content", "") or str(resp)

        text = (text or "").strip()
        for line in text.splitlines():
            line = line.strip()
            if line:
                return line
        return text


# ----------- safe chat 包裝（原樣保留）-----------
def _safe_chat(chat_client, system_prompt: str, user_prompt: str, batch, timeout_sec: int = 20) -> str:
    import time
    t0 = time.time()
    try:
        out = chat_client.chat(system_prompt, user_prompt)
        if time.time() - t0 > timeout_sec:
            raise TimeoutError(f"model timeout after {timeout_sec}s")
        return out if isinstance(out, str) else str(out)
    except Exception as e:
        print(f"[Warn ] 模型失敗或逾時: {e}")
        return "\n".join(raw for _, _, raw in batch)


# ----------- 生成快取（原樣保留）-----------
class MappingStore:
    def __init__(self, path: Optional[str] = None):
        base_dir = os.path.dirname(__file__)
        default_path = os.path.join(base_dir, "pii_map.json")
        self.path = path or default_path
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


# ----------- 你原本的 Presidio 類型集合（原樣保留）-----------
PRESIDIO_TYPES = {
    "EMAIL_ADDRESS","ADDRESS",
    "PHONE_NUMBER", "TW_PHONE_NUMBER",
    "DATE_TIME", "DURATION_TIME",
    "CREDIT_CARD",
    "IP_ADDRESS", "URL", "MAC_ADDRESS",
    "TW_ID_NUMBER", "UNIFIED_BUSINESS_NO", "TW_HEALTH_INSURANCE", "TW_PASSPORT_NUMBER",
    "UK_NHS",
}


def _presidio_replace_one(e_type: str, raw: str) -> str:
    tmp_text = raw
    tmp_spans = [{"entity_type": e_type, "start": 0, "end": len(raw), "raw_txt": raw, "score": 1.0}]
    try:
        return _presidio_replace(tmp_text, tmp_spans)
    except Exception:
        return raw  # 保底


# ----------- 模型批次 prompt（原樣保留）-----------
SYSTEM_PROMPT = (
    "Replace each item with a fake value. Output only the replacement value for each item, one per line, without any type or raw label. Do not repeat the input format, just output the new value."
)

def build_user_prompt(batch):
    lines = ["Items to replace (one replacement per line, in order):"]
    for _, e_type, raw in batch:
        lines.append(f"type={e_type}; raw={raw}")
    return "\n".join(lines)


# ----------- 主函式：替換（保留原介面，預設用 KuwaChatClient）-----------
def replace_entities(
    text: str,
    spans: List[Dict],
    chat_client=None,
    mapping: Optional[MappingStore] = None,
    batch_size: int = 30,
    debug: bool = True,
) -> str:
    mapping = mapping or MappingStore()
    chat_client = chat_client or KuwaChatClient()  # ← 不傳就用 Kuwa

    prepared: Dict[int, str] = {}
    need_model: List[Tuple[int, str, str]] = []

    if debug:
        print("\n[Step 0] 原始文字：", text)
        print("[Step 0] 偵測到的 spans：")
        for s in spans:
            print("  -", s)

    # 2) 路由 + 快取
    for i, s in enumerate(spans):
        e_type = s.get("entity_type")
        start, end = int(s["start"]), int(s["end"])
        raw = s.get("raw_txt") or text[start:end]

        cached = mapping.get(e_type, raw)
        if cached:
            prepared[i] = cached
            if debug: print(f"[Route] 快取已有 #{i}: {raw!r} -> {cached!r}")
            continue

        if e_type in PRESIDIO_TYPES:
            rep = _presidio_replace_one(e_type, raw)
            mapping.put(e_type, raw, rep)
            prepared[i] = rep
            if debug: print(f"[Local ] presidio 替換 #{i}: {e_type} {raw!r} -> {rep!r}")
        else:
            need_model.append((i, e_type, raw))
            if debug: print(f"[Model ] 模型處理 #{i}: {e_type} {raw!r}")

    # 3) 模型批次
    for j in range(0, len(need_model), batch_size):
        batch = need_model[j:j + batch_size]
        if not batch:
            break

        user_prompt = build_user_prompt(batch)
        if debug:
            print("\n[Model] 發送批次：")
            print(user_prompt)

        out = _safe_chat(chat_client, SYSTEM_PROMPT, user_prompt, batch, timeout_sec=10)
        lines = (out or "").strip().splitlines()

        # 補齊
        while len(lines) < len(batch):
            lines.append("")

        for line, (i, e_type, raw) in zip(lines, batch):
            rep = (line or "").strip()
            if (not rep) or (rep == raw):
                rep = raw  # 保守處理
            mapping.put(e_type, raw, rep)
            prepared[i] = rep
            if debug:
                print(f"[Model] 批次結果 #{i}: {raw!r} -> {rep!r}")

    # 4) 右→左套用
    new_text = text
    for i, s in sorted(enumerate(spans), key=lambda x: int(x[1]["start"]), reverse=True):
        if i not in prepared:
            continue
        start, end = int(s["start"]), int(s["end"])
        before = new_text
        new_text = new_text[:start] + prepared[i] + new_text[end:]
        if debug:
            print(f"[Apply ] #{i} 位置({start},{end})：{before!r} -> {new_text!r}")

    if debug:
        print("\n[Done ] 最終輸出：", new_text)
    return new_text