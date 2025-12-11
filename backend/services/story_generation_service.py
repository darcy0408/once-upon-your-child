import google.generativeai as genai
import os
import logging
from backend.utils.gemini_utils import generate_with_retry

logger = logging.getLogger(__name__)

class StoryGenerationService:
    def __init__(self):
        api_key = os.getenv('GEMINI_API_KEY')
        if not api_key:
            raise ValueError("GEMINI_API_KEY not set")

        genai.configure(api_key=api_key)
        # Use env var for model or default to current preferred model
        model_name = os.getenv('GEMINI_MODEL', 'models/gemini-2.5-flash')
        self.model = genai.GenerativeModel(model_name)

    def generate_story(self, prompt: str) -> str:
        """Generate story from prompt"""
        try:
            logger.info(f"Generating story with prompt: {prompt[:100]}...")
            
            # Use retry mechanism
            response = generate_with_retry(self.model, prompt)
            
            logger.info(f"API response received: {type(response)}")
            if response and hasattr(response, 'text') and response.text:
                logger.info("Story generated successfully")
                return response.text
            elif response and hasattr(response, 'candidates') and response.candidates:
                # Try alternative response format
                candidate = response.candidates[0]
                if hasattr(candidate, 'content') and candidate.content.parts:
                    text = candidate.content.parts[0].text
                    logger.info("Story generated from candidates")
                    return text
            logger.warning("No valid response text found")
            return "Sorry, I couldn't generate a story right now. Please try again."
        except Exception as e:
            logger.error(f"Story generation failed: {e}", exc_info=True)
            return "Sorry, there was an error generating your story. Please try again."

