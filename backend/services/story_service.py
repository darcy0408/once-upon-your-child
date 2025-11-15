
import random
import re
import json

# ----------------------
# Story components
# ----------------------
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
    def get_companion_info(cls, companion_name: str | None):
        if not companion_name:
            return None
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

    def generate_enhanced_prompt(
        self,
        character: str,
        theme: str,
        companion: str | None,
        therapeutic_prompt: str = "",
        feelings_prompt: str | None = None,
    ):
        story_structure = self.story_structures.get_random_structure(theme)
        companion_info = self.companion_dynamics.get_companion_info(companion)
        plot_twist = random.choice(self.story_structures.PLOT_TWISTS)
        wisdom = self.wisdom_gems.get_wisdom(theme)
        parts = [
            "You are a master storyteller creating an enchanting tale for children.",
            "\nSTORY DETAILS:",
            f"- Main Character: {character}",
            f"- Theme: {theme}",
            f"- Story Structure: {story_structure['structure']}",
        ]
        if companion_info:
            parts.extend([
                f"- Companion: {companion}",
                f"- How Companion Helps: {companion_info['contribution']}",
            ])

        # Add therapeutic elements if provided
        if therapeutic_prompt:
            parts.extend([
                "\nTHERAPEUTIC ELEMENTS:",
                therapeutic_prompt,
            ])
        if feelings_prompt:
            parts.extend([
                "\nFEELINGS-FOCUSED GUIDANCE:",
                feelings_prompt,
            ])

        parts.extend([
            "\nNARRATIVE REQUIREMENTS:",
            f"1. Start with an engaging opening that introduces {character}.",
            f"2. Incorporate this plot element naturally: {plot_twist}.",
            "3. End with a satisfying resolution.",
        ])

        if therapeutic_prompt:
            parts.append("4. Weave therapeutic elements naturally into the story (not preachy or obvious).")

        parts.extend([
            "\nSTORY LENGTH: Approximately 500-600 words.",
            "\nSENSORY-RICH WRITING:",
            "- Use SENSORY DETAILS: What does the character see, hear, feel, smell, taste?",
            "- SHOW emotions through body language: 'heart racing', 'palms sweating', 'warm feeling spreading'",
            "- Use VIVID DESCRIPTIONS: colors, sounds, textures, temperatures",
            "- Create IMMERSIVE scenes that readers can picture clearly",
            "- Example: Instead of 'Emma was scared', write 'Emma's heart pounded as shadows danced on the wall'",
            "\nFORMAT REQUIREMENTS:",
            "- Start with: [TITLE: A Creative and Engaging Title]",
            f"- End with: [WISDOM GEM: {wisdom}]",
        ])
        return "\n".join(parts)

story_engine = AdvancedStoryEngine()

# ----------------------
# Helpers
# ----------------------
_TITLE_RE = re.compile(r'\[TITLE:\s*(.*?)\s*\]', re.DOTALL)
_GEM_RE = re.compile(r'\[WISDOM GEM:\s*(.*?)\s*\]', re.DOTALL)

def _safe_extract_title_and_gem(text: str, theme: str):
    title_match = _TITLE_RE.search(text or "")
    gem_match = _GEM_RE.search(text or "")
    title = title_match.group(1).strip() if title_match and title_match.group(1).strip() else "A Brave Little Adventure"
    wisdom_gem = gem_match.group(1).strip() if gem_match and gem_match.group(1).strip() else WisdomGems.get_wisdom(theme)
    story_body = _TITLE_RE.sub("", text or "").strip()
    story_body = _GEM_RE.sub("", story_body).strip()
    return title, wisdom_gem, story_body


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


def _get_age_guidelines(age: int) -> dict:
    if age <= 5:
        return {
            "length_guideline": "100-150 words",
            "vocabulary_level": "very simple vocabulary (CVC + sight words)",
            "sentence_structure": "3-6 word sentences with repetition",
            "vocabulary_examples": "cat, dog, hop, sun, play, happy",
            "concepts": "tangible, concrete ideas only",
            "special_instructions": "Use rhyme, rhythm, and repeatable frames.",
        }
    if age <= 8:
        return {
            "length_guideline": "150-250 words",
            "vocabulary_level": "simple (sight words + basic phonics)",
            "sentence_structure": "short, clear, mostly present-tense sentences",
            "vocabulary_examples": "magic, brave, puzzle, curious",
            "concepts": "simple cause/effect with predictable plots",
            "special_instructions": "Include dialogue and phonics-friendly words.",
        }
    if age <= 12:
        return {
            "length_guideline": "250-400 words",
            "vocabulary_level": "grade-level vocabulary",
            "sentence_structure": "mix of short and complex sentences",
            "vocabulary_examples": "determined, shimmering, mysterious, courageous",
            "concepts": "character growth with layered plots and emotional arcs",
            "special_instructions": "Highlight problem-solving and empathy.",
        }
    if age <= 15:
        return {
            "length_guideline": "400-600 words",
            "vocabulary_level": "advanced / expressive vocabulary",
            "sentence_structure": "sophisticated and varied sentences",
            "vocabulary_examples": "contemplated, resilience, luminous, intricate",
            "concepts": "identity exploration, moral dilemmas, nuanced relationships",
            "special_instructions": "Use nuanced emotions and real-world parallels.",
        }
    return {
        "length_guideline": "600-800 words",
        "vocabulary_level": "mature / literary vocabulary",
        "sentence_structure": "complex, literary prose",
        "vocabulary_examples": "introspective, paradoxical, cathartic, transcendent",
        "concepts": "philosophical questions and mature themes",
        "special_instructions": "Employ literary devices, symbolism, and deep psychology.",
    }


def _build_age_instruction_block(age: int) -> str:
    guidelines = _get_age_guidelines(age)
    return (
        f"AGE-APPROPRIATE GUIDELINES FOR {age}-YEAR-OLD:\n"
        f"- LENGTH: {guidelines['length_guideline']} (strict requirement)\n"
        f"- VOCABULARY: {guidelines['vocabulary_level']}\n"
        f"- SENTENCE STYLE: {guidelines['sentence_structure']}\n"
        f"- WORD EXAMPLES: {guidelines['vocabulary_examples']}\n"
        f"- CONCEPTS: {guidelines['concepts']}\n"
        f"- SPECIAL NOTES: {guidelines['special_instructions']}"
    )


def _build_learning_to_read_prompt(character_name, theme, age, character_details, companion=None, extra_characters=None):
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
        "1. TOTAL LENGTH: 50-100 words only.\n"
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

def _as_list(v):
    """Accept list, JSON string, comma string, or None; return list[str]."""
    if isinstance(v, list):
        return [str(x) for x in v]
    if v in (None, "", []) :
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
