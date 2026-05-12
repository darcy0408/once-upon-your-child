try:
    from .emotion_service import EmotionService
    from ..config import config_by_name
    from ..data.superhero_matrix import (
        VILLAINS as _SH_VILLAINS,
        PROBLEMS as _SH_PROBLEMS,
        POWERS as _SH_POWERS,
        pick_pairing as _sh_pick_pairing,
    )
except ImportError:
    from services.emotion_service import EmotionService
    from config import config_by_name
    from data.superhero_matrix import (  # type: ignore[no-redef]
        VILLAINS as _SH_VILLAINS,
        PROBLEMS as _SH_PROBLEMS,
        POWERS as _SH_POWERS,
        pick_pairing as _sh_pick_pairing,
    )

class PromptService:
    @staticmethod
    def build_story_prompt(
        character: str,
        theme: str,
        age: int,
        companion: str = None,
        companion_characters: list = None,
        spark_tool: str = None,
        mood_physics: dict = None,
        current_feeling: dict = None,
        rhyme_time_mode: bool = False,
        learning_to_read_mode: bool = False,
        character_details: dict = None,
        character_evolution: dict = None,
        hero_costume_color: str | None = None,
        hero_cape_style: str | None = None,
        hero_emblem: str | None = None,
        hero_power: str | None = None,
        superhero_villain_id: str | None = None,
        superhero_problem_id: str | None = None,
    ) -> str:
        """Build complete story generation prompt.

        Superhero Mode (ages 3-5) branches out to ``_build_superhero_prompt`` when
        ``theme == 'superhero'``. The villain/problem IDs are normally chosen
        server-side via :func:`backend.data.superhero_matrix.pick_pairing` and
        passed in via ``superhero_villain_id`` / ``superhero_problem_id``.
        """

        # ----- Superhero Mode short-circuit (ages 3-5) ------------------
        if isinstance(theme, str) and theme.strip().lower() == "superhero":
            return PromptService._build_superhero_prompt(
                character=character,
                age=age,
                hero_costume_color=hero_costume_color,
                hero_cape_style=hero_cape_style,
                hero_emblem=hero_emblem,
                hero_power=hero_power,
                villain_id=superhero_villain_id,
                problem_id=superhero_problem_id,
            )

        sections = []

        # Base story setup
        sections.append(f"Create a story for {character} (age {age})")
        sections.append(f"Theme: {theme}")
        
        # Companion Setup (Enhanced)
        if companion_characters:
            sections.append(PromptService._build_companion_section(companion_characters))
        elif companion:
             sections.append(f"Companion: {companion}")

        # Spark Tool Instruction
        if spark_tool:
            sections.append(f"HERO TOOL: The hero has a special tool called '{spark_tool}'. It MUST be used exactly once, either at the midpoint or the climax, to help solve a specific problem.")

        # Mood Physics (World Rules)
        if mood_physics:
             sections.append(f"""
             WORLD PHYSICS RULE (The world bends to the mood '{mood_physics.get('mood_name')}'):
             - RULE: {mood_physics.get('world_rule')}
             - SENSORY CHANGE: {mood_physics.get('sensory_change')}
             - NOTE: This is a literal rule of the magic world for this story.
             """)

        # Feelings integration
        if current_feeling:
            feelings_section = EmotionService.build_feelings_prompt(
                character, current_feeling
            )
            sections.append(feelings_section)

        # Climax Instruction (Three-Key Lock)
        # We only add this for standard or rhyme modes, not ultra-short learning-to-read
        if not learning_to_read_mode:
            sections.append(f"""
            CLIMAX REQUIREMENT (The Three-Key Lock):
            The story's climax MUST require three things to resolve:
            1. The Hero's Special Ability or Strength (from character details).
            2. The Companion's Unique Power (if present). Note: The companion ENABLES the hero, they do not solve it themselves.
            3. A feature of the setting or the 'Spark Tool' (if one was selected).
            
            All three elements must combine in a cinematic moment to save the day.
            """)

        # Age-appropriate content
        age_guidelines = PromptService._get_age_guidelines(age)
        sections.append(age_guidelines)

        # Mode-specific instructions
        if learning_to_read_mode:
            sections.append(PromptService._get_learning_to_read_instructions(character, theme, age, companion, character_details))
        elif rhyme_time_mode:
            sections.append(PromptService._get_rhyme_time_instructions(age))

        # Character details
        if character_details:
            details_section = PromptService._build_character_details(
                character_details
            )
            sections.append(details_section)

        # Character evolution
        if character_evolution:
            evolution_section = PromptService._build_character_evolution_context(
                character, character_evolution
            )
            sections.append(evolution_section)

        return "\n\n".join(sections)

    @staticmethod
    def _get_age_guidelines(age: int) -> str:
        """Return age-appropriate content guidelines"""
        if age <= 5:
            return """
            CRITICAL AGE-APPROPRIATE REQUIREMENTS (Ages 3-5):
            ⚠️ MAXIMUM LENGTH: 100-150 words TOTAL. DO NOT EXCEED 150 WORDS.
            - Count your words carefully and STOP at 150 words maximum
            - Vocabulary: ONLY very simple words (cat, dog, run, happy, sun, play)
            - Sentences: 3-6 words each (short and simple)
            - Concepts: Concrete, tangible only (things they can see/touch)
            - Use repetition for learning (repeat key phrases)
            """
        elif age <= 8:
            return """
            CRITICAL AGE-APPROPRIATE REQUIREMENTS (Ages 6-8):
            ⚠️ MAXIMUM LENGTH: 150-250 words TOTAL. DO NOT EXCEED 250 WORDS.
            - Count your words carefully and STOP at 250 words maximum
            - Vocabulary: Sight words + basic phonics (simple words young readers know)
            - Sentences: Short and clear (under 10 words per sentence)
            - Concepts: Simple cause and effect (what happens and why)
            """
        elif age <= 12:
            return """
            CRITICAL AGE-APPROPRIATE REQUIREMENTS (Ages 9-12):
            ⚠️ MAXIMUM LENGTH: 250-400 words TOTAL. DO NOT EXCEED 400 WORDS.
            - Count your words carefully and STOP at 400 words maximum
            - Vocabulary: Grade-level appropriate
            - Sentences: Varied length, some complex structures allowed
            - Concepts: Multiple plot layers, character growth, lessons learned
            """
        elif age <= 15:
            return """
            CRITICAL AGE-APPROPRIATE REQUIREMENTS (Ages 13-15):
            ⚠️ MAXIMUM LENGTH: 400-600 words TOTAL. DO NOT EXCEED 600 WORDS.
            - Count your words carefully and STOP at 600 words maximum
            - Vocabulary: Advanced but not overly academic
            - Sentences: Sophisticated structure and varied rhythm
            - Concepts: Complex themes, moral dilemmas, identity exploration
            """
        else:
            return """
            CRITICAL AGE-APPROPRIATE REQUIREMENTS (Ages 16+):
            ⚠️ MAXIMUM LENGTH: 600-800 words TOTAL. DO NOT EXCEED 800 WORDS.
            - Count your words carefully and STOP at 800 words maximum
            - Vocabulary: Adult vocabulary allowed
            - Sentences: Complex and literary style
            - Concepts: Mature themes, philosophical questions, nuanced emotions
            """

    @staticmethod
    def _get_learning_to_read_instructions(character_name: str, theme: str, age: int, companion: str | None, character_details: dict | None) -> str:
        companion_text = f"Include {companion} as a gentle helper." if companion else ""
        return f"""
You are creating a LEARNING TO READ rhyming story for a {age}-year-old named {character_name}.

STRICT REQUIREMENTS (NO EXCEPTIONS):
1. TOTAL LENGTH: 50-100 words (stop inside this range).
2. RHYME PATTERN: Simple AABB scheme (line 1 rhymes with 2, line 3 rhymes with 4, etc.).
3. LINE LENGTH: 4-6 short words per line (keep it punchy).
4. VOCABULARY: Only CVC words (cat, dog, hop, sun) and common sight words (the, and, can, see, like, play). No tricky spellings, blends, or silent letters.
5. STRUCTURE: Repetition helps reading. Use predictable frames like "Can {character_name} ___? Yes! {character_name} can ___!".
6. TONE: Encouraging, musical, and confidence-building.
7. FORMAT: Each sentence or phrase on its own line for easy finger-tracking.

THEME: {theme} {companion_text}

Create the rhyming learning-to-read story about {character_name} now:
"""

    @staticmethod
    def _get_rhyme_time_instructions(age: int = 7) -> str:
        """Instructions for rhyme time mode - age-appropriate rhyming"""
        return f"""
        RHYME TIME MODE (Age-Appropriate for {age} year old):
        - Story MUST follow the age-appropriate length requirements above
        - Use consistent rhyme scheme (AABB or ABAB)
        - Playful and musical tone with rhythm and flow
        - Vocabulary must match the child's age level
        - Keep it silly and fun while staying within word count limits
        """

    @staticmethod
    def _build_companion_section(companion_characters: list) -> str:
        """Build detailed companion section with powers/constraints"""
        lines = ["COMPANIONS:"]
        for comp in companion_characters:
            if isinstance(comp, dict) and 'signature_power' in comp:
                lines.append(f"- Name: {comp.get('name')}")
                lines.append(f"  Description: {comp.get('description')}")
                lines.append(f"  Signature Power: {comp.get('signature_power')}")
                lines.append(f"  Constraint: {comp.get('power_constraint')}")
                lines.append(f"  Sensory Tell: {comp.get('sensory_tell')}")
            elif isinstance(comp, dict):
                 lines.append(f"- {comp.get('name')}")
            else:
                 lines.append(f"- {comp}")
        return "\n".join(lines)

    @staticmethod
    def _build_character_details(character_details: dict) -> str:
        """Build character details section for prompt"""
        details = ["CHARACTER DETAILS:"]
        
        if 'special_ability' in character_details:
            details.append(f"SPECIAL ABILITY: {character_details['special_ability']}")
            
        if 'personality_sliders' in character_details:
             details.append(f"Personality: {character_details['personality_sliders']}")

        return "\n".join(details)

    @staticmethod
    def _build_character_evolution_context(character_name: str, character_evolution: dict) -> str:
        """Build character evolution context for prompt"""
        # This would be more complex, extracting development stage, therapeutic progress, etc.
        return ""

    # ------------------------------------------------------------------
    # Superhero Mode (ages 3-5) — 6-beat hero chain.
    #
    # The prompt is deliberately rigid: the model gets the exact 6 beats,
    # the hero's identity tag, the villain action phrase, and a 150-word
    # hard cap. Tone is calibrated against the two reference samples
    # documented in docs/SUPERHERO_MODE_SPEC.md (Mia/Super Hugs vs Cranky
    # Crab; Leo/Super Speed vs Sock Goblin).
    # ------------------------------------------------------------------
    @staticmethod
    def _build_superhero_prompt(
        character: str,
        age: int,
        hero_costume_color: str | None,
        hero_cape_style: str | None,
        hero_emblem: str | None,
        hero_power: str | None,
        villain_id: str | None,
        problem_id: str | None,
    ) -> str:
        """Build the 6-beat Superhero Mode prompt for Sprout-band readers.

        ``villain_id`` and ``problem_id`` should be pre-picked by the caller
        via :func:`backend.data.superhero_matrix.pick_pairing`. If either is
        missing or invalid, the function falls back to a sensible default
        derived from the hero's power so a malformed request still produces
        a coherent story rather than a 500.
        """
        # --- Resolve power (with safe fallback) ---
        power_id = (hero_power or "").strip().lower() or "super_smile"
        if power_id not in _SH_POWERS:
            power_id = "super_smile"
        power_spec = _SH_POWERS[power_id]
        power_name = power_spec["name"]
        power_verb = power_spec["verb"]

        # --- Resolve villain + problem (server-picked, fallback if missing) ---
        if not villain_id or villain_id not in _SH_VILLAINS \
                or not problem_id or problem_id not in _SH_PROBLEMS:
            villain_id, problem_id = _sh_pick_pairing(power_id)
        villain = _SH_VILLAINS[villain_id]
        problem = _SH_PROBLEMS[problem_id]

        # --- Costume description (each field optional; "none" cape allowed) ---
        color = (hero_costume_color or "bright").strip().lower() or "bright"
        cape = (hero_cape_style or "matching").strip().lower() or "matching"
        emblem = (hero_emblem or "star").strip().lower() or "star"

        if cape == "none":
            cape_phrase = "no cape"
        elif cape == "rainbow":
            cape_phrase = "rainbow cape"
        else:
            cape_phrase = f"{color} cape"

        identity_tag = f"{power_name} {character}"

        # --- The 6 beats in plain language (the model fills in the prose) ---
        beat1 = (
            f"{character} put on the {color} suit. Today, {character} "
            f"is {identity_tag}!"
        )
        beat2 = f"Oh no! {villain['name']} came to {villain['action']}."
        beat3 = f"{character} said, 'I can help!'"
        beat4 = (
            f"{character} used {power_verb} to {problem['verb']} "
            f"({problem['summary']})."
        )
        beat5 = f"{villain['name']} {villain['softens']}."
        beat6 = f"Everyone cheered. {character} saved the day!"

        # --- Prompt assembly ---
        # Use a tagged, structured format so the validator in story_tasks.py
        # can still strip the meta if it leaks. The model is told repeatedly:
        # 150 words MAX, sentences 3-7 words, no scary content.
        return f"""SUPERHERO MODE STORY (Ages 3-5 — Sprout band)

You are writing a short, picture-book-style superhero story for a {age}-year-old.

HERO IDENTITY (use the name and identity tag at least TWICE):
- Hero name: {character}
- Identity tag: "{identity_tag}"
- Costume: {color} suit with {cape_phrase} and a {emblem} emblem
- Signature power: {power_name} ({power_verb})

VILLAIN (silly, never frightening):
- Name: {villain['name']}
- What they do: {villain['action']}
- How they soften: {villain['softens']}

PROBLEM TO SOLVE:
- Goal: {problem['name']} — {problem['summary']}
- Hero's resolution verb: {problem['verb']}

STORY MUST FOLLOW THESE 6 BEATS IN ORDER:

1. HERO INTRO  — Open with: "{beat1}"
2. TROUBLE     — Then: "{beat2}"
3. HERO RESPONDS — Then: "{beat3}"
4. POWER USED  — Show {character} using {power_name} to {problem['verb']} the situation. Reference beat 4 idea: "{beat4}" (rewrite naturally; do NOT use the bracketed summary in the prose).
5. RESOLUTION  — End the conflict like this: "{beat5}"
6. CHEER       — Close with: "{beat6}"

HARD RULES — these are non-negotiable:
- MAXIMUM 130 words TOTAL. Count and STOP at 130.
- TARGET 100–130 words. Anything under 90 is too short.
- Sentences: 3–7 words each. Short and punchy.
- Vocabulary: ONLY very simple words a 3–5 year old knows.
- Use the hero's name AT LEAST TWICE and the identity tag "{identity_tag}" AT LEAST TWICE.
- Include ONE repeated sensory phrase (a sound, a color, or a texture) for early-reader memorability — repeat it once for rhythm.
- NO violence, NO weapons, NO scary descriptions, NO monsters chasing.
- The villain is SILLY, never frightening. They soften, say sorry, or join in — they are NEVER defeated by force.
- Resolution must come through kindness, cleverness, sharing, comforting, or inviting in. NEVER through force or punishment.

OUTPUT FORMAT:
Return the story as plain prose (no JSON, no markdown headers, no "PAGE X" labels, no beat numbers).
The story should read as one continuous picture-book story.

Begin now. Stop at 130 words.
"""

