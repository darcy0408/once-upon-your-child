import google.generativeai as genai
import os
import logging

logger = logging.getLogger(__name__)

class StoryGenerationService:
    def __init__(self):
        api_key = os.getenv('GEMINI_API_KEY')
        if not api_key:
            raise ValueError("GEMINI_API_KEY not set")

        genai.configure(api_key=api_key)
        self.model = genai.GenerativeModel('gemini-1.5-pro-latest')

    def generate_story(self, prompt: str) -> str:
        """Generate story from prompt"""
        try:
            response = self.model.generate_content(prompt)
            return getattr(response, 'text', '')
        except Exception as e:
            logger.error(f"Story generation failed: {e}", exc_info=True)
            raise
