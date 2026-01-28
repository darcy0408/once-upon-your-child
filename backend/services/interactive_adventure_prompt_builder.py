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

    # Age calibration settings updated to match Story Weaver Coverage v2
    AGE_BANDS = {
        '3-4': {
            'sentence_length': 'very simple (3-6 words), short sentences with repetition',
            'vocabulary': 'simple words only, comforting rhythm (think Corduroy)',
            'vocabulary_avoid': 'NO: parchment, depicts, constellations, nestled, velvet, motes, vibrant, bustling, encouraging, contagious, shimmer, unravel. YES: paper, shows, stars, sitting, soft cloth, dust, bright, busy, happy, sparkle, open',
            'word_count_ranges': {
                'short': (200, 300),
                'medium': (300, 450),
                'long': (450, 650)
            },
            'stakes': 'gentle, with frequent reassurance',
            'suspense': 'minimal but magical',
            'complexity': 'very simple cause-and-effect'
        },
        '5-7': {
            'sentence_length': 'simple but varied (5-10 words), storybook-style',
            'vocabulary': 'simple vocabulary with occasional new words explained by context',
            'vocabulary_avoid': 'NO: parchment, depicts, constellations, velvet, motes, vibrant, bustling, shimmering. YES: paper, shows, stars, soft, dust, bright, busy, sparkling',
            'word_count_ranges': {
                'short': (450, 650),
                'medium': (650, 900),
                'long': (900, 1200)
            },
            'stakes': 'clear and friendly',
            'suspense': 'light, with humor and wonder',
            'complexity': 'clear cause/effect choices'
        },
        '8-10': {
            'sentence_length': 'varied (6-15 words), richer detail',
            'vocabulary': 'vivid and engaging, richer detail (think Magic Tree House)',
            'word_count_ranges': {
                'short': (900, 1200),
                'medium': (1200, 1800),
                'long': (1800, 2400)
            },
            'stakes': 'engaging quest structure, clear cause-effect, stronger arcs',
            'suspense': 'mystery, humor, clever twists',
            'complexity': 'layered choices with clear strategy'
        },
        '11-13': {
            'sentence_length': 'varied (8-18 words), dynamic pacing',
            'vocabulary': 'nuanced emotions, deeper motivation, age-appropriate but complex',
            'word_count_ranges': {
                'short': (1300, 1700),
                'medium': (1800, 2600),
                'long': (2600, 3400)
            },
            'stakes': 'nuanced emotions, deeper motivation, still clean',
            'suspense': 'mystery, social complexity',
            'complexity': 'multi-layered consequences'
        },
        '13-15': {
            'sentence_length': 'varied (8-20 words), identity/friendship themes',
            'vocabulary': 'respectful humor, sophisticated but accessible',
            'word_count_ranges': {
                'short': (1600, 2200),
                'medium': (2400, 3400),
                'long': (3400, 4500)
            },
            'stakes': 'identity, friendship, respectful humor',
            'suspense': 'emotional tension, complex relationships',
            'complexity': 'layered moral choices'
        },
        '15-18': {
            'sentence_length': 'sophisticated, introspection-focused',
            'vocabulary': 'complex stakes, introspection, full range',
            'word_count_ranges': {
                'short': (2000, 2800),
                'medium': (3000, 4200),
                'long': (4200, 6000)
            },
            'stakes': 'complex stakes, introspection, mature relationships (clean)',
            'suspense': 'psychological tension, complex stakes',
            'complexity': 'morally complex choices'
        },
        'adult': {
            'sentence_length': 'mature, nuanced literary range',
            'vocabulary': 'nuanced themes (stress, meaning, relationships), therapeutic tone',
            'word_count_ranges': {
                'short': (2000, 3000),
                'medium': (3200, 5200),
                'long': (5200, 7800)
            },
            'stakes': 'nuanced themes, stress, meaning, relationships',
            'suspense': 'thematic depth, introspection',
            'complexity': 'philosophical and relational complexity'
        }
    }

    # Choice count based on story length (default 2 for meaningful choices)
    CHOICE_COUNTS = {
        'short': 2,
        'medium': 2,
        'long': 2
    }

    # Estimated Path Depths (how many segments a user actually reads in one play)
    # These are used to divide the total word count into per-segment counts.
    PATH_DEPTHS = {
        '3-4': {'short': 4, 'medium': 5, 'long': 6},
        '5-7': {'short': 5, 'medium': 6, 'long': 7},
        '8-10': {'short': 6, 'medium': 7, 'long': 8},
        '11-13': {'short': 7, 'medium': 8, 'long': 9},
        '13-15': {'short': 8, 'medium': 9, 'long': 10},
        '15-18': {'short': 9, 'medium': 10, 'long': 11},
        'adult': {'short': 10, 'medium': 12, 'long': 14}
    }

    # Segment targets based on Story Weaver Coverage v2 Table (Nodes)
    SEGMENT_TARGETS = {
        '3-4': {'short': (7, 9), 'medium': (9, 11), 'long': (11, 13)},
        '5-7': {'short': (9, 12), 'medium': (12, 15), 'long': (15, 18)},
        '8-10': {'short': (12, 16), 'medium': (16, 20), 'long': (20, 24)},
        '11-13': {'short': (14, 18), 'medium': (18, 22), 'long': (22, 26)},
        '13-15': {'short': (16, 20), 'medium': (20, 26), 'long': (26, 32)},
        '15-18': {'short': (18, 24), 'medium': (24, 30), 'long': (30, 38)},
        'adult': {'short': (18, 26), 'medium': (26, 34), 'long': (34, 44)}
    }

    # Structured Life Challenges for therapeutic integration
    # Maps challenge name to (metaphor, coping_strategy, growth_outcome)
    LIFE_CHALLENGES = {
        'Making New Friends': {
            'metaphor': 'A bridge between two floating islands that needs careful building.',
            'coping_strategy': 'Asking a kind question, noticing a shared interest, offering a small token of help.',
            'growth_outcome': 'The hero feels the warmth of connection and realizes others feel nervous too.'
        },
        'Starting School': {
            'metaphor': 'Entering a vast library where every book is a new adventure waiting to be read.',
            'coping_strategy': 'Finding a "safe anchor" (a familiar object/thought), deep belly breaths, observing before jumping in.',
            'growth_outcome': 'Uncertainty turns into curiosity; the hero finds their rhythm in the new routine.'
        },
        'Sibling Rivalry': {
            'metaphor': 'Two different stars trying to shine in the same patch of night sky.',
            'coping_strategy': 'Taking turns, finding a way to combine their different "lights", expressing needs with words instead of pushes.',
            'growth_outcome': 'Realizing that together they make the sky brighter; finding the "team" in the family.'
        },
        'Handling Big Feelings': {
            'metaphor': 'A stormy weather system inside a magical crystal bottle.',
            'coping_strategy': 'Naming the "storm", watching it pass without being swept away, finding the "calm center".',
            'growth_outcome': 'The hero learns that feelings are like weather—they change, and you can stay safe through them.'
        },
        'Trying New Foods': {
            'metaphor': 'Exploring a planet with strange but wonderful textures and "flavor-fields".',
            'coping_strategy': 'The "One-Bite Discovery", describing the sensation objectively, pairing the new with the familiar.',
            'growth_outcome': 'Bravery in small tastes; discovering that the "unknown" can be delicious.'
        },
        'Sharing Toys': {
            'metaphor': 'A magical fountain that only flows when the water is allowed to move between basins.',
            'coping_strategy': 'Setting a timer, noticing the joy on the other person\'s face, finding a game that uses two toys together.',
            'growth_outcome': 'The discovery that "joy shared is joy doubled".'
        },
        'Being Brave at Night': {
            'metaphor': 'The Night-Glow garden where flowers only bloom in the quiet dark.',
            'coping_strategy': 'Checking the "security perimeter", using a "bravery mantra", visualizing a protective light shield.',
            'growth_outcome': 'The hero realizes they are the keeper of their own safety; shadows become just shapes.'
        },
        'Patience & Waiting': {
            'metaphor': 'Watching a slow-growing moon-flower that only opens when it\'s perfectly ready.',
            'coping_strategy': 'The "Waiting Game" (observing details), focusing on the "now" instead of the "next", deep slow breathing.',
            'growth_outcome': 'Finding magic in the stillness; realizing that the best things are worth the time.'
        }
    }

    SAFETY_GUARDRAILS = """
SAFETY RULES:
- No sexual content, no graphic violence, no self-harm, no illegal wrongdoing.
- Handle sensitive emotions gently. Safe, therapeutic tone.
- Do NOT invent characters or family members not provided.
- Must Include: A Moment of Wonder (age-appropriate), a coping moment in action (resilience/perspective), and a satisfying earned ending.
- SAFETY: Ensure no scary imagery or abandonment themes for children.
"""

    TEEN_TONE_INSTRUCTION = """
- **TONE (Teen)**: Avoid 'babyish' or condescending language. Use sophisticated, nuanced vocabulary. 
- **THEMES**: Focus on identity, autonomy, moral complexity, and the internal journey. 
- **ENGAGEMENT**: Choices should reflect social or internal dilemmas, not just physical actions.
"""

    @classmethod
    def get_age_band(cls, age: int) -> str:
        """Determine age band from specific age based on new categories"""
        if age <= 4:
            return '3-4'
        elif age <= 7:
            return '5-7'
        elif age <= 10:
            return '8-10'
        elif age <= 13:
            return '11-13'
        elif age <= 15:
            return '13-15'
        elif age <= 18:
            return '15-18'
        else:
            return 'adult'

    @classmethod
    def _calculate_per_segment_word_count(cls, age_band: str, length: str) -> tuple:
        """Calculate per-segment word count based on age band and total word count range."""
        age_config = cls.AGE_BANDS[age_band]
        total_range = age_config['word_count_ranges'].get(length, age_config['word_count_ranges']['medium'])
        
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
        life_challenge: Optional[str] = None,
        personality_sliders: Optional[Dict[str, int]] = None
    ) -> str:
        """
        Build the opening segment prompt for a new interactive adventure.
        """
        age_band = cls.get_age_band(age)
        age_config = cls.AGE_BANDS[age_band]
        
        # Calculate PER-SEGMENT word count
        word_count = cls._calculate_per_segment_word_count(age_band, length)
        
        choice_count = cls.CHOICE_COUNTS.get(length, 2)
        path_depth = cls.PATH_DEPTHS[age_band].get(length, 10)

        # Build companion context
        companion_context = cls._build_companion_context(companions) if companions else "solo on this adventure"

        # Character details
        char_data = character or {}
        special_ability = char_data.get('special_ability', char_data.get('specialAbility', 'None specified'))
        gender = char_data.get('gender', 'not specified')
        pronouns = char_data.get('pronouns', '')
        gender_text = f" (Gender: {gender}{', Pronouns: ' + pronouns if pronouns else ''})"
        
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

        # Life Challenge (Therapeutic Integration)
        challenge_instruction = ""
        if life_challenge:
            challenge_data = cls.LIFE_CHALLENGES.get(life_challenge)
            if challenge_data:
                challenge_instruction = f"""
- **LIFE CHALLENGE**: {life_challenge}
- **METAPHOR**: {challenge_data['metaphor']}
- **COPING STRATEGY TO TEACH**: {challenge_data['coping_strategy']}
- **GROWTH OUTCOME**: {challenge_data['growth_outcome']}
- **INSTRUCTION**: Use the metaphor provided to frame the adventure. Ensure the hero uses the coping strategy at a key decision point to achieve the growth outcome. Keep it magical and age-appropriate."""
            else:
                challenge_instruction = f"- **LIFE CHALLENGE**: The story must subtly reflect the challenge of '{life_challenge}'. The hero should learn to cope with this through the adventure, but keep it metaphorical and magical, not clinical."

        # Age-specific impossible element suggestions
        impossible_elements = {
            '3-4': 'Ride on a friendly cloud, talk to a flower, jump over a moonbeam.',
            '5-7': 'Fly on dandelion seeds, taste rainbow colors, walk through a mirror.',
            '8-10': 'Surf on lightning bolts, rewrite the rules of gravity, talk to the stars.',
            '11-13': 'Architect a dreamscape, command the tides, freeze time with a thought.',
            '13-15': 'Bridge two worlds, heal a rift in space, weave light into a bridge.',
            '15-18': 'Navigate a paradox, harmonize a chaotic dimension, transcend physical limits.',
            'adult': 'Manifest an abstract emotion, reconcile lost timelines, find meaning in entropy.'
        }
        age_impossible = impossible_elements.get(age_band, 'Something magical and physics-defying.')

        # Age-appropriate default sensory palettes
        default_sensories = {
            '3-4': 'Bright colors, soft sounds, sweet smells.',
            '5-7': 'Vivid colors, magical sounds, familiar scents.',
            '8-10': 'Rich textures, mysterious echoes, crisp aromas.',
            '11-13': 'Dynamic lighting, layered sounds, complex atmosphere.',
            '13-15': 'Moody shadows, ambient noise, cinematic details.',
            '15-18': 'Gritty textures, visceral sounds, evocative atmosphere.',
            'adult': 'Intricate sensory metaphors, thematic undertones, immersive environment.'
        }
        final_sensory = sensory_palette or default_sensories.get(age_band, 'Bright colors, soft sounds.')

        # Pre-calculate choice templates
        choice_templates = [
            '    {"id": "choice_1", "text": "First choice option (Action-oriented)"}',
            '    {"id": "choice_2", "text": "Second choice option (Action-oriented)"}'
        ]
        choices_json = ",\n".join(choice_templates)

        # Dynamic Terminology for Teens
        tool_label = "HERO TOOL"
        tool_instruction = "(MUST be used later in the adventure)"
        if age >= 12:
            tool_label = "KEY ARTIFACT"
            tool_instruction = "(MUST be integral to the resolution)"

        tool_line = f"- **{tool_label}**: {f"'{spark_tool}' {tool_instruction}" if spark_tool else 'None'}"

        prompt = f"""
**PERSONA**: Expert Child Narrative Architect & Pick-A-Path Specialist.

You are generating the OPENING SEGMENT of a Pick-A-Path adventure for {child_name}{gender_text} (age {age}).

**STORY SPECS**:
- **THEME**: {theme} | **TONE**: {tone}
- **CONFLICT**: {conflict_hook or 'A magical mystery needs solving.'}
- **SENSORY PALETTE**: {final_sensory}
{challenge_instruction}
- **HERO**: {child_name} (Special Ability: {special_ability}).
{personality_profile}
{tool_line}
- **IMPOSSIBLE ELEMENTS**: Examples for this age: {age_impossible}
- **COMPANIONS**: {companion_context} (Must affect the story).
{mood_rules}

**WRITING** ({word_count[0]}-{word_count[1]} words per segment): {age_config['sentence_length']}, {age_config['vocabulary']}, {age_config['stakes']}
{f"**VOCABULARY FOR AGE {age}**: {age_config.get('vocabulary_avoid', '')}" if age <= 7 else ""}

**OUTPUT TYPE**: REQUIRED: output_type='CHOICE'. This is a Pick-A-Path adventure - every segment MUST present exactly {choice_count} distinct, meaningful choices.

**CRITICAL RULES**:
- **AGE {age}**: Keep vocabulary and complexity appropriate for this age.
- **POV**: ALWAYS use "you" (second-person). The hero's name is "{child_name}".
- **WORD COUNT REQUIREMENT**: This INDIVIDUAL SEGMENT MUST be between {word_count[0]} and {word_count[1]} words.
- **Companion Contract**: REQUIRED: 3+ distinct beats (actions/dialogue), 1 help, 1 bond. Companion MUST appear by name.
- **Choices**: {choice_count} concrete options. NO passive options. Start with vivid verbs.
- **Safety**: No violence/harm. Therapeutic tone.
{cls.SAFETY_GUARDRAILS}
{cls.TEEN_TONE_INSTRUCTION if age >= 15 else ""}

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
"""
        return prompt

    @classmethod
    def build_continuation_prompt(
        cls,
        story_context: Dict[str, Any],
        selected_choice: str,
        current_segment_number: int,
        inventory: Optional[List[str]] = None,
        story_state: Optional[Dict[str, Any]] = None,
        story_so_far: str = ""
    ) -> str:
        """Build the continuation prompt for the next interactive segment."""
        age = int(story_context.get('age') or 7)
        length = story_context.get('length', 'medium')
        theme = story_context.get('theme', 'Adventure')
        tone = story_context.get('tone', 'whimsical')
        character = story_context.get('character') or {}
        companions = story_context.get('companions') or []

        age_band = cls.get_age_band(age)
        age_config = cls.AGE_BANDS[age_band]
        
        # Calculate PER-SEGMENT word count
        word_count = cls._calculate_per_segment_word_count(age_band, length)
        
        choice_count = cls.CHOICE_COUNTS.get(length, 2)
        path_depth = cls.PATH_DEPTHS[age_band].get(length, 10)

        child_name = character.get('name', 'Hero')
        gender = character.get('gender', 'not specified')
        pronouns = character.get('pronouns', '')
        gender_text = f" (Gender: {gender}{', Pronouns: ' + pronouns if pronouns else ''})"

        companion_context = cls._build_companion_context(companions) if companions else "solo on this adventure"
        inventory = inventory or []
        story_state = story_state or {}

        # Age-appropriate default sensory palettes
        default_sensories = {
            '3-4': 'Bright colors, soft sounds, sweet smells.',
            '5-7': 'Vivid colors, magical sounds, familiar scents.',
            '8-10': 'Rich textures, mysterious echoes, crisp aromas.',
            '11-13': 'Dynamic lighting, layered sounds, complex atmosphere.',
            '13-15': 'Moody shadows, ambient noise, cinematic details.',
            '15-18': 'Gritty textures, visceral sounds, evocative atmosphere.',
            'adult': 'Intricate sensory metaphors, thematic undertones, immersive environment.'
        }
        final_sensory = story_context.get('sensory_palette') or default_sensories.get(age_band, 'Bright colors, soft sounds.')

        choice_templates = [
            '    {"id": "choice_1", "text": "First choice option (Action-oriented)"}',
            '    {"id": "choice_2", "text": "Second choice option (Action-oriented)"}'
        ]
        choices_json = ",\n".join(choice_templates)

        next_segment_number = current_segment_number + 1
        
        # Decide if this should be an ending
        is_near_end = next_segment_number >= (path_depth - 1)
        ending_instruction = ""
        if is_near_end:
            ending_instruction = f"\n**ENDING LOGIC**: You are at segment {next_segment_number}/{path_depth}. If appropriate for the plot, you MAY conclude the story in this segment by setting `is_ending: true`. If not, ensure the story concludes by segment {path_depth}."

        prompt = f"""
**PERSONA**: Expert Child Narrative Architect & Pick-A-Path Specialist.

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

**STORY SO FAR (summary)**:
{story_so_far or "No summary available."}

**WRITING** ({word_count[0]}-{word_count[1]} words per segment): {age_config['sentence_length']}, {age_config['vocabulary']}, {age_config['stakes']}
{f"**VOCABULARY FOR AGE {age}**: {age_config.get('vocabulary_avoid', '')}" if age <= 7 else ""}

**CRITICAL RULES**:
- **AGE {age}**: Keep vocabulary and complexity appropriate for this age.
- **POV**: ALWAYS use "you" (second-person). The hero's name is "{child_name}".
- **WORD COUNT REQUIREMENT**: This INDIVIDUAL SEGMENT MUST be between {word_count[0]} and {word_count[1]} words.
- **Companion Contract**: REQUIRED: 3+ distinct beats (actions/dialogue), 1 help, 1 bond. Companion MUST appear by name.
- **Choices**: {choice_count} concrete options. NO passive options. Start with vivid verbs.{ending_instruction}
- **Safety**: No violence/harm. Therapeutic tone.
{cls.SAFETY_GUARDRAILS}
{cls.TEEN_TONE_INSTRUCTION if age >= 15 else ""}

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
"""
        return prompt

    @staticmethod
    def _build_companion_context(companions: Optional[List[Dict]]) -> str:
        """Build companion context string from companion list."""
        if not companions:
            return "solo on this adventure"
        companion_descriptions = []
        for comp in companions[:2]:
            if 'species' in comp:
                companion_descriptions.append(f"{comp.get('name', 'companion')} the {comp.get('species', 'pet')} [ANIMAL]")
            else:
                companion_descriptions.append(f"{comp.get('name', 'friend')} [SPEAKING]")
        return "joined by " + " and ".join(companion_descriptions)
