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
        sensory_palette: Optional[str] = None
    ) -> str:
        """
        Build the opening segment prompt for a new interactive adventure.
        """
        age_band = cls.get_age_band(age)
        age_config = cls.AGE_BANDS[age_band]
        word_count = age_config['word_count_ranges'].get(length, age_config['word_count_ranges']['medium'])
        choice_count = cls.CHOICE_COUNTS.get(length, 2)
        segment_range = cls.SEGMENT_TARGETS[age_band].get(length, (10, 15))

        # Build companion context
        companion_context = cls._build_companion_context(companions) if companions else "solo on this adventure"

        # Character details
        char_data = character or {}
        special_ability = char_data.get('special_ability', char_data.get('specialAbility', 'None specified'))
        
        # Mood Physics
        mood_rules = ""
        if mood_physics:
            mood_rules = f"\nWORLD PHYSICS (Mood: {mood_physics.get('mood', 'Magic')}):\n- RULE: {mood_physics.get('worldRule', '')}\n- SENSORY: {mood_physics.get('sensoryChange', '')}"

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

        # Pre-calculate choice templates
        choice_templates = [
            '    {"id": "choice_1", "text": "First choice option (Action-oriented)"}',
            '    {"id": "choice_2", "text": "Second choice option (Action-oriented)"}'
        ]
        choices_json = ",\n".join(choice_templates)

        prompt = f"""
**PERSONA**: Expert Child Narrative Architect & Pick-A-Path Specialist.

You are generating the OPENING SEGMENT of a Pick-A-Path adventure for {child_name} (age {age}).

**STORY SPECS**:
- **THEME**: {theme} | **TONE**: {tone}
- **CONFLICT**: {conflict_hook or 'A magical mystery needs solving.'}
- **SENSORY PALETTE**: {sensory_palette or 'Bright colors, soft sounds, sweet smells.'}
- **HERO**: {child_name} (Special Ability: {special_ability}).
- **HERO TOOL**: {f"'{spark_tool}' (MUST be used later in the adventure)" if spark_tool else "None"}
- **IMPOSSIBLE ELEMENTS**: Examples for this age: {age_impossible}
- **COMPANIONS**: {companion_context} (Must affect the story).
{mood_rules}

**WRITING** ({word_count[0]}-{word_count[1]} words): {age_config['sentence_length']}, {age_config['vocabulary']}, {age_config['stakes']}
{f"**VOCABULARY FOR AGE {age}**: {age_config.get('vocabulary_avoid', '')}" if age <= 7 else ""}

**OUTPUT TYPE**: REQUIRED: output_type='CHOICE'. This is a Pick-A-Path adventure - every segment MUST present exactly {choice_count} distinct, meaningful choices.

**CRITICAL RULES**:
- **AGE {age}**: Keep vocabulary and complexity appropriate for this age.
- **POV**: ALWAYS use "you" (second-person). The hero's name is "{child_name}".
- **WORD COUNT REQUIREMENT**: Your content MUST be between {word_count[0]} and {word_count[1]} words.
- **Companion Contract**: REQUIRED: 3+ distinct beats (actions/dialogue), 1 help, 1 bond. Companion MUST appear by name.
- **Choices**: {choice_count} concrete options. NO passive options. Start with vivid verbs.
- **Safety**: No violence/harm. Therapeutic tone.

**Opening Segment 1/{segment_range[1]}**:
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
  "word_count": {word_count[0] + 50},
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
