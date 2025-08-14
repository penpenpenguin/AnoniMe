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
        resp = requests.post(
            url,
            json={
                "model": self.model,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                "stream": False,
            },
            timeout=600,
        )
        resp.raise_for_status()
        data = resp.json()
        return data["message"]["content"]

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
    依官方 API Sample 設定。
    - 預設 endpoint 用 app.aihub.qualcomm.com
    - AIHUB_CHAT_PATH 預設 /api/v1/chat/completions
    - AIHUB_AUTH = bearer | x-api-key
    """
    def __init__(self, api_key: str, endpoint: str, model: str):
        self.api_key = api_key
        self.endpoint = endpoint.rstrip("/")
        self.model = model
        self.chat_path = os.environ.get("AIHUB_CHAT_PATH", "/api/v1/chat/completions")
        self.auth_mode = os.environ.get("AIHUB_AUTH", "bearer").lower()

    def chat(self, system_prompt: str, user_prompt: str) -> str:
        url = f"{self.endpoint}{self.chat_path}"
        if self.auth_mode == "x-api-key":
            headers = {"x-api-key": self.api_key, "Content-Type": "application/json"}
        else:
            headers = {"Authorization": f"Bearer {self.api_key}", "Content-Type": "application/json"}
        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "stream": False,
        }
        resp = requests.post(url, json=payload, headers=headers, timeout=600)
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
        raise RuntimeError(f"Unexpected AI Hub response schema: {data}")

def get_chat_client() -> ChatClient:
    provider = os.environ.get("PROVIDER", "ollama").lower()
    if provider == "qualcomm":
        api_key = os.environ.get("AIHUB_API_KEY", "")
        endpoint = os.environ.get("AIHUB_ENDPOINT", "")
        model = os.environ.get("AIHUB_MODEL", "")
        if not api_key or not endpoint:
            token, api_url = _load_cli_token_and_url()
            api_key = api_key or token
            endpoint = endpoint or api_url or "https://app.aihub.qualcomm.com"
        if not model:
            model = "llama-v3.1-8b-instruct"
        if not api_key or not endpoint or not model:
            raise RuntimeError("AIHUB_API_KEY / AIHUB_ENDPOINT / AIHUB_MODEL 未設定")
        return QualcommAiHubClient(api_key, endpoint, model)
    base_url = os.environ.get("OLLAMA_URL", "http://localhost:11434")
    model = os.environ.get("OLLAMA_MODEL", "llama3.2:latest")
    return OllamaClient(base_url, model)