"""
Anthropic Claude Story Generation Service (direct API).

MT-248: the launch-gate fix routes children's story TEXT to the Anthropic
Claude API, whose terms expressly permit products serving minors WITH COPPA
safeguards (age gate, AI-disclosure, content moderation, child-safety system
prompt) — unlike Gemini, whose Additional Terms prohibit child-directed apps.

This is the DIRECT-Anthropic counterpart to ``openrouter_story_generator.py``.
Routing Claude via OpenRouter works technically, but a direct API relationship
is the cleanest fit for Anthropic's "Organizations Serving Minors" program
(OpenRouter's ToS keeps you responsible for Anthropic's Model Terms and does
not shield you, and Anthropic's audit/suspend enforcement attaches to the
account). See docs/MT-248_RECOMMENDATIONS_2026-06-09.md.

The ``anthropic`` SDK is imported lazily (inside ``_make_anthropic_client``) so
this module imports cleanly in environments where the package isn't installed
yet — the provider simply fails closed to the static fallback at call time.
Going live needs only ``pip install anthropic`` + an ``ANTHROPIC_API_KEY``.
"""

import logging
import os

logger = logging.getLogger(__name__)

# Paid / premium / family / BYOK tier AND free tier both default to Claude
# Haiku 4.5 — a single clean provider at the cheap Anthropic tier ($1/$5 per M).
# Bump the paid model to Sonnet via OPENROUTER-style env override without a
# deploy. (Model IDs are bare aliases — never append a date suffix.)
ANTHROPIC_PAID_MODEL = "claude-haiku-4-5"
ANTHROPIC_FREE_MODEL = "claude-haiku-4-5"

# Hard fallback when tier resolution fails entirely (mirrors the OpenRouter
# generator's defensive constant so we never crash on an unknown-tier path).
ANTHROPIC_FALLBACK_MODEL = "claude-haiku-4-5"

# Output budget. Non-streaming single call — kept well under the ~16K
# non-streaming SDK-timeout threshold. A 15-page illustrated kids' story's JSON
# fits comfortably; override via ANTHROPIC_MAX_TOKENS if longer formats appear.
_DEFAULT_MAX_TOKENS = 8192

# Tiers that get the paid (higher-quality) text model. Anything not in this set
# — including a missing/None tier — falls through to free-tier logic, EXCEPT
# that an unknown non-empty tier is treated as paid (fail toward quality),
# matching the Gemini- and OpenRouter-side helpers.
_PAID_TEXT_TIERS = frozenset({"premium", "family", "byok"})

# Child-safety system prompt — a safeguard Anthropic's minors program expects.
# The upstream prompt (built by prompt_service) already carries safety framing;
# this reinforces it at the system level. Override via ANTHROPIC_SYSTEM_PROMPT.
_DEFAULT_SYSTEM_PROMPT = (
    "You are a warm, imaginative storyteller writing for children. Every story "
    "must be age-appropriate, kind, and emotionally safe: no graphic violence, "
    "no sexual content, no profanity, no frightening or unsafe-to-imitate "
    "scenarios, and no real-world personal data. Follow the user's structure "
    "and formatting instructions exactly."
)

_SAFETY_FALLBACK = (
    "I wasn't able to create that story right now. " "Let's try a different adventure!"
)


def _resolve_text_model(user_tier: str | None) -> str:
    """Pick the Claude model for a subscription tier.

    Mirrors ``openrouter_story_generator._resolve_text_model``: free tier gets
    the free model, paid/premium/family/BYOK and any unrecognized non-empty
    tier get the paid model, and a missing tier defaults to paid so a payer is
    never silently downgraded (fail toward quality). Both overridable via env.
    """
    paid_model = os.getenv("ANTHROPIC_PAID_MODEL", ANTHROPIC_PAID_MODEL)
    free_model = os.getenv("ANTHROPIC_FREE_MODEL", ANTHROPIC_FREE_MODEL)
    tier = (user_tier or "").strip().lower()
    if tier == "free":
        return free_model
    return paid_model


def _resolve_max_tokens() -> int:
    """Output-token budget, overridable via ANTHROPIC_MAX_TOKENS."""
    raw = os.getenv("ANTHROPIC_MAX_TOKENS")
    if not raw:
        return _DEFAULT_MAX_TOKENS
    try:
        value = int(raw)
        return value if value > 0 else _DEFAULT_MAX_TOKENS
    except (TypeError, ValueError):
        logger.warning(
            "ANTHROPIC_MAX_TOKENS=%r is not a valid int; using %s.",
            raw,
            _DEFAULT_MAX_TOKENS,
        )
        return _DEFAULT_MAX_TOKENS


def _extract_text(response) -> str | None:
    """
    Pull text out of an Anthropic Messages response and return None if the
    response was refused / empty so the caller substitutes ``_SAFETY_FALLBACK``.

    ``response.content`` is a list of content blocks; we concatenate the
    ``text`` blocks. ``stop_reason`` semantics (mirroring the OpenRouter side):
      * ``"refusal"`` — hard safety block -> None.
      * ``"max_tokens"`` — truncated but valid -> return the partial text.
      * ``"end_turn"`` / ``"stop_sequence"`` — normal completion.
    Empty / whitespace-only text is treated as a block (-> None).
    """
    if response is None:
        return None

    stop_reason = getattr(response, "stop_reason", None)

    if stop_reason == "refusal":
        details = getattr(response, "stop_details", None)
        category = getattr(details, "category", None)
        logger.warning(
            "Claude refused the request for safety reasons. category=%s", category
        )
        return None

    blocks = getattr(response, "content", None) or []
    parts = []
    for block in blocks:
        if getattr(block, "type", None) == "text":
            text_part = getattr(block, "text", "") or ""
            if text_part:
                parts.append(text_part)
    content = "".join(parts)

    if not content or not content.strip():
        logger.warning("Claude response had empty content. stop_reason=%s", stop_reason)
        return None

    if stop_reason == "max_tokens":
        logger.warning(
            "Claude response truncated by output budget. len=%s", len(content)
        )

    return content


def _make_anthropic_client(api_key: str):
    """Lazily import the SDK and build a client. Patched in tests.

    Kept as a module function (not an inline import) so unit tests can stub the
    SDK without the ``anthropic`` package being installed.
    """
    import anthropic  # lazy: see module docstring

    return anthropic.Anthropic(api_key=api_key)


class ClaudeDirectStoryGenerator:
    def __init__(self, api_key=None, user_tier: str | None = None):
        """Initialize with the Anthropic API key and optional subscription tier.

        ``user_tier`` selects the model via ``_resolve_text_model``. When the
        caller does not pass a tier (legacy call path), the paid model is used
        (fail toward quality). Override per-request with
        ``generate_story(..., model=...)``.
        """
        self.api_key = api_key or os.getenv("ANTHROPIC_API_KEY")
        if not self.api_key:
            raise ValueError("ANTHROPIC_API_KEY not set")
        self._user_tier = user_tier
        self._max_tokens = _resolve_max_tokens()
        self._system_prompt = os.getenv(
            "ANTHROPIC_SYSTEM_PROMPT", _DEFAULT_SYSTEM_PROMPT
        )
        try:
            self._model_name = _resolve_text_model(user_tier)
        except Exception as exc:
            # Defensive: never let model-resolution crash the generator.
            logger.warning(
                "Claude model resolution failed (%s); using hard fallback %s.",
                exc,
                ANTHROPIC_FALLBACK_MODEL,
            )
            self._model_name = ANTHROPIC_FALLBACK_MODEL
        # Build the client last so an import/auth failure surfaces here and is
        # tagged by the orchestrator's _try_claude rather than crashing import.
        self._client = _make_anthropic_client(self.api_key)
        logger.info(
            "Initializing Claude (direct) with model: %s (tier=%s)",
            self._model_name,
            user_tier or "unknown",
        )

    def generate_story(self, prompt: str, model: str | None = None) -> str:
        """Generate story text from ``prompt`` using a Claude model.

        ``model`` overrides the tier-resolved default for this call only (tests
        / ad-hoc experiments). The Anthropic SDK already retries 429 / 5xx with
        exponential backoff (default max_retries=2), so no hand-rolled retry
        loop is needed here.
        """
        chosen_model = model or self._model_name or ANTHROPIC_FALLBACK_MODEL
        try:
            logger.info("Claude (direct): generating story... (model=%s)", chosen_model)
            response = self._client.messages.create(
                model=chosen_model,
                max_tokens=self._max_tokens,
                system=self._system_prompt,
                messages=[{"role": "user", "content": prompt}],
            )
            story_text = _extract_text(response)
            if story_text:
                logger.info("Claude (direct): story generated successfully.")
                return story_text

            # Refusal / empty content — don't retry; surface the safety fallback
            # (mirrors the OpenRouter generator's behavior).
            logger.warning(
                "Claude response did not contain valid story content "
                "(may be refused). stop_reason=%s",
                getattr(response, "stop_reason", None),
            )
            return _SAFETY_FALLBACK

        except Exception as exc:
            # Classify by status_code when the SDK exposes one (RateLimitError,
            # APIStatusError, etc. all carry it), else fall back to a generic
            # message. Any "Sorry, ..." return is treated as a failure by the
            # orchestrator, which then falls through to the static fallback.
            status_code = getattr(exc, "status_code", None)
            logger.error(
                "Claude (direct) story generation failed (status=%s): %s",
                status_code,
                exc,
                exc_info=True,
            )
            if status_code == 429:
                return (
                    "Sorry, the story generator is currently busy. "
                    "Please try again in a few minutes."
                )
            if isinstance(status_code, int):
                return (
                    f"Sorry, there was a server error ({status_code}) "
                    "while generating the story."
                )
            return "Sorry, an unexpected error occurred while generating your story."
