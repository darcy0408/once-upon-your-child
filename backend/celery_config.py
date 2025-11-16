from celery import Celery
import os
import re
import logging
from backend.services.story_generation_service import StoryGenerationService

celery = Celery(
    'story_weaver',
    broker=os.getenv('REDIS_URL'),
    backend=os.getenv('REDIS_URL')
)

logger = logging.getLogger("story_engine")
story_generation_service = StoryGenerationService()

_TITLE_RE = re.compile(r'\[TITLE:\s*(.*?)\s*\]', re.DOTALL)
_GEM_RE = re.compile(r'\[WISDOM GEM:\s*(.*?)\s*\]', re.DOTALL)

def _safe_extract_title_and_gem(text: str, theme: str):
    title_match = _TITLE_RE.search(text or "")
    gem_match = _GEM_RE.search(text or "")
    title = title_match.group(1).strip() if title_match and title_match.group(1) else "A Brave Little Adventure"
    wisdom_gem = gem_match.group(1).strip() if gem_match and gem_match.group(1) else "Always be kind." # Fallback
    story_body = _TITLE_RE.sub("", text or "").strip()
    story_body = _GEM_RE.sub("", story_body).strip()
    return title, wisdom_gem, story_body

@celery.task(bind=True)
def generate_story_task(self, prompt, theme):
    try:
        story_text = story_generation_service.generate_story(prompt)
        _, _, story_body = _safe_extract_title_and_gem(story_text, theme)
        self.update_state(state='SUCCESS', meta={'story_text': story_body})
        return story_body

    except Exception as e:
        logger.warning("Model error, using fallback: %s", e)
        self.update_state(state='FAILURE', meta=str(e))
        raw_text = (
            "[TITLE: An Unexpected Adventure]\n"
            "Once upon a time, a brave hero discovered that the greatest adventures come from "
            "facing our fears with courage and kindness.\n"
            "[WISDOM GEM: Always be kind.]"
        )
        _, _, story_body = _safe_extract_title_and_gem(raw_text, theme)
        return story_body
