"""LLM-based post-generation content safety classifier.

This is the second layer of output moderation, used after the fast keyword
filter in app_helpers.py. It catches contextual and subtle safety violations
that keyword matching cannot reliably detect.

Design principles:
- Fail open: if the classifier errors, the story passes (keyword filter
  already ran as the first layer).
- Age-band-aware: the classifier prompt is tailored to the child's age.
- Fast and cheap: uses gemini-2.5-flash-lite, not the full story model.
- Classifies only; never modifies story text.
"""

import json
import logging
import os

logger = logging.getLogger(__name__)

_CLASSIFIER_MODEL = "gemini-2.5-flash-lite"

# Upper age bound of the Sprout band (ages 3-5). The interactive story path
# fails CLOSED for this band: if the LLM classifier errors, the segment is
# replaced with SAFE_FALLBACK_SEGMENT rather than served unmoderated. Older
# bands keep the deliberate fail-open behaviour (the keyword filter ran first).
SPROUT_MAX_AGE = 5

# Generic, always-safe interactive segment served when moderation fails closed
# for the Sprout band, or when a generated segment is flagged. Deliberately
# gentle, choice-bearing, and free of any custom/free-text input so it cannot
# itself carry whatever made the original segment unsafe.
SAFE_FALLBACK_SEGMENT = {
    "title": "A Gentle Pause",
    "content": (
        "The little hero takes a slow, deep breath. The sun is warm and the "
        "garden is calm and safe. A friendly butterfly lands softly nearby and "
        "waits, ready for the next part of the adventure."
    ),
    "image_description": (
        "a warm, gentle children's book illustration of a sunny garden with a "
        "friendly butterfly, soft and calm"
    ),
    "output_type": "CHOICE",
    "choices": [
        {"id": "choice_1", "text": "Follow the friendly butterfly"},
        {"id": "choice_2", "text": "Rest in the warm sunshine"},
    ],
    "inventory": [],
    "story_state": {},
    "is_ending": False,
}


def is_sprout_band(age) -> bool:
    """True if *age* falls in the Sprout band (3-5), which fails closed."""
    try:
        return int(age) <= SPROUT_MAX_AGE
    except (TypeError, ValueError):
        # Unknown age — treat as the most protected band.
        return True


def build_safe_fallback_segment(segment_number: int = 1, is_opening: bool = True) -> dict:
    """Return a fresh copy of SAFE_FALLBACK_SEGMENT shaped for the caller.

    A copy is returned each call so callers can mutate it freely (e.g. when
    persisting a StorySegment record) without corrupting the module template.
    """
    segment = json.loads(json.dumps(SAFE_FALLBACK_SEGMENT))
    segment["segment_number"] = segment_number
    return segment

# Module-level client — initialised lazily so tests can patch os.getenv.
_client = None


def _get_client():
    global _client
    if _client is None:
        from google import genai
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise ValueError("GEMINI_API_KEY not set")
        _client = genai.Client(api_key=api_key)
    return _client


def _age_band_label(age: int) -> str:
    if age <= 7:
        return "a young child aged 3-7"
    if age <= 12:
        return "a child aged 8-12"
    if age <= 17:
        return "a teenager aged 13-17"
    return "an adult"


def moderate_story_content(
    story_text: str, age: int, client=None, fail_closed: bool = False
) -> tuple[bool, str]:
    """Check a generated story for age-inappropriate content using an LLM classifier.

    Args:
        story_text: The full generated story text.
        age: The child's age (used to set age-appropriate safety thresholds).
        client: Optional google.genai.Client instance. If None, uses the
            module-level client initialised from GEMINI_API_KEY.
        fail_closed: When True, a classifier error returns (False, <reason>)
            instead of (True, "") — i.e. the content is treated as UNSAFE
            when the classifier could not vet it. The interactive Sprout-band
            path (ages 3-5) sets this so unmoderated content is never served
            to the youngest children. Defaults to False (fail open) to
            preserve the existing behaviour of the keyword-backed paths.

    Returns:
        (is_safe, reason) — is_safe=True means content passed, reason is
        empty string when safe or a brief explanation when flagged.

    On any error the function returns (True, "") to fail open by default,
    preserving story delivery while the keyword filter acts as the primary
    safety net. With fail_closed=True it instead returns (False, reason).
    """
    if not story_text or not story_text.strip():
        return True, ""

    # Result returned when the classifier cannot run / cannot be trusted.
    _unverified = (False, "moderation unavailable") if fail_closed else (True, "")

    if client is None:
        try:
            client = _get_client()
        except Exception as exc:
            logger.warning(
                f"content_moderator: could not initialise client ({exc!r}), "
                f"{'failing closed' if fail_closed else 'failing open'}"
            )
            return _unverified

    age_label = _age_band_label(age)

    prompt = (
        f"You are a child content safety reviewer. Read the following story written for "
        f"{age_label} and determine whether it is safe and appropriate.\n\n"
        f"Flag the story as UNSAFE if it contains ANY of the following:\n"
        f"- Sexual content or innuendo\n"
        f"- Graphic violence, gore, or torture\n"
        f"- Self-harm or suicide themes\n"
        f"- Real personal information (e.g. real school names, home addresses, phone numbers)\n"
        f"- Content that would be frightening or harmful for {age_label}\n\n"
        f"Respond ONLY with a JSON object — no other text:\n"
        f'  {{"safe": true}} if the story is appropriate\n'
        f'  {{"safe": false, "reason": "brief explanation"}} if it is not\n\n'
        f"Story (first 3000 characters):\n{story_text[:3000]}"
    )

    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash-lite",
            contents=prompt,
        )
        raw = ""
        if response and hasattr(response, "text") and response.text:
            raw = response.text.strip()
        elif response and hasattr(response, "candidates") and response.candidates:
            candidate = response.candidates[0]
            if hasattr(candidate, "content") and candidate.content.parts:
                raw = candidate.content.parts[0].text.strip()

        if not raw:
            logger.warning(
                "content_moderator: empty response from classifier, "
                f"{'failing closed' if fail_closed else 'failing open'}"
            )
            return _unverified

        # Strip markdown code fences if the model wrapped its JSON
        if raw.startswith("```"):
            lines = raw.splitlines()
            raw = "\n".join(
                line for line in lines if not line.startswith("```")
            ).strip()

        result = json.loads(raw)
        is_safe = bool(result.get("safe", True))
        reason = result.get("reason", "") if not is_safe else ""

        if not is_safe:
            logger.warning(
                f"content_moderator: story flagged for age {age} — {reason!r} "
                f"(first 200 chars): {story_text[:200]!r}"
            )

        return is_safe, reason

    except json.JSONDecodeError:
        logger.warning(
            f"content_moderator: could not parse classifier response {raw[:200]!r}, "
            f"{'failing closed' if fail_closed else 'failing open'}"
        )
        return _unverified
    except Exception as exc:
        logger.warning(
            f"content_moderator: classifier error ({exc!r}), "
            f"{'failing closed' if fail_closed else 'failing open'}"
        )
        return _unverified
