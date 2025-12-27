"""
Interactive Adventure Story Prompt Builder
Generates comprehensive, age-calibrated prompts for interactive children's stories
following the Interactive Children's Adventure Story Weaver specification.
"""
import json
from typing import Dict, List, Optional, Any


class InteractiveAdventurePromptBuilder:
    """
    Builds structured prompts for the Interactive Adventure Story system.
    Implements age calibration, choice management, inventory tracking, and state persistence.
    """

    # Age calibration settings
    AGE_BANDS = {
        '3-5': {
            'sentence_length': 'very short (3-6 words)',
            'vocabulary': 'concrete words only, CVC words preferred',
            'word_count': (250, 350),  # Increased for better immersion
            'stakes': 'gentle, with frequent reassurance',
            'suspense': 'minimal',
            'complexity': 'simple cause-and-effect'
        },
        '6-8': {
            'sentence_length': 'short to medium (5-10 words)',
            'vocabulary': 'simple but vivid, basic phonics',
            'word_count': (350, 500),  # Increased: 2-4 min reading time
            'stakes': 'clear and friendly',
            'suspense': 'light, with humor',
            'complexity': 'clear cause/effect choices'
        },
        '9-12': {
            'sentence_length': 'medium (8-15 words)',
            'vocabulary': 'grade-level appropriate, richer descriptive words',
            'word_count': (450, 650),  # Increased for deeper immersion
            'stakes': 'engaging quest structure',
            'suspense': 'moderate mystery and puzzles',
            'complexity': 'layered choices with strategic thinking'
        },
        '13-16': {
            'sentence_length': 'varied (10-20 words)',
            'vocabulary': 'complex themes (still safe), nuanced language',
            'word_count': (500, 750),  # Increased for richer narrative
            'stakes': 'deeper emotional resonance',
            'suspense': 'strategic challenges',
            'complexity': 'multi-layered consequences'
        }
    }

    # Choice count based on story length (default 2 for meaningful choices)
    CHOICE_COUNTS = {
        'short': 2,
        'medium': 2,  # Changed from 3 to 2 for quality over quantity
        'long': 2     # Changed from 4 to 2 for meaningful branching
    }

    # Segment targets based on story length
    SEGMENT_TARGETS = {
        'short': (3, 4),    # Fewer, longer segments
        'medium': (5, 7),   # Adjusted for 350-650 word segments
        'long': (8, 12)     # More depth, not more choices
    }

    # Choice cadence rule: minimum words before allowing next choice
    MIN_WORDS_BETWEEN_CHOICES = 450

    @classmethod
    def get_age_band(cls, age: int) -> str:
        """Determine age band from specific age"""
        if age <= 5:
            return '3-5'
        elif age <= 8:
            return '6-8'
        elif age <= 12:
            return '9-12'
        else:
            return '13-16'

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
        fears_or_sensitivities: Optional[List[str]] = None
    ) -> str:
        """
        Build the opening segment prompt for a new interactive adventure.

        Args:
            child_name: Name of the child hero
            age: Child's age for content calibration
            length: short, medium, or long
            theme: Story theme (Adventure, Magic, Dragons, etc.)
            tone: whimsical, mystery, sci-fi, fantasy, cozy-adventure
            character: Character model dict with avatar, traits, fears, strengths
            companions: List of companion dicts (pets/characters)
            interests: Topics/elements child is interested in
            must_include: Elements that MUST appear in the story
            avoid: Elements to avoid
            fears_or_sensitivities: Things to avoid or handle carefully

        Returns:
            Complete prompt string for Gemini
        """
        age_band = cls.get_age_band(age)
        age_config = cls.AGE_BANDS[age_band]
        choice_count = cls.CHOICE_COUNTS.get(length, 3)
        segment_range = cls.SEGMENT_TARGETS.get(length, (4, 6))

        # Build character context
        character_context = cls._build_character_context(character) if character else f"a brave {age}-year-old named {child_name}"

        # Build companion context
        companion_context = cls._build_companion_context(companions) if companions else "solo on this adventure"

        # Pre-calculate choice templates based on count
        choice_templates = [
            '    {"id": "choice_1", "text": "First choice option"}',
            '    {"id": "choice_2", "text": "Second choice option"}'
        ]
        if choice_count >= 3:
            choice_templates.append('    {"id": "choice_3", "text": "Third choice option"}')
        if choice_count >= 4:
            choice_templates.append('    {"id": "choice_4", "text": "Fourth choice option"}')
        
        choices_json = ",\n".join(choice_templates)

        # Build optimized prompt (reduced 50% from ~7000 chars to ~3500 chars)
        prompt = f"""Generate interactive adventure for {child_name} (age {age}).

**Story**: {theme} | {tone} | {segment_range[0]}-{segment_range[1]} segments | {choice_count} choices
**Companion**: {companion_context}
{cls._build_content_guidelines(interests, must_include, avoid, fears_or_sensitivities)}

**Writing** ({age_config['word_count'][0]}-{age_config['word_count'][1]} words): {age_config['sentence_length']}, {age_config['vocabulary']}, {age_config['stakes']}

**Rules**:
- **POV**: Second-person ("you"). Use "{child_name}" max 2x. Include 2+ senses.
- **Companion** (if present): 3+ appearances, 1 help, 1 bond. Never replaces child's choice.
- **Inventory**: Show new items clearly. Ref within 1 segment. Max 5 items.
- **Choices**: {choice_count} concrete options. NO "ask what to do"/"wait"/passive. Each changes outcome.
- **Safety**: No violence/harm/abuse/abandonment. Safe, whimsical only.

**Opening Segment 1/{segment_range[1]}**:
1. Sensory hook (first 60 words)
2. Introduce challenge
3. Show companion ability (if present)
4. Establish location & goal
5. End with {choice_count} distinct choices

**JSON Output**:
```json
{{
  "title": "Adventure Title",
  "output_type": "CHOICE",
  "segment_number": 1,
  "content": "Story in second-person POV ({age_config['word_count'][0]}-{age_config['word_count'][1]} words)",
  "word_count": 450,
  "image_description": "Scene description",
  "companion_beats": [{{"type": "dialogue|action|bond", "text": "..."}}],
  "inventory": [],
  "inventory_references": [],
  "story_state": {{
    "location": "Where",
    "goal": "What trying to achieve",
    "key_clues": [],
    "companion_status": "How companion is",
    "time_pressure": null
  }},
  "choices": [
{choices_json}
  ],
  "is_ending": false
}}
```

Generate opening segment as JSON."""



        return prompt

    @classmethod
    def build_continuation_prompt(
        cls,
        story_context: Dict[str, Any],
        selected_choice: str,
        current_segment_number: int,
        inventory: List[str],
        story_state: Dict[str, Any],
        story_so_far: str
    ) -> str:
        """
        Build continuation prompt for next segment based on user's choice.

        Args:
            story_context: Dict with theme, tone, length, age, character, companions
            selected_choice: The choice text the user selected
            current_segment_number: Current segment number
            inventory: Current inventory items
            story_state: Current story state dict
            story_so_far: Summary of story segments so far

        Returns:
            Complete prompt string for Gemini
        """
        age = story_context.get('age', 8)
        length = story_context.get('length', 'medium')
        age_band = cls.get_age_band(age)
        age_config = cls.AGE_BANDS[age_band]
        choice_count = cls.CHOICE_COUNTS.get(length, 3)
        segment_range = cls.SEGMENT_TARGETS.get(length, (4, 6))

        next_segment_number = current_segment_number + 1
        is_approaching_end = next_segment_number >= segment_range[1] - 1
        should_conclude = next_segment_number >= segment_range[1]

        # Determine if this should be a CONTINUE or CHOICE segment
        # For opening segments (1-2), typically end with CONTINUE to build immersion
        # For decision points, use CHOICE
        words_since_last_choice = 0  # This would be tracked in reality

        # Build continuation guidance
        continuation_guidance = ""
        output_type_guidance = ""

        # Choice Cadence Rule logic
        if should_conclude:
            output_type_guidance = f"\n**OUTPUT TYPE DECISION**: This is the FINAL segment. Set output_type='CONTINUE' (no choices), is_ending=true, and deliver the satisfying conclusion."
            continuation_guidance = f"\n**FINAL SEGMENT**: This is the concluding segment {next_segment_number}. Deliver the 'Impossible Moment' climax and warm resolution."
        elif is_approaching_end:
            output_type_guidance = f"\n**OUTPUT TYPE DECISION**: As you approach the climax, use output_type='CHOICE' for major decision points."
            continuation_guidance = f"\n**APPROACHING CLIMAX**: This is segment {next_segment_number} of {segment_range[1]}. Begin escalating toward the 'Impossible Moment'."
        else:
            output_type_guidance = f"\n**OUTPUT TYPE DECISION**: Use output_type='CHOICE'. Provide exactly {choice_count} distinct, meaningful choices to drive the story forward. Ensure the user has agency."
            # Removed guidance to prefer CONTINUE for early segments to ensure CYOA feel

        # Pre-calculate choice templates based on count
        choice_templates = [
            '    {"id": "choice_1", "text": "First choice"}'
        ]
        if not should_conclude:
            choice_templates.append('    {"id": "choice_2", "text": "Second choice"}')
            if choice_count >= 3:
                choice_templates.append('    {"id": "choice_3", "text": "Third choice"}')
            if choice_count >= 4:
                choice_templates.append('    {"id": "choice_4", "text": "Fourth choice"}')
        else:
            # If concluding, no choices
            choice_templates = []
        
        choices_json = ",\n".join(choice_templates)

        prompt = f"""Continue adventure segment {next_segment_number}/{segment_range[1]}.

**Title**: {story_context.get('title', 'Untitled')} | **Theme**: {story_context.get('theme', 'Adventure')} | **Age**: {age}

**Story So Far**:
{story_so_far}

**Hero chose**: "{selected_choice}"

**Inventory**: {json.dumps(inventory) if inventory else "[]"}
**State**: {json.dumps(story_state)}

{continuation_guidance}
{output_type_guidance}

**Writing** ({age_config['word_count'][0]}-{age_config['word_count'][1]} words): {age_config['sentence_length']}. Second-person POV. Use name max 2x. Include 2+ senses.
**Companion** (if present): 3+ beats, 1 help, 1 bond.
**Inventory** (if items): Reference items. Show new ones clearly.
**Choices**: {choice_count} concrete options. NO passive choices. Each must change outcome. If output_type=CONTINUE, choices=[].

**JSON Output**:
```json
{{
  "output_type": "CHOICE or CONTINUE",
  "segment_number": {next_segment_number},
  "content": "Story ({age_config['word_count'][0]}-{age_config['word_count'][1]} words)",
  "word_count": 450,
  "image_description": "Scene",
  "companion_beats": [{{"type": "dialogue|action|bond", "text": "..."}}],
  "inventory": [],
  "inventory_references": [],
  "story_state": {{
    "location": "Where",
    "goal": "Goal",
    "key_clues": [],
    "companion_status": "Status",
    "time_pressure": null
  }},
  "choices": [
{choices_json}
  ],
  "is_ending": false
}}
```

**REMINDER**:
- If output_type='CONTINUE': choices array should be EMPTY []
- If output_type='CHOICE': choices array must have exactly {choice_count} meaningful options
- If is_ending=true: choices array should be EMPTY [] and output_type='CONTINUE'

Generate the next segment as valid JSON."""



        return prompt

    @staticmethod
    def _build_character_context(character: Dict) -> str:
        """Build character context string from character dict"""
        parts = []

        name = character.get('name', 'the hero')
        age = character.get('age')
        gender = character.get('gender', 'they')

        parts.append(f"{name}")
        if age:
            parts.append(f"age {age}")

        # Personality
        if character.get('personality_traits'):
            traits = character['personality_traits']
            if isinstance(traits, list) and traits:
                parts.append(f"personality: {', '.join(traits[:3])}")

        # Strengths
        if character.get('strengths'):
            strengths = character['strengths']
            if isinstance(strengths, list) and strengths:
                parts.append(f"strengths: {', '.join(strengths[:2])}")

        # Fears (to address in story)
        if character.get('fears'):
            fears = character['fears']
            if isinstance(fears, list) and fears:
                parts.append(f"working on: {fears[0]}")

        # Comfort item
        if character.get('comfort_item'):
            parts.append(f"comfort item: {character['comfort_item']}")

        return ", ".join(parts)

    @staticmethod
    def _build_companion_context(companions: List[Dict]) -> str:
        """Build companion context string from companions list"""
        if not companions:
            return "solo on this adventure"

        companion_descriptions = []
        for comp in companions[:2]:  # Max 2 companions for complexity
            if 'species' in comp:  # Pet companion
                desc = f"{comp.get('name', 'companion')} the {comp.get('species', 'pet')}"
                if comp.get('personality'):
                    desc += f" ({comp['personality']})"
                companion_descriptions.append(desc)
            else:  # Character companion
                desc = f"{comp.get('name', 'friend')}"
                if comp.get('signaturePower'):
                    desc += f" with ability to {comp['signaturePower']}"
                companion_descriptions.append(desc)

        return "joined by " + " and ".join(companion_descriptions)

    @staticmethod
    def _build_content_guidelines(
        interests: Optional[List[str]],
        must_include: Optional[List[str]],
        avoid: Optional[List[str]],
        fears_or_sensitivities: Optional[List[str]]
    ) -> str:
        """Build content guidelines section"""
        guidelines = []

        if interests:
            guidelines.append(f"**Interests to incorporate**: {', '.join(interests)}")

        if must_include:
            guidelines.append(f"**MUST include (plot-relevant)**: {', '.join(must_include)}")

        if avoid or fears_or_sensitivities:
            avoid_list = (avoid or []) + (fears_or_sensitivities or [])
            guidelines.append(f"**AVOID**: {', '.join(set(avoid_list))}")

        if not guidelines:
            guidelines.append("**Creative freedom**: Use theme and tone as guides")

        return "\n".join(guidelines)
