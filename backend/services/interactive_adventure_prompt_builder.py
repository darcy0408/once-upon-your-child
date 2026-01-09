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
        fears_or_sensitivities: Optional[List[str]] = None
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

        # Pre-calculate choice templates
        choice_templates = [
            '    {"id": "choice_1", "text": "First choice option"}',
            '    {"id": "choice_2", "text": "Second choice option"}'
        ]
        choices_json = ",\n".join(choice_templates)

        prompt = f"""Generate interactive adventure for {child_name} (age {age}).

**Story**: {theme} | {tone} | {segment_range[0]}-{segment_range[1]} segments | {choice_count} choices
**Companion**: {companion_context}
{cls._build_content_guidelines(interests, must_include, avoid, fears_or_sensitivities)}

**Writing** ({word_count[0]}-{word_count[1]} words): {age_config['sentence_length']}, {age_config['vocabulary']}, {age_config['stakes']}
{f"**VOCABULARY FOR AGE {age}**: {age_config.get('vocabulary_avoid', '')}" if age <= 7 else ""}

**OUTPUT TYPE**: REQUIRED: output_type='CHOICE'. This is a Pick-A-Path adventure - every segment MUST present exactly {choice_count} distinct, meaningful choices. No CONTINUE segments except for the final ending.

**CRITICAL RULES**:
- **AGE {age}**: Keep vocabulary and complexity appropriate for this age.
- **POV**: ALWAYS use "you" (second-person). The hero's name is "{child_name}".
- **WORD COUNT REQUIREMENT**: Your content MUST be between {word_count[0]} and {word_count[1]} words. THIS IS CRITICAL.
- **Companion Contract**: REQUIRED: 3+ distinct beats (actions/dialogue), 1 help, 1 bond. Companion MUST appear by name and affect story.
  - **ANIMAL COMPANIONS**: Do NOT make animals talk unless magically explained.
- **Characters**: NEVER invent names for family/friends not provided.
- **Inventory Contract**: Visibility: Show new items clearly. Max 5 items.
- **Choices**: {choice_count} concrete options. NO passive options like "wait" or "ask what to do". Start with vivid verbs.
- **Safety**: No violence/harm/abuse. Therapeutic tone.

**Opening Segment 1/{segment_range[1]}**:
1. Begin with sensory details - natural storybook opening.
2. Introduce gentle challenge or mystery.
3. Establish magical surprise/motif and earned small win early.
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
        age = story_context.get('age', 8)
        length = story_context.get('length', 'medium')
        age_band = cls.get_age_band(age)
        age_config = cls.AGE_BANDS[age_band]
        word_count = age_config['word_count_ranges'].get(length, age_config['word_count_ranges']['medium'])
        choice_count = cls.CHOICE_COUNTS.get(length, 2)
        segment_range = cls.SEGMENT_TARGETS[age_band].get(length, (10, 15))

        next_segment_number = current_segment_number + 1
        should_conclude = next_segment_number >= segment_range[1]

        prompt = f"""Continue adventure segment {next_segment_number}/{segment_range[1]}.

**Title**: {story_context.get('title', 'Untitled')} | **Theme**: {story_context.get('theme', 'Adventure')} | **Age**: {age}

**Hero chose**: "{selected_choice}"
**Inventory**: {json.dumps(inventory)}
**State**: {json.dumps(story_state)}

**Story So Far**:
{story_so_far}

**CRITICAL RULES**:
- **WORD COUNT**: Content MUST be between {word_count[0]} and {word_count[1]} words.
- **POV**: ALWAYS use "you" (second-person).
- **Companion**: Companion MUST be involved in at least 2 beats this segment.
- **Mode**: Pick-A-Path. Every segment needs {choice_count} choices UNLESS final segment.
- **Ending**: If final segment, deliver a satisfying earned ending and a coping moment in action.

**JSON Output**:
```json
{{
  "output_type": "{('CONTINUE' if should_conclude else 'CHOICE')}",
  "segment_number": {next_segment_number},
  "content": "Story content ({word_count[0]}-{word_count[1]} words)",
  "word_count": {word_count[0] + 50},
  "choices": [
    {('{{"id": "end_story", "text": "End Adventure"}}' if should_conclude else '{{"id": "choice_1", "text": "..."}}, {{"id": "choice_2", "text": "..."}}')}
  ],
  "is_ending": {str(should_conclude).lower()}
}}
```
"""
        return prompt

    @staticmethod
    def _build_companion_context(companions: List[Dict]) -> str:
        if not companions:
            return "solo on this adventure"
        companion_descriptions = []
        for comp in companions[:2]:
            if 'species' in comp:
                companion_descriptions.append(f"{comp.get('name', 'companion')} the {comp.get('species', 'pet')} [ANIMAL]")
            else:
                companion_descriptions.append(f"{comp.get('name', 'friend')} [SPEAKING]")
        return "joined by " + " and ".join(companion_descriptions)

    @staticmethod
    def _build_content_guidelines(interests, must_include, avoid, fears) -> str:
        guidelines = []
        if interests: guidelines.append(f"**Interests**: {', '.join(interests)}")
        if must_include: guidelines.append(f"**MUST include**: {', '.join(must_include)}")
        if avoid or fears: guidelines.append(f"**AVOID**: {', '.join(set((avoid or []) + (fears or [])))}")
        return "\n".join(guidelines)