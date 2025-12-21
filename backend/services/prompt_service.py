try:
    from .emotion_service import EmotionService
    from ..config import config_by_name
except ImportError:
    from services.emotion_service import EmotionService
    from config import config_by_name

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
    ) -> str:
        """Build complete story generation prompt"""

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
