import google.generativeai as genai
import os
import logging
import time
from google.api_core import exceptions as google_exceptions

logger = logging.getLogger(__name__)

class StoryGenerationService:
    def __init__(self):
        api_key = os.getenv('GEMINI_API_KEY')
        if not api_key:
            raise ValueError("GEMINI_API_KEY not set")

        genai.configure(api_key=api_key)
        # Use configured model from env (defaults to gemini-2.0-flash - FREE experimental model)
        model_name = os.getenv('GEMINI_MODEL', 'gemini-2.0-flash')
        logger.info(f"Initializing Gemini with model: {model_name}")
        self.model = genai.GenerativeModel(model_name)
        self._model_name = model_name

    def generate_story(self, prompt: str) -> str:
        """Generate story from prompt with retry logic for rate limiting."""
        max_retries = 5
        base_delay = 1  # seconds

        for attempt in range(max_retries):
            try:
                logger.info(f"Generating story with prompt: {prompt[:100]}... (Attempt {attempt + 1})")
                response = self.model.generate_content(prompt)
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
            except Exception as e:
                error_text = str(e)
                if "not found for API version" in error_text or "is not supported for generateContent" in error_text:
                    fallback_model = "gemini-1.5-flash"
                    if self._model_name != fallback_model:
                        logger.warning(
                            "Model %s unavailable; retrying with fallback %s.",
                            self._model_name,
                            fallback_model,
                        )
                        self.model = genai.GenerativeModel(fallback_model)
                        self._model_name = fallback_model
                        try:
                            response = self.model.generate_content(prompt)
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
