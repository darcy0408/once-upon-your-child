"""
OpenAI Story Generation Service (direct API).

MT-248 follow-up: the launch-gate fix routes children's story TEXT off Gemini
(whose Additional Terms prohibit child-directed apps) and onto providers whose
terms permit products serving minors WITH COPPA safeguards. OpenAI's usage
policies allow under-18 users with parental-consent / COPPA handling — the same
eligibility class as Anthropic — so OpenAI is a valid story-text provider.

This is the DIRECT-OpenAI counterpart to ``anthropic_story_generator.py``. The
2026-06 blind taste test (backend/scripts/taste_test_5x.py, n=5/cell) found
GPT-5 mini to be the cost-quality winner for the FREE / volume tier: cheapest
in every age band (~$0.0012/story, ~3.7x under Haiku) and fast (~7s), with
prose quality that held across all five samples — while GPT-5.4 was dominated
on every axis (priciest, slowest, shortest). The intended split is therefore
free -> OpenAI (gpt-5-mini), paid -> Claude (Haiku); see the ``tiered`` mode in
tasks/story_tasks.py and docs/MT-248_RECOMMENDATIONS_2026-06-09.md.

The ``openai`` SDK is imported lazily (inside ``_make_openai_client``) so this
module imports cleanly where the package isn't installed yet — the provider
simply fails closed to the static fallback at call time. Going live needs only
``pip install openai`` + an ``OPENAI_API_KEY``.
"""

import logging
import os

logger = logging.getLogger(__name__)

# Free AND paid tier both default to GPT-5 mini — the taste-test value winner.
# A pure-OpenAI deployment can bump the paid model to a larger model via env
# (OPENAI_PAID_MODEL) without a deploy, but the data did not justify paying for
# GPT-5.4: it lost to mini on cost and speed and to Haiku on warmth. (Model IDs
# are bare OpenAI slugs — e.g. "gpt-5-mini", "gpt-4.1".)
OPENAI_PAID_MODEL = "gpt-5-mini"
OPENAI_FREE_MODEL = "gpt-5-mini"

# Hard fallback when tier resolution fails entirely (mirrors the OpenRouter /
# Anthropic generators' defensive constant so we never crash on an unknown-tier
# path).
OPENAI_FALLBACK_MODEL = "gpt-5-mini"

# Output budget. GPT-5 is a reasoning family: the Chat Completions API takes
# ``max_completion_tokens`` (NOT the deprecated ``max_tokens``) and the budget
# must cover hidden reasoning tokens AND the visible story, so it is set higher
# than the visible-prose need. Override via OPENAI_MAX_TOKENS.
_DEFAULT_MAX_TOKENS = 8192

# Reasoning effort for GPT-5 / o-series. "low" matches the taste-test config:
# it keeps the model from burning the whole token budget on hidden reasoning
# before it writes the story (the cause of the empty-content failure seen at
# default effort). Set OPENAI_REASONING_EFFORT to "none"/"off"/"" to omit the
# param entirely — required when overriding to a NON-reasoning model like
# gpt-4.1, which rejects ``reasoning_effort``.
_DEFAULT_REASONING_EFFORT = "low"

# Tiers that get the paid (higher-quality) text model. Anything not in this set
# — including a missing/None tier — falls through to free-tier logic, EXCEPT
# that an unknown non-empty tier is treated as paid (fail toward quality),
# matching the Gemini-, OpenRouter-, and Anthropic-side helpers.
_PAID_TEXT_TIERS = frozenset({"premium", "family", "byok"})

# Child-safety system prompt — a safeguard the COPPA posture expects. The
# upstream prompt (built by prompt_service) already carries safety framing;
# this reinforces it at the system level. Override via OPENAI_SYSTEM_PROMPT.
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

_NO_REASONING_SENTINELS = frozenset({"", "none", "off", "default"})


def _resolve_text_model(user_tier: str | None) -> str:
    """Pick the OpenAI model for a subscription tier.

    Mirrors ``anthropic_story_generator._resolve_text_model``: free tier gets
    the free model, paid/premium/family/BYOK and any unrecognized non-empty
    tier get the paid model, and a missing tier defaults to paid so a payer is
    never silently downgraded (fail toward quality). Both overridable via env.
    """
    paid_model = os.getenv("OPENAI_PAID_MODEL", OPENAI_PAID_MODEL)
    free_model = os.getenv("OPENAI_FREE_MODEL", OPENAI_FREE_MODEL)
    tier = (user_tier or "").strip().lower()
    if tier == "free":
        return free_model
    return paid_model


def _resolve_max_tokens() -> int:
    """Output-token budget, overridable via OPENAI_MAX_TOKENS."""
    raw = os.getenv("OPENAI_MAX_TOKENS")
    if not raw:
        return _DEFAULT_MAX_TOKENS
    try:
        value = int(raw)
        return value if value > 0 else _DEFAULT_MAX_TOKENS
    except (TypeError, ValueError):
        logger.warning(
            "OPENAI_MAX_TOKENS=%r is not a valid int; using %s.",
            raw,
            _DEFAULT_MAX_TOKENS,
        )
        return _DEFAULT_MAX_TOKENS


def _resolve_reasoning_effort() -> str | None:
    """Reasoning effort for the request, or None to omit the param.

    Returns None when OPENAI_REASONING_EFFORT is set to a no-reasoning sentinel
    ("none"/"off"/""/"default") so a non-reasoning override model (e.g. gpt-4.1)
    doesn't 400 on an unsupported ``reasoning_effort`` argument.
    """
    raw = os.getenv("OPENAI_REASONING_EFFORT")
    if raw is None:
        return _DEFAULT_REASONING_EFFORT
    effort = raw.strip().lower()
    if effort in _NO_REASONING_SENTINELS:
        return None
    return effort


def _extract_text(choice) -> str | None:
    """
    Pull text out of an OpenAI Chat Completions ``choice`` and return None if
    the response was refused / filtered / empty so the caller substitutes
    ``_SAFETY_FALLBACK``.

    ``finish_reason`` semantics (mirroring the Anthropic side):
      * ``"content_filter"`` — hard safety block -> None.
      * a structured ``message.refusal`` -> None.
      * ``"length"`` — truncated by the token budget but valid -> partial text.
      * ``"stop"`` — normal completion.
    Empty / whitespace-only content is treated as a block (-> None).
    """
    if choice is None:
        return None

    finish_reason = getattr(choice, "finish_reason", None)
    message = getattr(choice, "message", None)

    if finish_reason == "content_filter":
        logger.warning("OpenAI blocked the request (finish_reason=content_filter).")
        return None

    refusal = getattr(message, "refusal", None)
    if refusal:
        logger.warning("OpenAI returned a structured refusal: %s", refusal)
        return None

    content = getattr(message, "content", None) or ""
    if not content or not content.strip():
        logger.warning(
            "OpenAI response had empty content. finish_reason=%s", finish_reason
        )
        return None

    if finish_reason == "length":
        logger.warning(
            "OpenAI response truncated by output budget. len=%s", len(content)
        )

    return content


def _make_openai_client(api_key: str):
    """Lazily import the SDK and build a client. Patched in tests.

    Kept as a module function (not an inline import) so unit tests can stub the
    SDK without the ``openai`` package being installed.
    """
    import openai  # lazy: see module docstring

    return openai.OpenAI(api_key=api_key)


class OpenAIStoryGenerator:
    def __init__(self, api_key=None, user_tier: str | None = None):
        """Initialize with the OpenAI API key and optional subscription tier.

        ``user_tier`` selects the model via ``_resolve_text_model``. When the
        caller does not pass a tier (legacy call path), the paid model is used
        (fail toward quality). Override per-request with
        ``generate_story(..., model=...)``.
        """
        self.api_key = api_key or os.getenv("OPENAI_API_KEY")
        if not self.api_key:
            raise ValueError("OPENAI_API_KEY not set")
        self._user_tier = user_tier
        self._max_tokens = _resolve_max_tokens()
        self._reasoning_effort = _resolve_reasoning_effort()
        self._system_prompt = os.getenv("OPENAI_SYSTEM_PROMPT", _DEFAULT_SYSTEM_PROMPT)
        try:
            self._model_name = _resolve_text_model(user_tier)
        except Exception as exc:
            # Defensive: never let model-resolution crash the generator.
            logger.warning(
                "OpenAI model resolution failed (%s); using hard fallback %s.",
                exc,
                OPENAI_FALLBACK_MODEL,
            )
            self._model_name = OPENAI_FALLBACK_MODEL
        # Build the client last so an import/auth failure surfaces here and is
        # tagged by the orchestrator's _try_openai rather than crashing import.
        self._client = _make_openai_client(self.api_key)
        logger.info(
            "Initializing OpenAI (direct) with model: %s (tier=%s)",
            self._model_name,
            user_tier or "unknown",
        )

    def generate_story(self, prompt: str, model: str | None = None) -> str:
        """Generate story text from ``prompt`` using an OpenAI model.

        ``model`` overrides the tier-resolved default for this call only (tests
        / ad-hoc experiments). The OpenAI SDK already retries 429 / 5xx with
        exponential backoff (default max_retries=2), so no hand-rolled retry
        loop is needed here.
        """
        chosen_model = model or self._model_name or OPENAI_FALLBACK_MODEL
        # GPT-5 reasoning models require max_completion_tokens, not max_tokens.
        kwargs = {
            "model": chosen_model,
            "max_completion_tokens": self._max_tokens,
            "messages": [
                {"role": "system", "content": self._system_prompt},
                {"role": "user", "content": prompt},
            ],
        }
        if self._reasoning_effort is not None:
            kwargs["reasoning_effort"] = self._reasoning_effort
        try:
            logger.info("OpenAI (direct): generating story... (model=%s)", chosen_model)
            response = self._client.chat.completions.create(**kwargs)
            choice = (getattr(response, "choices", None) or [None])[0]
            story_text = _extract_text(choice)
            if story_text:
                logger.info("OpenAI (direct): story generated successfully.")
                return story_text

            # Refusal / filter / empty content — don't retry; surface the safety
            # fallback (mirrors the Anthropic generator's behavior).
            logger.warning(
                "OpenAI response did not contain valid story content "
                "(may be refused). finish_reason=%s",
                getattr(choice, "finish_reason", None),
            )
            return _SAFETY_FALLBACK

        except Exception as exc:
            # Classify by status_code when the SDK exposes one (RateLimitError,
            # APIStatusError, etc. all carry it), else fall back to a generic
            # message. Any "Sorry, ..." return is treated as a failure by the
            # orchestrator, which then falls through to the static fallback.
            status_code = getattr(exc, "status_code", None)
            logger.error(
                "OpenAI (direct) story generation failed (status=%s): %s",
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
