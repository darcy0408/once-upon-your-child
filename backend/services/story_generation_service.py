from google import genai
import os
import logging
import time
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FuturesTimeoutError
from google.api_core import exceptions as google_exceptions

logger = logging.getLogger(__name__)

class StoryGenerationService:
    def __init__(self):
        api_key = os.getenv('GEMINI_API_KEY')
        if not api_key:
            raise ValueError("GEMINI_API_KEY not set")

        self._client = genai.Client(api_key=api_key)
        # Use configured model from env (defaults to gemini-2.0-flash)
        self._model_name = os.getenv('GEMINI_MODEL', 'gemini-2.0-flash')
        self._request_timeout_seconds = int(os.getenv('GEMINI_REQUEST_TIMEOUT_SECONDS', '45'))
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
                    contents=prompt
                )
                try:
                    response = future.result(timeout=self._request_timeout_seconds)
                finally:
                    executor.shutdown(wait=False, cancel_futures=True)
                logger.info(f"API response received: {type(response)}")

                if response and hasattr(response, 'text') and response.text:
                    logger.info("Story generated successfully")
                    return response.text
                elif response and hasattr(response, 'candidates') and response.candidates:
                    candidate = response.candidates[0]
                    if hasattr(candidate, 'content') and candidate.content.parts:
                        text = candidate.content.parts[0].text
                        logger.info("Story generated from candidates")
                        return text

                logger.warning("No valid response text found, but no exception raised.")
                # Don't retry if the API returns a valid but empty response
                return "Sorry, I couldn't generate a story right now. Please try again."

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
                                contents=prompt
                            )
                            if response and hasattr(response, 'text') and response.text:
                                return response.text
                            elif response and hasattr(response, 'candidates') and response.candidates:
                                candidate = response.candidates[0]
                                if hasattr(candidate, 'content') and candidate.content.parts:
                                    return candidate.content.parts[0].text
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
