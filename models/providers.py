# providers.py
# 功能：統一管理不同的 ChatClient (Ollama / Qualcomm)，
# 設定只讀取專案根目錄的 .env，不會再抓系統環境變數

import requests
from urllib.parse import urljoin
from typing import Optional, Dict, Any, List
from requests.exceptions import Timeout, HTTPError, RequestException



# -------------------- 讀取 .env --------------------
# 優先用 python-dotenv，沒有的話用簡單的自己 parser
try:
    from dotenv import dotenv_values   # pip install python-dotenv
    DOTENV = dotenv_values(".env")
    
except Exception:
    def _load_env_file(path: str = ".env") -> dict:
        values = {}
        try:
            with open(path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    if "=" in line:
                        k, v = line.split("=", 1)
                        values[k.strip()] = v.strip()
        except FileNotFoundError:
            pass
        return values
    DOTENV = _load_env_file()

def _int(v, default):
    try:
        return int(str(v).strip())
    except Exception:
        return default

REQ_TIMEOUT = _int(DOTENV.get("REQUEST_TIMEOUT", 60), 60)   # 預設 60 秒

def _flag(v: str) -> bool:
    """把字串轉成布林值，方便判斷 True/False"""
    return str(v or "").lower() not in ("", "0", "false", "no")

# 控制 debug 輸出
PROVIDERS_DEBUG = _flag(DOTENV.get("PROVIDERS_DEBUG", "0"))

# -------------------- ChatClient 介面 --------------------
class ChatClient:
    def chat(self, system_prompt: str, user_prompt: str, **kwargs) -> str:
        raise NotImplementedError

# -------------------- Ollama Client --------------------
class OllamaClient(ChatClient):
    """對接本機的 Ollama"""
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
        resp = requests.post(url, json=payload, timeout=REQ_TIMEOUT)   # ← 用同一個 REQ_TIMEOUT
        resp.raise_for_status()
        return resp.json()["message"]["content"]

# -------------------- RoundRobin ChatClient --------------------
class RoundRobinChatClient(ChatClient):
    """
    包多個 client，輪流使用。
    如果遇到 429 / Rate limit，就自動切換到下一個。
    """
    def __init__(self, clients: List[ChatClient]):
        assert clients, "RoundRobinChatClient 至少要有一個子 client"
        self.clients = clients
        self._i = 0

    def _is_rate_limit_err(self, e: Exception) -> bool:
        # 明確處理 requests 的 Timeout
        if isinstance(e, Timeout):
            return True
        msg = str(e).lower()
        if any(x in msg for x in ("429", "rate limit", "too many requests")):
            return True
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
                    print(f"[providers] 使用模型 idx={idx}")
                res = cli.chat(system_prompt, user_prompt, **kwargs)
                # 成功後，下一次換下一個 client
                self._i = (idx + 1) % n
                return res
            except Exception as e:
                last_err = e
                if self._is_rate_limit_err(e):
                    if PROVIDERS_DEBUG:
                        print(f"[providers] 模型 idx={idx} 被限流，換下一個")
                    self._i = (idx + 1) % n
                    continue
                raise
        raise last_err or RuntimeError("所有 client 都失敗")

# -------------------- Qualcomm Client --------------------
class QualcommAiHubClient(ChatClient):
    """對接 Core42 / Qualcomm AI Hub"""
    def __init__(
        self,
        api_key: str,
        base_or_endpoint: Optional[str] = None,   # 例如 https://playground.core42.ai/apis
        model: str = "Llama-3.1-8B",
        auth_mode: str = "bearer",                # bearer | token | x-api-key
        chat_path: str = "/v2/chat/completions",  # 預設 v2 路徑
    ):
        if not api_key:
            raise RuntimeError("AIHUB_API_KEY 不可為空")

        self.api_key = api_key.strip()
        self.model = model.strip()
        self.auth_mode = auth_mode.strip().lower()
        self.chat_path = chat_path.strip()

        # endpoint 設定
        raw = (base_or_endpoint or "").strip().rstrip("/")
        self._absolute_endpoint: Optional[str] = None
        if raw:
            if "/v2/" in raw:    # 已經是完整 endpoint
                self._absolute_endpoint = raw
                self.base = None
            else:
                self.base = raw  # base，例如 https://host/apis
        else:
            self.base = "https://playground.core42.ai/apis"

    def _headers(self) -> Dict[str, str]:
        h = {"Content-Type": "application/json"}
        if self.auth_mode == "x-api-key":
            h["x-api-key"] = self.api_key
        elif self.auth_mode == "token":
            h["Authorization"] = f"Token {self.api_key}"
        else:
            h["Authorization"] = f"Bearer {self.api_key}"
        return h

    def _endpoint_url(self) -> str:
        if self._absolute_endpoint:
            return self._absolute_endpoint
        base = (self.base or "https://playground.core42.ai/apis").rstrip("/") + "/"
        path = self.chat_path.lstrip("/")
        return urljoin(base, path)

    def chat(self, system_prompt: str, user_prompt: str, stream: bool = False,
            extra_params: Optional[Dict[str, Any]] = None) -> str:
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

        if PROVIDERS_DEBUG:
            print(f"[AIHUB] POST {url} model={self.model}")

        try:
            resp = requests.post(
                url, json=payload, headers=self._headers(), timeout=REQ_TIMEOUT
            )
            resp.raise_for_status()
        except Timeout as e:
            # 讓 RoundRobin 偵測到是 timeout，換下一個 client
            raise RuntimeError(f"timeout after {REQ_TIMEOUT}s") from e
        except HTTPError as e:
            # 附帶狀態碼與文字，除 429 以外會往外拋
            status = getattr(resp, "status_code", None)
            text = getattr(resp, "text", "")
            raise RuntimeError(f"AI Hub HTTP {status}: {text}") from e
        except RequestException as e:
            # 其他 requests 例外
            raise RuntimeError(f"AI Hub request failed: {e}") from e

        data = resp.json()
        # 解析回傳
        if "choices" in data and data["choices"]:
            c0 = data["choices"][0]
            if isinstance(c0, dict):
                msg = c0.get("message")
                if isinstance(msg, dict) and "content" in msg:
                    return msg["content"]
                if "text" in c0:
                    return c0["text"]
        if isinstance(data.get("message"), dict) and "content" in data["message"]:
            return data["message"]["content"]
        if "output_text" in data:
            return data["output_text"]

        raise RuntimeError(f"無法解析 AI Hub 回傳格式: {data}")

# -------------------- 工廠方法 --------------------
def _build_qualcomm_client_for_model(model: str) -> ChatClient:
    api_key = (DOTENV.get("AIHUB_API_KEY") or "").strip()
    base_or_endpoint = (DOTENV.get("AIHUB_FULL_URL") or DOTENV.get("AIHUB_ENDPOINT") or "").strip()
    auth_mode = (DOTENV.get("AIHUB_AUTH_MODE") or "bearer").strip().lower()
    chat_path = (DOTENV.get("AIHUB_CHAT_PATH") or "/v2/chat/completions").strip()
    return QualcommAiHubClient(
        api_key=api_key,
        base_or_endpoint=base_or_endpoint,
        model=model.strip(),
        auth_mode=auth_mode,
        chat_path=chat_path,
    )

def get_chat_client() -> ChatClient:
    """根據 .env 的 PROVIDER 來建立對應的 client"""
    provider = (DOTENV.get("PROVIDER") or "ollama").strip().lower()

    if provider == "qualcomm":
        # 支援多模型清單：AIHUB_MODELS=llama3-70b,Llama-3.1-8B
        raw_models = (DOTENV.get("AIHUB_MODELS") or "").strip()
        if raw_models:
            models = [m.strip() for m in raw_models.split(",") if m.strip()]
        else:
            models = [(DOTENV.get("AIHUB_MODEL") or "Llama-3.1-8B").strip()]

        # 過濾掉 vision 模型
        models = [m for m in models if "vision" not in m.lower()]

        clients = [_build_qualcomm_client_for_model(m) for m in models]
        return clients[0] if len(clients) == 1 else RoundRobinChatClient(clients)

    # 預設：Ollama
    base = (DOTENV.get("OLLAMA_URL") or "http://localhost:11434").strip()
    model = (DOTENV.get("OLLAMA_MODEL") or "llama3.2:latest").strip()
    return OllamaClient(base_url=base, model=model)
