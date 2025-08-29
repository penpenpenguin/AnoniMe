# muiltAI_pii_replace.py
import json, os, hashlib, random, string, re
from typing import List, Dict, Tuple, Optional
from faker_models.presidio_replacer_plus import replace_pii as _presidio_replace

from transformers import pipeline
import torch

# ----------- Llama 模型初始化 -----------
from transformers import AutoTokenizer, AutoModelForCausalLM, pipeline

model_id = "meta-llama/Llama-3.2-1B-Instruct"

use_cuda = torch.cuda.is_available()
dtype = torch.bfloat16 if use_cuda else torch.float32  # GPU: bf16 / CPU: fp32（CPU 不要用 bf16）
device = 0 if use_cuda else -1

tok = AutoTokenizer.from_pretrained(model_id)
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    torch_dtype=dtype,
    device_map="auto" if use_cuda else None,   # CPU 就別用 device_map
)

pipe = pipeline(
    "text-generation",
    model=model,
    tokenizer=tok,
    device=device,
)

class LlamaChatClient:
    def chat(self, system_prompt: str, user_prompt: str) -> str:
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]
        # 轉成可生成的文字（避免直接丟 list）
        prompt_text = pipe.tokenizer.apply_chat_template(
            messages, tokenize=False, add_generation_prompt=True
        )

        out = pipe(
            prompt_text,
            max_new_tokens=32,          # 一行足夠
            do_sample=True,             # 讓 temperature/top_p 生效
            temperature=0.3,            # 假值要多樣但別太野
            top_p=0.9,
            return_full_text=False,
            eos_token_id=tok.eos_token_id,
            pad_token_id=tok.eos_token_id,
            max_time=6.0,
        )
        text = (out[0]["generated_text"] if out else "").strip()
        # 只取第一個非空行，避免多餘說明
        for line in text.splitlines():
            line = line.strip()
            if line:
                return line
        return ""


# ----------- safe chat 包裝 -----------
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
        return "\n".join(raw for _, _, raw in batch)    
    
# ----------- 生成快取 -----------
class MappingStore:
    def __init__(self, path: Optional[str] = None):
        base_dir = os.path.dirname(__file__)   # 這個檔案所在資料夾
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


# 批次處理類別 "DATE_TIME"
PRESIDIO_TYPES = {
    "EMAIL_ADDRESS",
    "PHONE_NUMBER", "TW_PHONE_NUMBER",
    "DATE", "TIME", "DURATION_TIME",
    "CREDIT_CARD",
    "IP_ADDRESS", "URL", "MAC_ADDRESS",
    "TW_ID_NUMBER", "UNIFIED_BUSINESS_NO", "TW_HEALTH_INSURANCE", "TW_PASSPORT_NUMBER",
    "UK_NHS",
    }


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
    "You anonymize sensitive strings.\n"
    "RULES:\n"
    "1) Output EXACTLY one line per item, in order, no extra text.\n"
    "2) Each line = replacement ONLY (no index/labels/quotes).\n"
    "3) Keep the same language/script as raw; keep punctuation/spaces.\n"
    "4) Preserve the overall pattern (letters vs digits vs symbols) and length within ±2 chars.\n"
    "5) The value MUST differ from raw; if unsure, minimally perturb letters/digits.\n"
    "\n"
    "Examples:\n"
    "Items to replace (one replacement per line, in order):\n"
    "type=PERSON; raw=John Doe\n"
    "type=ORGANIZATION; raw=Acme Corp.\n"
    "type=LOCATION; raw=New Taipei City\n"
    "===\n"
    "Jonn Dae\n"
    "Acna Carp.\n"
    "New Taipel Citz\n"
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
        if not batch: break
        user_prompt = build_user_prompt(batch)
        

        if debug:
            print("\n[Model] 發送批次：")
            print(user_prompt)

        # 呼叫後
        out = _safe_chat(chat_client, SYSTEM_PROMPT, user_prompt, batch, timeout_sec=10)

        # 解析 → 一行對一項
        lines = out.strip().splitlines()

        # 如果行數不足，補到跟 batch 一樣多（用 fallback）
        while len(lines) < len(batch):
            lines.append("")

        for line, (i, e_type, raw) in zip(lines, batch):
            rep = (line or "").strip()

            if (not rep) or (rep.strip() == "") or (rep == raw):
                # 不進行任何擾動：維持原文字
                rep = raw

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

