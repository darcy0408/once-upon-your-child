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


def moderate_story_content(story_text: str, age: int, client=None) -> tuple[bool, str]:
    """Check a generated story for age-inappropriate content using an LLM classifier.

    Args:
        story_text: The full generated story text.
        age: The child's age (used to set age-appropriate safety thresholds).
        client: Optional google.genai.Client instance. If None, uses the
            module-level client initialised from GEMINI_API_KEY.

    Returns:
        (is_safe, reason) — is_safe=True means content passed, reason is
        empty string when safe or a brief explanation when flagged.

    On any error the function returns (True, "") to fail open, preserving
    story delivery while the keyword filter acts as the primary safety net.
    """
    if not story_text or not story_text.strip():
        return True, ""

    if client is None:
        try:
            client = _get_client()
        except Exception as exc:
            logger.warning(f"content_moderator: could not initialise client ({exc!r}), failing open")
            return True, ""

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
            logger.warning("content_moderator: empty response from classifier, failing open")
            return True, ""

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
            f"content_moderator: could not parse classifier response {raw[:200]!r}, failing open"
        )
        return True, ""
    except Exception as exc:
        logger.warning(
            f"content_moderator: classifier error ({exc!r}), failing open"
        )
        return True, ""
