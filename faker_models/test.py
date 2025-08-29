
import asyncio
import sys, os
from dotenv import load_dotenv
load_dotenv()
sys.path.append(r"C:\kuwa\GenAI OS\src\library\client\src\kuwa")
from client.base import KuwaClient

client = KuwaClient(
    base_url="http://127.0.0.1",
    model=".bot/Llama 3.1 8B @NPU",
    auth_token=os.environ.get("KUWA_API_KEY"),
)

async def main():
    user_prompt = input("> ")
    message = [{"role": "user", "content": user_prompt}]

    generator = client.chat_complete(messages=message, streaming=True)

    async for chunk in generator:
        print(chunk, end="")

    print()


if __name__ == "__main__":
    asyncio.run(main())

    