from backend.services.emotion_service import EmotionService
from backend.config import config_by_name # Assuming config is needed for GEMINI_MODEL

class PromptService:
    @staticmethod
    def build_story_prompt(
        character: str,
        theme: str,
        age: int,
        companion: str = None,
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

        if companion:
            sections.append(f"Companion: {companion}")

        # Feelings integration
        if current_feeling:
            feelings_section = EmotionService.build_feelings_prompt(
                character, current_feeling
            )
            sections.append(feelings_section)

        # Age-appropriate content
        age_guidelines = PromptService._get_age_guidelines(age)
        sections.append(age_guidelines)

        # Mode-specific instructions
        if learning_to_read_mode:
            sections.append(PromptService._get_learning_to_read_instructions(character, theme, age, companion, character_details))
        elif rhyme_time_mode:
            sections.append(PromptService._get_rhyme_time_instructions())

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
            AGE-APPROPRIATE GUIDELINES (Ages 3-5):
            - Length: 100-150 words maximum
            - Vocabulary: Very simple (cat, dog, run, happy)
            - Sentences: 3-6 words each
            - Concepts: Concrete, tangible only
            - Use repetition for learning
            """
        elif age <= 8:
            return """
            AGE-APPROPRIATE GUIDELINES (Ages 6-8):
            - Length: 150-250 words
            - Vocabulary: Sight words + basic phonics
            - Sentences: Short and clear
            - Concepts: Simple cause and effect
            """
        elif age <= 12:
            return """
            AGE-APPROPRIATE GUIDELINES (Ages 9-12):
            - Length: 250-400 words
            - Vocabulary: Grade-level
            - Sentences: Varied, some complex
            - Concepts: Multiple plot layers, character growth
            """
        elif age <= 15:
            return """
            AGE-APPROPRIATE GUIDELINES (Ages 13-15):
            - Length: 400-600 words
            - Vocabulary: Advanced
            - Sentences: Sophisticated
            - Concepts: Complex themes, moral dilemmas, identity
            """
        else:
            return """
            AGE-APPROPRIATE GUIDELINES (Ages 16+):
            - Length: 600-800 words
            - Vocabulary: Adult
            - Sentences: Complex and literary
            - Concepts: Mature themes, philosophical questions
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
    def _get_rhyme_time_instructions() -> str:
        """Instructions for rhyme time mode"""
        return """
        RHYME TIME MODE:
        - Story should have a consistent rhyme scheme (AABB or ABAB)
        - Playful and musical tone
        - Focus on rhythm and flow
        """

    @staticmethod
    def _build_character_details(character_details: dict) -> str:
        """Build character details section for prompt"""
        # This would be more complex, extracting fears, strengths, etc.
        return ""

    @staticmethod
    def _build_character_evolution_context(character_name: str, character_evolution: dict) -> str:
        """Build character evolution context for prompt"""
        # This would be more complex, extracting development stage, therapeutic progress, etc.
        return ""
