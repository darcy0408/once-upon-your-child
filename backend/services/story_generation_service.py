import logging
import os
import time
from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import TimeoutError as FuturesTimeoutError
from typing import Iterator

from google import genai
from google.api_core import exceptions as google_exceptions
from google.genai import types

logger = logging.getLogger(__name__)

# Output-side content filter applied to every Gemini response before it is
# returned to the caller.  These settings are evaluated by the model after
# generation — a separate layer from the prompt-injection defenses in
# story_service.py.  Thresholds are tuned for a children's audience:
#   BLOCK_LOW_AND_ABOVE  — near-zero tolerance (sexual content, hate, harassment)
#   BLOCK_MEDIUM_AND_ABOVE — blocks moderate+ harm (allows mild age-appropriate
#                            danger/conflict language that appears in children's
#                            stories, e.g. "the dragon was frightening").
_CHILD_SAFETY_SETTINGS = [
    types.SafetySetting(
        category="HARM_CATEGORY_SEXUALLY_EXPLICIT",
        threshold="BLOCK_LOW_AND_ABOVE",
    ),
    types.SafetySetting(
        category="HARM_CATEGORY_DANGEROUS_CONTENT",
        threshold="BLOCK_MEDIUM_AND_ABOVE",
    ),
    types.SafetySetting(
        category="HARM_CATEGORY_HARASSMENT",
        threshold="BLOCK_LOW_AND_ABOVE",
    ),
    types.SafetySetting(
        category="HARM_CATEGORY_HATE_SPEECH",
        threshold="BLOCK_LOW_AND_ABOVE",
    ),
]

_SAFETY_FALLBACK = (
    "I wasn't able to create that story right now. " "Let's try a different adventure!"
)


def _extract_text(response) -> str | None:
    """
    Pull text out of a Gemini response and return None if the response was
    blocked by the safety filter rather than raising or returning empty text.
    Logs safety blocks so they can be monitored without exposing prompt content.
    """
    # Check prompt-level block (request rejected before generation).
    feedback = getattr(response, "prompt_feedback", None)
    if feedback and getattr(feedback, "block_reason", None):
        logger.warning(
            "Gemini blocked the request at prompt level. block_reason=%s",
            feedback.block_reason,
        )
        return None

    candidates = getattr(response, "candidates", None) or []
    for candidate in candidates:
        finish_reason = getattr(candidate, "finish_reason", None)
        # finish_reason == 3 or "SAFETY" indicates a safety-filtered response.
        if finish_reason in (3, "SAFETY", "RECITATION"):
            ratings = getattr(candidate, "safety_ratings", [])
            triggered = [
                f"{r.category}={r.probability}"
                for r in ratings
                if getattr(r, "blocked", False)
            ]
            logger.warning(
                "Gemini blocked response after generation. finish_reason=%s triggered=%s",
                finish_reason,
                triggered,
            )
            return None

    # Normal extraction paths.
    if response and hasattr(response, "text") and response.text:
        return response.text
    for candidate in candidates:
        content = getattr(candidate, "content", None)
        if content and getattr(content, "parts", None):
            text = content.parts[0].text
            if text:
                return text

    return None


# Tiers that get the full-quality (more expensive) text model. Anything not in
# this set — including a missing/None tier — falls through to free-tier logic,
# EXCEPT that an unknown non-empty tier is treated as paid (fail toward quality).
_PAID_TEXT_TIERS = frozenset({"premium", "family", "byok"})


def _resolve_text_model(user_tier: str | None) -> str:
    """Pick the Gemini text model for a subscription tier.

    Free-tier users (who never pay) get the cheaper flash-lite model;
    everyone else — paid, BYOK, or any unrecognized tier — gets the full
    GEMINI_MODEL. A missing tier defaults to the full model so a payer is
    never silently downgraded (fail toward quality).
    """
    full_model = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
    free_model = os.getenv("GEMINI_MODEL_FREE", "gemini-2.5-flash-lite")
    tier = (user_tier or "").strip().lower()
    if tier == "free":
        return free_model
    return full_model


class StoryGenerationService:
    def __init__(self, user_tier: str | None = None):
        primary_key = os.getenv("GEMINI_API_KEY")
        if not primary_key:
            raise ValueError("GEMINI_API_KEY not set")

        # Build a rotation list: primary key first, then up to 3 backup keys.
        # When the primary key is rate-limited the service cycles through backups
        # before giving up and raising ResourceExhausted to the caller.
        backup_keys = [
            k
            for k in (
                os.getenv("GOOGLE_API_KEY_2"),
                os.getenv("GOOGLE_API_KEY_3"),
                os.getenv("GOOGLE_API_KEY_4"),
            )
            if k
        ]
        self._api_keys = [primary_key] + backup_keys
        self._client = genai.Client(api_key=primary_key)
        # Tier-aware model selection: free tier uses the cheaper flash-lite
        # model; paid/BYOK/unknown/missing tiers use the full GEMINI_MODEL.
        self._user_tier = user_tier
        self._model_name = _resolve_text_model(user_tier)
        self._request_timeout_seconds = int(
            os.getenv("GEMINI_REQUEST_TIMEOUT_SECONDS", "90")
        )
        logger.info(
            f"Initializing Gemini with model: {self._model_name} "
            f"(tier={user_tier or 'unknown'}, "
            f"{len(self._api_keys)} key(s) available for rotation)"
        )

    def generate_story(self, prompt: str) -> str:
        """Generate story from prompt with retry + key-rotation logic."""
        max_retries = 5
        base_delay = 1  # seconds
        key_index = 0  # which API key we're currently using

        for attempt in range(max_retries):
            try:
                logger.info(
                    f"Generating story with prompt: {prompt[:100]}... (Attempt {attempt + 1}, key_index={key_index})"
                )
                executor = ThreadPoolExecutor(max_workers=1)
                future = executor.submit(
                    self._client.models.generate_content,
                    model=self._model_name,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        safety_settings=_CHILD_SAFETY_SETTINGS,
                    ),
                )
                try:
                    response = future.result(timeout=self._request_timeout_seconds)
                finally:
                    executor.shutdown(wait=False, cancel_futures=True)
                logger.info(f"API response received: {type(response)}")

                text = _extract_text(response)
                if text:
                    logger.info("Story generated successfully")
                    return text

                # Safety block or empty response — don't retry.
                logger.warning("No valid response text found (may be safety-filtered).")
                return _SAFETY_FALLBACK

            except google_exceptions.ResourceExhausted as e:
                next_key_index = key_index + 1
                if next_key_index < len(self._api_keys):
                    # Rotate to the next backup key immediately (no sleep needed).
                    key_index = next_key_index
                    self._client = genai.Client(api_key=self._api_keys[key_index])
                    logger.warning(
                        f"Key {key_index - 1} rate-limited. Rotating to backup key {key_index} "
                        f"(attempt {attempt + 1}/{max_retries})."
                    )
                elif attempt < max_retries - 1:
                    delay = base_delay * (2**attempt)
                    logger.warning(
                        f"All keys rate-limited. Waiting {delay}s before retry (attempt {attempt + 1}/{max_retries})."
                    )
                    time.sleep(delay)
                else:
                    logger.error(
                        f"Story generation failed after {max_retries} retries — all keys exhausted.",
                        exc_info=True,
                    )
                    raise e
            except FuturesTimeoutError:
                if attempt < max_retries - 1:
                    delay = base_delay * (2**attempt)
                    logger.warning(
                        "Gemini request timed out after %ss. Retrying in %ss... (Attempt %s/%s)",
                        self._request_timeout_seconds,
                        delay,
                        attempt + 1,
                        max_retries,
                    )
                    time.sleep(delay)
                else:
                    logger.error(
                        "Story generation timed out after %s retries (timeout=%ss).",
                        max_retries,
                        self._request_timeout_seconds,
                        exc_info=True,
                    )
                    raise TimeoutError(
                        f"Gemini request timed out after {self._request_timeout_seconds}s"
                    )
            except Exception as e:
                error_text = str(e)
                if (
                    "not found for API version" in error_text
                    or "is not supported for generateContent" in error_text
                ):
                    fallback_model = "gemini-2.5-flash-lite"
                    if self._model_name != fallback_model:
                        logger.warning(
                            "Model %s unavailable; retrying with fallback %s.",
                            self._model_name,
                            fallback_model,
                        )
                        self._model_name = fallback_model
                        try:
                            response = self._client.models.generate_content(
                                model=self._model_name,
                                contents=prompt,
                                config=types.GenerateContentConfig(
                                    safety_settings=_CHILD_SAFETY_SETTINGS,
                                ),
                            )
                            text = _extract_text(response)
                            if text:
                                return text
                        except Exception as retry_error:
                            logger.error(
                                "Fallback model %s also failed: %s",
                                fallback_model,
                                retry_error,
                                exc_info=True,
                            )
                logger.error(
                    f"Story generation failed with an unexpected error: {e}",
                    exc_info=True,
                )
                # For other exceptions, fail immediately without retrying
                return "Sorry, there was an unexpected error generating your story. Please try again."

        # This part should be unreachable if the loop completes, but as a fallback:
        return "Sorry, there was an error generating your story after multiple retries. Please try again later."

    def generate_story_stream(self, prompt: str) -> Iterator[str]:
        """Stream story generation, yielding text chunks as they arrive.

        Yields each incremental chunk of text from Gemini's streaming API.
        Caller accumulates the chunks; an empty generator means generation
        failed or was safety-blocked (caller falls back to `generate_story`).

        PERF-01 slice 1: this enables a worker to write partial-story state to
        Redis during generation, so /task-status can return time-to-first-
        paragraph well under the full-generation wall time.

        Retry/key-rotation semantics differ from `generate_story`:
        - A `ResourceExhausted` (429) on the INITIAL stream open rotates keys
          and retries (same as single-call). Once chunks have started flowing,
          a mid-stream 429 abandons the partial stream — Gemini's stream API
          does not support resume, so a partial stream cannot be salvaged.
        - The configured `_request_timeout_seconds` is applied to the FIRST
          chunk's arrival only. Subsequent chunks are read until the stream
          naturally ends; no per-chunk timeout (a long quiet period mid-story
          would otherwise spuriously abort a healthy generation).
        - Safety blocks surfaced via the first chunk's `prompt_feedback`
          terminate the stream without yielding text — caller treats this as
          failure and may fall through to the non-streaming fallback.
        """
        max_retries = 5
        base_delay = 1
        key_index = 0

        for attempt in range(max_retries):
            try:
                logger.info(
                    "Streaming story (attempt %s, key_index=%s, prompt prefix: %s...)",
                    attempt + 1,
                    key_index,
                    prompt[:100],
                )
                executor = ThreadPoolExecutor(max_workers=1)
                future = executor.submit(
                    self._client.models.generate_content_stream,
                    model=self._model_name,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        safety_settings=_CHILD_SAFETY_SETTINGS,
                    ),
                )
                try:
                    stream = future.result(timeout=self._request_timeout_seconds)
                finally:
                    executor.shutdown(wait=False, cancel_futures=True)

                yielded_any = False
                for chunk in stream:
                    feedback = getattr(chunk, "prompt_feedback", None)
                    block_reason = (
                        getattr(feedback, "block_reason", None) if feedback else None
                    )
                    if block_reason:
                        logger.warning(
                            "Streaming generation safety-blocked: %s", block_reason
                        )
                        return
                    chunk_text = getattr(chunk, "text", None)
                    if chunk_text:
                        yielded_any = True
                        yield chunk_text

                if yielded_any:
                    logger.info("Streaming generation completed successfully")
                else:
                    logger.warning(
                        "Streaming generation produced no text (safety filter or empty model output)"
                    )
                return

            except google_exceptions.ResourceExhausted:
                next_key_index = key_index + 1
                if next_key_index < len(self._api_keys):
                    key_index = next_key_index
                    self._client = genai.Client(api_key=self._api_keys[key_index])
                    logger.warning(
                        "Stream key %s rate-limited; rotating to backup key %s (attempt %s/%s).",
                        key_index - 1,
                        key_index,
                        attempt + 1,
                        max_retries,
                    )
                elif attempt < max_retries - 1:
                    delay = base_delay * (2**attempt)
                    logger.warning(
                        "All stream keys rate-limited. Waiting %ss before retry (attempt %s/%s).",
                        delay,
                        attempt + 1,
                        max_retries,
                    )
                    time.sleep(delay)
                else:
                    logger.error(
                        "Stream generation failed after %s retries — all keys exhausted.",
                        max_retries,
                        exc_info=True,
                    )
                    raise
            except FuturesTimeoutError:
                if attempt < max_retries - 1:
                    delay = base_delay * (2**attempt)
                    logger.warning(
                        "Gemini stream open timed out after %ss. Retrying in %ss (attempt %s/%s)",
                        self._request_timeout_seconds,
                        delay,
                        attempt + 1,
                        max_retries,
                    )
                    time.sleep(delay)
                else:
                    logger.error(
                        "Stream generation timed out after %s retries (timeout=%ss).",
                        max_retries,
                        self._request_timeout_seconds,
                        exc_info=True,
                    )
                    raise TimeoutError(
                        f"Gemini stream open timed out after {self._request_timeout_seconds}s"
                    )
            except Exception as e:
                logger.error("Streaming generation failed: %s", e, exc_info=True)
                return
