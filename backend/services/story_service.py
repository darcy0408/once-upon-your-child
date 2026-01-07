import random
import re
import json
import time
from google.api_core import exceptions as google_exceptions
from .avatar_to_prompt_helper import AvatarToPromptHelper

SAFETY_GUARDRAILS = """
SAFETY RULES (non-negotiable):
- Keep content safe, gentle, and age-appropriate for children 4-12.
- Avoid violence, weapons, blood, death, or scary/frightening scenes.
- Avoid bullying, insults, or harm to self/others.
- Focus on kindness, courage, teamwork, inclusion, and seeking help.
- Keep language friendly, encouraging, and therapeutic.

PERSONALIZATION RULES (critical for immersion):
- DO NOT invent family members (siblings, parents, cousins) unless explicitly provided
- DO NOT add characters that weren't specified in the request
- If a companion is specified, they MUST appear and play a meaningful role in the story
- Use ONLY the character details provided - don't make up backstory elements
- The child should feel "this story is really about ME"
"""

# Age-appropriate humor elements for ages 5-8
AGE_5_HUMOR_GUIDE = """
AGE 5-8 HUMOR REQUIREMENTS (Include at least ONE per page):
- Sound effects: "Boing!", "Whoosh!", "Ding!", "Splish-splash!", "Zzzip!"
- Silly but friendly names: "Mr. Wiggles", "Princess Sparklepants", "Captain Giggles"
- Tiny misunderstandings that get resolved quickly and happily
- Animal helpers doing goofy things (bird lands on head, cat sneezes sparkles, dog  spins in circles)
- "Oops!" moments with quick reassurance ("Oops! But that's okay!")
- Rhyming silly words: "higgledy-piggledy", "topsy-turvy", "wibbly-wobbly"
- Playful reactions: giggles, tickles, wiggles, bounces

HUMOR RULES:
- Keep it light and friendly, never mean or scary
- Make sure kids are "in on the joke" - no adult sarcasm
- Physical comedy is great (gentle stumbles, silly faces, funny hops)
- Exaggeration for fun ("the BIGGEST smile ever!", "a million sparkles!")
"""

# ----------------------
# Story components
# ----------------------
# ----------------------
# Helper Functions (Defined early to avoid NameErrors)
# ----------------------
def _get_age_guidelines(age: int, story_duration: str | None = None) -> dict:
    """Get age-appropriate guidelines, optionally with duration-specific word counts"""
    # Import here to avoid circular dependency
    try:
        from .story_duration_service import DurationConfig, StoryDuration
        if story_duration:
            config = DurationConfig.get_config(story_duration, age)
            length_guideline = f"{config['min_words']}-{config['max_words']} words, {config['min_pages']}-{config['max_pages']} pages"
        else:
            length_guideline = None
    except ImportError:
        length_guideline = None

    if age <= 5:
        return {
            "length_guideline": length_guideline or "100-150 words",
            "vocabulary_level": "very simple vocabulary (CVC + sight words)",
            "sentence_structure": "3-6 word sentences with repetition",
            "vocabulary_examples": "cat, dog, hop, sun, play, happy",
            "concepts": "tangible, concrete ideas only",
            "special_instructions": "Use rhyme, rhythm, and repeatable frames. Include light humor (sound effects, silly moments).",
        }
    if age <= 8:
        return {
            "length_guideline": length_guideline or "150-250 words",
            "vocabulary_level": "simple (sight words + basic phonics)",
            "sentence_structure": "short, clear, mostly present-tense sentences",
            "vocabulary_examples": "magic, brave, puzzle, curious",
            "concepts": "simple cause/effect with predictable plots",
            "special_instructions": "Include dialogue and phonics-friendly words.",
        }
    if age <= 12:
        return {
            "length_guideline": length_guideline or "250-400 words",
            "vocabulary_level": "grade-level vocabulary",
            "sentence_structure": "mix of short and complex sentences",
            "vocabulary_examples": "determined, shimmering, mysterious, courageous",
            "concepts": "character growth with layered plots and emotional arcs",
            "special_instructions": "Highlight problem-solving and empathy.",
        }
    if age <= 15:
        return {
            "length_guideline": length_guideline or "400-600 words",
            "vocabulary_level": "advanced / expressive vocabulary",
            "sentence_structure": "sophisticated and varied sentences",
            "vocabulary_examples": "contemplated, resilience, luminous, intricate",
            "concepts": "identity exploration, moral dilemmas, nuanced relationships",
            "special_instructions": "Use nuanced emotions and real-world parallels.",
        }
    return {
        "length_guideline": length_guideline or "600-800 words",
        "vocabulary_level": "mature / literary vocabulary",
        "sentence_structure": "complex, literary prose",
        "vocabulary_examples": "introspective, paradoxical, cathartic, transcendent",
        "concepts": "philosophical questions and mature themes",
        "special_instructions": "Employ literary devices, symbolism, and deep psychology.",
    }


def _get_age_5_plot_arc_prompt(num_pages: int) -> str:
    """Get plot arc structure for age 5 stories with specific page requirements"""
    if num_pages <= 8:
        # 5-minute story arc (5-8 pages)
        return """
PAGE-BY-PAGE PLOT ARC FOR AGE 5 (5-8 pages):
Page 1 - Cozy Hook: Meet character in their normal, safe world with something magical appearing
Page 2 - Enter Wonder: Step through the magic door/portal into a colorful, fun place
Page 3 - Fun Discovery: Find something delightful and interesting (candy forest, talking animals, etc.)
Page 4 - Uh-Oh Moment: A small, gentle problem appears (not scary, just needs solving)
Page 5 - Silly Idea: Character tries a funny solution that doesn't quite work (include humor here!)
Page 6 - Kind & Smart Solution: Character uses kindness/cleverness to solve it properly
Page 7 - Sparkly Payoff: Everything works! Magical celebratory moment
Page 8 - Home & Smile: Return home feeling happy and proud

CRITICAL: Each page should end at a natural story beat, not mid-sentence!
"""
    else:
        # 10-minute story arc (8-12 pages)
        return """
PAGE-BY-PAGE PLOT ARC FOR AGE 5 (8-12 pages):
Page 1 - Cozy Start: Character in normal world, happy and curious
Page 2 - Magic Appears: Something wonderful and mysterious shows up
Page 3 - First Discovery: Character explores and finds something amazing
Page 4 - New Friends: Meet helpful companions with fun personalities
Page 5 - Little Problem: A gentle obstacle or puzzle appears
Page 6 - Silly Attempt: Try a goofy solution (humor moment - include sound effects!)
Page 7 - Better Idea: Think of a smarter, kinder way
Page 8 - Brave & Kind Action: Use the good idea with courage and heart
Page 9 - Sparkly Moment: Everything becomes magical and wonderful!
Page 10 - Happy Celebration: Everyone cheers and celebrates together
Page 11 - Journey Home: Head back to the normal world, changed for the better
Page 12 - Warm Glow: Quiet, cozy ending with a smile and happy thought

CRITICAL: Each page should be 70-140 words and end at a sentence boundary!
"""


def _build_age_instruction_block(age: int, story_duration: str | None = None) -> str:
    """Build age-appropriate instruction block with optional duration-specific requirements"""
    guidelines = _get_age_guidelines(age, story_duration)
    return (
        f"AGE-APPROPRIATE GUIDELINES FOR {age}-YEAR-OLD:\n"
        f"- LENGTH: {guidelines['length_guideline']} (strict requirement)\n"
        f"- VOCABULARY: {guidelines['vocabulary_level']}\n"
        f"- SENTENCE STYLE: {guidelines['sentence_structure']}\n"
        f"- WORD EXAMPLES: {guidelines['vocabulary_examples']}\n"
        f"- CONCEPTS: {guidelines['concepts']}\n"
        f"- SPECIAL NOTES: {guidelines['special_instructions']}"
    )


class StoryStructures:
    ADVENTURE_TEMPLATES = [
        {"name": "The Quest", "structure": "Hero receives mission -> Faces obstacles -> Finds strength -> Achieves goal"},
        {"name": "The Discovery", "structure": "Hero finds something unusual -> Investigates -> Uncovers truth -> Shares wisdom"},
        {"name": "The Friendship", "structure": "Hero meets someone different -> Overcomes prejudice -> Works together -> Lasting bond"},
    ]
    PLOT_TWISTS = [
        "The villain turns out to be under a spell and needs help",
        "The treasure they seek was inside them all along",
        "Their companion reveals a magical secret",
        "A tiny creature provides the most important help",
    ]

    @classmethod
    def get_random_structure(cls, theme: str | None = None):
        if theme:
            t = theme.lower()
            if "friend" in t:
                return next((s for s in cls.ADVENTURE_TEMPLATES if s["name"] == "The Friendship"), random.choice(cls.ADVENTURE_TEMPLATES))
            if any(x in t for x in ["discover", "mystery", "secret"]):
                return next((s for s in cls.ADVENTURE_TEMPLATES if s["name"] == "The Discovery"), random.choice(cls.ADVENTURE_TEMPLATES))
        return random.choice(cls.ADVENTURE_TEMPLATES)

class CompanionDynamics:
    COMPANION_ROLES = {
        "Loyal Dog": {"contribution": "sniffs out clues and warns of danger"},
        "Mysterious Cat": {"contribution": "guides through dark places and senses magic"},
        "Mischievous Fairy": {"contribution": "unlocks small spaces and talks to creatures"},
        "Tiny Dragon": {"contribution": "provides aerial view and dragon wisdom"},
    }
    @classmethod
    def get_companion_info(cls, companion_name: str | None, custom_pet: dict | None = None):
        if not companion_name:
            return None
        
        if custom_pet and custom_pet.get("name") == companion_name:
             # It's a custom pet!
             species = custom_pet.get("species", "animal")
             personality = custom_pet.get("personality", "loyal friend")
             return {"contribution": f"is a {species} who act as a {personality}"}

        return cls.COMPANION_ROLES.get(companion_name, {"contribution": "provides emotional support"})

class WisdomGems:
    THEME_WISDOM = {
        "Adventure": ["The greatest adventures begin with a single brave step"],
        "Friendship": ["True friends accept you exactly as you are"],
        "Magic": ["Real magic comes from believing in yourself"],
    }
    @classmethod
    def get_wisdom(cls, theme: str | None):
        return random.choice(cls.THEME_WISDOM.get(theme, cls.THEME_WISDOM["Adventure"]))

class AdvancedStoryEngine:
    def __init__(self):
        self.story_structures = StoryStructures()
        self.companion_dynamics = CompanionDynamics()
        self.wisdom_gems = WisdomGems()
    
    def _format_character_line(self, character: str | dict, additional_characters: list[str] | None) -> str:
        if isinstance(character, dict):
            name = character.get("name", "Hero")
            age = character.get("age", "Unknown")
            traits = character.get("personality_traits", [])
            special_ability = character.get("special_ability")
            avatar_params = character.get("avatar_params")

            char_str = f"- Child/Character: {name} (Age: {age})"

            # Add avatar appearance description if available
            if avatar_params:
                try:
                    # Parse avatar params if it's a JSON string
                    if isinstance(avatar_params, str):
                        avatar_params = json.loads(avatar_params)

                    # Convert to natural language description
                    avatar_desc = AvatarToPromptHelper.avatar_to_description(
                        avatar_params,
                        age=age if isinstance(age, int) else 8
                    )
                    # Extract just the appearance details (skip age since we already have it)
                    appearance_parts = avatar_desc.split(', ', 1)
                    if len(appearance_parts) > 1:
                        char_str += f"\n  APPEARANCE: {appearance_parts[1]}"
                except Exception as e:
                    # If avatar parsing fails, continue without it
                    pass

            if traits:
                char_str += f", Traits: {', '.join(traits)}"
            if special_ability:
                 char_str += f", SPECIAL ABILITY: {special_ability}"
        else:
            char_str = f"- Child/Character: {character}"

        if additional_characters:
            char_str += f"\n- Additional Characters/Friends: {', '.join(additional_characters)}"

        return char_str

    def generate_enhanced_prompt(
        self,
        character: str,
        theme: str,
        companion: str | None = None,  # Legacy support
        custom_pet: dict | None = None,  # Legacy support
        companion_pets: list[dict] | None = None,  # NEW: List of pet companions
        companion_characters: list[str] | None = None,  # NEW: List of character companions
        spark_tool: str | None = None, # NEW: Spark Tool
        mood_physics: dict | None = None, # NEW: Mood Physics
        conflict_hook: str | None = None, # NEW: Plot Driver
        sensory_palette: str | None = None, # NEW: Atmosphere
        custom_elements: str = "",  # NEW: Free-form custom story requests
        additional_characters: list[str] | None = None,
        therapeutic_prompt: str = "",
        feelings_prompt: str | None = None,
        character_details: dict | None = None, # Passed for prompt building
        story_length: str = "standard",  # Legacy: 'quick', 'standard', or 'epic'
        story_duration: str | None = None,  # NEW: '5_minutes' or '10_minutes'
        age: int = 5,  # NEW: Age for calibration
    ):
        # Length calibration for 10-minute read
        if age == 8 and (story_duration == '10_minutes' or story_length in ['standard', 'epic']):
            target_word_count = "1350-1650 words"
            target_pages = "10-12 pages"
        else:
            # Fallback/Default targets
            target_word_count = "600-900 words"
            target_pages = "6-8 pages"

        # Handle companions
        companion_lines = []
        if companion_pets:
            for pet in companion_pets:
                pet_name = pet.get('name', 'Unknown')
                pet_species = pet.get('species', 'pet')
                companion_lines.append(f"- Pet Companion: {pet_name} (a {pet_species.lower()})")

        if companion_characters:
            for char_data in companion_characters:
                if isinstance(char_data, dict):
                    char_name = char_data.get('name', 'Friend')
                    signature_power = char_data.get('signaturePower')
                    sensory_tell = char_data.get('sensoryTell')
                    line = f"- Character Companion: {char_name}"
                    if signature_power:
                        line += f" (Magical Power: {signature_power}, Tell: {sensory_tell})"
                    companion_lines.append(line)

        if not companion_lines and companion:
            companion_lines.append(f"- Companion: {companion}")

        companion_section = "\n".join(companion_lines) if companion_lines else "- Companions: None"

        # Magic Density Checklist for Age 8
        magic_density = ""
        if age == 8:
            magic_density = """
            MAGIC DENSITY CHECKLIST (Age 8):
            - At least 3 distinct magical set pieces (e.g., floating islands, talking trees).
            - At least 3 transformations or magical acts, each with a vivid sensory tell.
            - At least 2 moments of kid-safe suspense (thrilling but safe).
            - At least 6 lines of dialogue total.
            """

        parts = [
            "You are a MASTER STORYTELLER for children. Create a magical, adventurous, and vivid story.",
            "",
            "OUTPUT FORMAT: STRICT JSON ONLY",
            "You MUST return a valid JSON object. No prose before or after the JSON. No markdown fences.",
            "",
            "JSON SCHEMA:",
            """{
  "title": "Story Title",
  "pages": [
    "Full text for page 1...",
    "Full text for page 2...",
    "..."
  ],
  "post_story": {
    "wisdom_gem": "A short, meaningful lesson",
    "adventure_report": {
      "plot_beats": ["Beat 1", "Beat 2", "..."],
      "character_snapshot": "Concise summary of character growth",
      "emotion_notes": ["Note 1", "Note 2"],
      "rereadability_hooks": ["Hook 1", "Hook 2"]
    }
  }
}""",
            "",
            "STORY CONTEXT:",
            self._format_character_line(character, additional_characters),
            f"- Theme: {theme}",
            companion_section,
            f"- Age: {age}",
            "",
            "STORY REQUIREMENTS:",
            f"- TARGET LENGTH: {target_word_count} total.",
            f"- PAGINATION: Split into {target_pages}.",
            "- TONE: Magical, adventurous, funny, and vivid.",
            "- POV: ALWAYS use second-person ('You').",
            "- NO META: Do NOT include 'PAGE X', 'REQUEST SUMMARY', or any internal markers in the page text.",
            "- READABILITY: Use double newlines (\\n\\n) for paragraph breaks inside pages.",
            magic_density,
            SAFETY_GUARDRAILS.strip(),
        ]

        if feelings_prompt:
            parts.append(f"\nFEELINGS-FOCUSED GUIDANCE:\n{feelings_prompt}")

        if custom_elements:
            parts.append(f"\nCUSTOM ELEMENTS:\n{custom_elements}")

        return "\n".join(parts)


    def generate_interactive_story(
        self,
        character_name: str,
        theme: str,
        companion: str | None,
        character_age: int,
        model, # The initialized Gemini model
        user_api_key: str | None,
    ):
        age_guidelines = _build_age_instruction_block(character_age)

        prompt = f"""
You are an experienced children's author running the Engaging Storycraft v9.0 engine for an interactive story.
Child profile:
- Name: {character_name}
- Age: {character_age}
- Theme: {theme}
- Companion: {companion if companion else "None"}
- Mode: Interactive

{age_guidelines}
{SAFETY_GUARDRAILS}

IMPORTANT: Never include code blocks, syntax, or programming examples in your response. Only return story text and reader choices in plain narrative form.

OUTPUT: Return a single, valid, RFC 8259-compliant JSON object in your response. Do not include any text outside of the JSON object.
Example:
{
  "text": "The dragon looked at you curiously. What do you do?",
  "choices": [
    {
      "id": "choice_1",
      "text": "Offer the dragon an apple",
      "emotional_skill": "seeking_support"
    },
    {
      "id": "choice_2",
      "text": "Run away quickly",
      "emotional_skill": "self_reliance"
    },
    {
      "id": "choice_3",
      "text": "Try to talk to the dragon",
      "emotional_skill": "teamwork"
    }
  ],
  "can_conclude": false
}

The JSON object should have the following keys:
- "text": Narrative formatted with these labels (plain text, no code fences):
  REQUEST SUMMARY
  STORY START (2-3 lively paragraphs ending at a clear decision point)
  CHOICE 1:
    A) ... (seeking_support)
    B) ... (self_reliance)
    C) ... (teamwork)
  Keep story prose 220-320 words. No markdown fences.
- "choices": Mirror the options above with ids and emotional_skill fields.

CHOICE RULES:
- Exactly 3 options mapping to seeking_support, self_reliance, and teamwork.
- Each option should feel different and drive the plot/emotions meaningfully.
- No color/door/left-right filler.

Ensure text is vivid, age-tuned, playful, with a strong hook/problem and embodied feelings. Do NOT wrap JSON in backticks.
"""
        # Determine which model to use (User's key > Server model)
        active_model = model
        if user_api_key:
            try:
                import google.generativeai as genai
                genai.configure(api_key=user_api_key)
                # Use the same model name as server or default
                active_model = genai.GenerativeModel("gemini-2.0-flash-exp")
            except Exception as e:
                # Log but fall back to server model if possible, or fail later
                print(f"Error configuring user API key: {e}")

        if not active_model:
            raise ValueError("No valid Gemini model available (Server key missing and no User key provided)")

        max_retries = 5
        base_delay = 1  # seconds
        for attempt in range(max_retries):
            try:
                response = active_model.generate_content(prompt)
                text = getattr(response, "text", "")
                if not text:
                    raise ValueError("Empty model response for interactive story opening")
                return self._parse_interactive_story_response(text)
            except google_exceptions.ResourceExhausted as e:
                if attempt < max_retries - 1:
                    delay = base_delay * (2 ** attempt)
                    time.sleep(delay)
                else:
                    raise e
        
        # This part should be unreachable if the loop completes, but as a fallback:
        raise ValueError("Failed to generate interactive story after multiple retries.")

    def continue_interactive_story(
        self,
        character_name: str,
        theme: str,
        companion: str | None,
        choice_text: str,
        story_so_far: str,
        choices_made: list[str],
        character_age: int,
        model,
        user_api_key: str | None,
    ):
        age_guidelines = _build_age_instruction_block(character_age)

        prompt = f"""
You are continuing an interactive children's story using Engaging Storycraft v9.0 for a {character_age}-year-old.

CONTEXT:
- Main Character: {character_name}
- Theme: {theme}
- Companion: {companion if companion else "None"}
- Story so far: {story_so_far}
- Choices made: {", ".join(choices_made)}
- Last choice: {choice_text}

{age_guidelines}
{SAFETY_GUARDRAILS}

IMPORTANT: Never include code blocks, syntax, or programming examples in your response. Only return story text and reader choices in plain narrative form.

OUTPUT: Return a single, valid, RFC 8259-compliant JSON object in your response. Do not include any text outside of the JSON object.
Example:
{
  "text": "You offer the dragon the apple. It sniffs it curiously, then takes a small bite. It seems to like it!",
  "choices": [
    {
      "id": "choice_1",
      "text": "Ask the dragon its name",
      "emotional_skill": "seeking_support"
    },
    {
      "id": "choice_2",
      "text": "Offer it another apple",
      "emotional_skill": "teamwork"
    },
    {
      "id": "choice_end",
      "text": "End the story here"
    }
  ],
  "can_conclude": true
}

The JSON object should have the following keys:
- "text": Plain prose with labels (no code fences):
  STORY CONTINUES (1-2 paragraphs reflecting last choice; keep 200-280 words)
  If can_conclude is true, append STORY END, WISDOM GEM (5-10 words), and ADVENTURE REPORT bullets as in v9 (plot beats, character snapshot, emotion notes, re-readability hooks).
- "choices": 2-3 meaningful next options. Always include an "end_story" option when can_conclude is true.
- "can_conclude": true if this segment can gracefully end now, else false.

CHOICE RULES:
- Options must be specific actions tied to emotional skills; no color/door/left-right filler.
- Keep each option under 14 words.
Do NOT wrap JSON in backticks.
"""
        # Determine which model to use (User's key > Server model)
        active_model = model
        if user_api_key:
            try:
                import google.generativeai as genai
                genai.configure(api_key=user_api_key)
                active_model = genai.GenerativeModel("gemini-2.0-flash-exp")
            except Exception as e:
                print(f"Error configuring user API key: {e}")

        if not active_model:
            raise ValueError("No valid Gemini model available (Server key missing and no User key provided)")

        max_retries = 5
        base_delay = 1  # seconds
        for attempt in range(max_retries):
            try:
                response = active_model.generate_content(prompt)
                text = getattr(response, "text", "")
                if not text:
                    raise ValueError("Empty model response for interactive story continuation")
                return self._parse_interactive_story_response(text)
            except google_exceptions.ResourceExhausted as e:
                if attempt < max_retries - 1:
                    delay = base_delay * (2 ** attempt)
                    time.sleep(delay)
                else:
                    raise e
        
        # This part should be unreachable if the loop completes, but as a fallback:
        raise ValueError("Failed to continue interactive story after multiple retries.")

    def _parse_interactive_story_response(self, text: str):
        def _try_load_json(raw: str):
            """Try multiple sane fallbacks to load JSON from model text."""
            stripped = (raw or "").strip()
            if not stripped:
                return None

            candidates = []

            # 1) Best guess at an object block even if the model added prose around it
            brace_start = stripped.find("{")
            brace_end = stripped.rfind("}")
            if brace_start != -1 and brace_end != -1 and brace_end > brace_start:
                candidates.append(stripped[brace_start:brace_end + 1].strip())

            # 2) Remove optional markdown code fences
            if stripped.startswith("```"):
                fence_stripped = re.sub(r"^```(?:json)?", "", stripped, flags=re.IGNORECASE)
                fence_stripped = re.sub(r"```$", "", fence_stripped).strip()
                candidates.append(fence_stripped)

            # 3) Raw text as-is
            candidates.append(stripped)

            seen = set()
            for candidate in candidates:
                if not candidate or candidate in seen:
                    continue
                seen.add(candidate)
                try:
                    return json.loads(candidate)
                except json.JSONDecodeError:
                    continue
            return None

        payload = _try_load_json(text)
        if payload is None:
            # Fallback to old parser if model doesn't return usable JSON
            return self._parse_legacy_interactive_response(text)

        story_text = payload.get("text") or ""
        if not isinstance(story_text, str):
            story_text = str(story_text)
        choices = payload.get("choices") or []
        if not isinstance(choices, list):
            choices = []

        validated_choices = []
        for choice in choices:
            choice_id = choice.get("id") or f"choice_{len(validated_choices)+1}"
            text_value = (choice.get("text") or "").strip()
            skill = (choice.get("emotional_skill") or "").strip()
            if not text_value:
                continue
            if any(bad in text_value.lower() for bad in ["door", "left", "right", "red", "blue", "green"]):
                continue
            validated_choices.append({
                "id": choice_id,
                "text": text_value,
                "emotional_skill": skill or None
            })

        if not validated_choices:
            # Graceful fallback
            return {
                "text": story_text or "Let's end the story here.",
                "choices": [{"id": "choice_end", "text": "End the story here."}]
            }

        return {
            "text": story_text,
            "choices": validated_choices,
            "can_conclude": payload.get("can_conclude", False)
        }

    def _parse_legacy_interactive_response(self, text: str):
        segment_match = re.search(r"\[SEGMENT\]\s*(.*?)(?=\[CHOICE_|$)", text, re.DOTALL)
        segment_text = segment_match.group(1).strip() if segment_match else text.strip()

        choices = []
        for i in range(1, 10): # Look for up to 9 choices
            choice_match = re.search(rf"\[CHOICE_{i}\]\s*(.*?)(?=\[CHOICE_|\Z)", text)
            if choice_match:
                choices.append({
                    "id": f"choice_{i}", # Simple ID for now
                    "text": choice_match.group(1).strip()
                })
            else:
                break
        
        # Check for end choice
        if "[CHOICE_END]" in text:
            choices.append({
                "id": "choice_end",
                "text": "End the story here."
            })

        if not choices:
            # If no choices are found, assume it's the end of the story
            return {"text": segment_text, "choices": [{"id": "choice_end", "text": "End the story here."}]}
        
        return {"text": segment_text, "choices": choices}


# Legacy compatibility: some parts of the backend still import story_service.story_engine.
# Instantiate a shared AdvancedStoryEngine so those references continue to work even
# though the app now prefers create_app()'s story_engine_instance.
story_engine = AdvancedStoryEngine()


# ----------------------
# Helpers
# ----------------------
def _safe_extract_title_and_gem(text: str, theme: str):
    """
    Parses the new JSON story format.
    Returns: title, wisdom_gem, story_body, pages_list, post_story_dict
    """
    # Try to clean markdown code blocks if present
    clean_text = text.strip()
    if clean_text.startswith("```"):
        clean_text = re.sub(r"^```(?:json)?", "", clean_text, flags=re.IGNORECASE)
        clean_text = re.sub(r"```$", "", clean_text).strip()

    try:
        data = json.loads(clean_text)
        
        # Happy path: valid JSON
        title = data.get("title", f"A {theme} Adventure")
        pages = data.get("pages", [])
        post_story = data.get("post_story", {})
        wisdom_gem = post_story.get("wisdom_gem") or "You are magic!"
        
        # Fallback if wisdom_gem is top-level
        if not wisdom_gem and "wisdom_gem" in data:
            wisdom_gem = data["wisdom_gem"]

        # If pages is a single string, wrap it
        if isinstance(pages, str):
            pages = [pages]
            
        # Create full text for legacy storage
        story_body = "\n\n".join(pages)
        
        return title, wisdom_gem, story_body, pages, post_story

    except Exception as e:
        # Fallback to regex extraction for legacy/malformed output
        # (This keeps the old logic as a backup)
        _TITLE_RE = re.compile(r"\[TITLE:\s*(.*?)\s*\]", re.DOTALL)
        _GEM_RE = re.compile(r"\[WISDOM GEM:\s*(.*?)\s*\]", re.DOTALL)
        
        title_match = _TITLE_RE.search(text or "")
        gem_match = _GEM_RE.search(text or "")

        if title_match:
            try:
                title_text = title_match.group(1).strip()
                title = title_text if title_text else f"A {theme} Adventure"
            except (IndexError, AttributeError):
                title = f"A {theme} Adventure"
        else:
            title = f"A {theme} Adventure"

        if gem_match:
            try:
                gem_text = gem_match.group(1).strip()
                wisdom_gem = gem_text if gem_text else "You are magic!"
            except (IndexError, AttributeError):
                wisdom_gem = "You are magic!"
        else:
            wisdom_gem = "You are magic!"

        # Remove title and wisdom gem markers
        story_body = _TITLE_RE.sub("", text or "").strip()
        story_body = _GEM_RE.sub("", story_body).strip()

        # Clean up template artifacts from the story
        if "REQUEST SUMMARY" in story_body:
            parts = story_body.split("STORY:")
            if len(parts) > 1:
                story_body = parts[1].strip()

        story_body = story_body.replace("STORY START", "").strip()
        story_body = story_body.replace("STORY END", "").strip()

        if "ADVENTURE REPORT:" in story_body:
            story_body = story_body.split("ADVENTURE REPORT:")[0].strip()

        if "\nWISDOM GEM:" in story_body:
            story_body = story_body.split("\nWISDOM GEM:")[0].strip()

        # Return empty list for pages since we couldn't parse them
        return title, wisdom_gem, story_body, [story_body], {}


def _describe_slider_value(value, left_label, right_label):
    if value is None:
        return None
    delta = abs(value - 50)
    if delta <= 5:
        return f"balanced between {left_label.lower()} and {right_label.lower()}"
    direction = right_label if value > 50 else left_label
    if delta >= 30:
        qualifier = "strongly "
    elif delta >= 15:
        qualifier = "leans "
    else:
        qualifier = "slightly "
    return f"{qualifier}{direction.lower()}"


def _describe_personality_sliders(personality_sliders):
    if not personality_sliders:
        return []
    lines = ["\nPERSONALITY STYLE DIALS: (0 = left trait, 100 = right trait)"]
    # This should be passed in or defined in a shared location
    PERSONALITY_SLIDER_DEFINITIONS = {
        "organization_planning": {"label": "Organization & Planning", "left_label": "Tidy Planner", "right_label": "Messy Freestyle"},
        "assertiveness": {"label": "Voice Style", "left_label": "Bold Voice", "right_label": "Soft Voice"},
        "sociability": {"label": "Social Energy", "left_label": "Jump-Right-In", "right_label": "Warm-Up-First"},
        "adventure": {"label": "Adventure Level", "left_label": "Let's Explore!", "right_label": "Careful Steps"},
        "expressiveness": {"label": "Energy Level", "left_label": "Mega Energy", "right_label": "Calm Breeze"},
        "feelings_sharing": {"label": "Feelings Expression", "left_label": "Heart-On-Sleeve", "right_label": "Quiet Feelings"},
        "problem_solving": {"label": "Problem-Solving Style", "left_label": "Brainy Builder", "right_label": "Imagination Wiz"},
        "play_preference": {"label": "Play Preference", "left_label": "Caring & Nurturing", "right_label": "Building & Action"},
    }
    for key, meta in PERSONALITY_SLIDER_DEFINITIONS.items():
        value = personality_sliders.get(key)
        if value is None:
            continue
        descriptor = _describe_slider_value(
            value, meta["left_label"], meta["right_label"]
        )
        if descriptor:
            toward = meta["right_label"] if value > 50 else meta["left_label"]
            lines.append(
                f"- {meta['label']}: {descriptor} ({value}/100 toward {toward.lower()})"
            )
    return lines


def _build_character_integration(character_name, fears, strengths, likes, dislikes, comfort_item, personality_traits, personality_sliders):
    """Build deep character integration for personalized, therapeutic storytelling"""

    parts = [
        "DEEP CHARACTER INTEGRATION:",
        f"Character Name: {character_name}",
    ]

    # Personality
    if personality_traits:
        traits_str = ", ".join(personality_traits)
        parts.append(f"Personality: {traits_str}")

    slider_lines = _describe_personality_sliders(personality_sliders)
    if slider_lines:
        parts.extend(slider_lines)

    # Fears (Critical for therapeutic stories)
    if fears:
        fears_str = ", ".join(fears)
        parts.extend([
            f"\nFEARS TO ADDRESS: {fears_str}",
            "IMPORTANT: The story MUST help the character face and overcome one of these fears.",
            "Show the character feeling scared at first, then discovering courage and strength.",
            "Make the fear resolution realistic and empowering, not dismissive.",
        ])

    # Strengths (Use these to overcome challenges)
    if strengths:
        strengths_str = ", ".join(strengths)
        parts.extend([
            f"\nSTRENGTHS TO UTILIZE: {strengths_str}",
            f"IMPORTANT: Show how {character_name} uses these strengths to solve problems.",
            "Let the character discover that they already have what they need inside them.",
        ])

    # Comfort item (Emotional security)
    if comfort_item:
        parts.extend([
            f"\nCOMFORT ITEM: {comfort_item}",
            f"Include the {comfort_item} in the story as a source of courage and comfort.",
            f"Perhaps {character_name} carries it during scary moments or it helps them feel brave.",
        ])

    # Likes (Make story engaging)
    if likes:
        likes_str = ", ".join(likes)
        parts.extend([
            f"\nLIKES: {likes_str}",
            f"Incorporate elements related to {likes_str} to make the story personally engaging.",
        ])

    # Dislikes (Add realistic challenges)
    if dislikes:
        dislikes_str = ", ".join(dislikes)
        parts.extend([
            f"\nDISLIKES: {dislikes_str}",
            f"Consider using one of these dislikes as a minor challenge or something {character_name} must face.",
        ])

    # Therapeutic structure
    parts.extend([
        "\nSTORY STRUCTURE (CRITICAL):",
        f"1. BEGINNING: Introduce {character_name} in their normal world, showing their personality traits",
        "2. CHALLENGE: Present a situation that involves one of their fears or growth areas",
        "3. STRUGGLE: Show realistic difficulty - fears are real, challenges are hard",
        "4. DISCOVERY: Character realizes they have inner strength (use their strengths list)",
        "5. RESOLUTION: Character overcomes the challenge, grows emotionally, learns about themselves",
        "6. REFLECTION: End with character feeling proud, more confident, emotionally stronger",
        "\nNARRATIVE REQUIREMENTS:",
        "- Use sensory details (what they see, hear, feel, smell) to make scenes vivid",
        "- Show emotions, don't just tell (e.g., 'heart pounding' not 'felt scared')",
        f"- Keep {character_name} as the main character who drives the action",
        "- Make the therapeutic element natural, not preachy or obvious",
        "- Create a clear emotional arc: vulnerable -> challenged -> growing -> empowered",
    ])

    return "\n".join(parts)





def _build_learning_to_read_prompt(character_name, theme, age, character_details, companion=None, extra_characters=None, story_length="standard"):
    # Map story length to word count for learning-to-read mode (shorter ranges)
    word_count_map = {
        'quick': '50-75 words',
        'standard': '75-125 words',
        'epic': '125-175 words',
    }
    target_word_count = word_count_map.get(story_length, '75-125 words')

    def _format_list(label, values):
        if not values:
            return ""
        clean = [v.strip() for v in values if isinstance(v, str) and v.strip()]
        if not clean:
            return ""
        return f"\n{label}: {', '.join(clean[:5])}"

    detail_section = ""
    if character_details:
        detail_section += _format_list("LIKES", character_details.get("likes"))
        detail_section += _format_list("STRENGTHS", character_details.get("strengths"))
        comfort_item = character_details.get("comfort_item")
        if comfort_item:
            detail_section += f"\nCOMFORT ITEM: {comfort_item}"

    if extra_characters:
        detail_section += f"\nFRIENDS IN STORY: {', '.join(extra_characters[:5])}"

    companion_text = ""
    if companion and companion != "None":
        companion_text = f"\nCOMPANION: Include {companion} as a gentle helper."

    return (
        f"You are creating a LEARNING TO READ rhyming story for a {age}-year-old child named {character_name}.\n\n"
        "STRICT REQUIREMENTS (NO EXCEPTIONS):\n"
        f"1. TOTAL LENGTH: {target_word_count} only.\n"
        "2. RHYME PATTERN: AABB (line 1 rhymes with line 2, line 3 with line 4, etc.).\n"
        "3. LINE LENGTH: Each line must use only 4-6 simple words.\n"
        "4. VOCABULARY: Only CVC words (cat, dog, hop, sun) and common sight words (the, and, can, see, like, play). "
        "Avoid blends, silent letters, or complex spelling patterns.\n"
        f"5. STRUCTURE: Repetition helps reading. Use predictable frames like \"Can {character_name} ___? Yes, {character_name} can ___!\".\n"
        "6. TONE: Encouraging, musical, confident.\n"
        "7. FORMAT: Place each short sentence or clause on its own line for easy finger tracking.\n\n"
        f"THEME: {theme}{companion_text}{detail_section}\n\n"
        f"Create the rhyming learning-to-read story about {character_name} now."
    )

def _build_rhyme_time_prompt(character_name, theme, age, character_details, companion_pets=None, companion_characters=None, extra_characters=None, story_length="standard"):
    """Build a prompt for rhyming stories (Rhyme Time Mode).

    Less restrictive than Learning to Read mode - allows age-appropriate vocabulary
    but maintains strong rhyme structure.
    """
    # Map story length to word count for rhyme-time mode
    word_count_map = {
        'quick': '100-150 words',
        'standard': '150-250 words',
        'epic': '250-350 words',
    }
    target_word_count = word_count_map.get(story_length, '150-250 words')

    def _format_list(label, values):
        if not values:
            return ""
        clean = [v.strip() for v in values if isinstance(v, str) and v.strip()]
        if not clean:
            return ""
        return f"\n{label}: {', '.join(clean[:5])}"

    detail_section = ""
    if character_details:
        detail_section += _format_list("LIKES", character_details.get("likes"))
        detail_section += _format_list("STRENGTHS", character_details.get("strengths"))
        comfort_item = character_details.get("comfort_item")
        if comfort_item:
            detail_section += f"\nCOMFORT ITEM: {comfort_item}"

    if extra_characters:
        detail_section += f"\nFRIENDS IN STORY: {', '.join(extra_characters[:5])}"

    # Handle companion pets with species info
    companion_text = ""
    if companion_pets:
        for pet in companion_pets:
            pet_name = pet.get('name', 'Unknown')
            pet_species = pet.get('species', 'pet')
            companion_text += f"\nPET COMPANION: {pet_name} the {pet_species}"

    # Handle companion characters
    if companion_characters:
        companion_text += f"\nCHARACTER COMPANIONS: {', '.join(companion_characters)}"

    return (
        f"You are creating a RHYME TIME story for a {age}-year-old child named {character_name}.\n\n"
        "STRICT REQUIREMENTS:\n"
        f"1. LENGTH: {target_word_count}.\n"
        "2. RHYME PATTERN: Strong, consistent AABB rhyme scheme (couplets).\n"
        "3. RHYTHM: Clear, bouncy rhythm that flows naturally when read aloud.\n"
        "4. VOCABULARY: Age-appropriate words for a {age}-year-old. Fun, playful language.\n"
        "5. STRUCTURE: Each rhyming couplet should advance the story.\n"
        "6. TONE: Joyful, musical, engaging. Make it FUN to read aloud!\n"
        "7. FORMAT: Place each rhyming line on its own line for clear visual structure.\n\n"
        f"THEME: {theme}{companion_text}{detail_section}\n\n"
        f"Create a delightful rhyming story about {character_name}'s adventure now."
    )

def _as_list(v):
    """Accept list, JSON string, comma string, or None; return list[str]."""
    if isinstance(v, list):
        return [str(x) for x in v]
    if v in (None, "", []):
        return []
    if isinstance(v, str):
        s = v.strip()
        if not s:
            return []
        if s.startswith("[") and s.endswith("]"):
            try:
                parsed = json.loads(s)
                return [str(x) for x in parsed] if isinstance(parsed, list) else [s]
            except Exception:
                pass
        return [part.strip() for part in s.split(",") if part.strip()]
    return [str(v)]

def _extract_current_feeling(container):
    """Return a normalized current feeling dictionary or None."""
    if not isinstance(container, dict):
        return None
    feeling = container.get("current_feeling")
    if feeling is None and "currentFeeling" in container:
        feeling = container.get("currentFeeling")
    if not isinstance(feeling, dict):
        return None

    def _clean(value):
        if value is None:
            return None
        value_str = str(value).strip()
        return value_str or None

    intensity = feeling.get("intensity")
    try:
        intensity = int(intensity)
    except (TypeError, ValueError):
        intensity = None
    else:
        intensity = max(1, min(intensity, 5))

    coping_value = feeling.get("coping_strategies")
    if coping_value is None and "copingStrategies" in feeling:
        coping_value = feeling.get("copingStrategies")
    coping_strategies = [item for item in _as_list(coping_value) if item]

    # Handle both old emotion structure and new feelings wheel structure
    emotion_name = (
        _clean(feeling.get("emotion_name") or feeling.get("emotionName"))
        or _clean(feeling.get("tertiary_emotion"))  # New feelings wheel
        or _clean(feeling.get("secondary_emotion"))  # Fallback to secondary
        or _clean(feeling.get("core_emotion"))  # Fallback to core
    )

    normalized = {
        "emotion_id": _clean(feeling.get("emotion_id") or feeling.get("emotionId") or feeling.get("tertiary_emotion")),
        "emotion_name": emotion_name,
        "emotion_emoji": _clean(feeling.get("emotion_emoji") or feeling.get("emotionEmoji")),
        "emotion_description": _clean(feeling.get("emotion_description") or feeling.get("emotionDescription")),
        "intensity": intensity,
        "what_happened": _clean(feeling.get("what_happened") or feeling.get("whatHappened")),
        "physical_signs": _clean(feeling.get("physical_signs") or feeling.get("physicalSigns")),
        "coping_strategies": coping_strategies,
    }

    # If no meaningful data, return None
    if not any(value for key, value in normalized.items() if key != "coping_strategies"):
        if not normalized["coping_strategies"]:
            return None
    return normalized

def _build_feelings_prompt(character_name: str, feeling: dict | None) -> str:
    if not feeling:
        return ""

    emotion_name = feeling.get("emotion_name") or "a big feeling"
    emoji = feeling.get("emotion_emoji") or ""
    description = feeling.get("emotion_description")
    what_happened = feeling.get("what_happened")
    physical_signs = feeling.get("physical_signs")
    intensity = feeling.get("intensity")
    coping = feeling.get("coping_strategies") or []

    lines = [
        f"- Current emotion: {emotion_name} {emoji}".strip(),
    ]
    if intensity:
        lines.append(f"- Intensity: {intensity} out of 5 (1=calm, 5=very strong).")
    if description:
        lines.append(f"- How it feels: {description}.")
    if what_happened:
        lines.append(f"- Recent situation: {what_happened}.")
    if physical_signs:
        lines.append(f"- Body clues: {physical_signs}.")
    if coping:
        strategies = ", ".join(coping)
        lines.append(f"- Coping strategies to highlight: {strategies}.")

    guidelines = [
        f"1. Begin the story by acknowledging that {character_name} feels {emotion_name.lower()} and why.",
        "2. Validate the feeling with compassionate language (all feelings are okay).",
        "3. Describe the character's body sensations and thoughts tied to the emotion.",
        "4. Weave coping strategies into the narrative in a natural, supportive way.",
        "5. Show the character processing the feeling, using coping skills, and noticing a shift.",
        "6. End with hopeful reflection—what the character learned about their feelings.",
    ]

    return "\n".join([
        *lines,
        "\nFEELINGS STORY REQUIREMENTS:",
        *guidelines,
        "7. Keep the tone gentle, therapeutic, and empowering throughout.",
    ])
