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
            'sentence_length': 'simple but varied (4-10 words), storybook-style with personality',
            'vocabulary': 'easy words with playful phrasing (think Corduroy, Where the Wild Things Are, not See Spot Run)',
            'vocabulary_avoid': 'NO: parchment, depicts, constellations, nestled, velvet, motes, vibrant, bustling, encouraging, contagious, shimmer, unravel. YES: paper, shows, stars, sitting, soft cloth, dust, bright, busy, happy, sparkle, open',
            'word_count': (180, 280),  # Increased to allow natural storybook pacing
            'stakes': 'gentle, with frequent reassurance',
            'suspense': 'minimal but magical',
            'complexity': 'simple cause-and-effect with whimsy and wonder'
        },
        '6-8': {
            'sentence_length': 'simple but varied (5-12 words), storybook-style with personality',
            'vocabulary': 'easy to moderate words with playful phrasing (think Magic Tree House, Junie B. Jones)',
            'vocabulary_avoid': 'NO: parchment, depicts, constellations, velvet, motes, vibrant, bustling, shimmering. YES: paper, shows, stars, soft, dust, bright, busy, sparkling',
            'word_count': (220, 350),  # Age-appropriate: longer than 3-5, but still kid-friendly
            'stakes': 'clear and friendly',
            'suspense': 'light, with humor and wonder',
            'complexity': 'clear cause/effect choices with mild strategy'
        },
        '9-12': {
            'sentence_length': 'varied (6-15 words), dynamic pacing with personality',
            'vocabulary': 'vivid and engaging (think Percy Jackson, Harry Potter early books) - avoid being too formal or academic',
            'vocabulary_encourage': 'YES: mysterious, ancient, glowing, whispered, twisted, shimmering, echo, shadow. AVOID sounding like a textbook.',
            'word_count': (280, 450),  # Engaging length - not too long
            'stakes': 'engaging quest structure with emotional stakes',
            'suspense': 'mystery, foreshadowing, clever twists',
            'complexity': 'layered choices with strategic thinking and consequences',
            'humor': 'clever wordplay, ironic observations, situational comedy'
        },
        '13-16': {
            'sentence_length': 'varied (8-20 words), literary style with voice',
            'vocabulary': 'sophisticated but accessible (think Hunger Games, Six of Crows) - wit, nuance, emotional depth',
            'vocabulary_encourage': 'YES: sarcasm, wit, irony, subtext, complex emotions. Can use "constellations", "velvet", "parchment" for atmosphere.',
            'word_count': (320, 500),  # Rich but not exhausting
            'stakes': 'deeper emotional resonance, moral complexity',
            'suspense': 'strategic puzzles, foreshadowing, plot twists, identity questions',
            'complexity': 'multi-layered consequences, moral gray areas',
            'humor': 'sarcasm, dry wit, pop culture references (age-appropriate), self-aware narrator'
        },
        '17+': {
            'sentence_length': 'varied (5-25 words), literary style with strong voice',
            'vocabulary': 'sophisticated and evocative - full literary range while staying engaging',
            'vocabulary_encourage': 'Full range: lyrical prose, sharp dialogue, rich metaphors. Can be literary without being pretentious.',
            'word_count': (350, 550),  # Immersive but respects reader time
            'stakes': 'emotional depth, philosophical questions, complex relationships',
            'suspense': 'psychological tension, unreliable narration, thematic depth',
            'complexity': 'morally complex choices, long-term consequences, character development',
            'humor': 'sophisticated wit, literary references, dark humor (safe), absurdist comedy'
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
        elif age <= 16:
            return '13-16'
        else:
            return '17+'

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
{f"**VOCABULARY FOR AGE {age}**: {age_config.get('vocabulary_avoid', '')}" if age <= 5 else ""}

**CRITICAL RULES**:
- {f"**AGE {age} VOCABULARY**: Use ONLY simple words a {age}-year-old knows. NO: parchment/depicts/constellations/nestled/velvet/vibrant/bustling/encouraging/shimmer/unravel. YES: paper/shows/stars/sitting/soft cloth/bright/busy/happy/sparkle/open. Keep sentences SHORT (4-10 words)!" if age <= 5 else f"**AGE {age}**: Keep vocabulary and complexity appropriate for this age."}
- **POV**: ALWAYS use "you" (second-person). The hero's name is "{child_name}". DO NOT use any other names. DO NOT call the hero "Max", "Sam", or any invented name. Use "{child_name}" ONLY if absolutely necessary (max 2x total), otherwise say "you".
- **WORD COUNT REQUIREMENT**: Your content MUST be between {age_config['word_count'][0]} and {age_config['word_count'][1]} words. Count your words before finishing. If under {age_config['word_count'][0]}, add more sensory details, dialogue, and description.
- **Companion** (if present): 3+ appearances, 1 help, 1 bond. Never replaces child's choice.
  - **ANIMAL COMPANIONS**: Do NOT make animals talk unless there's a magical reason (e.g., enchanted, found magic item). Animals communicate through actions, sounds, and body language.
- **Characters**: NEVER invent names for family/friends not provided. Use generic terms: "grandma", "mom", "dad", "friend", "neighbor".
- **Inventory**: Show new items clearly. Ref within 1 segment. Max 5 items.
- **Choices**: {choice_count} concrete options. NO "ask what to do"/"wait"/passive. Each changes outcome. Start with vivid verbs ("Knock", "Whisper", "Tap", "Sing").
- **Safety**: No violence/harm/abuse/abandonment. Safe, whimsical only.

**ENGAGEMENT RECIPE** (age-calibrated):

**Ages 3-8**: Fun Recipe (playful, magical)
1. Silly Detail (funny sound, goofy rule)
2. Magical Twist (object talks/sings/dances/glows)
3. 2+ Dialogue Lines
4. Tiny Challenge (pattern, count, color)
5. Mini Cliffhanger (sound, movement, glow)

**Ages 9-12**: Adventure Recipe (clever, mysterious)
1. Clever Detail (ironic observation, unexpected insight, wordplay)
2. Mysterious Element (ancient runes, hidden door, cryptic message, strange behavior)
3. 3+ Dialogue Lines with personality/subtext
4. Puzzle/Strategy Challenge (decode pattern, outwit opponent, piece clues together)
5. Strong Hook/Cliffhanger (revelation, danger, plot twist, moral dilemma preview)

**Ages 13-16**: Depth Recipe (wit, complexity)
1. Sharp Detail (sarcastic observation, symbolic element, emotional insight)
2. Atmospheric/Thematic Element (moral gray area, identity question, power dynamics, foreshadowing)
3. 3+ Dialogue Lines with subtext, wit, or emotional weight
4. Complex Challenge (moral dilemma, strategic puzzle, social navigation, identity choice)
5. Compelling Hook (plot twist, character revelation, philosophical question, stakes raised)

**Ages 17+**: Literary Recipe (sophisticated, immersive)
1. Evocative Detail (sensory-rich, metaphorical, psychologically revealing)
2. Thematic Depth (philosophical question, unreliable narration, complex relationships, existential stakes)
3. 4+ Dialogue Lines with distinct voices, subtext, emotional resonance
4. Meaningful Challenge (ethical dilemma, character-defining choice, psychological obstacle)
5. Powerful Hook (thematic revelation, character transformation, plot complication, emotional gut-punch)

**LOGIC RULE** (all ages): Choices must match obstacles. Make mismatches magical (ages 3-8) or explained by story logic (ages 9+).

**Opening Segment 1/{segment_range[1]}**:
1. Begin with sensory details (what child sees/hears/smells) - natural storybook opening
2. Introduce gentle challenge or mystery
3. Show companion personality (if present)
4. Establish magical location & sense of wonder
5. End with {choice_count} distinct, exciting choices

**JSON Output**:
```json
{{
  "title": "Adventure Title",
  "output_type": "CHOICE",
  "segment_number": 1,
  "stage_label": "Wake Up!",
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

**QUALITY CHECK** (before output):
1. Word count: Is content between {age_config['word_count'][0]}-{age_config['word_count'][1]} words? If not, add more description/dialogue.
2. POV: Does content say "you" instead of invented names like "Max"? No name hallucination?
3. {f"Vocabulary (AGE {age}): No hard words like 'parchment', 'depicts', 'constellations', 'nestled', 'vibrant'? Use simple words only!" if age <= 5 else f"Vocabulary (AGE {age}): {'Playful & accessible?' if age <= 8 else 'Vivid & engaging (not textbook-like)?' if age <= 12 else 'Sophisticated but accessible?' if age <= 16 else 'Literary but not pretentious?'}"}
4. Engagement Recipe: {f"Fun Recipe present? (silly, magical, 2+ dialogue, challenge, cliffhanger)" if age <= 8 else f"Adventure Recipe present? (clever, mysterious, 3+ dialogue, puzzle, hook)" if age <= 12 else f"Depth Recipe present? (sharp, atmospheric, 3+ dialogue w/ subtext, complex challenge, compelling hook)" if age <= 16 else "Literary Recipe present? (evocative, thematic, 4+ dialogue w/ voices, meaningful challenge, powerful hook)"}
5. Dialogue: Enough lines? {"2+" if age <= 8 else "3+" if age <= 16 else "4+"}
6. Choices: Vivid verbs? Logic matches obstacles? Cliffhanger in last sentence?
If any check fails, revise content before outputting JSON.

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

        # Pick-A-Path Rule: ALWAYS show choices except for the absolute final ending
        if should_conclude:
            output_type_guidance = f"\n**OUTPUT TYPE**: This is the FINAL segment. Set output_type='CONTINUE' (no choices), is_ending=true, and deliver the satisfying conclusion."
            continuation_guidance = f"\n**FINAL SEGMENT**: This is the concluding segment {next_segment_number}. Deliver the 'Impossible Moment' climax and warm resolution."
        elif is_approaching_end:
            output_type_guidance = f"\n**OUTPUT TYPE**: REQUIRED: output_type='CHOICE'. This is a Pick-A-Path adventure - every segment MUST present {choice_count} meaningful choices until the final ending."
            continuation_guidance = f"\n**APPROACHING CLIMAX**: This is segment {next_segment_number} of {segment_range[1]}. Begin escalating toward the 'Impossible Moment' while providing crucial choices."
        else:
            output_type_guidance = f"\n**OUTPUT TYPE**: REQUIRED: output_type='CHOICE'. This is a Pick-A-Path adventure - every segment MUST present exactly {choice_count} distinct, meaningful choices. No CONTINUE segments except for the final ending."
            continuation_guidance = ""

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

**AGE CALIBRATION (CRITICAL)**: This story is for a {age}-year-old child. Use {age_config['vocabulary']} and {age_config['sentence_length']}. Keep it age-appropriate throughout!
{f"**VOCABULARY FOR AGE {age}**: {age_config.get('vocabulary_avoid', '')}" if age <= 5 else ""}

**Story So Far**:
{story_so_far}

**Hero chose**: "{selected_choice}"

**Inventory**: {json.dumps(inventory) if inventory else "[]"}
**State**: {json.dumps(story_state)}

{continuation_guidance}
{output_type_guidance}

**CRITICAL RULES**:
- {f"**AGE {age} VOCABULARY**: Use ONLY simple words a {age}-year-old knows. NO: parchment/depicts/constellations/nestled/vibrant/encouraging/shimmer. YES: paper/shows/stars/sitting/bright/happy/sparkle. Keep sentences SHORT (4-10 words)!" if age <= 5 else f"**AGE {age}**: Keep vocabulary and complexity appropriate for this age."}
- **POV**: ALWAYS use "you" (second-person). DO NOT invent names. DO NOT call the hero "Max", "Sam", or any other name. The hero is addressed as "you".
- **WORD COUNT REQUIREMENT**: Your content MUST be between {age_config['word_count'][0]} and {age_config['word_count'][1]} words. Count your words. If under {age_config['word_count'][0]}, add more sensory details, dialogue, and description until you reach the minimum.
- **Companion** (if present): 3+ beats, 1 help, 1 bond.
  - **ANIMAL COMPANIONS**: Do NOT make animals talk unless there's a magical reason. Animals communicate through actions, sounds, body language.
- **Characters**: NEVER invent names for family/friends not provided. Use generic terms: "grandma", "mom", "friend".
- **Inventory** (if items): Reference items. Show new ones clearly.
- **Choices**: REQUIRED - Must provide exactly {choice_count} concrete options (unless final ending). NO passive choices. Each must change outcome. Start with vivid verbs.

**ENGAGEMENT RECIPE** (age-calibrated, REQUIRED):
- **Ages 3-8**: Fun Recipe - Silly detail + Magical twist + 2+ dialogue + Tiny challenge + Mini cliffhanger
- **Ages 9-12**: Adventure Recipe - Clever detail + Mysterious element + 3+ dialogue (personality) + Puzzle challenge + Strong hook
- **Ages 13-16**: Depth Recipe - Sharp detail + Atmospheric/thematic element + 3+ dialogue (subtext/wit) + Complex challenge + Compelling hook
- **Ages 17+**: Literary Recipe - Evocative detail + Thematic depth + 4+ dialogue (distinct voices) + Meaningful challenge + Powerful hook

**LOGIC RULE**: Choices match obstacles. Make mismatches magical (3-8) or logically explained (9+).

**JSON Output**:
```json
{{
  "output_type": "{('CONTINUE' if should_conclude else 'CHOICE')}",
  "segment_number": {next_segment_number},
  "stage_label": "Kid-friendly 2-4 word label (e.g., Play Time!, Find the Star!, Big Choice!)",
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
  "is_ending": {str(should_conclude).lower()}
}}
```

**CRITICAL RULE FOR PICK-A-PATH**:
- This is a Pick-A-Path adventure where EVERY segment must give choices
- output_type MUST be 'CHOICE' with exactly {choice_count} options (unless this is the final ending segment)
- ONLY the absolute final ending segment (is_ending=true) can have output_type='CONTINUE' with no choices
- Never use CONTINUE for narrative segments - always provide meaningful choices

**QUALITY CHECK** (before output):
1. Word count: Is content between {age_config['word_count'][0]}-{age_config['word_count'][1]} words? If under minimum, add sensory details/dialogue.
2. POV: Using "you" only? NO invented names like "Max" or "Sam"?
3. {f"Vocabulary (AGE {age}): No hard words like 'parchment', 'depicts', 'constellations', 'nestled', 'vibrant', 'encouraging', 'shimmer'? Use ONLY simple words a {age}-year-old knows!" if age <= 5 else f"Vocabulary (AGE {age}): {'Playful & accessible?' if age <= 8 else 'Vivid & engaging (not textbook-like)?' if age <= 12 else 'Sophisticated but accessible?' if age <= 16 else 'Literary but not pretentious?'}"}
4. {f"Sentence length (AGE {age}): Are all sentences SHORT (4-10 words max)? No long complex sentences!" if age <= 5 else "Sentence complexity and pacing appropriate for age?"}
5. Engagement Recipe: {f"Fun Recipe present? (silly, magical, 2+ dialogue, challenge, cliffhanger)" if age <= 8 else f"Adventure Recipe present? (clever, mysterious, 3+ dialogue, puzzle, hook)" if age <= 12 else f"Depth Recipe present? (sharp, atmospheric, 3+ dialogue w/ subtext, complex challenge, compelling hook)" if age <= 16 else "Literary Recipe present? (evocative, thematic, 4+ dialogue w/ voices, meaningful challenge, powerful hook)"}
6. Dialogue: Enough lines with {"personality" if age <= 8 else "subtext/wit" if age <= 16 else "distinct voices"}? {"2+" if age <= 8 else "3+" if age <= 16 else "4+"}
7. Choices: {choice_count} vivid action verb choices? Logic matches obstacles? Cliffhanger in last sentence?
If any check fails, revise content before outputting JSON.

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
                desc = f"{comp.get('name', 'companion')} the {comp.get('species', 'pet')} [ANIMAL - no speech]"
                if comp.get('personality'):
                    desc += f" ({comp['personality']})"
                companion_descriptions.append(desc)
            else:  # Character companion
                desc = f"{comp.get('name', 'friend')} [can speak]"
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
