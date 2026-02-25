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

STRICT_OUTPUT_CONSTRAINTS = """
STRICT OUTPUT CONSTRAINTS:
- Do NOT include any meta-talk or introductory phrases (e.g., "Here we go!", "Sure, I can do that", "Here is your story").
- Do NOT repeat any part of these instructions in the story text.
- Do NOT include technical jargon or internal storytelling terms in the prose (e.g., "consequence chain", "two-step challenge", "therapeutic specialist", "narrative specialist", "narrative architect", "earned ending", "earned win", "insight", "climax", "resolution", "manifest an abstract emotion", "challenge arc", "tradeoff").
- Do NOT explicitly state the "lessons" or "insights" as a summary at the end; let them emerge naturally from the narrative.
- Do NOT repeat or closely paraphrase the opening paragraph at the end of the story.
- ONLY return the story content itself in the requested format.
"""

SAFETY_GUARDRAILS = f"""
{STRICT_OUTPUT_CONSTRAINTS}
SAFETY RULES:
- No sexual content, no graphic violence, no self-harm, no illegal wrongdoing.
- Handle sensitive emotions gently. Safe, therapeutic tone.
- Do NOT invent characters or family members not provided.
- SAFETY: Ensure no scary imagery or abandonment themes for children.
"""

def _get_age_band(age: int) -> str:
    if age <= 4: return '3-4'
    if age <= 7: return '5-7'
    if age <= 10: return '8-10'
    if age <= 13: return '11-13'
    if age < 15: return '13-15'
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
        length_key = 'medium'
        if story_length == 'short' or story_length == 'quick':
            length_key = 'short'
        elif story_length == 'long' or story_length == 'epic':
            length_key = 'long'
        else:
            length_key = 'medium'
        word_range = config['regular'][length_key]
        
        # Build character context (Gender/Strengths)
        char_details = character_details or {}
        special_ability = char_details.get('specialAbility', 'None specified')
        strengths = ", ".join(char_details.get('strengths', []))
        gender = char_details.get('gender', 'not specified')
        pronouns = char_details.get('pronouns', '')
        gender_text = f" (Gender: {gender}{', Pronouns: ' + pronouns if pronouns else ''})"

        # Build companion context
        companion_sections = []
        all_companion_names = []
        if companion_pets: 
            pets = []
            for p in companion_pets:
                pets.append(f"{p['name']} the {p.get('species', 'pet')}")
                all_companion_names.append(p['name'])
            companion_sections.append(f"PETS: {', '.join(pets)}")
        if companion_characters:
            chars = []
            for c in companion_characters:
                chars.append(f"{c['name']}{' (Power: ' + c['signaturePower'] + ')' if c.get('signaturePower') else ''}")
                all_companion_names.append(c['name'])
            companion_sections.append(f"FRIENDS: {', '.join(chars)}")
        if additional_characters:
            others = []
            for ac in additional_characters:
                name = ac.get('name') if isinstance(ac, dict) else str(ac)
                if name:
                    others.append(name)
                    all_companion_names.append(name)
            if others:
                companion_sections.append(f"GUESTS: {', '.join(others)}")

        if not companion_sections and companion:
            if isinstance(companion, dict):
                comp_name = companion.get('name', 'Companion')
                comp_type = companion.get('type') or companion.get('species')
                if comp_type:
                    companion_sections.append(f"COMPANION: {comp_name} the {comp_type}")
                else:
                    companion_sections.append(f"COMPANION: {comp_name}")
                all_companion_names.append(comp_name)
            else:
                companion_sections.append(f"COMPANION: {companion}")
                all_companion_names.append(str(companion))
        
        comp_str = "\n".join(companion_sections) if companion_sections else "None"
        all_companion_names = [str(n) for n in all_companion_names if n]
        mandatory_names_str = ", ".join(all_companion_names) if all_companion_names else "None"

        # Mood Physics & Sensory
        mood_rules = ""
        if mood_physics:
            mood_rules = f"\nWORLD PHYSICS (Mood: {mood_physics.get('mood', 'Magic')}):\n- RULE: {mood_physics.get('worldRule', '')}\n- SENSORY: {mood_physics.get('sensoryChange', '')}"

        # Age-specific impossible element suggestions - FOR INSPIRATION ONLY, DO NOT USE VERBATIM
        impossible_elements = {
            '3-4': 'riding a friendly cloud, talking to a flower, or jumping over a moonbeam.',
            '5-7': 'flying on dandelion seeds, tasting rainbow colors, or walking through a mirror.',
            '8-10': 'surfing on lightning bolts, shifting gravity, or talking to the stars.',
            '11-13': 'shaping a dreamscape, commanding the tides, or freezing time.',
            '13-15': 'bridging two worlds, healing a rift in space, or weaving light into a bridge.',
            '15-18': 'navigating a paradox, harmonizing a chaotic dimension, or transcending physical limits.',
            'adult': 'visualizing a complex emotion as a physical force, reconciling memories from different times, or finding order in chaos.'
        }
        age_impossible = impossible_elements.get(band, 'Something magical and physics-defying.')

        # Age-appropriate Terminology adjustments
        tool_label = "HERO TOOL"
        tool_instruction = "' (MUST be used exactly once to solve a specific problem)"
        
        if age >= 12:
            tool_label = "KEY ARTIFACT"
            tool_instruction = "' (MUST be integral to the resolution)"

        tool_section = ""
        if spark_tool:
            tool_section = f"- **{tool_label}**: '{spark_tool}{tool_instruction}"
        else:
            tool_section = f"- **{tool_label}**: None"

        # Therapeutic Tone Adjustment for Teens
        coping_instruction = "a gentle magical surprise, a coping moment in action (breathing/naming feelings)"
        safety_reinforcement = ""
        if age <= 7:
            safety_reinforcement = "\n- SAFETY: This is for a young child. Ensure NO scary imagery, NO monsters, NO abandonment."
        
        if age >= 14:
            coping_instruction = "a clever plot twist, a moment of wonder, a moment of resilience or perspective-shifting (internal monologue)"

        # Explicit writing calibration so models do not flatten all ages to simple prose.
        if age <= 7:
            complexity_instruction = "Short, concrete sentences. Simple vocabulary. Single-thread plot with clear cause/effect."
        elif age <= 10:
            complexity_instruction = "Mix short and medium sentences. Introduce richer descriptive words with context clues. Build a two-part challenge where solving the first problem opens a second, harder one."
        elif age <= 13:
            complexity_instruction = "Use varied sentence structure with occasional complex clauses. Include nuanced emotions and at least one meaningful tradeoff."
        elif age <= 18:
            complexity_instruction = "Use sophisticated but readable prose, layered motivation, and multi-step consequences. Avoid childish phrasing."
        else:
            complexity_instruction = "Use mature, nuanced prose with reflective inner monologue, relational complexity, and thematic depth suitable for adults."

        # Hard constraints to force complexity scaling for older readers.
        hard_complexity_constraints = ""
        if age >= 11 and age <= 13:
            hard_complexity_constraints = (
                "At least 30% of sentences should be compound or complex. "
                "Include at least one situation where every available option has a downside. "
                "Include at least one short internal reflection paragraph by the hero."
            )
        elif age >= 14 and age <= 18:
            hard_complexity_constraints = (
                "At least 35% of sentences should be compound or complex. "
                "Include at least two internal reflection moments (motivation, doubt, or reframing). "
                "Show how an early decision ripples forward to reshape the outcome — without labeling it."
            )
        elif age > 18:
            hard_complexity_constraints = (
                "At least 40% of sentences should be compound or complex with varied rhythm. "
                "Include at least two reflective passages with relational or existential tension. "
                "Show how early decisions ripple forward to a resolution that feels genuinely earned through the character's actions, not announced."
            )

        # Age-appropriate wisdom gem guidance for the prompt
        if age <= 5:
            wisdom_gem_guidance = "simple, warm encouragement a toddler can understand (e.g. 'Being kind makes magic happen')"
        elif age <= 7:
            wisdom_gem_guidance = "simple lesson a young child can repeat to themselves (e.g. 'Asking for help is brave')"
        elif age <= 10:
            wisdom_gem_guidance = "clear takeaway about the feeling or challenge in the story (e.g. 'When you feel scared, taking one small step helps')"
        elif age <= 13:
            wisdom_gem_guidance = "thoughtful insight connecting the hero's growth to real life (e.g. 'Choosing kindness when it's hard is what makes it matter')"
        elif age <= 18:
            wisdom_gem_guidance = "honest, non-preachy reflection on the theme — speak to a teenager as an equal"
        else:
            wisdom_gem_guidance = "a resonant, adult insight distilled from the story's theme — concise and genuine"

        return f"""
**PERSONA**: Expert Children's Author & Therapeutic Storyteller.

You are a MASTER STORYTELLER creating a {story_length} adventure for {character}{gender_text} (age {age}).

**STORY SPECS**:
- **THEME**: {theme}
- **CONFLICT**: {conflict_hook or 'A magical mystery needs solving.'}
- **SENSORY PALETTE**: {sensory_palette or 'Bright colors, soft sounds, sweet smells.'}
- **HERO**: {character} (Strengths: {strengths or 'Brave and kind'}).
- **SPECIAL ABILITY**: {special_ability} (MUST be used at the climax).
{tool_section}
- **IMPOSSIBLE ELEMENTS**: (Inspiration Only - DO NOT use these exact phrases): {age_impossible}
- **COMPANIONS**: 
{comp_str}
(MANDATORY: Every character/pet listed above MUST be in the story. Checklist of names to include: {mandatory_names_str})
- **CUSTOM REQUESTS**: {custom_elements or 'None'} (CRITICAL: You MUST use the exact words from this request at least once each, verbatim, in the story).
  If a custom request implies an action or relationship (e.g., "ride a dragon", "make friends"), include it as a concrete scene or outcome, not just a mention.
{mood_rules}

**WRITING GUIDELINES**:
- **Tone**: {config['notes']}
- **Word Count**: Approximately {word_range[0]}-{word_range[1]} words total.
- **Complexity Calibration**: {complexity_instruction}
- **Hard Complexity Targets**: {hard_complexity_constraints or 'N/A for this age band.'}
- **Safety**: {SAFETY_GUARDRAILS.strip()}{safety_reinforcement}
- **Mandatory Elements**: Must include {coping_instruction}, and a satisfying conclusion.

{STRICT_OUTPUT_CONSTRAINTS}
**OUTPUT FORMAT**:
Strictly return valid JSON with this structure:
{{
  "title": "Story Title",
  "wisdom_gem": "A {wisdom_gem_guidance} — one sentence, no more.",
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

    # Strip markdown code blocks (```json ... ```)
    clean_text = re.sub(r"^\s*```(?:json)?\s*\n?", "", clean_text, flags=re.IGNORECASE)
    clean_text = re.sub(r"\n?\s*```\s*$", "", clean_text, flags=re.IGNORECASE)

    # Strip markdown bold markers (**) that some LLMs wrap around JSON
    clean_text = re.sub(r"^\s*\*\*\s*", "", clean_text)
    clean_text = re.sub(r"\s*\*\*\s*$", "", clean_text)

    # Save candidate text for fallback (prose mode)
    candidate_text = clean_text

    # Try to locate JSON object
    json_start = clean_text.find('{')
    json_end = clean_text.rfind('}')
    
    sliced_text = clean_text
    if json_start >= 0 and json_end > json_start:
        sliced_text = clean_text[json_start:json_end + 1]

    def _parse_story_data(json_str):
        data = json.loads(json_str)
        title = data.get("title", f"A {theme} Adventure")
        pages_input = data.get("pages", [])
        post_story = data.get("post_story", {})
        # Read from top-level first (new prompt format), fall back to post_story (legacy), then generic default
        wisdom_gem = data.get("wisdom_gem") or post_story.get("wisdom_gem") or "You are magic!"

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

        # If valid JSON but missing 'pages', check for 'story' or 'story_text'
        if not pages:
             if 'story' in data and isinstance(data['story'], str):
                 pages = [data['story']]
             elif 'story_text' in data and isinstance(data['story_text'], str):
                 pages = [data['story_text']]
        
        return title, wisdom_gem, pages, post_story

    try:
        # 1. Try to parse the sliced text (most likely JSON candidate)
        title, wisdom_gem, pages, post_story = _parse_story_data(sliced_text)
        
        # If successful but pages empty, it might be a false positive JSON (rare) or just empty structure
        if not pages:
            # Fallback to using the entire sliced text if it was actually prose caught in braces?
            # Unlikely if it parsed as JSON. 
            # But let's check if sliced_text is very short/unlikely to be the real story?
            # For now, trust the JSON parser.
            pass

    except json.JSONDecodeError:
        # 2. If sliced failed, maybe the full text is valid JSON (e.g. start at 0)?
        # Or maybe the braces were part of prose.
        try:
             if sliced_text != candidate_text:
                title, wisdom_gem, pages, post_story = _parse_story_data(candidate_text)
             else:
                raise # Already tried candidate (as sliced)
        except json.JSONDecodeError as e:
            # 3. Fallback to prose
            # Use candidate_text (stripped of markdown) as the story
            # Log the parsing error for debugging but don't fail
            logger.warning(f"Failed to parse story JSON: {e}. Falling back to raw text.")
            return f"A {theme} Adventure", "You are magic!", candidate_text, [candidate_text], {}
    except Exception as e:
        logger.warning(f"Unexpected error parsing story: {e}. Falling back to raw text.")
        return f"A {theme} Adventure", "You are magic!", candidate_text, [candidate_text], {}

    # If we parsed successfully but got no pages, verify content length
    if not pages:
         # This shouldn't happen with proper JSON unless 'pages' key was empty list
         # Use candidate text as fallback
         pages = [candidate_text]

    story_body = "\n\n".join(pages)
    return title, wisdom_gem, story_body, pages, post_story


def _build_learning_to_read_prompt(character_name, theme, age, character_details, companion=None, companion_pets=None, companion_characters=None, extra_characters=None, story_length="standard", custom_elements=""):
    """Build prompt for Learning to Read mode stories with graduated vocabulary."""
    band = _get_age_band(age)
    config = AGE_CONSTRAINTS[band]
    if 'ltr' not in config:
        return "Mode unavailable for this age."

    length_key = 'medium'
    if story_length == 'short' or story_length == 'quick':
        length_key = 'short'
    elif story_length == 'long' or story_length == 'epic':
        length_key = 'long'
    else:
        length_key = 'medium'
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

    # Build companion context
    companion_sections = []
    all_companion_names = []
    if character_details:
        pets = character_details.get('pets') or []
        for p in pets:
            name = p.get('name')
            species = p.get('species')
            if name and species:
                companion_sections.append(f"{name} the {species}")
                all_companion_names.append(name)
            elif name:
                companion_sections.append(name)
                all_companion_names.append(name)

    if companion_pets:
        for p in companion_pets:
            if isinstance(p, dict):
                name = p.get('name')
                species = p.get('species')
                if name and species:
                    companion_sections.append(f"{name} the {species}")
                    all_companion_names.append(name)
                elif name:
                    companion_sections.append(name)
                    all_companion_names.append(name)
            elif p:
                companion_sections.append(str(p))
                all_companion_names.append(str(p))

    if companion_characters:
        for c in companion_characters:
            if isinstance(c, dict):
                name = c.get('name')
                if name:
                    companion_sections.append(name)
                    all_companion_names.append(name)
            elif c:
                companion_sections.append(str(c))
                all_companion_names.append(str(c))

    if extra_characters:
        for c in extra_characters:
            if isinstance(c, dict):
                name = c.get('name')
                if name:
                    companion_sections.append(name)
                    all_companion_names.append(name)
            elif c:
                companion_sections.append(str(c))
                all_companion_names.append(str(c))

    if companion:
        companion_sections.append(companion)
        all_companion_names.append(companion)

    comp_str = ", ".join(companion_sections) if companion_sections else "None"
    mandatory_names_str = ", ".join(all_companion_names) if all_companion_names else "None"

    return f"""
Create a LEARN TO READ story for {character_name} (age {age}).
Theme: {theme}
Format: {num_pages} pages. {format_instruction}
Vocabulary: {vocab_instruction}
Requirements: Repeating frames, comforting rhythm, 1 coping moment.
Companions: {comp_str} (MANDATORY Checklist: {mandatory_names_str} - EVERY name here MUST be in the story).
Custom Requests: {custom_elements or 'None'} (CRITICAL: You MUST use the exact words from this request at least once each, verbatim, in the story).
If a custom request implies an action or relationship (e.g., "ride a dragon", "make friends"), include it as a concrete scene or outcome, not just a mention.
{SAFETY_GUARDRAILS}
{STRICT_OUTPUT_CONSTRAINTS}
"""


def _build_rhyme_time_prompt(character_name, theme, age, character_details, companion_pets=None, companion_characters=None, extra_characters=None, story_length="standard", custom_elements=""):
    """Build prompt for Rhyme Time mode stories."""
    band = _get_age_band(age)
    config = AGE_CONSTRAINTS[band]
    length_key = 'medium'
    if story_length == 'short' or story_length == 'quick':
        length_key = 'short'
    elif story_length == 'long' or story_length == 'epic':
        length_key = 'long'
    else:
        length_key = 'medium'
    word_range = config['rhyme'][length_key]

    # Age-appropriate instructions
    age_instruction = ""
    if age <= 5:
        age_instruction = "Use simple, magical vocabulary. Focus on wonder and sensory delight."
    elif age >= 13:
        age_instruction = "Avoid 'babyish' or condescending tones. Use sophisticated rhymes that explore identity, resilience, or complex friendships."

    companion_sections = []
    all_companion_names = []
    if companion_pets:
        for p in companion_pets:
            if isinstance(p, dict):
                name = p.get('name')
                species = p.get('species')
                if name and species:
                    companion_sections.append(f"{name} the {species}")
                    all_companion_names.append(name)
                elif name:
                    companion_sections.append(name)
                    all_companion_names.append(name)
            elif p:
                companion_sections.append(str(p))
                all_companion_names.append(str(p))

    if companion_characters:
        for c in companion_characters:
            if isinstance(c, dict):
                name = c.get('name')
                if name:
                    companion_sections.append(name)
                    all_companion_names.append(name)
            elif c:
                companion_sections.append(str(c))
                all_companion_names.append(str(c))

    if extra_characters:
        for c in extra_characters:
            if isinstance(c, dict):
                name = c.get('name')
                if name:
                    companion_sections.append(name)
                    all_companion_names.append(name)
            elif c:
                companion_sections.append(str(c))
                all_companion_names.append(str(c))

    comp_str = ", ".join(companion_sections) if companion_sections else "None"
    mandatory_names_str = ", ".join(all_companion_names) if all_companion_names else "None"

    return f"""
Create a RHYME TIME story for {character_name} (age {age}).
Theme: {theme}
Tone: {age_instruction or 'Uplifting and fun'}
Word Count: {word_range[0]}-{word_range[1]} words.
Scheme: Consistent AABB or ABCB.
Requirements: Include a magical surprise and a coping moment. {character_name} is the hero.
Companions: {comp_str} (MANDATORY Checklist: {mandatory_names_str} - EVERY name here MUST be in the story).
Custom Requests: {custom_elements or 'None'} (CRITICAL: You MUST use the exact words from this request at least once each, verbatim, in the story).
If a custom request implies an action or relationship (e.g., "ride a dragon", "make friends"), include it as a concrete scene or outcome, not just a mention.
{SAFETY_GUARDRAILS}
{STRICT_OUTPUT_CONSTRAINTS}
"""
