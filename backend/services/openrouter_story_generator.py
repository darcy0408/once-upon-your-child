"""
OpenRouter Story Generation Service
Uses OpenRouter chat-completions to generate story text. Phase 1 of the
Gemini -> OpenRouter migration (MT-171): replaces Gemini-only text gen with a
tier-aware OpenRouter chain that does NOT subject child users to Gemini's
prohibited-use ToS for child-directed apps.
"""

import logging
import os
import time

import requests

logger = logging.getLogger(__name__)

# Paid / premium / family / BYOK tier: Claude Haiku 4.5 via OpenRouter.
# F-02 audit: was Claude Sonnet 4.7 (~$3/$15 per M). This OpenRouter path is
# only the *fallback* (primary is Gemini direct), so it fires rarely; Haiku
# keeps the three properties Sonnet was chosen for — Anthropic provider
# (cross-provider redundancy vs a Google/Gemini outage), native JSON mode, and
# a low refusal rate on child-safe content — at ~3x lower cost (~$1/$5 per M).
# Override via OPENROUTER_PAID_MODEL to A/B back to Sonnet without a deploy.
OPENROUTER_PAID_MODEL = "anthropic/claude-haiku-4.5"

# Free tier: Llama 3.3 70B Instruct — broad permissive license, capable of
# child-safe long-form prose. NOT the ":free" route (that hits an unstable
# free pool with stricter rate limits).
OPENROUTER_FREE_MODEL = "meta-llama/llama-3.3-70b-instruct"

# Hard fallback when tier resolution fails entirely (preserves the prior
# behavior — the pinned free Llama 3.2 3B route — so we never crash if both
# the env-based override and the tier table miss).
OPENROUTER_FALLBACK_MODEL = "meta-llama/llama-3.2-3b-instruct:free"

# Tiers that get the paid (higher-quality) text model. Anything not in this set —
# including a missing/None tier — falls through to free-tier logic, EXCEPT that
# an unknown non-empty tier is treated as paid (fail toward quality, mirroring
# the Gemini-side `_resolve_text_model` policy in
# backend/services/story_generation_service.py).
_PAID_TEXT_TIERS = frozenset({"premium", "family", "byok"})


_SAFETY_FALLBACK = (
    "I wasn't able to create that story right now. " "Let's try a different adventure!"
)

# Child-safety system prompt — parity with the OpenAI/Anthropic generators
# (audit P2#23). The OpenRouter request previously sent only a user message, so
# the weaker free-tier model (Llama) had no system-level safety framing. The
# upstream prompt already carries safety rules; this reinforces them. Override
# via OPENROUTER_SYSTEM_PROMPT.
_DEFAULT_SYSTEM_PROMPT = (
    "You are a warm, imaginative storyteller writing for children. Every story "
    "must be age-appropriate, kind, and emotionally safe: no graphic violence, "
    "no sexual content, no profanity, no frightening or unsafe-to-imitate "
    "scenarios, and no real-world personal data. Follow the user's structure "
    "and formatting instructions exactly."
)


def _resolve_text_model(user_tier: str | None) -> str:
    """Pick the OpenRouter text model for a subscription tier.

    Free-tier users get Llama 3.3 70B Instruct (free-tier-cheap, decent quality).
    Paid/Premium/Family/BYOK and any unrecognized non-empty tier get Claude
    Haiku 4.5 — a missing tier defaults to the paid model so a payer is never
    silently downgraded (fail toward quality), exactly like the Gemini-side
    helper at story_generation_service.py:_resolve_text_model.

    Both models are overridable via env vars so we can A/B without code change:
      OPENROUTER_PAID_MODEL  / OPENROUTER_FREE_MODEL
    """
    paid_model = os.getenv("OPENROUTER_PAID_MODEL", OPENROUTER_PAID_MODEL)
    free_model = os.getenv("OPENROUTER_FREE_MODEL", OPENROUTER_FREE_MODEL)
    tier = (user_tier or "").strip().lower()
    if tier == "free":
        return free_model
    return paid_model


def _extract_text(response_json: dict) -> str | None:
    """
    Pull text out of an OpenRouter chat-completions response and return None if
    the response was blocked / empty / truncated unsafely.

    OpenRouter follows the OpenAI shape:
        { "choices": [{"message": {"content": "..."}, "finish_reason": "stop"}] }

    Claude finish reasons via OpenRouter: ``end_turn``, ``max_tokens``,
    ``tool_use``. OpenAI/Llama finish reasons: ``stop``, ``length``,
    ``content_filter``, ``tool_calls``. We treat ``content_filter`` as a hard
    safety block (return None so the caller substitutes the user-visible
    ``_SAFETY_FALLBACK`` string). ``max_tokens`` / ``length`` are *truncated*
    but valid — we return the partial text rather than dropping it on the floor.

    Llama models don't expose granular safety-block metadata; for those, an
    empty content string is the only signal we have, so empty is treated as a
    block.
    """
    if not isinstance(response_json, dict):
        return None

    choices = response_json.get("choices") or []
    if not choices:
        logger.warning("OpenRouter response had no choices.")
        return None

    first = choices[0] or {}
    finish_reason = first.get("finish_reason") or first.get("native_finish_reason")
    message = first.get("message") or {}
    content = message.get("content")

    # Hard safety block (OpenAI/Llama-style).
    if finish_reason == "content_filter":
        logger.warning(
            "OpenRouter blocked response after generation. finish_reason=%s",
            finish_reason,
        )
        return None

    # Claude returns a list of content blocks under some routes; flatten if so.
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                text_part = block.get("text") or ""
                if text_part:
                    parts.append(text_part)
            elif isinstance(block, str):
                parts.append(block)
        content = "".join(parts) if parts else None

    if not content or not str(content).strip():
        logger.warning(
            "OpenRouter response had empty content. finish_reason=%s",
            finish_reason,
        )
        return None

    if finish_reason in ("max_tokens", "length"):
        # Truncated but non-empty — surface the partial text and log so we can
        # bump max_tokens if this is happening on real stories.
        logger.warning(
            "OpenRouter response truncated by output budget. finish_reason=%s len=%s",
            finish_reason,
            len(content),
        )

    return content


class OpenRouterStoryGenerator:
    def __init__(self, api_key=None, user_tier: str | None = None):
        """Initialize with OpenRouter API key and optional subscription tier.

        ``user_tier`` selects the model via ``_resolve_text_model``. When the
        caller does not pass a tier (legacy code path), the paid model is used
        (fail toward quality). Override per-request with
        ``generate_story(..., model=...)``.
        """
        self.api_key = api_key or os.getenv("OPENROUTER_API_KEY")
        if not self.api_key:
            raise ValueError("OPENROUTER_API_KEY not set")
        self.base_url = "https://openrouter.ai/api/v1"
        self._user_tier = user_tier
        self._system_prompt = os.getenv(
            "OPENROUTER_SYSTEM_PROMPT", _DEFAULT_SYSTEM_PROMPT
        )
        try:
            self._model_name = _resolve_text_model(user_tier)
        except Exception as exc:
            # Defensive: never let model-resolution crash the generator.
            logger.warning(
                "OpenRouter model resolution failed (%s); using hard fallback %s.",
                exc,
                OPENROUTER_FALLBACK_MODEL,
            )
            self._model_name = OPENROUTER_FALLBACK_MODEL
        logger.info(
            "Initializing OpenRouter with model: %s (tier=%s)",
            self._model_name,
            user_tier or "unknown",
        )

    def generate_story(self, prompt: str, model: str | None = None) -> str:
        """Generate story from prompt using an OpenRouter model.

        ``model`` overrides the tier-resolved default for the duration of this
        call only (used in tests and ad-hoc experiments).
        """
        max_retries = 3
        base_delay = 2  # seconds
        chosen_model = model or self._model_name or OPENROUTER_FALLBACK_MODEL

        for attempt in range(max_retries):
            try:
                logger.info(
                    "OpenRouter: Sending request for story generation... (Attempt %s, model=%s)",
                    attempt + 1,
                    chosen_model,
                )
                response = requests.post(
                    f"{self.base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "HTTP-Referer": "https://story-weaver-app-production.up.railway.app",  # Recommended by OpenRouter
                        "X-Title": "Story Weaver App",  # Recommended by OpenRouter
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": chosen_model,
                        "messages": [
                            {
                                "role": "system",
                                "content": self._system_prompt,
                            },
                            {
                                "role": "user",
                                "content": prompt,
                            },
                        ],
                    },
                    timeout=90,
                )

                response.raise_for_status()  # Will raise an HTTPError for bad responses (4xx or 5xx)

                data = response.json()
                story_text = _extract_text(data)
                if story_text:
                    logger.info("OpenRouter: Story generated successfully.")
                    return story_text

                # Safety block / empty content / no choices — don't retry.
                logger.warning(
                    "OpenRouter response did not contain valid story content (may be safety-filtered). Response: %s",
                    data,
                )
                return _SAFETY_FALLBACK

            except requests.exceptions.HTTPError as e:
                # Handle HTTP errors, including 429 Rate Limit
                if e.response.status_code == 429:
                    if attempt < max_retries - 1:
                        # Use exponential backoff, OpenRouter might have its own retry-after header
                        retry_after = int(
                            e.response.headers.get(
                                "Retry-After", base_delay * (2**attempt)
                            )
                        )
                        logger.warning(
                            f"OpenRouter rate limit exceeded. Retrying in {retry_after} seconds..."
                        )
                        time.sleep(retry_after)
                    else:
                        logger.error(
                            f"OpenRouter story generation failed after {max_retries} retries due to rate limiting.",
                            exc_info=True,
                        )
                        return "Sorry, the story generator is currently busy. Please try again in a few minutes."
                else:
                    # For other HTTP errors, fail immediately
                    logger.error(
                        f"OpenRouter API error: {e.response.status_code} - {e.response.text}",
                        exc_info=True,
                    )
                    return f"Sorry, there was a server error ({e.response.status_code}) while generating the story."
            except Exception as e:
                logger.error(
                    f"An unexpected error occurred with OpenRouter: {e}", exc_info=True
                )
                # For other exceptions, don't retry
                return (
                    "Sorry, an unexpected error occurred while generating your story."
                )

        return "Sorry, there was an error generating your story after multiple retries. Please try again later."
