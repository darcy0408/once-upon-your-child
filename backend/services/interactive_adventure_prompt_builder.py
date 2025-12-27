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

        # Build the comprehensive prompt
        prompt = f"""# Interactive Children's Adventure Story Weaver

## Context & Background
You are generating interactive, personalized adventure stories for a children's story app. The stories must feel vivid, magical, and empowering while staying psychologically safe and age-appropriate. The child is always the hero, and companions exist to unlock "impossible" moments, not to steal the spotlight.

**CRITICAL IMMERSION PRINCIPLE**: Each segment should feel like continuous reading, not a quiz. Use the CONTINUE/CHOICE system to balance flow with agency.

## Your Role
- **Interactive Adventure Architect**: Create branching story segments with clear, consequential choices ONLY at decision hinges
- **Second-Person Immersion Master**: Write in "you" POV to make the child feel inside the story
- **Age-Calibrated Language Engine**: Adjust vocabulary and sentence length to match the child's age
- **Sensory Scene Builder**: Write cinematic scenes using multiple senses (sight, sound, touch, smell, heartbeat)
- **Agency-First Storyteller**: Ensure the child solves main problems through choices, courage, or cleverness
- **Continuity Keeper**: Track inventory, promises, clues, and companion abilities with zero contradictions

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

## CRITICAL: Point-of-View Requirements (MUST-PASS)

**PRIMARY POV**: Second-person ("you") for EVERY action, observation, and feeling
- ✅ CORRECT: "You step into the garden. Your heart skips. You smell roses."
- ❌ WRONG: "{child_name} steps into the garden. {child_name}'s heart skips."

**NAME USAGE**: Use the child's name sparingly (1-2 times per segment maximum) as a "spotlight moment"
- Example: "{child_name}, you feel the warmth of the brick under your fingers."

**SENSORY ANCHORING**: Ground every scene in the child's physical experience
- Use: "Your sneakers squeak... Your hands grip... Your breath catches..."
- Include at least 2 different senses per segment (sight, sound, touch, smell, heartbeat)

## CRITICAL: Companion Contract (MUST-PASS if companion present)

If a companion is part of this story, EVERY segment must include:
1. **Narrative Presence** (3+ mentions): Companion appears in action, dialogue, or reaction at least 3 times
2. **Helpful Contribution**: Companion provides ONE concrete assist (idea, tool, distraction, comfort)
3. **Bond Moment**: ONE short relationship beat (joke, high-five, encouragement, shared look)
4. **Agency Balance**: Companion offers perspective but NEVER replaces the child's choice

Example companion beats:
- Dialogue: "Pip whispers, 'I've got a plan if you need it.'"
- Action: "Pip does a quick spin, checking for danger."
- Bond: "Pip looks up at you and grins. 'You're brilliant!'"
- Help: "Pip points to a hidden path you almost missed."

## CRITICAL: Inventory Contract (MUST-PASS if items present)

For ANY item in inventory:
1. **Visibility**: New items must be explicitly shown/described when acquired
2. **In-Scene Reference**: Within 1 segment of gaining an item, reference its presence or potential use
3. **Future Use Hint**: Suggest how the item might matter later
4. **Meaningful Size**: Keep inventory small (2-5 items), not a dumping ground

Example: "The glowing Keeper Brick warms your pocket. You can feel it humming softly."

## CRITICAL: Choice Quality Requirements (MUST-PASS)

**BANNED CHOICE TYPES** - NEVER include these:
- ❌ "Ask [companion] what to do"
- ❌ "Ask [NPC] more questions" (as a standalone choice)
- ❌ "Wait and see what happens"
- ❌ Any passive/stalling option

**REQUIRED CHOICE QUALITIES** - Each choice must:
1. **Change Strategy or Outcome**: Not just different wording for same result
2. **Be Doable and Concrete**: Clear action the child can visualize
3. **Have Distinct Flavor**: Choices should feel different (Brave / Clever / Kind)
4. **Show Agency**: Child makes the decision, not companion or narrator

**DEFAULT CHOICE COUNT**: Provide exactly {choice_count} choices (usually 2)
- Use 3 choices ONLY if all three are truly meaningful and distinct

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
  "output_type": "CHOICE",
  "segment_number": 1,
  "content": "The story prose in SECOND-PERSON POV ({age_config['word_count'][0]}-{age_config['word_count'][1]} words)",
  "word_count": 450,
  "image_description": "Visual scene description for illustration generation",
  "companion_beats": [
    {{"type": "dialogue", "text": "Companion's words"}},
    {{"type": "action", "text": "Companion's action"}},
    {{"type": "bond", "text": "Bond moment description"}}
  ],
  "inventory": [],
  "inventory_references": ["Item mentioned in scene"],
  "story_state": {{
    "location": "Current location",
    "goal": "What the hero is trying to achieve",
    "key_clues": [],
    "companion_status": "How companion is doing",
    "time_pressure": null
  }},
  "choices": [
{choices_json}
  ],
  "is_ending": false
}}
```

**output_type VALUES**:
- "CHOICE": Segment ends with meaningful choices at a decision hinge
- "CONTINUE": Segment ends mid-flow; reader clicks Continue to keep reading (NO choices)

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
{output_type_guidance}

## CRITICAL: Point-of-View Requirements (MUST-PASS)

**PRIMARY POV**: Second-person ("you") - NEVER use third-person or the child's name excessively
- ✅ "You step forward. Your heart pounds."
- ❌ "NAME steps forward. NAME's heart pounds."

**NAME USAGE**: 1-2 times per segment MAX as spotlight moments only

## CRITICAL: Companion Contract (MUST-PASS if companion present)

If companion exists, EVERY segment MUST include:
1. **3+ Companion Beats**: dialogue, action, or reaction
2. **1 Helpful Contribution**: concrete assist or idea
3. **1 Bond Moment**: relationship beat (encouragement, joke, shared look)

## CRITICAL: Inventory Contract (MUST-PASS if items exist)

For items in inventory:
- Reference their presence in the scene
- Show how they might be useful
- Don't let items disappear without mention

## CRITICAL: Choice Quality (MUST-PASS if output_type='CHOICE')

**BANNED**: "Ask what to do", "Ask more questions", passive waiting
**REQUIRED**: Each choice changes strategy/outcome, not just wording
**COUNT**: Exactly {choice_count} choices (usually 2)

## Continuation Requirements

1. **Honor the Choice**: The selected choice must lead to a DISTINCT consequence - not a cosmetic variation
2. **Update State**: Modify at least ONE of: location, goal, clues, companion_status, or time_pressure
3. **Inventory Changes**: Add or remove items if the choice leads to discovery or use
4. **Meaningful Progression**: Build on previous segments, reference past choices
5. **Micro-Hook**: Add a curiosity spark (clue, whisper, odd object, or surprising rule)
6. **Sensory Details**: Include at least 2 different senses (sight, sound, touch, smell, heartbeat)

## Required JSON Output Format
```json
{{
  "output_type": "CHOICE or CONTINUE",
  "segment_number": {next_segment_number},
  "content": "Story prose in SECOND-PERSON POV ({age_config['word_count'][0]}-{age_config['word_count'][1]} words)",
  "word_count": 450,
  "image_description": "Visual scene description",
  "companion_beats": [
    {{"type": "dialogue", "text": "Companion's words"}},
    {{"type": "action", "text": "Companion's action"}},
    {{"type": "bond", "text": "Bond moment"}}
  ],
  "inventory": {json.dumps(inventory)},
  "inventory_references": ["Item mentioned in this scene"],
  "story_state": {{
    "location": "Updated location",
    "goal": "Updated or same goal",
    "key_clues": ["clue1", "clue2"],
    "companion_status": "Updated companion status",
    "time_pressure": "Optional urgency element"
  }},
  "choices": [
{choices_json}
  ],
  "is_ending": {str(should_conclude).lower()}
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
