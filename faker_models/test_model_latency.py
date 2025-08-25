# test_model_latency.py
import time
import sys
from pathlib import Path  

# 將專案根加入 sys.path（AnoniMe）
root = Path(__file__).resolve().parents[1]
if str(root) not in sys.path:
    sys.path.insert(0, str(root))
from models.providers import get_chat_client

def main():
    client = get_chat_client()
    system_prompt = "You are a test model."
    user_prompt = "請隨便回覆一段簡短的文字，用來測試延遲。"

    print("[Test] 開始測試模型回應時間 ...")
    start = time.time()
    try:
        resp = client.chat(system_prompt, user_prompt, stream=False)
    except Exception as e:
        print("[Error] 模型呼叫失敗:", e)
        return
    end = time.time()

    print("模型回應：", resp[:200], "..." if len(resp) > 200 else "")
    print(f"耗時：{end - start:.2f} 秒")

if __name__ == "__main__":
    main()
