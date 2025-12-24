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
            'word_count': (50, 80),
            'stakes': 'gentle, with frequent reassurance',
            'suspense': 'minimal',
            'complexity': 'simple cause-and-effect'
        },
        '6-8': {
            'sentence_length': 'short to medium (5-10 words)',
            'vocabulary': 'simple but vivid, basic phonics',
            'word_count': (100, 150),
            'stakes': 'clear and friendly',
            'suspense': 'light, with humor',
            'complexity': 'clear cause/effect choices'
        },
        '9-12': {
            'sentence_length': 'medium (8-15 words)',
            'vocabulary': 'grade-level appropriate, richer descriptive words',
            'word_count': (150, 220),
            'stakes': 'engaging quest structure',
            'suspense': 'moderate mystery and puzzles',
            'complexity': 'layered choices with strategic thinking'
        },
        '13-16': {
            'sentence_length': 'varied (10-20 words)',
            'vocabulary': 'complex themes (still safe), nuanced language',
            'word_count': (200, 280),
            'stakes': 'deeper emotional resonance',
            'suspense': 'strategic challenges',
            'complexity': 'multi-layered consequences'
        }
    }

    # Choice count based on story length
    CHOICE_COUNTS = {
        'short': 2,
        'medium': 3,
        'long': 4
    }

    # Segment targets based on story length
    SEGMENT_TARGETS = {
        'short': (2, 3),
        'medium': (4, 6),
        'long': (7, 10)
    }

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

        # Build the comprehensive prompt
        prompt = f"""# Interactive Children's Adventure Story Weaver

## Context & Background
You are generating interactive, personalized adventure stories for a children's story app. The stories must feel vivid, magical, and empowering while staying psychologically safe and age-appropriate. The child is always the hero, and companions exist to unlock "impossible" moments, not to steal the spotlight. Each story unfolds in short segments where the reader chooses what happens next, and those choices create meaningful consequences and a persistent inventory.

## Your Role
- Interactive Adventure Architect: Create branching story segments with clear, consequential choices
- Age-Calibrated Language Engine: Adjust vocabulary and sentence length to match the child's age
- Sensory Scene Builder: Write cinematic scenes using multiple senses
- Agency-First Storyteller: Ensure the child solves main problems through choices, courage, or cleverness
- Continuity Keeper: Track inventory, promises, clues, and companion abilities with zero contradictions

## Current Story Configuration

### Child & Character
- **Hero**: {child_name}, age {age}
- **Character Details**: {character_context}
- **Companions**: {companion_context}

### Story Settings
- **Theme**: {theme}
- **Tone**: {tone}
- **Length**: {length} ({segment_range[0]}-{segment_range[1]} total segments)
- **Choices per segment**: {choice_count}

### Age Calibration (Age Band: {age_band})
- **Sentence Length**: {age_config['sentence_length']}
- **Vocabulary**: {age_config['vocabulary']}
- **Word Count**: {age_config['word_count'][0]}-{age_config['word_count'][1]} words
- **Stakes**: {age_config['stakes']}
- **Suspense Level**: {age_config['suspense']}
- **Complexity**: {age_config['complexity']}

### Content Guidelines
{cls._build_content_guidelines(interests, must_include, avoid, fears_or_sensitivities)}

## Safety Protocols
- No realistic violence, self-harm, abuse, sexual content, hate, or permanent loss
- Avoid abandonment themes; separations must be temporary, safe, and reassuring
- No medical, legal, or "real-world unsafe instruction" content
- Keep stakes "epic-feeling but safe," using whimsy, puzzles, and wonder instead of harm

## Output Instructions

**This is segment 1 of {segment_range[0]}-{segment_range[1]}** - Create an opening that:
1. Opens with a sensory "Hook of Wonder" within the first 60 words
2. Introduces a safe, exciting challenge by the end of the segment
3. Shows the companion's unique ability (if present) in a minor way
4. Establishes the initial location and goal
5. Ends with {choice_count} distinct choices that lead to different consequences

### Required JSON Output Format:
```json
{{
  "title": "The Adventure Title (only include in first segment)",
  "segment_number": 1,
  "content": "The story prose ({age_config['word_count'][0]}-{age_config['word_count'][1]} words)",
  "image_description": "Visual scene description for illustration generation",
  "inventory": [],
  "story_state": {{
    "location": "Current location",
    "goal": "What the hero is trying to achieve",
    "key_clues": [],
    "companion_status": "How companion is doing",
    "time_pressure": null
  }},
  "choices": [
    {{"id": "choice_1", "text": "First choice option"}},
    {{"id": "choice_2", "text": "Second choice option"}}{"," + chr(10) + ' ' * 4 + '{"id": "choice_3", "text": "Third choice option"}' if choice_count >= 3 else ""}{"," + chr(10) + ' ' * 4 + '{"id": "choice_4", "text": "Fourth choice option"}' if choice_count >= 4 else ""}
  ],
  "is_ending": false
}}
```

## Critical Requirements

### Meaningful Branching
Each choice must change at least TWO of:
- Location
- Obstacle type
- New item acquired
- Clue discovered
- Ally relationship
- Next scene tone

### Sensory Writing
- Include at least 2 senses per segment
- Use concrete, vivid details
- Avoid passive voice and clichés

### Agency Check
- The hero (not companion or narrator) drives the solution
- Choices have real consequences
- Avoid "cosmetic" variations

### Inventory System
- Items must be story-relevant
- Track what's gained and lost
- Items can unlock future solutions

Now generate the opening segment as valid JSON."""

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

        # Build continuation guidance
        continuation_guidance = ""
        if is_approaching_end and not should_conclude:
            continuation_guidance = f"\n**APPROACHING CLIMAX**: This is segment {next_segment_number} of {segment_range[1]}. Begin escalating toward the 'Impossible Moment' - a physics-defying, wonder-filled feat that requires the hero's courage, the companion's unique power, and a creative use of inventory or setting."
        elif should_conclude:
            continuation_guidance = f"\n**FINAL SEGMENT**: This is the concluding segment {next_segment_number}. Deliver the 'Impossible Moment' climax and warm resolution. Set is_ending to true and provide NO choices."

        prompt = f"""# Continue Interactive Adventure

## Story Context

**Title**: {story_context.get('title', 'Untitled Adventure')}
**Current Segment**: {next_segment_number} of {segment_range[0]}-{segment_range[1]}
**Theme**: {story_context.get('theme', 'Adventure')}
**Tone**: {story_context.get('tone', 'whimsical')}
**Age**: {age} (Band: {age_band})

## Story So Far
{story_so_far}

## User's Choice
The hero chose: "{selected_choice}"

## Current Inventory
{json.dumps(inventory, indent=2) if inventory else "[]"}

## Current Story State
```json
{json.dumps(story_state, indent=2)}
```

## Age Calibration (Age Band: {age_band})
- **Sentence Length**: {age_config['sentence_length']}
- **Word Count**: {age_config['word_count'][0]}-{age_config['word_count'][1]} words
- **Complexity**: {age_config['complexity']}
{continuation_guidance}

## Continuation Requirements

1. **Honor the Choice**: The selected choice must lead to a DISTINCT consequence - not a cosmetic variation
2. **Update State**: Modify at least ONE of: location, goal, clues, companion_status, or time_pressure
3. **Inventory Changes**: Add or remove items if the choice leads to discovery or use
4. **Meaningful Progression**: Build on previous segments, reference past choices
5. **Micro-Hook**: Add a curiosity spark (clue, whisper, odd object, or surprising rule)

## Required JSON Output Format
```json
{{
  "segment_number": {next_segment_number},
  "content": "Story prose ({age_config['word_count'][0]}-{age_config['word_count'][1]} words)",
  "image_description": "Visual scene description",
  "inventory": {json.dumps(inventory)},
  "story_state": {{
    "location": "Updated location",
    "goal": "Updated or same goal",
    "key_clues": ["clue1", "clue2"],
    "companion_status": "Updated companion status",
    "time_pressure": "Optional urgency element"
  }},
  "choices": [
    {{"id": "choice_1", "text": "First choice"}}{"," + chr(10) + ' ' * 4 + '{"id": "choice_2", "text": "Second choice"}' if not should_conclude else ''}{"," + chr(10) + ' ' * 4 + '{"id": "choice_3", "text": "Third choice"}' if choice_count >= 3 and not should_conclude else ''}{"," + chr(10) + ' ' * 4 + '{"id": "choice_4", "text": "Fourth choice"}' if choice_count >= 4 and not should_conclude else ''}
  ],
  "is_ending": {str(should_conclude).lower()}
}}
```

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
