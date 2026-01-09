import random
import re
import json
import time
from google.api_core import exceptions as google_exceptions
from .avatar_to_prompt_helper import AvatarToPromptHelper

# Master constraint table from Story Weaver Coverage v2
AGE_CONSTRAINTS = {
    '3-4': {
        'regular': {'short': (200, 300), 'medium': (300, 450), 'long': (450, 650)},
        'rhyme': {'short': (150, 250), 'medium': (200, 350), 'long': (350, 500)},
        'ltr': {'short': 6, 'medium': 8, 'long': 10}, # pages
        'notes': 'Very simple words, short sentences, repetition, comforting rhythm.'
    },
    '5-7': {
        'regular': {'short': (450, 650), 'medium': (650, 900), 'long': (900, 1200)},
        'rhyme': {'short': (350, 500), 'medium': (500, 700), 'long': (700, 950)},
        'ltr': {'short': 8, 'medium': 10, 'long': 12},
        'notes': 'Simple vocabulary with occasional new words explained by context.'
    },
    '8-10': {
        'regular': {'short': (900, 1200), 'medium': (1200, 1800), 'long': (1800, 2400)},
        'rhyme': {'short': (650, 900), 'medium': (900, 1400), 'long': (1400, 1800)},
        'ltr': {'short': 10, 'medium': 12, 'long': 14},
        'notes': 'Richer detail, humor, clear cause-effect, stronger plot arcs.'
    },
    '11-13': {
        'regular': {'short': (1300, 1700), 'medium': (1800, 2600), 'long': (2600, 3400)},
        'rhyme': {'short': (900, 1300), 'medium': (1400, 2200), 'long': (2200, 2800)},
        'notes': 'More nuanced emotions, deeper motivation, still clean and age-appropriate.'
    },
    '13-15': {
        'regular': {'short': (1600, 2200), 'medium': (2400, 3400), 'long': (3400, 4500)},
        'rhyme': {'short': (1100, 1600), 'medium': (1700, 2600), 'long': (2600, 3400)},
        'notes': 'Identity/friendship themes, respectful humor, no babyish tone.'
    },
    '15-18': {
        'regular': {'short': (2000, 2800), 'medium': (3000, 4200), 'long': (4200, 6000)},
        'rhyme': {'short': (1400, 2200), 'medium': (2300, 3400), 'long': (3400, 4800)},
        'notes': 'Complex stakes and introspection; mature but clean.'
    },
    'adult': {
        'regular': {'short': (2000, 3000), 'medium': (3200, 5200), 'long': (5200, 7800)},
        'rhyme': {'short': (1500, 2400), 'medium': (2500, 3800), 'long': (3800, 5500)},
        'notes': 'Nuanced themes (stress, meaning, relationships) with therapeutic tone.'
    }
}

SAFETY_GUARDRAILS = """
SAFETY RULES:
- No sexual content, no graphic violence, no self-harm, no illegal wrongdoing.
- Handle sensitive emotions gently. Safe, therapeutic tone.
- Do NOT invent characters or family members not provided.
- Personalization: Weave in interests and unique magical motif.
- Must Include: A gentle magical surprise, a coping moment in action, and a satisfying earned ending.
"""

def _get_age_band(age: int) -> str:
    if age <= 4: return '3-4'
    if age <= 7: return '5-7'
    if age <= 10: return '8-10'
    if age <= 13: return '11-13'
    if age <= 15: return '13-15'
    if age <= 18: return '15-18'
    return 'adult'

class AdvancedStoryEngine:
    def generate_enhanced_prompt(
        self,
        character: str,
        theme: str,
        companion: str | None = None,
        companion_pets: list[dict] | None = None,
        companion_characters: list[dict] | None = None,
        custom_elements: str = "",
        therapeutic_prompt: str = "",
        feelings_prompt: str | None = None,
        story_length: str = "standard", # 'short', 'medium', 'long'
        age: int = 5,
    ):
        band = _get_age_band(age)
        config = AGE_CONSTRAINTS[band]
        length_key = 'medium' if story_length == 'standard' else story_length
        word_range = config['regular'][length_key]
        
        # Build companion context
        companion_context = []
        if companion_pets: 
            for p in companion_pets: companion_context.append(f"{p['name']} the {p['species']}")
        if companion_characters:
            for c in companion_characters: companion_context.append(f"{c['name']} ({c.get('role', 'friend')})")
        if not companion_context and companion:
            companion_context.append(companion)
        
        comp_str = ", ".join(companion_context) if companion_context else "None"

        return f"""
You are a MASTER STORYTELLER creating a {story_length} story for {character} (age {age}).

STORY THEME: {theme}
COMPANIONS: {comp_str}
READABILITY: {config['notes']}

OUTPUT FORMAT: Return STRICT JSON.
{{
  "title": "Title",
  "pages": ["Page 1...", "Page 2...", "..."],
  "post_story": {{ "wisdom_gem": "Lesson", "adventure_report": {{ "plot_beats": [] }} }}
}}

REQUIREMENTS:
- Word Count: {word_range[0]}-{word_range[1]} words.
- Pagination: Split into 8-12 pages.
- POV: Second-person ('You') for age <= 7, else Third-person.
- Must Include: A magical surprise, a coping moment (breathing/naming feelings), and an earned ending.
- Consistency: {comp_str} MUST appear by name and affect at least 2 beats.

{SAFETY_GUARDRAILS}{f"FEELINGS: {feelings_prompt}" if feelings_prompt else ""}{f"CUSTOM: {custom_elements}" if custom_elements else ""}
"""

def _build_rhyme_time_prompt(character_name, theme, age, character_details, companion_pets=None, companion_characters=None, story_length="standard"):
    band = _get_age_band(age)
    config = AGE_CONSTRAINTS[band]
    length_key = 'medium' if story_length == 'standard' else story_length
    word_range = config['rhyme'][length_key]

    return f"""
Create a RHYME TIME story for {character_name} (age {age}).
Theme: {theme}
Word Count: {word_range[0]}-{word_range[1]} words.
Scheme: Consistent AABB or ABCB.
Requirements: Include a magical surprise and a coping moment. {character_name} is the hero.
{SAFETY_GUARDRAILS}
"""

def _build_learning_to_read_prompt(character_name, theme, age, character_details, story_length="standard"):
    band = _get_age_band(age)
    config = AGE_CONSTRAINTS[band]
    if 'ltr' not in config: return "Mode unavailable for this age."
    
    length_key = 'medium' if story_length == 'standard' else story_length
    num_pages = config['ltr'][length_key]

    return f"""
Create a LEARN TO READ story for {character_name} (age {age}).
Theme: {theme}
Format: {num_pages} pages. Each page 1-2 short sentences.
Vocabulary: CVC words and simple sight words only.
Requirements: Repeating frames, comforting rhythm, 1 coping moment.
{SAFETY_GUARDRAILS}
"""

# Rest of the helper functions from original file...
def _safe_extract_title_and_gem(text: str, theme: str):
    clean_text = text.strip()
    if clean_text.startswith("```"):
        clean_text = re.sub(r"^```(?:json)?", "", clean_text, flags=re.IGNORECASE)
        clean_text = re.sub(r"```$", "", clean_text).strip()
    try:
        data = json.loads(clean_text)
        title = data.get("title", f"A {theme} Adventure")
        pages = data.get("pages", [])
        post_story = data.get("post_story", {})
        wisdom_gem = post_story.get("wisdom_gem") or "You are magic!"
        if isinstance(pages, str): pages = [pages]
        return title, wisdom_gem, "\n\n".join(pages), pages, post_story
    except:
        return f"A {theme} Adventure", "You are magic!", text, [text], {}

def _extract_current_feeling(container):
    if not isinstance(container, dict): return None
    feeling = container.get("current_feeling") or container.get("currentFeeling")
    if not isinstance(feeling, dict): return None
    return feeling

def _build_feelings_prompt(character_name: str, feeling: dict | None) -> str:
    if not feeling: return ""
    return f"Character is feeling {feeling.get('emotion_name')}. Show them using coping skills."

story_engine = AdvancedStoryEngine()