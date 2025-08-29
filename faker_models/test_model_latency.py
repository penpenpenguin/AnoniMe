# chat_cli.py
import os
os.environ["TRANSFORMERS_NO_TORCHAUDIO"] = "1"
os.environ["TRANSFORMERS_NO_TORCHVISION"] = "1"

import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
from transformers.generation.stopping_criteria import StoppingCriteriaList, MaxTimeCriteria

MODEL_ID = "meta-llama/Llama-3.2-1B-Instruct"   # 可換: "Qwen/Qwen2.5-0.5B-Instruct" 會更快
USE_CUDA = torch.cuda.is_available()
DTYPE = torch.bfloat16 if USE_CUDA else torch.float32   # GPU: bf16；CPU: fp32
DEVICE = 0 if USE_CUDA else -1

print(f"[Init] device={'cuda' if USE_CUDA else 'cpu'} dtype={DTYPE}")

tok = AutoTokenizer.from_pretrained(MODEL_ID)
model = AutoModelForCausalLM.from_pretrained(
    MODEL_ID,
    torch_dtype=DTYPE,
    device_map="auto" if USE_CUDA else None,  # CPU 不用 device_map
).eval()

# pad_token_id 必設，避免警告
if tok.pad_token_id is None:
    tok.pad_token_id = tok.eos_token_id

pipe = pipeline(
    "text-generation",
    model=model,
    tokenizer=tok,
    device=DEVICE,
)

SYSTEM = "You are a helpful, concise assistant."

history = []  # 存放 {"role": "...", "content": "..."}

def chat_once(user_text: str, max_new_tokens: int = 64, max_time: float = 4.0) -> str:
    global history
    messages = [{"role": "system", "content": SYSTEM}] + history + [{"role": "user", "content": user_text}]
    prompt = tok.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)

    with torch.inference_mode():
        out = pipe(
            prompt,
            max_new_tokens=max_new_tokens,   # 小一點 → 更快回應
            do_sample=False,                  # 決定性、也較快
            return_full_text=False,           # 只取生成部分
            eos_token_id=tok.eos_token_id,
            pad_token_id=tok.eos_token_id,
            max_time=max_time,                # 硬性截止，避免卡住
        )

    text = (out[0]["generated_text"] if out else "").strip()
    if text:
        for line in text.splitlines():        # 只留第一個非空行，防囉嗦
            line = line.strip()
            if line:
                text = line
                break

    history += [{"role": "user", "content": user_text}, {"role": "assistant", "content": text}]
    return text or "(no output)"

if __name__ == "__main__":
    print("=== Simple Chat (type 'exit' to quit) ===")
    while True:
        try:
            u = input("> ")
        except (EOFError, KeyboardInterrupt):
            print("\nBye!")
            break
        if not u or u.lower() in {"exit", "quit"}:
            print("Bye!")
            break
        try:
            ans = chat_once(u)
            print(ans)
        except Exception as e:
            print(f"[Error] {e}")
