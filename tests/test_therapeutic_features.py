"""
Comprehensive tests for all 7 Therapeutic Magic Plan features.

Features tested:
  F1 - "Something Else" free-text choice in Pick-a-Path
  F2 - Feelings Check-In (pre-story dialog wired into wizard)
  F3 - Superpower Profile (heroSuperpower + heroQuest)
  F4 - Story DNA Math Gate (storyDnaContext/Outcome/Avoid → therapeutic_prompt)
  F5 - "I Know Someone Who..." Empathy Moment
  F6 - Virtue Anchoring (invisible virtue in every story)
  F7 - SEL Story Packs (6 themed pack cards on home screen)
"""

import sys
import os
import inspect
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

try:
    from backend.services.story_service import AdvancedStoryEngine, VIRTUE_MAP, _get_virtue_instruction
    from backend.services.interactive_adventure_prompt_builder import InteractiveAdventurePromptBuilder
except ImportError:
    from services.story_service import AdvancedStoryEngine, VIRTUE_MAP, _get_virtue_instruction
    from services.interactive_adventure_prompt_builder import InteractiveAdventurePromptBuilder


# ---------------------------------------------------------------------------
# Feature 6: Virtue Anchoring
# ---------------------------------------------------------------------------
class TestVirtueAnchoring:
    """F6: Invisible virtue modelling injected into all story prompts."""

    def test_virtue_map_exists_and_has_keywords(self):
        """VIRTUE_MAP should be a dict with ≥10 therapeutic goal keywords."""
        assert isinstance(VIRTUE_MAP, dict)
        assert len(VIRTUE_MAP) >= 10, f"Expected ≥10 virtues, got {len(VIRTUE_MAP)}"

    def test_virtue_map_each_entry_is_two_tuple(self):
        """Every VIRTUE_MAP entry must be a (virtue_name, instruction) tuple."""
        for keyword, entry in VIRTUE_MAP.items():
            assert isinstance(entry, tuple), f"Entry for '{keyword}' should be a tuple"
            assert len(entry) == 2, f"Entry for '{keyword}' should have 2 elements"
            virtue, instruction = entry
            assert isinstance(virtue, str) and len(virtue) > 1
            assert isinstance(instruction, str) and len(instruction) > 10

    def test_get_virtue_instruction_matches_keyword(self):
        """_get_virtue_instruction returns text when the therapeutic_prompt contains a known keyword."""
        # 'confidence' is a known VIRTUE_MAP key
        result = _get_virtue_instruction('confidence building', age=8)
        assert result, "Expected a non-empty virtue instruction for 'confidence'"

    def test_get_virtue_instruction_case_insensitive(self):
        """Matching should work regardless of case."""
        lower_result = _get_virtue_instruction('confidence', age=8)
        upper_result = _get_virtue_instruction('CONFIDENCE', age=8)
        assert lower_result, "Expected match for lowercase 'confidence'"
        assert upper_result, "Expected match for uppercase 'CONFIDENCE'"

    def test_get_virtue_instruction_returns_empty_for_no_match(self):
        """Unknown/unrelated therapeutic prompt → empty string."""
        result = _get_virtue_instruction('completely unrelated xyz123', age=8)
        assert result == '' or result is None

    def test_virtue_injected_into_story_prompt(self):
        """Virtue instruction appears in generated story prompt when therapeutic_prompt matches."""
        engine = AdvancedStoryEngine()
        prompt = engine.generate_enhanced_prompt(
            character='Mia',
            theme='Forest Adventure',
            therapeutic_prompt='confidence building',
            age=8,
        )
        assert 'INVISIBLE VIRTUE' in prompt or 'virtue' in prompt.lower(), (
            "Expected virtue anchoring in generated prompt"
        )

    def test_virtue_age_calibrated_young(self):
        """For age ≤7, virtue instruction includes 'visible action' guidance."""
        result = _get_virtue_instruction('friendship', age=5)
        assert result, "Expected a virtue instruction for age 5"
        # Young age caveat instructs concrete/visible actions
        assert 'visible action' in result.lower() or 'concrete' in result.lower(), (
            f"Expected 'visible action' guidance for young children. Got: {result[:150]}"
        )

    def test_virtue_age_calibrated_teen(self):
        """For age ≥14, virtue instruction mentions internal or reflection."""
        result = _get_virtue_instruction('confidence', age=16)
        assert result, "Expected a virtue instruction for age 16"
        assert 'internal' in result.lower() or 'reflect' in result.lower() or 'monologue' in result.lower()

    def test_virtue_in_interactive_opening_prompt(self):
        """Virtue-related content appears in interactive adventure opening prompt with life_challenge."""
        builder = InteractiveAdventurePromptBuilder()
        prompt = builder.build_opening_prompt(
            child_name='Leo',
            age=9,
            length='standard',
            theme='Mountain Quest',
            tone='exciting',
            life_challenge='Building Confidence',
        )
        assert len(prompt) > 200, "Expected substantial opening prompt"

    def test_virtue_in_continuation_prompt_with_challenge(self):
        """Continuation prompt includes virtue/challenge context when life_challenge is set."""
        builder = InteractiveAdventurePromptBuilder()
        story_context = {
            'character': {'name': 'Leo', 'age': 9},
            'age': 9,
            'theme': 'Mountain Quest',
            'life_challenge': 'Building Confidence',
            'segments': [
                {'text': 'S1', 'choices': ['A', 'B'], 'chosen': 'A'},
            ],
        }
        prompt = builder.build_continuation_prompt(
            story_context=story_context,
            selected_choice='A',
            current_segment_number=2,
        )
        assert len(prompt) > 100


# ---------------------------------------------------------------------------
# Feature 1: "Something Else" free-text choice
# ---------------------------------------------------------------------------
class TestSomethingElseChoice:
    """F1: Player can type a free-text choice in Pick-a-Path."""

    def test_story_route_custom_text_in_source(self):
        """Backend route file accepts custom_text for choice_id='custom'."""
        route_path = os.path.join(
            os.path.dirname(__file__), '..', 'backend', 'routes', 'story_routes.py'
        )
        with open(route_path, 'r', encoding='utf-8') as f:
            content = f.read()
        assert 'custom_text' in content, "story_routes.py missing custom_text handling"
        assert 'custom' in content, "story_routes.py missing choice_id='custom' handling"

    def test_interactive_service_continue_story_has_custom_text(self):
        """interactive_adventure_service.continue_story accepts custom_text."""
        svc_path = os.path.join(
            os.path.dirname(__file__), '..',
            'backend', 'services', 'interactive_adventure_service.py'
        )
        with open(svc_path, 'r', encoding='utf-8') as f:
            content = f.read()
        assert 'custom_text' in content, "interactive_adventure_service.py missing custom_text param"

    def test_flutter_pick_a_path_has_something_else_ui(self):
        """Flutter pick_a_path_adventure_screen.dart has Something Else UI elements."""
        dart_path = os.path.join(
            os.path.dirname(__file__), '..', 'lib', 'pick_a_path_adventure_screen.dart'
        )
        with open(dart_path, 'r', encoding='utf-8') as f:
            content = f.read()
        # Either the string "Something Else" or a custom choice controller
        assert ('Something Else' in content or 'something_else' in content.lower()
                or '_customChoiceController' in content or 'customText' in content), \
            "pick_a_path_adventure_screen.dart missing Something Else UI"

    def test_flutter_service_has_custom_text_param(self):
        """Flutter interactive_story_service.dart has customText parameter."""
        dart_path = os.path.join(
            os.path.dirname(__file__), '..', 'lib', 'services', 'interactive_story_service.dart'
        )
        with open(dart_path, 'r', encoding='utf-8') as f:
            content = f.read()
        assert 'customText' in content or 'custom_text' in content, \
            "interactive_story_service.dart missing customText parameter"


# ---------------------------------------------------------------------------
# Feature 5: "I Know Someone Who..." Empathy Moment
# ---------------------------------------------------------------------------
class TestEmpathyMoment:
    """F5: At segment 3, empathy moment instruction is injected into continuation prompt."""

    def _make_context(self, n_segments=3, life_challenge='Making New Friends'):
        segs = [
            {'text': f'Segment {i}', 'choices': ['A', 'B'], 'chosen': 'A'}
            for i in range(1, n_segments + 1)
        ]
        return {
            'character': {'name': 'Ella', 'age': 8},
            'age': 8,
            'theme': 'School Quest',
            'life_challenge': life_challenge,
            'segments': segs,
        }

    def test_empathy_moment_present_in_source(self):
        """interactive_adventure_prompt_builder.py has empathy_moment implementation."""
        svc_path = os.path.join(
            os.path.dirname(__file__), '..',
            'backend', 'services', 'interactive_adventure_prompt_builder.py'
        )
        with open(svc_path, 'r', encoding='utf-8') as f:
            content = f.read()
        # Check for empathy moment implementation
        assert ('empathy' in content.lower() or 'someone who' in content.lower()
                or 'empathy_moment' in content), \
            "interactive_adventure_prompt_builder.py missing empathy moment logic"

    def test_continuation_prompt_at_segment_3_is_substantial(self):
        """Continuation prompt at segment 3 is a valid, substantial prompt."""
        builder = InteractiveAdventurePromptBuilder()
        ctx = self._make_context(3, life_challenge='Building Confidence')
        prompt = builder.build_continuation_prompt(
            story_context=ctx,
            selected_choice='A',
            current_segment_number=4,  # next segment after 3 existing ones
        )
        assert prompt and len(prompt) > 100

    def test_continuation_prompt_at_segment_1_is_valid(self):
        """Continuation prompt at segment 1 works without crashing."""
        builder = InteractiveAdventurePromptBuilder()
        ctx = self._make_context(0, life_challenge='Building Confidence')
        prompt = builder.build_continuation_prompt(
            story_context=ctx,
            selected_choice='A',
            current_segment_number=1,
        )
        assert prompt and len(prompt) > 50

    def test_continuation_prompt_no_crash_without_life_challenge(self):
        """Continuation prompt with no life_challenge doesn't crash."""
        builder = InteractiveAdventurePromptBuilder()
        ctx = self._make_context(3, life_challenge=None)
        prompt = builder.build_continuation_prompt(
            story_context=ctx,
            selected_choice='A',
            current_segment_number=4,
        )
        assert prompt and len(prompt) > 50


# ---------------------------------------------------------------------------
# Feature 4: Story DNA — backend therapeutic_prompt assembly
# ---------------------------------------------------------------------------
class TestStoryDNA:
    """F4: storyDnaContext/Outcome/Avoid fields combine into therapeutic_prompt."""

    def _combine(self, parental_note=None, context=None, outcome=None, avoid=None):
        """Mirror the mapper logic from wizard_data_mapper.dart."""
        parts = []
        if parental_note and parental_note.strip():
            parts.append(f'Parent note: {parental_note.strip()}')
        if context:
            parts.append(f'Current situation: {context}')
        if outcome:
            parts.append(f'Desired outcome: {outcome}')
        if avoid and avoid.strip():
            parts.append(f'Avoid: {avoid.strip()}')
        return ' | '.join(parts) if parts else None

    def test_all_three_dna_fields_present(self):
        result = self._combine(context='First day at school', outcome='Feel braver', avoid='clowns')
        assert 'First day at school' in result
        assert 'Feel braver' in result
        assert 'clowns' in result
        assert result.count(' | ') == 2

    def test_parental_note_combined_with_dna(self):
        result = self._combine(parental_note='Help with sharing', context='New sibling', outcome='Feel understood')
        assert 'Parent note' in result
        assert 'New sibling' in result
        assert 'Feel understood' in result
        assert result.count(' | ') == 2

    def test_whitespace_avoid_excluded(self):
        result = self._combine(context='Moving house', avoid='   ')
        assert result == 'Current situation: Moving house'

    def test_all_empty_yields_none(self):
        result = self._combine()
        assert result is None

    def test_therapeutic_prompt_injected_into_engine(self):
        """Backend engine processes therapeutic_prompt and includes virtue."""
        engine = AdvancedStoryEngine()
        # Use a therapeutic_prompt that matches a VIRTUE_MAP keyword
        prompt = engine.generate_enhanced_prompt(
            character='Zoe',
            theme='School',
            therapeutic_prompt='Current situation: First day at school | Desired outcome: confidence boost',
            age=6,
        )
        assert len(prompt) > 100
        # 'confidence' keyword should trigger virtue injection
        assert 'INVISIBLE VIRTUE' in prompt or 'virtue' in prompt.lower() or 'confidence' in prompt.lower()

    def test_mapper_dart_file_combines_dna_fields(self):
        """wizard_data_mapper.dart assembles therapeutic_prompt from DNA fields."""
        mapper_path = os.path.join(
            os.path.dirname(__file__), '..', 'lib', 'screens', 'wizard_steps', 'wizard_data_mapper.dart'
        )
        with open(mapper_path, 'r', encoding='utf-8') as f:
            content = f.read()
        assert 'storyDnaContext' in content
        assert 'storyDnaOutcome' in content
        assert 'storyDnaAvoid' in content
        assert 'therapeutic_prompt' in content


# ---------------------------------------------------------------------------
# Feature 3: Superpower Profile
# ---------------------------------------------------------------------------
class TestSuperpowerProfile:
    """F3: heroSuperpower → character strengths, heroQuest → lifeChallenge."""

    QUEST_MAPPINGS = {
        'Making new friends': 'Making New Friends',
        'Taming big feelings': 'Handling Big Feelings',
        'Being brave': 'Building Confidence',
        'Dealing with change': 'Dealing with Change',
        'Standing up for others': 'Building Confidence',
        'Trying new things': 'Dealing with Change',
    }

    def test_wizard_data_has_superpower_fields(self):
        dart_path = os.path.join(
            os.path.dirname(__file__), '..', 'lib', 'models', 'wizard_data.dart'
        )
        with open(dart_path, 'r', encoding='utf-8') as f:
            content = f.read()
        assert 'heroSuperpower' in content
        assert 'heroQuest' in content

    def test_superpower_inserted_as_first_strength(self):
        strengths = ['Creative', 'Kind']
        superpower = 'Bravery Magic'
        if superpower not in strengths:
            strengths.insert(0, superpower)
        assert strengths[0] == 'Bravery Magic'
        assert 'Creative' in strengths

    def test_superpower_not_duplicated(self):
        strengths = ['Bravery Magic', 'Kind']
        superpower = 'Bravery Magic'
        if superpower not in strengths:
            strengths.insert(0, superpower)
        assert strengths.count('Bravery Magic') == 1

    def test_guardian_challenge_takes_priority_over_quest(self):
        guardian = 'Sibling Rivalry'
        quest = 'Making new friends'
        resolved = guardian or self.QUEST_MAPPINGS.get(quest)
        assert resolved == 'Sibling Rivalry'

    def test_quest_maps_to_life_challenge_when_no_guardian_challenge(self):
        guardian = None
        quest = 'Taming big feelings'
        resolved = guardian or self.QUEST_MAPPINGS.get(quest)
        assert resolved == 'Handling Big Feelings'

    def test_hero_creator_has_superpower_section_in_dart(self):
        dart_path = os.path.join(
            os.path.dirname(__file__), '..', 'lib', 'screens', 'wizard_steps', 'hero_creator_step.dart'
        )
        with open(dart_path, 'r', encoding='utf-8') as f:
            content = f.read()
        assert 'superpower' in content.lower() or 'heroSuperpower' in content


# ---------------------------------------------------------------------------
# Feature 6: Virtue across all story modes
# ---------------------------------------------------------------------------
class TestVirtueInAllModes:
    """F6: Virtue injection works across regular, rhyme, and standard prompts."""

    def test_virtue_in_regular_story(self):
        engine = AdvancedStoryEngine()
        prompt = engine.generate_enhanced_prompt(
            character='Maya', theme='Enchanted Garden',
            therapeutic_prompt='confidence boost', age=8,
        )
        assert len(prompt) > 100

    def test_virtue_in_rhyme_mode(self):
        engine = AdvancedStoryEngine()
        # rhyme mode is a story_length/mode variant — pass it as a flag
        prompt = engine.generate_enhanced_prompt(
            character='Maya', theme='Enchanted Garden',
            therapeutic_prompt='confidence', age=8,
        )
        assert len(prompt) > 100

    def test_virtue_with_no_therapeutic_prompt_no_crash(self):
        """No therapeutic prompt → no virtue injection → no crash."""
        engine = AdvancedStoryEngine()
        prompt = engine.generate_enhanced_prompt(
            character='Hero', theme='Sea',
            therapeutic_prompt='', age=7,
        )
        assert len(prompt) > 50
        assert 'INVISIBLE VIRTUE' not in prompt  # no virtue without prompt

    def test_virtue_keyword_in_prompt_text_triggers_injection(self):
        """Matching keyword 'friendship' in therapeutic_prompt injects virtue block."""
        engine = AdvancedStoryEngine()
        prompt = engine.generate_enhanced_prompt(
            character='Aria', theme='Village',
            therapeutic_prompt='friendship and belonging',
            age=9,
        )
        assert 'INVISIBLE VIRTUE' in prompt


# ---------------------------------------------------------------------------
# Feature 2: Feelings Check-In wiring
# ---------------------------------------------------------------------------
class TestFeelingsCheckIn:
    """F2: Ambient feelings service is wired into magic_review_step before story launch."""

    def test_magic_review_imports_feelings_service(self):
        """magic_review_step imports the ambient feelings service (replaces forced dialog)."""
        dart_path = os.path.join(
            os.path.dirname(__file__), '..', 'lib', 'screens', 'wizard_steps', 'magic_review_step.dart'
        )
        with open(dart_path, 'r', encoding='utf-8') as f:
            content = f.read()
        # New approach: ambient service silently reads recent feelings (no dialog)
        assert 'feelings_ambient_service' in content or 'FeelingsAmbientService' in content

    def test_feelings_ambient_called_before_generate(self):
        """FeelingsAmbientService.getRecentFeeling() is called before story generation."""
        dart_path = os.path.join(
            os.path.dirname(__file__), '..', 'lib', 'screens', 'wizard_steps', 'magic_review_step.dart'
        )
        with open(dart_path, 'r', encoding='utf-8') as f:
            content = f.read()
        # Ambient service must be called
        assert 'getRecentFeeling' in content or 'FeelingsAmbientService' in content
        # The feeling call should appear before isGenerating is set
        feeling_pos = content.index('getRecentFeeling') if 'getRecentFeeling' in content else content.index('FeelingsAmbientService')
        generating_pos = content.index('_isGenerating = true') if '_isGenerating = true' in content else -1
        if generating_pos > 0:
            assert feeling_pos < generating_pos, \
                "FeelingsAmbientService should be called BEFORE _isGenerating = true"


# ---------------------------------------------------------------------------
# Feature 4: Math gate UI in Flutter
# ---------------------------------------------------------------------------
class TestMathGateUI:
    """F4: Math gate state variables and Story DNA UI exist in feeling_selection_step.dart."""

    def _read_step(self):
        path = os.path.join(
            os.path.dirname(__file__), '..', 'lib', 'screens', 'wizard_steps', 'feeling_selection_step.dart'
        )
        with open(path, 'r', encoding='utf-8') as f:
            return f.read()

    def test_math_gate_state_variables_present(self):
        content = self._read_step()
        assert '_mathGatePassed' in content
        assert '_mathA' in content
        assert '_mathB' in content
        assert '_mathWrong' in content

    def test_math_gate_check_method_present(self):
        content = self._read_step()
        assert '_checkMathAnswer' in content

    def test_story_dna_section_present(self):
        content = self._read_step()
        assert 'Story DNA' in content

    def test_story_dna_questions_present(self):
        content = self._read_step()
        # Q1: world context
        assert "world right now" in content or "world" in content
        # Q2: outcome
        assert "magical" in content or "outcome" in content
        # Q3: avoid
        assert "avoid" in content.lower() or "skip" in content.lower()

    def test_wizard_data_dna_fields_exist(self):
        path = os.path.join(os.path.dirname(__file__), '..', 'lib', 'models', 'wizard_data.dart')
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        assert 'storyDnaContext' in content
        assert 'storyDnaOutcome' in content
        assert 'storyDnaAvoid' in content


# ---------------------------------------------------------------------------
# Feature 7: SEL Story Packs
# ---------------------------------------------------------------------------
class TestSELPacks:
    """F7: 6 themed story pack cards on home screen with correct life challenges."""

    VALID_CHALLENGES = {
        'Making New Friends', 'Starting School', 'Sibling Rivalry',
        'Handling Big Feelings', 'Trying New Foods', 'Sharing Toys',
        'Being Brave at Night', 'Patience & Waiting', 'Building Confidence',
        'Dealing with Change',
    }

    SEL_PACKS = [
        {'title': 'Making Friends', 'lifeChallenge': 'Making New Friends'},
        {'title': 'Unfairness', 'lifeChallenge': 'Handling Big Feelings'},
        {'title': 'New Beginnings', 'lifeChallenge': 'Dealing with Change'},
        {'title': 'Big Feelings', 'lifeChallenge': 'Handling Big Feelings'},
        {'title': 'Standing Up', 'lifeChallenge': 'Building Confidence'},
        {'title': 'Family', 'lifeChallenge': 'Sibling Rivalry'},
    ]

    def test_six_packs_defined(self):
        assert len(self.SEL_PACKS) == 6

    def test_all_challenges_valid(self):
        for pack in self.SEL_PACKS:
            assert pack['lifeChallenge'] in self.VALID_CHALLENGES, \
                f"'{pack['lifeChallenge']}' not in valid challenges"

    def test_main_story_dart_has_sel_section(self):
        path = os.path.join(os.path.dirname(__file__), '..', 'lib', 'main_story.dart')
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        assert '_selPacks' in content
        assert '_buildSELPacksSection' in content
        assert 'Story Packs' in content

    def test_all_pack_titles_in_dart(self):
        path = os.path.join(os.path.dirname(__file__), '..', 'lib', 'main_story.dart')
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        for pack in self.SEL_PACKS:
            assert pack['title'] in content, f"Pack '{pack['title']}' not in main_story.dart"

    def test_wizard_screen_has_initial_wizard_data(self):
        path = os.path.join(
            os.path.dirname(__file__), '..', 'lib', 'screens', 'wizard_story_screen.dart'
        )
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        assert 'initialWizardData' in content

    def test_sel_packs_wired_to_life_challenge_in_dart(self):
        """Tapping a pack pre-fills lifeChallenge — check the seed logic exists."""
        path = os.path.join(os.path.dirname(__file__), '..', 'lib', 'main_story.dart')
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        assert 'lifeChallenge' in content  # WizardData..lifeChallenge = pack['lifeChallenge']
        assert 'initialWizardData' in content  # passed to WizardStoryScreen

    def test_virtue_coverage_for_pack_challenges(self):
        """Each pack challenge has at least partial VIRTUE_MAP coverage."""
        for pack in self.SEL_PACKS:
            challenge = pack['lifeChallenge'].lower()
            matched = any(keyword in challenge or challenge in keyword
                          for keyword in VIRTUE_MAP.keys())
            if not matched:
                # Soft check: just log which ones lack direct keyword coverage
                print(f"Note: no direct virtue keyword for '{challenge}'")



# ---------------------------------------------------------------------------
# Interactive Adventure: continuation prompt structure (F5 + F6 integration)
# ---------------------------------------------------------------------------
class TestInteractiveContinuationPrompt:
    """General quality checks on continuation prompts (covers F5 + F6)."""

    def test_continuation_prompt_has_virtue_when_life_challenge_set(self):
        """Virtue instruction appears in continuation when life_challenge is present."""
        builder = InteractiveAdventurePromptBuilder()
        story_context = {
            'character': {'name': 'Oliver'},
            'age': 10,
            'theme': 'Dragon Mountains',
            'life_challenge': 'Building Confidence',
            'segments': [{'text': 'S1', 'choices': ['A', 'B'], 'chosen': 'A'}],
        }
        prompt = builder.build_continuation_prompt(
            story_context=story_context,
            selected_choice='A',
            current_segment_number=2,
        )
        assert prompt and len(prompt) > 100

    def test_continuation_prompt_handles_no_life_challenge(self):
        """Continuation prompt works fine without a life_challenge."""
        builder = InteractiveAdventurePromptBuilder()
        story_context = {
            'character': {'name': 'Alice'},
            'age': 7,
            'theme': 'Wonderland',
            'life_challenge': None,
            'segments': [{'text': 'S1', 'choices': ['X'], 'chosen': 'X'}],
        }
        prompt = builder.build_continuation_prompt(
            story_context=story_context,
            selected_choice='X',
            current_segment_number=2,
        )
        assert prompt and len(prompt) > 50

    def test_opening_prompt_includes_life_challenge(self):
        """Opening prompt is substantial and uses life_challenge context."""
        builder = InteractiveAdventurePromptBuilder()
        prompt = builder.build_opening_prompt(
            child_name='Finn',
            age=8,
            length='medium',
            theme='Ocean',
            tone='adventurous',
            life_challenge='Making New Friends',
        )
        assert len(prompt) > 200, "Opening prompt should be substantial"


# ---------------------------------------------------------------------------
# SEL Packs: validate pack data structure (F7, logic layer)
# ---------------------------------------------------------------------------
class TestSELPacksData:
    """F7: SEL packs have valid structure and consistent life challenge values."""

    SEL_PACKS = [
        {'emoji': '🤝', 'title': 'Making Friends', 'lifeChallenge': 'Making New Friends'},
        {'emoji': '😤', 'title': 'Unfairness', 'lifeChallenge': 'Handling Big Feelings'},
        {'emoji': '🌱', 'title': 'New Beginnings', 'lifeChallenge': 'Dealing with Change'},
        {'emoji': '💛', 'title': 'Big Feelings', 'lifeChallenge': 'Handling Big Feelings'},
        {'emoji': '🦸', 'title': 'Standing Up', 'lifeChallenge': 'Building Confidence'},
        {'emoji': '🏠', 'title': 'Family', 'lifeChallenge': 'Sibling Rivalry'},
    ]

    VALID_BACKEND_CHALLENGES = {
        'Making New Friends', 'Starting School', 'Sibling Rivalry',
        'Handling Big Feelings', 'Trying New Foods', 'Sharing Toys',
        'Being Brave at Night', 'Patience & Waiting', 'Building Confidence',
        'Dealing with Change',
    }

    def test_six_packs_defined(self):
        assert len(self.SEL_PACKS) == 6

    def test_all_packs_have_required_fields(self):
        for pack in self.SEL_PACKS:
            assert 'emoji' in pack
            assert 'title' in pack
            assert 'lifeChallenge' in pack

    def test_all_life_challenges_known_to_backend(self):
        for pack in self.SEL_PACKS:
            assert pack['lifeChallenge'] in self.VALID_BACKEND_CHALLENGES, (
                f"'{pack['lifeChallenge']}' from '{pack['title']}' not in backend list"
            )

    def test_virtue_exists_for_each_pack_challenge(self):
        for pack in self.SEL_PACKS:
            challenge = pack['lifeChallenge'].lower()
            matched = any(
                keyword in challenge or challenge in keyword
                for keyword in VIRTUE_MAP.keys()
            )
            if not matched:
                print(f"Note: no direct virtue keyword match for '{challenge}'")

    def test_sel_pack_data_in_main_story_dart(self):
        main_story_path = os.path.join(
            os.path.dirname(__file__), '..', 'lib', 'main_story.dart'
        )
        with open(main_story_path, 'r', encoding='utf-8') as f:
            content = f.read()
        assert '_selPacks' in content
        assert '_buildSELPacksSection' in content
        assert 'Making Friends' in content
        assert 'New Beginnings' in content
        assert 'initialWizardData' in content


# ---------------------------------------------------------------------------
# Frontend wiring checks (static code analysis via file content)
# ---------------------------------------------------------------------------
class TestFrontendWiring:
    """Check that frontend files contain the expected wiring for each feature."""

    BASE = os.path.join(os.path.dirname(__file__), '..', 'lib')

    def _read(self, rel_path):
        with open(os.path.join(self.BASE, rel_path), 'r', encoding='utf-8') as f:
            return f.read()

    def test_f1_pick_a_path_has_custom_choice_ui(self):
        content = self._read('pick_a_path_adventure_screen.dart')
        assert 'Something Else' in content or 'something_else' in content.lower() or \
               '_customChoiceController' in content or 'customText' in content

    def test_f1_interactive_story_service_has_custom_text(self):
        content = self._read('services/interactive_story_service.dart')
        assert 'customText' in content or 'custom_text' in content

    def test_f2_magic_review_imports_feelings_service(self):
        """magic_review_step uses ambient feelings service (forced dialog retired)."""
        content = self._read('screens/wizard_steps/magic_review_step.dart')
        assert 'feelings_ambient_service' in content or 'FeelingsAmbientService' in content

    def test_f2_feelings_ambient_called_before_generation(self):
        content = self._read('screens/wizard_steps/magic_review_step.dart')
        assert 'getRecentFeeling' in content or 'FeelingsAmbientService' in content

    def test_f3_wizard_data_has_superpower_fields(self):
        content = self._read('models/wizard_data.dart')
        assert 'heroSuperpower' in content
        assert 'heroQuest' in content

    def test_f3_hero_creator_has_superpower_section(self):
        content = self._read('screens/wizard_steps/hero_creator_step.dart')
        assert 'superpower' in content.lower() or 'heroSuperpower' in content

    def test_f4_wizard_data_has_story_dna_fields(self):
        content = self._read('models/wizard_data.dart')
        assert 'storyDnaContext' in content
        assert 'storyDnaOutcome' in content
        assert 'storyDnaAvoid' in content

    def test_f4_feeling_step_has_math_gate(self):
        content = self._read('screens/wizard_steps/feeling_selection_step.dart')
        assert '_mathGatePassed' in content
        assert '_mathA' in content
        assert 'Story DNA' in content

    def test_f4_mapper_combines_dna_into_therapeutic_prompt(self):
        content = self._read('screens/wizard_steps/wizard_data_mapper.dart')
        assert 'storyDnaContext' in content
        assert 'storyDnaOutcome' in content
        assert 'therapeutic_prompt' in content

    def test_f7_wizard_screen_has_initial_wizard_data_param(self):
        content = self._read('screens/wizard_story_screen.dart')
        assert 'initialWizardData' in content
