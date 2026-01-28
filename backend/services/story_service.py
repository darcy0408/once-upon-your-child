import logging
import random
import re
import json
import time
from google.api_core import exceptions as google_exceptions
from .avatar_to_prompt_helper import AvatarToPromptHelper
from ..utils.validators import validate_age, validate_story_length

logger = logging.getLogger(__name__)

# Master constraint table from Story Weaver Coverage v2
# Capped Rhyme Time at 600-800 max to maintain AI quality.
AGE_CONSTRAINTS = {
    '3-4': {
        'regular': {'short': (200, 300), 'medium': (300, 450), 'long': (450, 650)},
        'rhyme': {'short': (150, 250), 'medium': (250, 350), 'long': (350, 450)},
        'ltr': {'short': 6, 'medium': 8, 'long': 10}, # pages
        'notes': 'Very simple words, short sentences, repetition, comforting rhythm.'
    },
    '5-7': {
        'regular': {'short': (450, 650), 'medium': (650, 900), 'long': (900, 1200)},
        'rhyme': {'short': (300, 450), 'medium': (450, 550), 'long': (550, 650)},
        'ltr': {'short': 8, 'medium': 10, 'long': 12},
        'notes': 'Simple vocabulary with occasional new words explained by context.'
    },
    '8-10': {
        'regular': {'short': (900, 1200), 'medium': (1200, 1800), 'long': (1800, 2400)},
        'rhyme': {'short': (400, 500), 'medium': (500, 650), 'long': (650, 800)},
        'ltr': {'short': 10, 'medium': 12, 'long': 14},
        'notes': 'Richer detail, humor, clear cause-effect, stronger plot arcs.'
    },
    '11-13': {
        'regular': {'short': (1300, 1700), 'medium': (1800, 2600), 'long': (2600, 3400)},
        'rhyme': {'short': (450, 550), 'medium': (550, 700), 'long': (700, 800)},
        'notes': 'More nuanced emotions, deeper motivation, still clean and age-appropriate.'
    },
    '13-15': {
        'regular': {'short': (1600, 2200), 'medium': (2400, 3400), 'long': (3400, 4500)},
        'rhyme': {'short': (500, 600), 'medium': (600, 750), 'long': (750, 850)},
        'notes': 'Identity/friendship themes, respectful humor, no babyish tone.'
    },
    '15-18': {
        'regular': {'short': (2000, 2800), 'medium': (3000, 4200), 'long': (4200, 6000)},
        'rhyme': {'short': (500, 650), 'medium': (650, 800), 'long': (800, 900)},
        'notes': 'Complex stakes and introspection; mature but clean.'
    },
    'adult': {
        'regular': {'short': (2000, 3000), 'medium': (3200, 5200), 'long': (5200, 7800)},
        'rhyme': {'short': (500, 700), 'medium': (700, 850), 'long': (850, 1000)},
        'notes': 'Nuanced themes (stress, meaning, relationships) with therapeutic tone.'
    }
}

SAFETY_GUARDRAILS = """
SAFETY RULES:
- No sexual content, no graphic violence, no self-harm, no illegal wrongdoing.
- Handle sensitive emotions gently. Safe, therapeutic tone.
- Do NOT invent characters or family members not provided.
- Must Include: A gentle magical surprise, a coping moment in action (breathing/naming feelings), and a satisfying earned ending.
- SAFETY: Ensure no scary imagery or abandonment themes for children.
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
        spark_tool: str | None = None,
        mood_physics: dict | None = None,
        conflict_hook: str | None = None,
        sensory_palette: str | None = None,
        custom_elements: str = "",
        additional_characters: list | None = None,
        therapeutic_prompt: str = "",
        feelings_prompt: str | None = None,
        character_details: dict | None = None,
        story_length: str = "standard", # 'short', 'medium', 'long'
        story_duration: str | None = None,
        age: int = 5,
    ):
        # Validation
        age = validate_age(age)
        story_length = validate_story_length(story_length)

        band = _get_age_band(age)
        config = AGE_CONSTRAINTS[band]
        length_key = 'medium' if story_length == 'standard' else story_length
        word_range = config['regular'][length_key]
        
        # Build companion context
        companion_context = []
        if companion_pets: 
            for p in companion_pets: 
                species = p.get('species', 'companion')
                companion_context.append(f"{p['name']} the {species} [ANIMAL]")
        if companion_characters:
            for c in companion_characters:
                # If it's a dict from companion_data.dart, it has signaturePower
                power = c.get('signaturePower', '')
                power_text = f" (Power: {power})" if power else ""
                companion_context.append(f"{c['name']}{power_text} [SPEAKING]")
        if not companion_context and companion:
            companion_context.append(f"{companion} [COMPANION]")
        
        comp_str = ", ".join(companion_context) if companion_context else "None"

        # Character strengths and ability
        char_details = character_details or {}
        special_ability = char_details.get('specialAbility', 'None specified')
        strengths = ", ".join(char_details.get('strengths', []))
        
        # Mood Physics & Sensory
        mood_rules = ""
        if mood_physics:
            mood_rules = f"\nWORLD PHYSICS (Mood: {mood_physics.get('mood', 'Magic')}):\n- RULE: {mood_physics.get('worldRule', '')}\n- SENSORY: {mood_physics.get('sensoryChange', '')}"

        # Age-specific impossible element suggestions
        impossible_elements = {
            '3-4': 'Ride on a friendly cloud, talk to a flower, jump over a moonbeam.',
            '5-7': 'Fly on dandelion seeds, taste rainbow colors, walk through a mirror.',
            '8-10': 'Surf on lightning bolts, rewrite the rules of gravity, talk to the stars.',
            '11-13': 'Architect a dreamscape, command the tides, freeze time with a thought.',
            '13-15': 'Bridge two worlds, heal a rift in space, weave light into a bridge.',
            '15-18': 'Navigate a paradox, harmonize a chaotic dimension, transcend physical limits.',
            'adult': 'Manifest an abstract emotion, reconcile lost timelines, find meaning in entropy.'
        }
        age_impossible = impossible_elements.get(band, 'Something magical and physics-defying.')

        return f"""
**PERSONA**: Expert Child Narrative Architect & Therapeutic Narrative Specialist.

You are a MASTER STORYTELLER creating a {story_length} adventure for {character} (age {age}).

**STORY SPECS**:
- **THEME**: {theme}
- **CONFLICT**: {conflict_hook or 'A magical mystery needs solving.'}
- **SENSORY PALETTE**: {sensory_palette or 'Bright colors, soft sounds, sweet smells.'}
- **HERO**: {character} (Strengths: {strengths or 'Brave and kind'}).
- **SPECIAL ABILITY**: {special_ability} (MUST be used at the climax).
- **HERO TOOL**: {("'" + spark_tool + "' (MUST be used exactly once to solve a specific problem)") if spark_tool else "None"}
- **IMPOSSIBLE ELEMENTS**: Examples for this age: {age_impossible}
- **COMPANIONS**: {comp_str} (MUST appear by name and help/bond with {character}).
- **CUSTOM REQUESTS**: {custom_elements or 'None'} (Use the exact words from this request at least once each, verbatim, in the story).
{mood_rules}

**WRITING GUIDELINES**:
- **Tone**: {config['notes']}
- **Word Count**: Approximately {word_range[0]}-{word_range[1]} words total.
- **Safety**: {SAFETY_GUARDRAILS.strip()}

**OUTPUT FORMAT**:
Strictly return valid JSON with this structure:
{{
  "title": "Story Title",
  "pages": [
    {{
      "text": "Page text (approx 100-150 words)...",
      "image_prompt": "Visual description for illustration..."
    }}
  ]
}}
"""

# Helper functions for story_tasks.py
def _safe_extract_title_and_gem(text: str, theme: str):
    """Extract title, wisdom gem, and pages from LLM JSON response."""
    clean_text = text.strip()
    # More robust code block stripping - handle various markdown formats
    # Match ```json or ``` at start (with optional whitespace/newlines)
    clean_text = re.sub(r"^\s*```(?:json)?\s*\n?", "", clean_text, flags=re.IGNORECASE)
    # Match ``` at end (with optional whitespace/newlines)
    clean_text = re.sub(r"\n?\s*```\s*$", "", clean_text, flags=re.IGNORECASE)
    clean_text = clean_text.strip()
    try:
        data = json.loads(clean_text)
        title = data.get("title", f"A {theme} Adventure")
        pages_input = data.get("pages", [])
        post_story = data.get("post_story", {})
        wisdom_gem = post_story.get("wisdom_gem") or "You are magic!"

        pages = []
        if isinstance(pages_input, str):
            pages = [pages_input]
        elif isinstance(pages_input, dict):
            # Handle single page as a dict
            page_text = pages_input.get("text", "")
            if page_text:
                pages = [page_text]
        elif isinstance(pages_input, list):
            for p in pages_input:
                if isinstance(p, dict):
                    page_text = p.get("text", "")
                    if page_text:
                        pages.append(page_text)
                elif isinstance(p, str) and p.strip():
                    pages.append(p)

        # If no valid pages extracted, use cleaned text as single page
        if not pages:
            pages = [clean_text]

        story_body = "\n\n".join(pages)
        return title, wisdom_gem, story_body, pages, post_story
    except json.JSONDecodeError as e:
        # Log the parsing error for debugging
        logger.warning(f"Failed to parse story JSON: {e}. First 200 chars: {clean_text[:200]}")
        # Return clean_text (with code blocks stripped) as fallback, not raw text
        return f"A {theme} Adventure", "You are magic!", clean_text, [clean_text], {}
    except Exception as e:
        logger.warning(f"Unexpected error parsing story: {e}")
        return f"A {theme} Adventure", "You are magic!", clean_text, [clean_text], {}


def _build_learning_to_read_prompt(character_name, theme, age, character_details, companion=None, extra_characters=None, story_length="standard", custom_elements=""):
    """Build prompt for Learning to Read mode stories with graduated vocabulary."""
    band = _get_age_band(age)
    config = AGE_CONSTRAINTS[band]
    if 'ltr' not in config:
        return "Mode unavailable for this age."

    length_key = 'medium' if story_length == 'standard' else story_length
    num_pages = config['ltr'][length_key]

    # Graduate vocabulary based on age
    if age <= 5:
        vocab_instruction = "CVC words (cat, hop, sun) and simple sight words only. No blends or silent letters."
        format_instruction = "Each page 1 short sentence."
    elif age <= 7:
        vocab_instruction = "Simple sight words plus basic blends (st, fl, br) and digraphs (ch, sh, th). Occasional 2-syllable words."
        format_instruction = "Each page 1-2 sentences."
    else:
        vocab_instruction = "Early chapter book level. Fluent sentences with varied vocabulary. Still accessible but engaging for a fluent reader."
        format_instruction = "Each page 2-3 sentences."

    return f"""
Create a LEARN TO READ story for {character_name} (age {age}).
Theme: {theme}
Format: {num_pages} pages. {format_instruction}
Vocabulary: {vocab_instruction}
Requirements: Repeating frames, comforting rhythm, 1 coping moment.
Custom Requests: {custom_elements or 'None'} (Use the exact words from this request at least once each, verbatim, in the story).
{SAFETY_GUARDRAILS}
"""


def _build_rhyme_time_prompt(character_name, theme, age, character_details, companion_pets=None, companion_characters=None, extra_characters=None, story_length="standard", custom_elements=""):
    """Build prompt for Rhyme Time mode stories."""
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
Custom Requests: {custom_elements or 'None'} (Use the exact words from this request at least once each, verbatim, in the story).
{SAFETY_GUARDRAILS}
"""
