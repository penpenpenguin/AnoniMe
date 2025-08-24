import os
import requests
import configparser
from pathlib import Path
from urllib.parse import urljoin
from typing import Optional, Dict, Any, List

PROVIDERS_DEBUG = os.getenv("PROVIDERS_DEBUG", "0").lower() not in ("", "0", "false", "no")


class ChatClient:
    def chat(self, system_prompt: str, user_prompt: str, **kwargs) -> str:
        raise NotImplementedError


class OllamaClient(ChatClient):
    def __init__(self, base_url: str = "http://localhost:11434", model: str = "llama3.2:latest"):
        self.base_url = base_url.rstrip("/")
        self.model = model

    def chat(self, system_prompt: str, user_prompt: str, stream: bool = False, **kwargs) -> str:
        url = f"{self.base_url}/api/chat"
        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "stream": bool(stream),
        }
        resp = requests.post(url, json=payload, timeout=600)
        resp.raise_for_status()
        return resp.json()["message"]["content"]


class RoundRobinChatClient(ChatClient):
    """將多個 ChatClient 組成一個，依序輪替；遇到 429/Rate limit 會切到下一個。"""
    def __init__(self, clients: List[ChatClient]):
        assert clients, "RoundRobinChatClient 需要至少一個子 client"
        self.clients = clients
        self._i = 0

    def _is_rate_limit_err(self, e: Exception) -> bool:
        msg = str(e).lower()
        if "429" in msg or "rate limit" in msg or "too many requests" in msg:
            return True
        # 某些實作會掛在 e.response.status_code
        try:
            return getattr(getattr(e, "response", None), "status_code", 0) == 429
        except Exception:
            return False

    def chat(self, system_prompt: str, user_prompt: str, **kwargs):
        n = len(self.clients)
        last_err = None
        for _ in range(n):
            idx = self._i % n
            cli = self.clients[idx]
            try:
                if PROVIDERS_DEBUG:
                    m = getattr(cli, "model", None)
                    print(f"[providers] round-robin use model={m} idx={idx}")
                res = cli.chat(system_prompt, user_prompt, **kwargs)
                # 下一次從下一個開始
                self._i = (idx + 1) % n
                return res
            except Exception as e:
                last_err = e
                if self._is_rate_limit_err(e):
                    if PROVIDERS_DEBUG:
                        print(f"[providers] rate-limited on idx={idx}, try next client")
                    # 換下個 client
                    self._i = (idx + 1) % n
                    continue
                # 非限流錯誤，直接拋出
                raise
        # 全部都限流或失敗，拋最後一個錯
        raise last_err or RuntimeError("All clients failed")


# -------------------- Qualcomm / Core42 v2 client --------------------

def _load_cli_token_and_url():
    """Load defaults from ~/.qai_hub/client.ini if present.
    [api]
    api_token=...
    api_url=https://playground.core42.ai/apis
    """
    ini = Path.home() / ".qai_hub" / "client.ini"
    token = ""
    api_url = ""
    if ini.exists():
        cp = configparser.ConfigParser()
        cp.read(ini)
        token = cp.get("api", "api_token", fallback="").strip()
        api_url = cp.get("api", "api_url", fallback="").strip().rstrip("/")
    return token, api_url


class QualcommAiHubClient(ChatClient):
    """
    Compatible with Core42/Qualcomm AI Inference Suite (OpenAPI servers: "/apis")

    ENV VARIABLES (recommended):
      PROVIDER=qualcomm
      AIHUB_API_KEY = <token or JWT>
      AIHUB_FULL_URL = "https://playground.core42.ai/apis"   # BASE, not the endpoint
      AIHUB_AUTH_MODE = bearer|token|x-api-key                  # default: bearer
      AIHUB_MODEL = Llama-3.1-8B                                # or any available model

    Back-compat (optional):
      AIHUB_ENDPOINT + AIHUB_CHAT_PATH (discouraged). If present, they are joined.
    """

    def __init__(
        self,
        api_key: str,
        base_or_endpoint: Optional[str] = None,
        model: Optional[str] = None,
        auth_mode: Optional[str] = None,
        chat_path: Optional[str] = None,
    ):
        if not api_key:
            raise RuntimeError("AIHUB_API_KEY is required")
        self.api_key = api_key.strip()

        # Choose model
        self.model = (model or os.getenv("AIHUB_MODEL") or "Llama-3.1-8B").strip()

        # Auth mode: use AIHUB_AUTH_MODE (not AIHUB_AUTH) to avoid confusion with Authorization header
        self.auth_mode = (auth_mode or os.getenv("AIHUB_AUTH_MODE") or "bearer").strip().lower()

        # Path handling: prefer v2 per OpenAPI; allow override for legacy
        self.chat_path = (chat_path or os.getenv("AIHUB_CHAT_PATH") or "/v2/chat/completions").strip()

        # Base URL / endpoint handling
        # priority: explicit base_or_endpoint -> AIHUB_FULL_URL -> AIHUB_ENDPOINT -> default base
        raw = (base_or_endpoint or os.getenv("AIHUB_FULL_URL") or os.getenv("AIHUB_ENDPOINT") or "").strip().rstrip("/")
        self._absolute_endpoint: Optional[str] = None

        if raw:
            # If it already contains /v2/, assume it's the full endpoint (absolute)
            if "/v2/" in raw:
                self._absolute_endpoint = raw
                self.base = None
            else:
                self.base = raw  # treat as BASE (e.g., https://host/apis)
        else:
            self.base = "https://playground.core42.ai/apis"  # sensible default BASE

    # -------------------- helpers --------------------
    def _headers(self) -> Dict[str, str]:
        h = {"Content-Type": "application/json"}
        if self.auth_mode == "x-api-key":
            h["x-api-key"] = self.api_key
        elif self.auth_mode == "token":
            h["Authorization"] = f"Token {self.api_key}"
        else:  # bearer
            h["Authorization"] = f"Bearer {self.api_key}"
        return h

    def _endpoint_url(self) -> str:
        if self._absolute_endpoint:
            return self._absolute_endpoint
        # join base + /v2/chat/completions (or custom path)
        base = (self.base or "https://playground.core42.ai/apis").rstrip("/") + "/"
        path = self.chat_path.lstrip("/")
        return urljoin(base, path)

    def _mask(self, token: str) -> str:
        return (token[:6] + "…" + token[-4:]) if len(token) > 12 else "***"

    # -------------------- public APIs --------------------
    def chat(self, system_prompt: str, user_prompt: str, stream: bool = False, extra_params: Optional[Dict[str, Any]] = None) -> str:
        url = self._endpoint_url()
        payload: Dict[str, Any] = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "stream": bool(stream),
        }
        if extra_params:
            payload.update(extra_params)

        print(f"[AIHUB] POST {url} model={self.model} auth_mode={self.auth_mode} token={self._mask(self.api_key)}")
        resp = requests.post(url, json=payload, headers=self._headers(), timeout=600)
        try:
            resp.raise_for_status()
        except requests.HTTPError as e:
            raise RuntimeError(f"AI Hub HTTP {resp.status_code}: {resp.text}") from e

        data = resp.json()
        # OpenAI-like / Core42-like schema
        if isinstance(data, dict):
            if "choices" in data and data["choices"]:
                c0 = data["choices"][0]
                if isinstance(c0, dict):
                    msg = c0.get("message")
                    if isinstance(msg, dict) and "content" in msg:
                        return msg["content"]
                    if "text" in c0:
                        return c0["text"]
            # some providers flatten
            if isinstance(data.get("message"), dict) and "content" in data["message"]:
                return data["message"]["content"]
            if "output_text" in data:
                return data["output_text"]
        raise RuntimeError(f"Unexpected AI Hub response schema: {data}")


# -------------------- factory --------------------

def _build_qualcomm_client_for_model(model: str) -> ChatClient:
    api_key = os.environ.get("AIHUB_API_KEY", "").strip()
    base_or_endpoint = os.environ.get("AIHUB_FULL_URL", "").strip()
    auth_mode = os.environ.get("AIHUB_AUTH_MODE", "bearer").strip().lower()
    chat_path = os.environ.get("AIHUB_CHAT_PATH", "apis/v2/chat/completions").strip()
    return QualcommAiHubClient(
        api_key=api_key,
        base_or_endpoint=base_or_endpoint,
        model=model.strip(),
        auth_mode=auth_mode,
        chat_path=chat_path,
    )

def get_chat_client() -> ChatClient:
    provider = os.environ.get("PROVIDER", "ollama").strip().lower()

    if provider == "qualcomm":
        # 支援多模型清單：AIHUB_MODELS=llama3-70b,Llama-3.1-8B,openai/gpt-oss-20b
        raw_models = os.environ.get("AIHUB_MODELS", "").strip()
        if raw_models:
            models = [m.strip() for m in raw_models.split(",") if m.strip()]
        else:
            # 單一模型仍相容 AIHUB_MODEL
            models = [os.environ.get("AIHUB_MODEL", "Llama-3.1-8B").strip()]

        # 避免視覺模型干擾文字任務
        models = [m for m in models if "vision" not in m.lower()]

        clients = [_build_qualcomm_client_for_model(m) for m in models]
        if PROVIDERS_DEBUG:
            print("[providers] build qualcomm clients:", [getattr(c, "model", None) for c in clients])

        if len(clients) == 1:
            return clients[0]
        return RoundRobinChatClient(clients)

    # default: ollama
    base = os.environ.get("OLLAMA_URL", "http://localhost:11434").strip()
    model = os.environ.get("OLLAMA_MODEL", "llama3.2:latest").strip()
    return OllamaClient(base_url=base, model=model)
