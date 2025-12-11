"""
OpenRouter Story Generation Service
Uses a free model from OpenRouter as a fallback for Gemini.
"""

import os
import requests
import logging
import time
from google.api_core import exceptions as google_exceptions

logger = logging.getLogger(__name__)

# A good free model available on OpenRouter
OPENROUTER_FREE_MODEL = "mistralai/mistral-small-latest"

class OpenRouterStoryGenerator:
    def __init__(self, api_key=None):
        """Initialize with OpenRouter API key"""
        self.api_key = api_key or os.getenv("OPENROUTER_API_KEY")
        if not self.api_key:
            raise ValueError("OPENROUTER_API_KEY not set")
        self.base_url = "https://openrouter.ai/api/v1"

    def generate_story(self, prompt: str) -> str:
        """Generate story from prompt using an OpenRouter model."""
        max_retries = 3
        base_delay = 2  # seconds

        for attempt in range(max_retries):
            try:
                logger.info(f"OpenRouter: Sending request for story generation... (Attempt {attempt + 1})")
                response = requests.post(
                    f"{self.base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "HTTP-Referer": "https://story-weaver-app-production.up.railway.app", # Recommended by OpenRouter
                        "X-Title": "Story Weaver App", # Recommended by OpenRouter
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": OPENROUTER_FREE_MODEL,
                        "messages": [
                            {
                                "role": "user",
                                "content": prompt
                            }
                        ],
                    },
                    timeout=90,
                )

                response.raise_for_status()  # Will raise an HTTPError for bad responses (4xx or 5xx)

                data = response.json()
                if data and data.get('choices') and data['choices'][0].get('message', {}).get('content'):
                    story_text = data['choices'][0]['message']['content']
                    logger.info("OpenRouter: Story generated successfully.")
                    return story_text
                else:
                    logger.warning(f"OpenRouter response did not contain valid story content. Response: {data}")
                    # Don't retry on a successful but empty response
                    return "Sorry, I received an unusual response from the story generator. Please try again."

            except requests.exceptions.HTTPError as e:
                # Handle HTTP errors, including 429 Rate Limit
                if e.response.status_code == 429:
                    if attempt < max_retries - 1:
                        # Use exponential backoff, OpenRouter might have its own retry-after header
                        retry_after = int(e.response.headers.get("Retry-After", base_delay * (2 ** attempt)))
                        logger.warning(f"OpenRouter rate limit exceeded. Retrying in {retry_after} seconds...")
                        time.sleep(retry_after)
                    else:
                        logger.error(f"OpenRouter story generation failed after {max_retries} retries due to rate limiting.", exc_info=True)
                        return "Sorry, the story generator is currently busy. Please try again in a few minutes."
                else:
                    # For other HTTP errors, fail immediately
                    logger.error(f"OpenRouter API error: {e.response.status_code} - {e.response.text}", exc_info=True)
                    return f"Sorry, there was a server error ({e.response.status_code}) while generating the story."
            except Exception as e:
                logger.error(f"An unexpected error occurred with OpenRouter: {e}", exc_info=True)
                # For other exceptions, don't retry
                return "Sorry, an unexpected error occurred while generating your story."

        return "Sorry, there was an error generating your story after multiple retries. Please try again later."
