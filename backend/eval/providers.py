"""Provider clients for the eval harness.

Three providers, three roles:
  - Gemini      : generation (the product) + optional Pro judge
  - OpenRouter  : fallback-parity generation
  - GitHubModels: judge only — free programmatic GPT-4.1/GPT-5 via the
                  GitHub Models marketplace (Student/Pro accounts)

Only GitHubModels is implemented today; Gemini and OpenRouter generation
stay stubbed until a budget is authorized. GitHub Models is free, so its
client is live now and used for the judge pass + connectivity ping.

Env vars (loaded from backend/.env):
  GITHUB_MODELS_TOKEN  - fine-grained PAT with the Models account permission
  GEMINI_API_KEY       - already present; used later for generation/Pro judge
"""

from __future__ import annotations

import os
import time
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
BACKEND_ENV = REPO_ROOT / "backend" / ".env"

GITHUB_MODELS_BASE_URL = "https://models.github.ai/inference"

# GitHub Models ids are publisher-prefixed. Defaults chosen for rubric
# scoring: gpt-4.1 is strong and mid-tier on rate limits; the -mini fallback
# sits in a higher-rate-limit tier if the full model throttles.
GITHUB_JUDGE_MODEL = "openai/gpt-4.1"
GITHUB_JUDGE_MODEL_FALLBACK = "openai/gpt-4.1-mini"


def load_env() -> None:
    """Load backend/.env into os.environ if not already present."""
    if BACKEND_ENV.exists():
        try:
            from dotenv import load_dotenv
            load_dotenv(BACKEND_ENV, override=False)
        except ImportError:
            # Minimal fallback parser if python-dotenv is absent.
            for line in BACKEND_ENV.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, _, v = line.partition("=")
                os.environ.setdefault(k.strip(), v.strip())


@dataclass
class CompletionResult:
    text: str
    model: str
    input_tokens: int | None
    output_tokens: int | None
    latency_ms: int
    error: str | None = None


class GitHubModelsClient:
    """Thin wrapper over the OpenAI SDK pointed at the GitHub Models endpoint.

    GitHub Models speaks the OpenAI chat-completions protocol, so the
    installed `openai` package works directly with a different base_url.
    """

    def __init__(self, model: str = GITHUB_JUDGE_MODEL):
        load_env()
        token = os.environ.get("GITHUB_MODELS_TOKEN")
        if not token:
            raise RuntimeError(
                "GITHUB_MODELS_TOKEN not found. Add it to backend/.env "
                "(fine-grained PAT with the Models account permission)."
            )
        try:
            from openai import OpenAI
        except ImportError as exc:
            raise RuntimeError(
                "The `openai` package is required for GitHub Models. "
                "Install with: pip install openai"
            ) from exc
        self._client = OpenAI(base_url=GITHUB_MODELS_BASE_URL, api_key=token)
        self.model = model

    def ping(self) -> CompletionResult:
        """One trivial call to confirm the token and endpoint work.

        Costs nothing (GitHub Models is free) and burns a single tiny request
        against the daily rate limit.
        """
        return self.complete(
            system="You are a connectivity check. Reply with exactly: OK",
            user="ping",
            max_tokens=5,
        )

    def complete(self, system: str, user: str, max_tokens: int = 1024,
                 temperature: float = 0.0) -> CompletionResult:
        start = time.time()
        try:
            resp = self._client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system},
                    {"role": "user", "content": user},
                ],
                max_tokens=max_tokens,
                temperature=temperature,
            )
        except Exception as exc:  # noqa: BLE001 - surface any provider error to the caller
            return CompletionResult(
                text="", model=self.model, input_tokens=None,
                output_tokens=None, latency_ms=int((time.time() - start) * 1000),
                error=f"{type(exc).__name__}: {exc}",
            )
        usage = getattr(resp, "usage", None)
        return CompletionResult(
            text=(resp.choices[0].message.content or "").strip(),
            model=self.model,
            input_tokens=getattr(usage, "prompt_tokens", None),
            output_tokens=getattr(usage, "completion_tokens", None),
            latency_ms=int((time.time() - start) * 1000),
        )
