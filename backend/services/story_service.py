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
⚠️ CRITICAL IMMERSION RULES — these override all other instructions:
1. The story must read as a seamless in-world narrative. Characters have ZERO awareness they are in a generated story or therapeutic exercise.
2. NEVER include AI-style preambles ("Here we go!", "Sure!", "Here is your story:") or sign-offs in the response.
3. NEVER expose internal storytelling mechanics inside the prose. Characters must not speak or think using craft/therapy terminology. Any sentence that sounds like a story-writing rubric, lesson summary, or process description has broken this rule.
4. NEVER end with an explicit moral recap or lesson announcement — theme and growth must emerge through action and feeling, not stated conclusions.
5. Do NOT repeat or closely paraphrase the opening paragraph at the end.
6. Return ONLY the JSON requested below — nothing before the opening brace, nothing after the closing brace.
"""

# Forbidden terms used by the post-processing leakage filter (see _strip_meta_leakage).
_META_LEAK_TERMS = [
    "earned ending", "challenge arc", "two-step challenge", "three-key lock",
    "therapeutic specialist", "narrative specialist", "narrative architect",
    "consequence chain", "earned win", "manifest an abstract emotion",
    "tradeoff", "plot twist arc", "story beat", "character arc",
    "therapeutic narrative", "coping moment",
]

SAFETY_GUARDRAILS = f"""
{STRICT_OUTPUT_CONSTRAINTS}
SAFETY RULES:
- No sexual content, no graphic violence, no self-harm, no illegal wrongdoing.
- Handle sensitive emotions gently. Safe, therapeutic tone.
- Do NOT invent characters or family members not provided.
- SAFETY: Ensure no scary imagery or abandonment themes for children.
"""

# Maps therapeutic keywords → (virtue_name, how_to_show_it_in_prose)
# NEVER name the virtue in the story — the character lives it, the reader feels it.
VIRTUE_MAP = {
    'friendship':          ('inclusion',          'The protagonist notices someone alone or left out and takes one small, concrete action to include them.'),
    'social':              ('inclusion',          'The protagonist notices someone alone or left out and takes one small, concrete action to include them.'),
    'making friends':      ('kindness',           'The protagonist initiates a genuine connection without being asked, and the moment costs them something (courage, comfort, time).'),
    'emotion':             ('self-awareness',     'The protagonist names their feeling aloud or in thought before reacting — slowing the impulse loop by one breath.'),
    'feeling':             ('self-awareness',     'The protagonist names their feeling aloud or in thought before reacting — slowing the impulse loop by one breath.'),
    'regulation':          ('patience',           'The protagonist pauses at the moment of highest frustration, chooses a slower path, and the story shows the downstream payoff of that pause.'),
    'anger':               ('patience',           'The protagonist pauses at the moment of highest frustration, chooses a slower path, and the story shows the downstream payoff of that pause.'),
    'anxiety':             ('courage',            'The protagonist tries the scary thing anyway — not fearlessly, but with the fear fully present. Show the physical sensation and the decision to act through it.'),
    'fear':                ('courage',            'The protagonist tries the scary thing anyway — not fearlessly, but with the fear fully present. Show the physical sensation and the decision to act through it.'),
    'scared':              ('courage',            'The protagonist tries the scary thing anyway — not fearlessly, but with the fear fully present. Show the physical sensation and the decision to act through it.'),
    'confidence':          ('voice',              'The protagonist speaks their truth once, clearly, in a moment where staying silent would have been easier. No lecture — just the act.'),
    'self-esteem':         ('voice',              'The protagonist speaks their truth once, clearly, in a moment where staying silent would have been easier. No lecture — just the act.'),
    'resilience':          ('perseverance',       'The protagonist fails at least once before succeeding. The failure is specific, the recovery is effortful, and the final success is earned — not given.'),
    'try':                 ('perseverance',       'The protagonist fails at least once before succeeding. The failure is specific, the recovery is effortful, and the final success is earned — not given.'),
    'empathy':             ('compassion',         'The protagonist makes a decision that costs them something personally in order to help or understand another character. Show their internal reasoning.'),
    'bullying':            ('integrity',          'The protagonist chooses the right action in a moment when no adult is watching and the wrong choice would go unpunished. Show the internal moment of choice.'),
    'pressure':            ('integrity',          'The protagonist chooses the right action in a moment when no adult is watching and the wrong choice would go unpunished. Show the internal moment of choice.'),
    'fairness':            ('justice',            'The protagonist encounters something unfair, names it internally, and chooses one of: speaking up, finding an alternative path, or accepting gracefully with perspective. No lecturing.'),
    'unfair':              ('justice',            'The protagonist encounters something unfair, names it internally, and chooses one of: speaking up, finding an alternative path, or accepting gracefully with perspective. No lecturing.'),
    'jealous':             ('gratitude',          'The protagonist feels the hot sting of jealousy — named honestly, not glossed over — then shifts their gaze to something they genuinely value. The shift is earned, not instant.'),
    'sharing':             ('generosity',         'The protagonist gives something up voluntarily and the story lingers on the warmth that follows — not the sacrifice.'),
    'transition':          ('adaptability',       'The protagonist encounters something that has irrevocably changed. They grieve it briefly, then find one new thing to anchor to. Change becomes survivable.'),
    'change':              ('adaptability',       'The protagonist encounters something that has irrevocably changed. They grieve it briefly, then find one new thing to anchor to. Change becomes survivable.'),
    'rules':               ('trust',              'The protagonist chooses to follow a rule whose purpose they don\'t yet understand, and the story — without moralizing — later reveals why the rule existed.'),
    'authority':           ('trust',              'The protagonist chooses to follow a rule whose purpose they don\'t yet understand, and the story — without moralizing — later reveals why the rule existed.'),
    'focus':               ('mindfulness',        'The protagonist\'s attention wanders at a key moment, they catch it, and returning to the present task makes all the difference. Show the noticing, not just the task.'),
    'problem':             ('resourcefulness',    'The protagonist solves the central challenge using something they already had — an overlooked skill, an ignored object, or an underestimated relationship.'),
}


def _get_virtue_instruction(therapeutic_prompt: str, age: int) -> str:
    """Return an invisible virtue anchoring instruction based on the therapeutic_prompt string.

    Scans for known keywords and returns the matching virtue instruction.
    If no match, returns a default resilience instruction.
    The instruction is injected into the prompt but must NEVER be stated in the story prose.
    """
    if not therapeutic_prompt:
        return ""
    prompt_lower = therapeutic_prompt.lower()
    for keyword, (virtue, instruction) in VIRTUE_MAP.items():
        if keyword in prompt_lower:
            age_caveat = ""
            if age <= 7:
                age_caveat = " Keep it simple and concrete — no internal monologue, just visible action."
            elif age >= 14:
                age_caveat = " For this age, lean into internal monologue and the cost of the choice."
            return (
                f"\n**INVISIBLE VIRTUE — {virtue.upper()}** (NEVER name this virtue in the story):\n"
                f"{instruction}{age_caveat}\n"
                "Rule: Model the virtue through one specific scene or choice. "
                "The child lives it vicariously — no character announces the lesson.\n"
            )
    return ""


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
        interests = ", ".join(char_details.get('interests', []))
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

        # Derive invisible virtue instruction from therapeutic_prompt
        virtue_instruction = _get_virtue_instruction(therapeutic_prompt, age)

        return f"""
**PERSONA**: Expert Children's Author & Therapeutic Storyteller.

You are a MASTER STORYTELLER creating a {story_length} adventure for {character}{gender_text} (age {age}).

**STORY SPECS**:
- **THEME**: {theme}
- **CONFLICT**: {conflict_hook or 'A magical mystery needs solving.'}
- **SENSORY PALETTE**: {sensory_palette or 'Bright colors, soft sounds, sweet smells.'}
- **HERO**: {character} (Strengths: {strengths or 'Brave and kind'}{(', Passions: ' + interests) if interests else ''}).
- **SPECIAL ABILITY**: {special_ability} (MUST be used at the climax).
- **CHARACTER VOICE**: {character} approaches problems using their strengths ({strengths or 'bravery and kindness'}). Let this shape how they think, speak, and act throughout — not just at the climax. A problem-solver notices clues; a healer checks on others first; an adventurer rushes in then reflects.
{tool_section}
- **IMPOSSIBLE ELEMENTS**: (Inspiration Only - DO NOT use these exact phrases): {age_impossible}
- **COMPANIONS**: 
{comp_str}
(MANDATORY: Every character/pet listed above MUST be in the story. Checklist of names to include: {mandatory_names_str})
- **CUSTOM REQUESTS**: {custom_elements or 'None'} (CRITICAL: You MUST use the exact words from this request at least once each, verbatim, in the story).
  If a custom request implies an action or relationship (e.g., "ride a dragon", "make friends"), include it as a concrete scene or outcome, not just a mention.
{mood_rules}
{virtue_instruction}
**WRITING GUIDELINES**:
- **Tone**: {config['notes']}
- **Word Count**: Approximately {word_range[0]}-{word_range[1]} words total.
- **Complexity Calibration**: {complexity_instruction}
- **Hard Complexity Targets**: {hard_complexity_constraints or 'N/A for this age band.'}
- **Safety**: {SAFETY_GUARDRAILS.strip()}{safety_reinforcement}
- **Mandatory Elements**: Must include {coping_instruction}, and a satisfying conclusion.

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
{STRICT_OUTPUT_CONSTRAINTS}"""

# Helper functions for story_tasks.py

def _strip_meta_leakage(pages: list) -> list:
    """Remove sentences that contain leaked storytelling jargon from page text.

    Checks each sentence in every page. If a sentence contains two or more
    terms from _META_LEAK_TERMS it is almost certainly meta-commentary that
    slipped through the prompt guard, so we drop it and log a warning.
    A single-term match is only removed when the sentence is very short
    (≤12 words) and starts with a declarative opener like "This was" / "It was".
    """
    cleaned = []
    for page in pages:
        sentences = re.split(r'(?<=[.!?])\s+', page.strip())
        kept = []
        for sent in sentences:
            lower = sent.lower()
            hits = sum(1 for term in _META_LEAK_TERMS if term in lower)
            words = sent.split()
            # Drop if 2+ leaked terms, OR single term in short declarative sentence
            if hits >= 2:
                logger.warning("Stripped meta-leakage (multi-term): %r", sent[:120])
                continue
            if hits == 1 and len(words) <= 12 and re.match(r'^(it was|this was|that was|in the end,?)\b', lower):
                logger.warning("Stripped meta-leakage (short declarative): %r", sent[:120])
                continue
            kept.append(sent)
        page_clean = " ".join(kept)
        if page_clean.strip():  # skip pages that became fully empty after stripping
            cleaned.append(page_clean)
        elif kept != sentences:
            logger.warning("Page became empty after meta-leakage stripping; retaining original.")
            cleaned.append(page)
        else:
            cleaned.append(page_clean)
    return cleaned


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
        raw_title = data.get("title", f"A {theme} Adventure")
        # Strip double articles: "A The X" → "The X", "An A X" → "A X", etc.
        title = re.sub(r'^(A|An)\s+(The|A|An)\s+', r'\2 ', raw_title, flags=re.IGNORECASE)
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
            fallback_title = re.sub(r'^(A|An)\s+(The|A|An)\s+', r'\2 ', f"A {theme} Adventure", flags=re.IGNORECASE)
            return fallback_title, "You are magic!", candidate_text, [candidate_text], {}
    except Exception as e:
        logger.warning(f"Unexpected error parsing story: {e}. Falling back to raw text.")
        fallback_title = re.sub(r'^(A|An)\s+(The|A|An)\s+', r'\2 ', f"A {theme} Adventure", flags=re.IGNORECASE)
        return fallback_title, "You are magic!", candidate_text, [candidate_text], {}

    # If we parsed successfully but got no pages, verify content length
    if not pages:
         # This shouldn't happen with proper JSON unless 'pages' key was empty list
         # Use candidate text as fallback
         pages = [candidate_text]

    pages = _strip_meta_leakage(pages)
    story_body = "\n\n".join(pages)
    return title, wisdom_gem, story_body, pages, post_story


def _build_learning_to_read_prompt(character_name, theme, age, character_details, companion=None, companion_pets=None, companion_characters=None, extra_characters=None, story_length="standard", custom_elements=""):
    """Build prompt for Learning to Read mode stories with graduated vocabulary."""
    band = _get_age_band(age)
    config = AGE_CONSTRAINTS[band]
    if 'ltr' not in config:
        raise ValueError(f"Learning to Read mode is not available for age {age}. Supported ages: 3–7.")

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
**OUTPUT FORMAT**: Strictly return valid JSON with this structure:
{{
  "title": "Story Title",
  "wisdom_gem": "One short, warm encouraging phrase the child can repeat (e.g. 'Being kind makes magic happen').",
  "pages": [
    {{"text": "Page text (1-2 sentences max)..."}},
    {{"text": "Page text..."}},
    ...
  ]
}}
Return EXACTLY {num_pages} page objects. No extra keys. No prose outside the JSON.
{STRICT_OUTPUT_CONSTRAINTS}"""


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
**OUTPUT FORMAT**: Strictly return valid JSON with this structure:
{{
  "title": "Story Title",
  "wisdom_gem": "One short rhyming or lyrical phrase the child can carry with them.",
  "pages": [
    {{"text": "Rhyming stanza or couplet..."}},
    {{"text": "Rhyming stanza or couplet..."}},
    ...
  ]
}}
No prose outside the JSON.
"""
