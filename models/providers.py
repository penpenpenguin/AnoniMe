import os
import requests
import configparser
from pathlib import Path

class ChatClient:
    def chat(self, system_prompt: str, user_prompt: str) -> str:
        raise NotImplementedError

class OllamaClient(ChatClient):
    def __init__(self, base_url: str = "http://localhost:11434", model: str = "llama3.2:latest"):
        self.base_url = base_url.rstrip("/")
        self.model = model
    def chat(self, system_prompt: str, user_prompt: str) -> str:
        url = f"{self.base_url}/api/chat"
        resp = requests.post(url, json={
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "stream": False,
        }, timeout=600)
        resp.raise_for_status()
        return resp.json()["message"]["content"]

def _load_cli_token_and_url():
    ini = Path.home() / ".qai_hub" / "client.ini"
    token = ""
    api_url = ""
    if ini.exists():
        cp = configparser.ConfigParser()
        cp.read(ini)
        token = cp.get("api", "api_token", fallback="")
        api_url = cp.get("api", "api_url", fallback="").rstrip("/")
    return token, api_url

class QualcommAiHubClient(ChatClient):
    """
    - 若設定 AIHUB_FULL_URL，直接使用該完整 URL（例如 Core42: https://playground.core42.ai/apis/v2/chat/completions）
    - AIHUB_AUTH = bearer | token | x-api-key
    """
    def __init__(self, api_key: str, endpoint: str, model: str):
        self.api_key = api_key
        self.endpoint = (endpoint or "").rstrip("/")
        self.model = model or "llama-v3.1-8b-instruct"
        self.chat_path = os.environ.get("AIHUB_CHAT_PATH", "/api/v1/chat/completions")
        self.auth_mode = os.environ.get("AIHUB_AUTH", "bearer").lower()
        self.full_url = os.environ.get("AIHUB_FULL_URL", "").strip()

    def _headers(self):
        h = {"Content-Type": "application/json"}
        if self.auth_mode == "x-api-key":
            h["x-api-key"] = self.api_key
        elif self.auth_mode == "token":
            h["Authorization"] = f"Token {self.api_key}"
        else:
            h["Authorization"] = f"Bearer {self.api_key}"
        return h

    def chat(self, system_prompt: str, user_prompt: str) -> str:
        url = self.full_url or (f"{self.endpoint}{self.chat_path}")
        print(f"[AIHUB] POST {url} model={self.model} auth={self.auth_mode}")
        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "stream": False,
        }
        resp = requests.post(url, json=payload, headers=self._headers(), timeout=600)
        try:
            resp.raise_for_status()
        except requests.HTTPError as e:
            raise RuntimeError(f"AI Hub HTTP {resp.status_code}: {resp.text}") from e
        data = resp.json()
        if isinstance(data, dict):
            if "choices" in data and data["choices"]:
                c0 = data["choices"][0]
                if isinstance(c0, dict):
                    if "message" in c0 and "content" in c0["message"]:
                        return c0["message"]["content"]
                    if "text" in c0:
                        return c0["text"]
            if "message" in data and "content" in data["message"]:
                return data["message"]["content"]
            if "output_text" in data:
                return data["output_text"]
        raise RuntimeError(f"Unexpected AI Hub response schema: {data}")

def get_chat_client() -> ChatClient:
    provider = os.environ.get("PROVIDER", "ollama").lower()
    if provider == "qualcomm":
        api_key = os.environ.get("AIHUB_API_KEY", "")
        endpoint = os.environ.get("AIHUB_ENDPOINT", "")
        model = os.environ.get("AIHUB_MODEL", "")
        full_url = os.environ.get("AIHUB_FULL_URL", "").strip()

        # 只在缺 token 時才讀 client.ini；有 FULL_URL 就不覆蓋 URL
        if not api_key:
            token, _api_url = _load_cli_token_and_url()
            api_key = api_key or token
        if not api_key:
            raise RuntimeError("缺少 AIHUB_API_KEY")

        return QualcommAiHubClient(api_key, endpoint, model)
    return OllamaClient()