"""
Interactive Adventure Story Prompt Builder
Generates comprehensive, age-calibrated prompts for interactive children's stories
following the Interactive Children's Adventure Story Weaver specification.
"""

import json
from typing import Any, Dict, List, Optional

from backend.services.story_service import transform_parent_context_to_story_guidance


class InteractiveAdventurePromptBuilder:
    """
    Builds structured prompts for the Interactive Adventure Story system.
    Implements age calibration, choice management, inventory tracking, and state persistence.
    """

    # Age calibration settings updated to match Story Weaver Coverage v2
    AGE_BANDS = {
        "3-4": {
            "sentence_length": "very simple (3-6 words), short sentences with repetition",
            "vocabulary": "simple words only, comforting rhythm (think Corduroy)",
            "vocabulary_avoid": "NO: parchment, depicts, constellations, nestled, velvet, motes, vibrant, bustling, encouraging, contagious, shimmer, unravel. YES: paper, shows, stars, sitting, soft cloth, dust, bright, busy, happy, sparkle, open",
            "word_count_ranges": {
                "short": (200, 300),
                "medium": (300, 450),
                "long": (450, 650),
            },
            "stakes": "gentle, with frequent reassurance",
            "suspense": "minimal but magical",
            "complexity": "very simple cause-and-effect",
        },
        "5-7": {
            "sentence_length": "simple but varied (5-10 words), storybook-style",
            "vocabulary": "simple vocabulary with occasional new words explained by context",
            "vocabulary_avoid": "NO: parchment, depicts, constellations, velvet, motes, vibrant, bustling, shimmering. YES: paper, shows, stars, soft, dust, bright, busy, sparkling",
            "word_count_ranges": {
                "short": (450, 650),
                "medium": (650, 900),
                "long": (900, 1200),
            },
            "stakes": "clear and friendly",
            "suspense": "light, with humor and wonder",
            "complexity": "clear cause/effect choices",
        },
        "8-10": {
            "sentence_length": "varied (6-15 words), richer detail",
            "vocabulary": "vivid and engaging, richer detail (think Magic Tree House)",
            "word_count_ranges": {
                "short": (900, 1200),
                "medium": (1200, 1800),
                "long": (1800, 2400),
            },
            "stakes": "engaging quest structure, clear cause-effect, stronger arcs",
            "suspense": "mystery, humor, clever twists",
            "complexity": "layered choices with clear strategy",
        },
        "11-13": {
            "sentence_length": "varied (8-18 words), dynamic pacing",
            "vocabulary": "nuanced emotions, deeper motivation, age-appropriate but complex",
            "word_count_ranges": {
                "short": (1300, 1700),
                "medium": (1800, 2600),
                "long": (2600, 3400),
            },
            "stakes": "nuanced emotions, deeper motivation, still clean",
            "suspense": "mystery, social complexity",
            "complexity": "multi-layered consequences and nuanced moral dilemmas",
        },
        "13-15": {
            "sentence_length": "varied (8-20 words), identity/friendship themes",
            "vocabulary": "respectful humor, sophisticated but accessible",
            "word_count_ranges": {
                "short": (1600, 2200),
                "medium": (2400, 3400),
                "long": (3400, 4500),
            },
            "stakes": "identity, friendship, respectful humor",
            "suspense": "emotional tension, complex relationships",
            "complexity": "layered moral choices",
        },
        "15-18": {
            "sentence_length": "sophisticated, introspection-focused",
            "vocabulary": "complex stakes, introspection, full range",
            "word_count_ranges": {
                "short": (2000, 2800),
                "medium": (3000, 4200),
                "long": (4200, 6000),
            },
            "stakes": "complex stakes, introspection, mature relationships (clean)",
            "suspense": "psychological tension, complex stakes",
            "complexity": "morally complex choices",
        },
        "adult": {
            "sentence_length": "mature, nuanced literary range",
            "vocabulary": "nuanced themes (stress, meaning, relationships), immersive and literary",
            "word_count_ranges": {
                "short": (2000, 3000),
                "medium": (3200, 5200),
                "long": (5200, 7800),
            },
            "stakes": "nuanced themes, stress, meaning, relationships",
            "suspense": "thematic depth, introspection",
            "complexity": "philosophical and relational complexity",
        },
    }

    # Choice count based on story length (default 2 for meaningful choices).
    # NOTE: This dict is retained for reference but is no longer used directly.
    # All runtime choice-count resolution goes through _get_choice_count().
    CHOICE_COUNTS = {"short": 2, "medium": 2, "long": 2}

    @staticmethod
    def _get_choice_count(age: int, length: str) -> int:
        """Return the appropriate number of choices for a story segment.

        Cognitive-load rationale:
          Ages 3-7   — 2 choices: simple binary keeps decision-making manageable.
          Ages 8-11  — 2-3 choices: scaled by length; more text = more complexity.
          Ages 12+   — 3-4 choices: teens benefit from richer branching and nuance.
        """
        if age <= 7:
            return 2
        if age <= 11:
            # Short stories stay at 2; medium and long step up to 3.
            return 2 if length == "short" else 3
        # Ages 12+: short and medium get 3; long gets 4.
        return 4 if length == "long" else 3

    # Estimated Path Depths (how many segments a user actually reads in one play)
    # These are used to divide the total word count into per-segment counts.
    PATH_DEPTHS = {
        "3-4": {"short": 4, "medium": 5, "long": 6},
        "5-7": {"short": 5, "medium": 6, "long": 7},
        "8-10": {"short": 6, "medium": 7, "long": 8},
        "11-13": {"short": 7, "medium": 8, "long": 9},
        "13-15": {"short": 8, "medium": 9, "long": 10},
        "15-18": {"short": 9, "medium": 10, "long": 11},
        "adult": {"short": 10, "medium": 12, "long": 14},
    }

    # Segment targets based on Story Weaver Coverage v2 Table (Nodes)
    SEGMENT_TARGETS = {
        "3-4": {"short": (7, 9), "medium": (9, 11), "long": (11, 13)},
        "5-7": {"short": (9, 12), "medium": (12, 15), "long": (15, 18)},
        "8-10": {"short": (12, 16), "medium": (16, 20), "long": (20, 24)},
        "11-13": {"short": (14, 18), "medium": (18, 22), "long": (22, 26)},
        "13-15": {"short": (16, 20), "medium": (20, 26), "long": (26, 32)},
        "15-18": {"short": (18, 24), "medium": (24, 30), "long": (30, 38)},
        "adult": {"short": (18, 26), "medium": (26, 34), "long": (34, 44)},
    }

    # Structured Life Challenges for therapeutic integration
    # Maps challenge name to (metaphor, coping_strategy, growth_outcome, virtue)
    # virtue = (name, how_to_show_it) — NEVER name the virtue in story prose.
    LIFE_CHALLENGES = {
        "Making New Friends": {
            "metaphor": "A bridge between two floating islands that needs careful building.",
            "coping_strategy": "Asking a kind question, noticing a shared interest, offering a small token of help.",
            "growth_outcome": "The hero feels the warmth of connection and realizes others feel nervous too.",
            "virtue": (
                "inclusion",
                "The protagonist notices someone alone and takes one small, concrete action to include them — the action costs them something (courage, comfort, time).",
            ),
        },
        "Starting School": {
            "metaphor": "Entering a vast library where every book is a new adventure waiting to be read.",
            "coping_strategy": 'Finding a "safe anchor" (a familiar object/thought), deep belly breaths, observing before jumping in.',
            "growth_outcome": "Uncertainty turns into curiosity; the hero finds their rhythm in the new routine.",
            "virtue": (
                "courage",
                "The protagonist tries the scary thing with the fear fully present — show the physical sensation and the decision to act through it anyway.",
            ),
        },
        "Sibling Rivalry": {
            "metaphor": "Two different stars trying to shine in the same patch of night sky.",
            "coping_strategy": 'Taking turns, finding a way to combine their different "lights", expressing needs with words instead of pushes.',
            "growth_outcome": 'Realizing that together they make the sky brighter; finding the "team" in the family.',
            "virtue": (
                "generosity",
                "The protagonist voluntarily gives something up and the story lingers on the warmth that follows — not the sacrifice.",
            ),
        },
        "Handling Big Feelings": {
            "metaphor": "A stormy weather system inside a magical crystal bottle.",
            "coping_strategy": 'Naming the "storm", watching it pass without being swept away, finding the "calm center".',
            "growth_outcome": "The hero learns that feelings are like weather—they change, and you can stay safe through them.",
            "virtue": (
                "self-awareness",
                "The protagonist names their feeling aloud or in thought before reacting — slowing the impulse loop by one breath.",
            ),
        },
        "Trying New Foods": {
            "metaphor": 'Exploring a planet with strange but wonderful textures and "flavor-fields".',
            "coping_strategy": 'The "One-Bite Discovery", describing the sensation objectively, pairing the new with the familiar.',
            "growth_outcome": 'Bravery in small tastes; discovering that the "unknown" can be delicious.',
            "virtue": (
                "adaptability",
                "The protagonist encounters something unfamiliar, resists briefly, then engages — and the story shows one specific payoff.",
            ),
        },
        "Sharing Toys": {
            "metaphor": "A magical fountain that only flows when the water is allowed to move between basins.",
            "coping_strategy": "Setting a timer, noticing the joy on the other person's face, finding a game that uses two toys together.",
            "growth_outcome": 'The discovery that "joy shared is joy doubled".',
            "virtue": (
                "generosity",
                "The protagonist gives something up voluntarily and the story lingers on the warmth that follows — not the sacrifice.",
            ),
        },
        "Being Brave at Night": {
            "metaphor": "The Night-Glow garden where flowers only bloom in the quiet dark.",
            "coping_strategy": 'Checking the "security perimeter", using a "bravery mantra", visualizing a protective light shield.',
            "growth_outcome": "The hero realizes they are the keeper of their own safety; shadows become just shapes.",
            "virtue": (
                "courage",
                "The protagonist tries the scary thing with the fear fully present — show the physical sensation and the decision to act through it anyway.",
            ),
        },
        "Patience & Waiting": {
            "metaphor": "Watching a slow-growing moon-flower that only opens when it's perfectly ready.",
            "coping_strategy": 'The "Waiting Game" (observing details), focusing on the "now" instead of the "next", deep slow breathing.',
            "growth_outcome": "Finding magic in the stillness; realizing that the best things are worth the time.",
            "virtue": (
                "patience",
                "The protagonist pauses at their moment of highest frustration, chooses the slower path, and the story shows the downstream payoff of that pause.",
            ),
        },
    }

    SAFETY_GUARDRAILS = """
SAFETY RULES:
- No sexual content, no graphic violence, no self-harm, no illegal wrongdoing.
- Handle sensitive emotions with care. Keep the tone warm, age-appropriate, and full of wonder.
- Do NOT invent characters or family members not provided.
- Must Include: A Moment of Wonder (age-appropriate), a coping moment in action (resilience/perspective), and a satisfying conclusion.
- SAFETY: Ensure no scary imagery or abandonment themes for children.
- Do NOT repeat or closely paraphrase the opening paragraph at the end of the story.
"""

    IMMERSION_RULES = """
⚠️ CRITICAL IMMERSION RULES — these override all other instructions:
1. The story must read as a seamless in-world narrative. Characters have ZERO awareness they are in a generated story or therapeutic exercise.
2. NEVER include AI-style preambles ("Here we go!", "Sure!", "Here is your story:") or sign-offs.
3. NEVER expose internal storytelling mechanics inside the prose. Characters must not speak or think using craft/therapy terminology (e.g. they cannot say they were being a "therapeutic specialist", refer to a "challenge arc", or announce an "earned ending").
4. NEVER end with an explicit moral recap or lesson announcement — growth must emerge through action and feeling, not stated conclusions.
5. CLEAN ENDING — the final segment's last sentence must be a sensory image, an action, or a feeling — NOT a lesson summary. Forbidden: "And so you learned...", "From that day on...", "And you knew that...", "It taught you that...", "The moral was...". End on the world, not the lesson.
6. Return ONLY the JSON object above — nothing before the opening brace, nothing after the closing brace.
"""

    TEEN_TONE_INSTRUCTION = """
- **TONE (Teen)**: Avoid 'babyish' or condescending language. Use sophisticated, nuanced vocabulary. 
- **THEMES**: Focus on identity, autonomy, moral complexity, and the internal journey. 
- **ENGAGEMENT**: Choices should reflect social or internal dilemmas, not just physical actions.
- **CO-AUTHORING**: Treat the reader as a creative partner. Respect their autonomy and provide deep, divergent plot branches.
"""

    MORAL_COMPLEXITY_INSTRUCTION = """
**MORAL COMPLEXITY GUIDE (Ages 11-13)**:
- Choices must NOT have an obvious right answer. Each path should have a genuine trade-off.
- Good example: Option A helps the hero's goal but disappoints a friend. Option B protects the friend but slows the mission.
- Avoid: One clearly brave choice + one clearly cowardly choice.
- Include: Social consequences, loyalty dilemmas, moments where being fair conflicts with being fast.
- The hero may feel conflicted after choosing — reflect this briefly in the narrative before the next choice.
- Minimum one line of internal monologue per scene showing the character weighing their decision.
"""

    CO_AUTHOR_INSTRUCTION = """
**CO-AUTHOR MODE (Ages 15+)**:
- Frame choices as narrative decisions: 'What does {name} decide?' not 'What do YOU do?'
- The reader is a co-author shaping the protagonist's journey, not the protagonist themselves.
- Choice text uses third-person: 'Have {name} confront the council' rather than 'Confront the council'.
- Internal monologue is encouraged; let the protagonist reflect on the weight of each option.
- Choices should reflect values, identity, and long-term consequences.
"""

    @classmethod
    def get_age_band(cls, age: int) -> str:
        """Determine age band from specific age based on new categories"""
        if age <= 4:
            return "3-4"
        elif age <= 7:
            return "5-7"
        elif age <= 10:
            return "8-10"
        elif age <= 13:
            return "11-13"
        elif age <= 15:
            return "13-15"
        elif age <= 18:
            return "15-18"
        else:
            return "adult"

    @classmethod
    def _calculate_per_segment_word_count(cls, age_band: str, length: str) -> tuple:
        """Calculate per-segment word count based on age band and total word count range."""
        age_config = cls.AGE_BANDS[age_band]
        total_range = age_config["word_count_ranges"].get(
            length, age_config["word_count_ranges"]["medium"]
        )

        # Use estimated path depth
        depth = cls.PATH_DEPTHS[age_band].get(length, 6)

        # Calculate and round to nearest 10
        min_w = max(40, (total_range[0] // depth // 10) * 10)
        max_w = max(80, (total_range[1] // depth // 10) * 10)

        return (min_w, max_w)

    @classmethod
    def build_opening_prompt(
        cls,
        child_name: str,
        age: int,
        length: str,
        theme: str,
        tone: str,
        character: Optional[Dict] = None,
        companions: Optional[List[Dict]] = None,
        interests: Optional[List[str]] = None,
        must_include: Optional[List[str]] = None,
        avoid: Optional[List[str]] = None,
        fears_or_sensitivities: Optional[List[str]] = None,
        spark_tool: Optional[str] = None,
        mood_physics: Optional[Dict] = None,
        conflict_hook: Optional[str] = None,
        sensory_palette: Optional[str] = None,
        world_bible: str = "",
        life_challenge: Optional[str] = None,
        personality_sliders: Optional[Dict[str, int]] = None,
        chronicle_context: Optional[Dict] = None,
        big_feelings_context: Optional[Dict] = None,
    ) -> str:
        """
        Build the opening segment prompt for a new interactive adventure.
        """
        age_band = cls.get_age_band(age)
        age_config = cls.AGE_BANDS[age_band]

        # Calculate PER-SEGMENT word count
        word_count = cls._calculate_per_segment_word_count(age_band, length)

        path_depth = cls.PATH_DEPTHS[age_band].get(length, 10)

        # Build companion context
        companion_context = (
            cls._build_companion_context(companions)
            if companions
            else "solo on this adventure"
        )

        # Character details
        char_data = character or {}
        special_ability = char_data.get(
            "special_ability", char_data.get("specialAbility", "None specified")
        )
        gender = char_data.get("gender", "not specified")
        pronouns = char_data.get("pronouns", "")
        gender_text = (
            f" (Gender: {gender}{', Pronouns: ' + pronouns if pronouns else ''})"
        )

        # Mood Physics
        mood_rules = ""
        if mood_physics:
            mood_rules = f"\nWORLD PHYSICS (Mood: {mood_physics.get('mood', 'Magic')}):\n- RULE: {mood_physics.get('worldRule', '')}\n- SENSORY: {mood_physics.get('sensoryChange', '')}"

        # Personality Profile (from sliders)
        personality_profile = ""
        if personality_sliders:
            traits = []
            for trait, value in personality_sliders.items():
                if value > 70:
                    traits.append(f"Very {trait}")
                elif value < 30:
                    traits.append(f"Not {trait}")
                else:
                    traits.append(trait)
            personality_profile = f"- **PERSONALITY PROFILE**: {', '.join(traits)}"

        # Life Challenge (Therapeutic Integration) + virtue anchoring
        challenge_instruction = ""
        virtue_instruction = ""
        if life_challenge:
            challenge_data = cls.LIFE_CHALLENGES.get(life_challenge)
            if challenge_data:
                challenge_instruction = f"""
- **LIFE CHALLENGE**: {life_challenge}
- **METAPHOR**: {challenge_data['metaphor']}
- **COPING STRATEGY TO TEACH**: {challenge_data['coping_strategy']}
- **GROWTH OUTCOME**: {challenge_data['growth_outcome']}
- **INSTRUCTION**: Use the metaphor provided to frame the adventure. Ensure the hero uses the coping strategy at a key decision point to achieve the growth outcome. Keep it magical and age-appropriate."""
                virtue_name, virtue_show = challenge_data.get("virtue", ("", ""))
                if virtue_name:
                    age_caveat = (
                        " Keep it simple and concrete — no internal monologue, just visible action."
                        if age <= 7
                        else (
                            " For this age, lean into internal monologue and the cost of the choice."
                            if age >= 14
                            else ""
                        )
                    )
                    virtue_instruction = (
                        f"\n**INVISIBLE VIRTUE — {virtue_name.upper()}** (NEVER name this virtue in the story):\n"
                        f"{virtue_show}{age_caveat}\n"
                        "Model the virtue through one specific scene or choice. "
                        "The child lives it vicariously — no character announces the lesson.\n"
                    )
            else:
                challenge_instruction = f"- **LIFE CHALLENGE**: The story must subtly reflect the challenge of '{life_challenge}'. The hero should learn to cope with this through the adventure, but keep it metaphorical and magical, not clinical."

        feelings_instruction = cls._build_big_feelings_instruction(
            big_feelings_context,
            age=age,
            child_name=child_name,
            is_opening=True,
        )

        # Age-specific impossible element suggestions - FOR INSPIRATION ONLY, DO NOT USE VERBATIM
        impossible_elements = {
            "3-4": "riding a friendly cloud, talking to a flower, or jumping over a moonbeam.",
            "5-7": "flying on dandelion seeds, tasting rainbow colors, or walking through a mirror.",
            "8-10": "surfing on lightning bolts, shifting gravity, or talking to the stars.",
            "11-13": "shaping a dreamscape, commanding the tides, or freezing time.",
            "13-15": "bridging two worlds, healing a rift in space, or weaving light into a bridge.",
            "15-18": "navigating a paradox, harmonizing a chaotic dimension, or transcending physical limits.",
            "adult": "visualizing a complex emotion as a physical force, reconciling memories from different times, or finding order in chaos.",
        }
        age_impossible = impossible_elements.get(
            age_band, "Something magical and physics-defying."
        )

        # Age-appropriate default sensory palettes
        default_sensories = {
            "3-4": "Bright colors, soft sounds, sweet smells.",
            "5-7": "Vivid colors, magical sounds, familiar scents.",
            "8-10": "Rich textures, mysterious echoes, crisp aromas.",
            "11-13": "Dynamic lighting, layered sounds, complex atmosphere.",
            "13-15": "Moody shadows, ambient noise, cinematic details.",
            "15-18": "Gritty textures, visceral sounds, evocative atmosphere.",
            "adult": "Intricate sensory metaphors, thematic undertones, immersive environment.",
        }
        final_sensory = sensory_palette or default_sensories.get(
            age_band, "Bright colors, soft sounds."
        )

        # Pre-calculate choice templates — count is age- and length-aware.
        desired_choice_count = cls._get_choice_count(age, length)
        choice_templates = cls._build_choice_templates(
            age=age,
            big_feelings_context=big_feelings_context,
            is_opening=True,
            count=desired_choice_count,
        )
        choice_count = len(choice_templates)
        choices_json = ",\n".join(choice_templates)

        # Dynamic Terminology for Teens
        tool_label = "HERO TOOL"
        tool_instruction = "(MUST be used later in the adventure)"
        if age >= 12:
            tool_label = "KEY ARTIFACT"
            tool_instruction = "(MUST be integral to the resolution)"

        tool_value = f"'{spark_tool}' {tool_instruction}" if spark_tool else "None"
        tool_line = f"- **{tool_label}**: {tool_value}"

        # Persona selection
        persona = "Master Storyteller & World-Builder. You write Pick-A-Path adventures so vivid and immersive that readers forget they're reading — they *are* the hero, living every heartbeat of the story."
        if age >= 15:
            persona = f"Collaborative Creative Partner. You are co-authoring a sophisticated narrative with {child_name}. Respect their autonomy and creative agency. Treat them as a peer in the storytelling process, providing rich, complex branches for them to explore."

        prompt = f"""
**PERSONA**: {persona}

You are generating the OPENING SEGMENT of a Pick-A-Path adventure for {child_name}{gender_text} (age {age}).
- **THEME**: {theme} | **TONE**: {tone}
- **CONFLICT**: {conflict_hook or 'A magical mystery needs solving.'}
- **SENSORY PALETTE**: {final_sensory}
{('- **WORLD BIBLE** (CRITICAL — follow this for setting consistency): ' + world_bible) if world_bible else ''}
{cls._build_chronicle_block(chronicle_context) if chronicle_context else ''}
{challenge_instruction}
{virtue_instruction}
{feelings_instruction}
- **HERO**: {child_name} (Special Ability: {special_ability}).
{personality_profile}
{tool_line}
- **IMPOSSIBLE ELEMENTS**: (Inspiration Only - DO NOT use these exact phrases): {age_impossible}
- **COMPANIONS**: {companion_context} (Must affect the story).
{mood_rules}

**WRITING** ({word_count[0]}-{word_count[1]} words per segment): {age_config['sentence_length']}, {age_config['vocabulary']}, {age_config['stakes']}
{f"**VOCABULARY FOR AGE {age}**: {age_config.get('vocabulary_avoid', '')}" if age <= 7 else ""}

**OUTPUT TYPE**: REQUIRED: output_type='CHOICE'. This is a Pick-A-Path adventure - every segment MUST present exactly {choice_count} distinct, meaningful choices.

**CRITICAL RULES**:
- **AGE {age}**: Keep vocabulary and complexity appropriate for this age.
- **POV**: {"Third-person for choices. Hero is " + child_name + ". Frame: What does " + child_name + " decide?" if age >= 15 else "ALWAYS use second-person (you). The hero is " + child_name + "."}
- **WORD COUNT REQUIREMENT**: This INDIVIDUAL SEGMENT MUST be between {word_count[0]} and {word_count[1]} words.
- **Companion Contract**: REQUIRED: 3+ distinct beats (actions/dialogue), 1 help, 1 bond. Companion MUST appear by name.
- **Choices**: {choice_count} concrete options. NO passive options. Start with vivid verbs.
- **Safety**: No violence/harm. Keep the tone warm, age-appropriate, and full of wonder.
{cls.SAFETY_GUARDRAILS}
{cls.TEEN_TONE_INSTRUCTION if age >= 15 else ""}
{cls.MORAL_COMPLEXITY_INSTRUCTION if 11 <= age <= 13 else ""}
{cls.CO_AUTHOR_INSTRUCTION.replace("{name}", child_name) if age >= 15 else ""}

**Opening Segment 1/{path_depth}**:
1. Begin with sensory details - natural storybook opening.
2. Introduce gentle challenge or mystery.
3. Establish magical surprise/motif.
4. End with {choice_count} distinct, exciting choices.

**JSON Output**:
```json
{{
  "title": "Adventure Title",
  "output_type": "CHOICE",
  "segment_number": 1,
  "stage_label": "Wake Up!",
  "content": "Story content ({word_count[0]}-{word_count[1]} words)",
  "word_count": {word_count[0] + 20},
  "image_description": "Scene description",
  "companion_beats": [{{"type": "dialogue|action|bond", "text": "..."}}],
  "inventory": [],
  "inventory_references": [],
  "story_state": {{
    "location": "Where",
    "goal": "Goal",
    "key_clues": [],
    "companion_status": "Status"
  }},
  "choices": [
{choices_json}
  ],
  "is_ending": false
}}
```
{cls.IMMERSION_RULES}"""
        return prompt

    @classmethod
    def build_continuation_prompt(
        cls,
        story_context: Dict[str, Any],
        selected_choice: str,
        current_segment_number: int,
        inventory: Optional[List[str]] = None,
        story_state: Optional[Dict[str, Any]] = None,
        story_so_far: str = "",
    ) -> str:
        """Build the continuation prompt for the next interactive segment."""
        age = int(story_context.get("age") or 7)
        length = story_context.get("length", "medium")
        theme = story_context.get("theme", "Adventure")
        tone = story_context.get("tone", "whimsical")
        character = story_context.get("character") or {}
        companions = story_context.get("companions") or []

        age_band = cls.get_age_band(age)
        age_config = cls.AGE_BANDS[age_band]

        # Calculate PER-SEGMENT word count
        word_count = cls._calculate_per_segment_word_count(age_band, length)

        path_depth = cls.PATH_DEPTHS[age_band].get(length, 10)

        child_name = character.get("name", "Hero")
        gender = character.get("gender", "not specified")
        pronouns = character.get("pronouns", "")
        gender_text = (
            f" (Gender: {gender}{', Pronouns: ' + pronouns if pronouns else ''})"
        )

        companion_context = (
            cls._build_companion_context(companions)
            if companions
            else "solo on this adventure"
        )
        inventory = inventory or []
        story_state = story_state or {}

        # Age-appropriate default sensory palettes
        default_sensories = {
            "3-4": "Bright colors, soft sounds, sweet smells.",
            "5-7": "Vivid colors, magical sounds, familiar scents.",
            "8-10": "Rich textures, mysterious echoes, crisp aromas.",
            "11-13": "Dynamic lighting, layered sounds, complex atmosphere.",
            "13-15": "Moody shadows, ambient noise, cinematic details.",
            "15-18": "Gritty textures, visceral sounds, evocative atmosphere.",
            "adult": "Intricate sensory metaphors, thematic undertones, immersive environment.",
        }
        final_sensory = story_context.get("sensory_palette") or default_sensories.get(
            age_band, "Bright colors, soft sounds."
        )

        # Carry virtue instruction forward from story_context if life_challenge was set
        continuation_virtue = ""
        life_challenge_ctx = story_context.get("life_challenge") or story_context.get(
            "lifeChallenge", ""
        )
        if life_challenge_ctx:
            challenge_data = cls.LIFE_CHALLENGES.get(life_challenge_ctx, {})
            virtue_name, virtue_show = challenge_data.get("virtue", ("", ""))
            if virtue_name:
                age_caveat = (
                    " Keep it simple and concrete — visible action only."
                    if age <= 7
                    else (
                        " Use internal monologue and the cost of the choice."
                        if age >= 14
                        else ""
                    )
                )
                continuation_virtue = (
                    f"\n**INVISIBLE VIRTUE — {virtue_name.upper()}** (NEVER name this — show it):\n"
                    f"{virtue_show}{age_caveat}\n"
                    "Model the virtue through action. The reader feels it, no character states it.\n"
                )

        continuation_feelings = cls._build_big_feelings_instruction(
            story_context.get("big_feelings_context"),
            age=age,
            child_name=child_name,
            is_opening=False,
        )

        desired_choice_count = cls._get_choice_count(age, length)
        choice_templates = cls._build_choice_templates(
            age=age,
            big_feelings_context=story_context.get("big_feelings_context"),
            is_opening=False,
            count=desired_choice_count,
        )
        choice_count = len(choice_templates)
        choices_json = ",\n".join(choice_templates)

        next_segment_number = current_segment_number + 1

        # Decide if this should be an ending
        is_near_end = next_segment_number >= (path_depth - 1)
        ending_instruction = ""
        if is_near_end:
            ending_instruction = f"\n**ENDING LOGIC**: You are at segment {next_segment_number}/{path_depth}. If appropriate for the plot, you MAY conclude the story in this segment by setting `is_ending: true`. If not, ensure the story concludes by segment {path_depth}."

        empathy_moment = (
            f"- **EMPATHY MOMENT**: In this segment, introduce a secondary character who is experiencing a challenge"
            f" related to '{life_challenge_ctx}'. Frame it as: '[Friend's name] looks sad and says: [their problem in"
            f" simple, relatable words].' Then give {child_name} choices about how to help this friend. This lets the"
            f" reader practice compassion safely \u2014 they help a friend, not themselves."
            if life_challenge_ctx and not is_near_end and next_segment_number == 3
            else ""
        )

        # Persona selection
        persona = "Master Storyteller & World-Builder. You write Pick-A-Path adventures so vivid and immersive that readers forget they're reading — they *are* the hero, living every heartbeat of the story."
        if age >= 15:
            persona = f"Collaborative Creative Partner. You are co-authoring a sophisticated narrative with {child_name}. Respect their autonomy and creative agency. Treat them as a peer in the storytelling process, providing rich, complex branches for them to explore."

        prompt = f"""
**PERSONA**: {persona}

You are continuing a Pick-A-Path adventure for {child_name}{gender_text} (age {age}).

**STORY CONTEXT**:
- **TITLE**: {story_context.get('title', 'Adventure Title')}
- **THEME**: {theme} | **TONE**: {tone}
- **HERO**: {child_name}
- **COMPANIONS**: {companion_context} (Must affect the story).
- **CURRENT SEGMENT**: {current_segment_number}/{path_depth}
- **SELECTED CHOICE**: {selected_choice}
- **INVENTORY**: {", ".join(inventory) if inventory else "None"}
- **STATE**: location={story_state.get('location', 'Unknown')}, goal={story_state.get('goal', 'Unknown')}
- **SENSORY PALETTE**: {final_sensory}
{('- **WORLD BIBLE** (CRITICAL — follow this for setting consistency): ' + story_context.get('world_bible', '')) if story_context.get('world_bible') else ''}
{continuation_virtue}
{continuation_feelings}

**STORY SO FAR (summary)**:
{story_so_far or "No summary available."}

**WRITING** ({word_count[0]}-{word_count[1]} words per segment): {age_config['sentence_length']}, {age_config['vocabulary']}, {age_config['stakes']}
{f"**VOCABULARY FOR AGE {age}**: {age_config.get('vocabulary_avoid', '')}" if age <= 7 else ""}

**CRITICAL RULES**:
- **AGE {age}**: Keep vocabulary and complexity appropriate for this age.
- **POV**: {"Third-person for choices. Hero is " + child_name + ". Frame: What does " + child_name + " decide?" if age >= 15 else "ALWAYS use second-person (you). The hero is " + child_name + "."}
- **WORD COUNT REQUIREMENT**: This INDIVIDUAL SEGMENT MUST be between {word_count[0]} and {word_count[1]} words.
- **Companion Contract**: REQUIRED: 3+ distinct beats (actions/dialogue), 1 help, 1 bond. Companion MUST appear by name.
- **Choices**: {choice_count} concrete options. NO passive options. Start with vivid verbs.{ending_instruction}
{empathy_moment}
- **Safety**: No violence/harm. Keep the tone warm, age-appropriate, and full of wonder.
{cls.SAFETY_GUARDRAILS}
{cls.TEEN_TONE_INSTRUCTION if age >= 15 else ""}
{cls.MORAL_COMPLEXITY_INSTRUCTION if 11 <= age <= 13 else ""}
{cls.CO_AUTHOR_INSTRUCTION.replace('{name}', child_name) if age >= 15 else ""}

**JSON Output**:
```json
{{
  "title": "{story_context.get('title', 'Adventure Title')}",
  "output_type": "CHOICE",
  "segment_number": {next_segment_number},
  "stage_label": "Next Step",
  "content": "Story content ({word_count[0]}-{word_count[1]} words)",
  "word_count": {word_count[0] + 20},
  "image_description": "Scene description",
  "companion_beats": [{{"type": "dialogue|action|bond", "text": "..."}}],
  "inventory": {json.dumps(inventory)},
  "inventory_references": [],
  "story_state": {{
    "location": "{story_state.get('location', 'Unknown')}",
    "goal": "{story_state.get('goal', 'Unknown')}",
    "key_clues": {json.dumps(story_state.get('key_clues', []))},
    "companion_status": "{story_state.get('companion_status', '')}"
  }},
  "choices": [
{choices_json}
  ],
  "is_ending": false
}}
```
{cls.IMMERSION_RULES}"""
        return prompt

    @staticmethod
    def _build_big_feelings_instruction(
        big_feelings_context: Optional[Dict[str, Any]],
        *,
        age: int,
        child_name: str,
        is_opening: bool,
    ) -> str:
        if not isinstance(big_feelings_context, dict) or not big_feelings_context:
            return ""

        current_feeling = big_feelings_context.get("current_feeling") or {}
        emotion_name = (
            current_feeling.get("emotion_name")
            or current_feeling.get("core_emotion")
            or current_feeling.get("secondary_emotion")
            or current_feeling.get("tertiary_emotion")
        )
        trigger = big_feelings_context.get("trigger") or current_feeling.get("trigger")
        body_signal = big_feelings_context.get("body_signal") or current_feeling.get(
            "physical_signs"
        )
        coping_tool = big_feelings_context.get("coping_tool")
        repair_goal = big_feelings_context.get("repair_goal")
        transformed_guidance = transform_parent_context_to_story_guidance(
            big_feelings_context
        )
        story_guidance = transformed_guidance.get("story_guidance")

        if not emotion_name:
            emotion_name = transformed_guidance.get("feeling")
        if not emotion_name:
            return ""

        feeling_label = str(emotion_name).strip().lower()
        pov_subject = "You" if age < 15 else child_name
        body_subject = "Your" if age < 15 else f"{child_name}'s"
        opening_parts = [f"{pov_subject} felt so {feeling_label}."]
        if trigger:
            opening_parts.append("Something happened that made the feeling big.")
        if body_signal:
            opening_parts.append(
                f"{body_subject} body clue was {str(body_signal).strip().lower()}."
            )
        opening_line = '"' + " ".join(opening_parts) + '"'

        stage_rule = (
            "Start the very first lines by naming the feeling and body clue."
            if is_opening
            else "Keep reflecting the same feeling thread so the branches stay emotionally coherent."
        )
        feeling_specific_rule = ""
        if feeling_label in {"mad", "angry"} and not is_opening:
            feeling_specific_rule = (
                "- For mad continuations, if the big reaction affects someone else or the room, "
                "the very next beat should move toward repair: check on them, say sorry, use gentle words, "
                "or help fix what happened."
            )

        preschool_rules = ""
        if age <= 5:
            preschool_rules = """
- PRESCHOOL PICK-A-PATH RULES:
  - Only present two clear choices.
  - One choice may be messy, but it must lead to a gentle repair chance instead of shame.
  - Use simple choices based on action, like breathe, ask for help, use words, or stomp and stop.
  - Keep the problem familiar and concrete.
  - In the first paragraph, use 2-3 short sentences in this order: feeling, what happened, body clue.
  - For mad stories, the first branch should contrast helper-now versus big reaction then stop; the next branch should offer repair.
  - For sad or scared stories, keep the helper choices close to comfort, connection, and one tiny brave step.
"""
        ages_6_to_8_rules = ""
        if 6 <= age <= 8:
            ages_6_to_8_rules = """
- AGES 6-8 BIG FEELINGS RULES:
  - Use richer feeling words than preschool, but keep them child-friendly and never clinical.
  - Keep the tone supportive and warm, with simple cause-and-effect the child can track.
  - Opening choices should include 2-3 active options: a fast reaction, a steadying move, and a connection/help option when it fits.
  - Show the emotional consequence of each choice quickly and clearly.
  - Calming strategies should feel natural in the scene, not scripted like a lesson.
  - If repair is needed, keep it brief, brave, and believable.
  - Let the feeling change shape or size; do not make it disappear on command.
"""
        ages_9_to_12_rules = ""
        if 9 <= age <= 12:
            ages_9_to_12_rules = """
- AGES 9-12 BIG FEELINGS RULES:
  - Use precise feeling words such as humiliated, overwhelmed, resentful, or conflicted when they fit the scene.
  - Keep the tone emotionally intelligent and socially real, never therapeutic-sounding.
  - The emotion is not the problem; the pressure, misunderstanding, impulse, or fallout is the problem.
  - Calming should read as regaining choice, not shutting the feeling down.
  - Pick-a-path choices should change the social outcome in believable ways.
  - Repair should feel brave and credible, not neat or instant.
  - Adults can steady the scene, but the child still makes the key choice.
"""
        ages_13_to_15_rules = ""
        if 13 <= age <= 15:
            ages_13_to_15_rules = """
- AGES 13-15 BIG FEELINGS RULES:
  - Keep the same grounded Big Feelings principles, but raise the social complexity to friend groups, identity pressure, and digital life.
  - Use higher emotional nuance and room for mixed motives without moralizing.
  - The emotion is not the problem; the real problem is the pressure, misunderstanding, impulse, or fallout around it.
  - Calming should restore choice and clarity, not perform emotional shutdown.
  - Repair may require vulnerability and is never framed as easy, tidy, or guaranteed to work.
  - Choices should feel credible to a teen social world: public response, private truth, strategic distance, or partial repair.
  - Avoid lecturing language from peers or adults; support can steady the scene without taking away agency.
"""

        lines = [
            "**BIG FEELINGS INTERACTIVE CONTEXT**:",
            f"- Feeling: {emotion_name}",
            f"- Opening style example: {opening_line}",
            stage_rule,
        ]
        if trigger:
            lines.append(f"- Trigger: {trigger}")
            lines.append(
                "- Weave the trigger into the scene naturally instead of copying it as a stiff setup line."
            )
        if body_signal:
            lines.append(f"- Body clue to mention early: {body_signal}")
        if coping_tool:
            lines.append(f"- Helper/tool to thread through choices: {coping_tool}")
        if repair_goal:
            lines.append(
                f"- If the hero causes a bump, include this repair beat: {repair_goal}"
            )
        if story_guidance:
            lines.append(f"- Parent-guided hidden scaffolding: {story_guidance}")
        lines.append(
            "- Show that feelings are okay and choices shape what happens next."
        )
        if feeling_specific_rule:
            lines.append(feeling_specific_rule)
        if preschool_rules:
            lines.append(preschool_rules)
        if ages_6_to_8_rules:
            lines.append(ages_6_to_8_rules)
        if ages_9_to_12_rules:
            lines.append(ages_9_to_12_rules)
        if ages_13_to_15_rules:
            lines.append(ages_13_to_15_rules)
        return "\n" + "\n".join(lines) + "\n"

    @staticmethod
    def _build_choice_templates(
        *,
        age: int,
        big_feelings_context: Optional[Dict[str, Any]],
        is_opening: bool,
        count: int = 2,
    ) -> List[str]:
        if not isinstance(big_feelings_context, dict) or not big_feelings_context:
            # Build a generic template list sized to `count`.
            generic = [
                '    {"id": "choice_1", "text": "First choice option (Action-oriented)"}',
                '    {"id": "choice_2", "text": "Second choice option (Action-oriented)"}',
                '    {"id": "choice_3", "text": "Third choice option (Action-oriented)"}',
                '    {"id": "choice_4", "text": "Fourth choice option (Action-oriented)"}',
            ]
            return generic[:count]

        current_feeling = big_feelings_context.get("current_feeling") or {}
        emotion_name = (
            current_feeling.get("emotion_name")
            or current_feeling.get("core_emotion")
            or current_feeling.get("secondary_emotion")
            or current_feeling.get("tertiary_emotion")
            or ""
        )
        coping_tool = str(big_feelings_context.get("coping_tool") or "").strip()
        feeling = str(emotion_name).strip().lower()

        def choice(text: str, idx: int) -> str:
            return f'    {{"id": "choice_{idx}", "text": "{text}"}}'

        if age <= 5:
            if feeling in {"mad", "angry"}:
                if is_opening:
                    options = [
                        coping_tool or "Take a dragon breath",
                        "Roar, then stop",
                    ]
                else:
                    options = [
                        "Use gentle words",
                        "Help fix it",
                    ]
            elif feeling in {"sad"}:
                if is_opening:
                    options = [
                        coping_tool or "Ask for a hug",
                        "Tell someone you feel sad",
                    ]
                else:
                    options = [
                        "Take a quiet breath",
                        "Try again with a friend",
                    ]
            elif feeling in {"scared", "worried", "anxious"}:
                if is_opening:
                    options = [
                        coping_tool or "Hold hands",
                        "Take a slow breath",
                    ]
                else:
                    options = [
                        "Ask for help",
                        "Take one tiny step",
                    ]
            elif feeling in {"frustrated"}:
                options = [
                    coping_tool or "Ask for help",
                    "Try again slowly",
                ]
            else:
                options = [
                    coping_tool or "Take a breath",
                    "Ask for help",
                ]
            return [choice(text, idx + 1) for idx, text in enumerate(options[:count])]

        if 6 <= age <= 8:
            if feeling in {
                "mad",
                "angry",
                "annoyed",
                "irritated",
                "furious",
                "hurt-mad",
                "left-out mad",
            }:
                if is_opening:
                    options = [
                        "Stomp ahead and grab your spot back",
                        coping_tool or "Step aside and take three dragon breaths",
                        "Say what happened in a steady voice",
                    ]
                else:
                    options = [
                        "Use clear words about what felt unfair",
                        coping_tool or "Loosen your fists and slow your breath",
                        "Check on the other kid and try a quick repair",
                    ]
            elif feeling in {
                "worried",
                "nervous",
                "uneasy",
                "shaky",
                "jumpy",
                "scared",
                "unsure",
                "what-if-y",
            }:
                if is_opening:
                    options = [
                        "Blurt that this feels too hard",
                        coping_tool or "Look for three safe things and breathe slowly",
                        "Ask what the first step is",
                    ]
                else:
                    options = [
                        "Try one small step now",
                        coping_tool or "Hold still long enough for one calm breath",
                        "Tell someone what feels confusing",
                    ]
            elif feeling in {
                "sad",
                "lonely",
                "disappointed",
                "left out",
                "gloomy",
                "hurt",
                "heavy",
                "teary",
            }:
                if is_opening:
                    options = [
                        "Hide away with the heavy feeling",
                        coping_tool or "Take a quiet breath and notice who feels safe",
                        "Tell someone what hurt",
                    ]
                else:
                    options = [
                        "Try the next small part of the adventure",
                        coping_tool or "Let the feeling settle while you breathe",
                        "Reconnect with someone who can help",
                    ]
            elif feeling in {
                "frustrated",
                "stuck",
                "bothered",
                "mixed up",
                "overwhelmed",
                "impatient",
                "ready-to-pop",
                "trying-so-hard",
            }:
                if is_opening:
                    options = [
                        "Groan and shove the problem away",
                        coping_tool or "Shake out the stuck sparks and reset",
                        "Say what is not working yet",
                    ]
                else:
                    options = [
                        "Try one smaller step",
                        coping_tool or "Take a restart minute",
                        "Ask for one clue or a different plan",
                    ]
            elif feeling in {
                "embarrassed",
                "awkward",
                "silly-in-a-bad-way",
                "exposed",
                "red-faced",
                "wish-i-could-hide",
            }:
                if is_opening:
                    options = [
                        "Hide or snap before anyone notices more",
                        coping_tool or "Take one breath and steady your face",
                        "Tell the truth about the mistake",
                    ]
                else:
                    options = [
                        "Try again with calmer words",
                        coping_tool or "Let your cheeks cool while you breathe",
                        "Ask for a do-over and keep going",
                    ]
            elif feeling in {
                "excited",
                "bouncy",
                "hyper",
                "proud",
                "can’t-wait",
                "buzzy",
                "can't-wait",
            }:
                if is_opening:
                    options = [
                        "Rush in so fast the plan gets messy",
                        coping_tool or "Bounce once, then slow down enough to think",
                        "Tell someone your big idea first",
                    ]
                else:
                    options = [
                        "Use the energy on the next smart step",
                        coping_tool or "Slow your body so your brain can catch up",
                        "Work with someone so the fun keeps going",
                    ]
            else:
                options = [
                    "React fast before the feeling gets bigger",
                    coping_tool or "Pause long enough to steady yourself",
                    "Tell someone what is going on",
                ]
            return [choice(text, idx + 1) for idx, text in enumerate(options[:count])]

        if 9 <= age <= 12:
            if feeling in {
                "mad",
                "angry",
                "annoyed",
                "irritated",
                "furious",
                "resentful",
                "wronged",
                "defensive",
                "heated",
            }:
                if is_opening:
                    options = [
                        "Call it out in front of everyone",
                        coping_tool
                        or "Step back long enough to get your next move on purpose",
                        "Pull one person aside and say what felt unfair",
                    ]
                else:
                    options = [
                        "Name the pressure without pretending you are fine",
                        coping_tool
                        or "Buy yourself a beat so you can choose, not explode",
                        "Try a brave repair without demanding instant forgiveness",
                    ]
            elif feeling in {
                "worried",
                "nervous",
                "uneasy",
                "tense",
                "overwhelmed",
                "on edge",
                "apprehensive",
                "panicked",
                "exposed",
            }:
                if is_opening:
                    options = [
                        "Pretend it does not matter and shut down",
                        coping_tool
                        or "Take a pause that helps you think clearly again",
                        "Ask one steady person what is actually going on",
                    ]
                else:
                    options = [
                        "Take one clear next step before your thoughts spiral further",
                        coping_tool or "Regroup until you can choose with intention",
                        "Tell the truth about what feels too big right now",
                    ]
            elif feeling in {
                "sad",
                "lonely",
                "disappointed",
                "left out",
                "hurt",
                "heavy",
                "ashamed",
                "humiliated",
                "discouraged",
                "heartsick",
                "isolated",
                "replaced",
            }:
                if is_opening:
                    options = [
                        "Disappear before anyone can read your face",
                        coping_tool
                        or "Give yourself a minute to steady without pretending it does not hurt",
                        "Tell one person what happened instead of carrying it alone",
                    ]
                else:
                    options = [
                        "Say the true thing, even if your voice shakes",
                        coping_tool
                        or "Stay with the feeling long enough to pick your next move",
                        "Try a repair or reconnection that leaves room for distance",
                    ]
            elif feeling in {
                "frustrated",
                "stuck",
                "bothered",
                "mixed up",
                "conflicted",
                "torn",
                "scrambled",
                "overstimulated",
                "uncertain",
                "suspicious",
            }:
                if is_opening:
                    options = [
                        "Push harder and make the conflict bigger",
                        coping_tool
                        or "Reset long enough to sort out what is actually bothering you",
                        "Say which part feels off before the pressure keeps building",
                    ]
                else:
                    options = [
                        "Pick one smaller move you can stand behind",
                        coping_tool
                        or "Slow the scene down until you can choose clearly",
                        "Ask for a different plan without pretending nothing happened",
                    ]
            else:
                options = [
                    "React in the moment and deal with the fallout later",
                    coping_tool or "Pause until you have a real choice again",
                    "Tell one honest version of what is going on",
                ]
            return [choice(text, idx + 1) for idx, text in enumerate(options[:count])]

        if 13 <= age <= 15:
            if feeling in {
                "mad",
                "angry",
                "annoyed",
                "irritated",
                "furious",
                "resentful",
                "wronged",
                "defensive",
                "heated",
            }:
                if is_opening:
                    options = [
                        "Fire back where everyone can see it",
                        coping_tool
                        or "Take space until you can decide what response you actually want",
                        "Message or pull aside the person who matters most and say what crossed the line",
                    ]
                else:
                    options = [
                        "State the impact without pretending the feeling is gone",
                        coping_tool
                        or "Regain enough control to choose the next move on purpose",
                        "Attempt a direct repair or boundary, knowing it may stay awkward",
                    ]
            elif feeling in {
                "worried",
                "nervous",
                "uneasy",
                "tense",
                "overwhelmed",
                "on edge",
                "apprehensive",
                "panicked",
                "exposed",
            }:
                if is_opening:
                    options = [
                        "Ghost the situation before it can get worse",
                        coping_tool
                        or "Step out of the noise long enough to think clearly again",
                        "Ask one trusted person what is true instead of guessing from the group chat",
                    ]
                else:
                    options = [
                        "Do the next honest thing before the pressure mutates further",
                        coping_tool
                        or "Take back enough choice to decide what matters now",
                        "Say out loud what part of this is actually too much",
                    ]
            elif feeling in {
                "sad",
                "lonely",
                "disappointed",
                "left out",
                "hurt",
                "heavy",
                "ashamed",
                "humiliated",
                "discouraged",
                "heartsick",
                "isolated",
                "replaced",
            }:
                if is_opening:
                    options = [
                        "Act like you do not care and go cold",
                        coping_tool
                        or "Get yourself steady without forcing the feeling underground",
                        "Tell one person the real version before the story spreads",
                    ]
                else:
                    options = [
                        "Say the vulnerable truth, even if it does not fix everything",
                        coping_tool
                        or "Wait until you can respond without erasing yourself",
                        "Choose partial repair, distance, or a new ally instead of fake harmony",
                    ]
            elif feeling in {
                "frustrated",
                "stuck",
                "bothered",
                "mixed up",
                "conflicted",
                "torn",
                "scrambled",
                "overstimulated",
                "uncertain",
                "suspicious",
            }:
                if is_opening:
                    options = [
                        "Double down and let the misunderstanding harden",
                        coping_tool
                        or "Pause until you can tell the difference between pressure and fact",
                        "Ask a direct question before the story writes itself",
                    ]
                else:
                    options = [
                        "Make one choice that matches your actual values",
                        coping_tool
                        or "Stay with the discomfort long enough to pick a clean next move",
                        "Try a blunt but respectful truth instead of another performance",
                    ]
            else:
                options = [
                    "React fast and protect your image first",
                    coping_tool or "Take enough space to choose instead of performing",
                    "Tell the truth to one person who can handle it",
                ]
            return [choice(text, idx + 1) for idx, text in enumerate(options[:count])]

        if feeling in {"mad", "angry"}:
            options = [
                coping_tool or "Take a breath first",
                "Use calm words",
            ]
        elif feeling in {"sad"}:
            options = [
                coping_tool or "Talk to someone safe",
                "Take a quiet pause",
            ]
        elif feeling in {"scared", "worried", "anxious"}:
            options = [
                coping_tool or "Ask for support",
                "Take one brave step",
            ]
        else:
            options = [
                coping_tool or "Pause and think",
                "Try a different plan",
            ]
        return [choice(text, idx + 1) for idx, text in enumerate(options[:count])]

    @staticmethod
    def _build_chronicle_block(ctx: Dict) -> str:
        """Format the chronicle context block for injection into the opening prompt."""
        if not ctx:
            return ""
        chapter_count = ctx.get("chapter_count", 0)
        character_state = ctx.get("character_state", "No state recorded yet.")
        world_facts = ctx.get("world_facts") or []
        arc_summaries = ctx.get("arc_summaries") or []
        recent_memories = ctx.get("recent_memories") or []
        unresolved_threads = ctx.get("unresolved_threads") or []
        last_chapter_ending = ctx.get("last_chapter_ending", "")

        facts_str = (
            "\n".join(f"  - {f}" for f in world_facts) if world_facts else "  None yet."
        )
        arcs_str = (
            "\n".join(f"  {a}" for a in arc_summaries)
            if arc_summaries
            else "  None yet."
        )

        memories_lines = []
        for i, mem in enumerate(recent_memories[-3:]):
            ch = mem.get("chapter_number", "?")
            bullets = mem.get("summary_bullets") or []
            bullets_str = " ".join(f"[{b}]" for b in bullets[:3])
            memories_lines.append(f"  Chapter {ch}: {bullets_str}")
        memories_str = (
            "\n".join(memories_lines) if memories_lines else "  No recent chapters yet."
        )

        threads_str = (
            "\n".join(f"  - {t}" for t in unresolved_threads)
            if unresolved_threads
            else "  None open."
        )

        ending_line = (
            f'\nLAST SESSION ENDED WITH: "{last_chapter_ending}"\nTHE NEXT CHAPTER MUST continue from exactly where this left off.'
            if last_chapter_ending
            else ""
        )

        return f"""
**LIVING CHRONICLE (Chapters 1-{chapter_count} completed — treat this as absolute canon)**:
CHARACTER STATE: {character_state}
WORLD FACTS (established canon — never contradict these):
{facts_str}
STORY ARCS SO FAR:
{arcs_str}
RECENT CHAPTERS:
{memories_str}
OPEN STORY THREADS (must eventually resolve):
{threads_str}{ending_line}
"""

    @staticmethod
    def _build_companion_context(companions: Optional[List[Dict]]) -> str:
        """Build companion context string from companion list."""
        if not companions:
            return "solo on this adventure"
        companion_descriptions = []
        for comp in companions[:2]:
            if "species" in comp:
                companion_descriptions.append(
                    f"{comp.get('name', 'companion')} the {comp.get('species', 'pet')} [ANIMAL]"
                )
            else:
                companion_descriptions.append(
                    f"{comp.get('name', 'friend')} [SPEAKING]"
                )
        return "joined by " + " and ".join(companion_descriptions)
