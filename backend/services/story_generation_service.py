from google import genai
from google.genai import types
import os
import logging
import time
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FuturesTimeoutError
from google.api_core import exceptions as google_exceptions

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
    "I wasn't able to create that story right now. "
    "Let's try a different adventure!"
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


class StoryGenerationService:
    def __init__(self):
        api_key = os.getenv('GEMINI_API_KEY')
        if not api_key:
            raise ValueError("GEMINI_API_KEY not set")

        self._client = genai.Client(api_key=api_key)
        # Use configured model from env (defaults to gemini-2.5-flash)
        self._model_name = os.getenv('GEMINI_MODEL', 'gemini-2.5-flash')
        self._request_timeout_seconds = int(os.getenv('GEMINI_REQUEST_TIMEOUT_SECONDS', '90'))
        logger.info(f"Initializing Gemini with model: {self._model_name}")

    def generate_story(self, prompt: str) -> str:
        """Generate story from prompt with retry logic for rate limiting."""
        max_retries = 5
        base_delay = 1  # seconds

        for attempt in range(max_retries):
            try:
                logger.info(f"Generating story with prompt: {prompt[:100]}... (Attempt {attempt + 1})")
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
                if attempt < max_retries - 1:
                    delay = base_delay * (2 ** attempt)
                    logger.warning(f"Rate limit exceeded. Retrying in {delay} seconds... (Attempt {attempt + 1}/{max_retries})")
                    time.sleep(delay)
                else:
                    logger.error(f"Story generation failed after {max_retries} retries due to rate limiting.", exc_info=True)
                    # Re-raise the exception to be handled by the caller's error handler
                    raise e
            except FuturesTimeoutError:
                if attempt < max_retries - 1:
                    delay = base_delay * (2 ** attempt)
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
                if "not found for API version" in error_text or "is not supported for generateContent" in error_text:
                    fallback_model = "gemini-2.0-flash-lite"
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
                logger.error(f"Story generation failed with an unexpected error: {e}", exc_info=True)
                # For other exceptions, fail immediately without retrying
                return "Sorry, there was an unexpected error generating your story. Please try again."

        # This part should be unreachable if the loop completes, but as a fallback:
        return "Sorry, there was an error generating your story after multiple retries. Please try again later."
