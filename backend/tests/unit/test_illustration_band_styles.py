"""Tests for per-age-band illustration styling (UX audit 2026-07-05).

Verifies that the new ILLUSTRATION_STYLE_BY_BAND map applies the correct
visual style, atmosphere, and safety rules for each of the five age bands:
Sprout (<=5), Explorer (6-8), Adventurer (9-12), Creator (13-14),
Adolescent (15+).
"""

from backend.replicate_image_generator import (
    _IMAGE_UNSAFE_PATTERN,
    _SAFE_FALLBACK_IMAGE_PROMPT,
    ReplicateImageGenerator,
)
from backend.services.image_prompt_helpers import (
    ILLUSTRATION_STYLE_BY_BAND,
    TEXTLESS_ART_RULE,
    build_companion_visuals,
    illustration_band_for_age,
)


class TestBandMapping:
    """Test 1: Band mapping — ages map to the correct band key."""

    def test_age_mapping(self):
        """Ages 3→sprout, 5→sprout, 6→explorer, 8→explorer, 9→adventurer,
        12→adventurer, 13→creator, 14→creator, 15→adolescent, 17→adolescent,
        25→adolescent; None→sprout; "not-a-number"→sprout."""
        assert illustration_band_for_age(3) == "sprout"
        assert illustration_band_for_age(5) == "sprout"
        assert illustration_band_for_age(6) == "explorer"
        assert illustration_band_for_age(8) == "explorer"
        assert illustration_band_for_age(9) == "adventurer"
        assert illustration_band_for_age(12) == "adventurer"
        assert illustration_band_for_age(13) == "creator"
        assert illustration_band_for_age(14) == "creator"
        assert illustration_band_for_age(15) == "adolescent"
        assert illustration_band_for_age(17) == "adolescent"
        assert illustration_band_for_age(25) == "adolescent"
        assert illustration_band_for_age(None) == "sprout"
        assert illustration_band_for_age("not-a-number") == "sprout"


class TestStyleMapIntegrity:
    """Test 2: Style map integrity — all five bands present with
    non-empty style and atmosphere."""

    def test_all_bands_present(self):
        """All five band keys must be present in ILLUSTRATION_STYLE_BY_BAND."""
        expected_bands = {"sprout", "explorer", "adventurer", "creator", "adolescent"}
        assert set(ILLUSTRATION_STYLE_BY_BAND.keys()) == expected_bands

    def test_each_band_has_style_and_atmosphere(self):
        """Each band must have non-empty 'style' and 'atmosphere' strings."""
        for band_name, band_dict in ILLUSTRATION_STYLE_BY_BAND.items():
            assert isinstance(band_dict, dict), f"{band_name} is not a dict"
            assert "style" in band_dict, f"{band_name} missing 'style' key"
            assert "atmosphere" in band_dict, f"{band_name} missing 'atmosphere' key"
            style = band_dict["style"]
            atmosphere = band_dict["atmosphere"]
            assert isinstance(style, str), f"{band_name} style is not a string"
            assert isinstance(
                atmosphere, str
            ), f"{band_name} atmosphere is not a string"
            assert len(style.strip()) > 0, f"{band_name} style is empty"
            assert len(atmosphere.strip()) > 0, f"{band_name} atmosphere is empty"


class TestSafetyVetCompatibility:
    """Test 3: Safety-vet compatibility — band styling cannot trip the M-5 vet
    and replace the entire prompt."""

    def test_band_styling_passes_safety_vet(self):
        """For every band, neither the style nor atmosphere string (nor
        TEXTLESS_ART_RULE) matches the unsafe pattern — i.e. band styling
        can never trip the M-5 vet."""
        for band_name, band_dict in ILLUSTRATION_STYLE_BY_BAND.items():
            style = band_dict["style"]
            atmosphere = band_dict["atmosphere"]

            # Check that none of these match the unsafe pattern
            style_match = _IMAGE_UNSAFE_PATTERN.search(style)
            atmosphere_match = _IMAGE_UNSAFE_PATTERN.search(atmosphere)
            textless_match = _IMAGE_UNSAFE_PATTERN.search(TEXTLESS_ART_RULE)

            assert (
                not style_match
            ), f"Band '{band_name}' style contains unsafe term: {style_match.group(0) if style_match else None}"
            assert (
                not atmosphere_match
            ), f"Band '{band_name}' atmosphere contains unsafe term: {atmosphere_match.group(0) if atmosphere_match else None}"
            assert (
                not textless_match
            ), f"TEXTLESS_ART_RULE contains unsafe term: {textless_match.group(0) if textless_match else None}"


class TestBuildPromptPerBand:
    """Test 4: _build_prompt per band — check for distinctive band styling."""

    def test_sprout_style_in_prompt(self):
        """Age 4 (Sprout) prompt contains distinctive Sprout style substring."""
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description="exploring a crystal cave",
            character_name="the hero",
            style="children's book illustration",
            age=4,
            therapeutic_focus=None,
            character_appearance=None,
            companions=None,
        )
        # Sprout style contains "warm rounded 3D storybook animation"
        assert (
            "warm rounded 3D storybook animation" in prompt
        ), f"Sprout style not found in: {prompt}"

    def test_explorer_style_in_prompt(self):
        """Age 7 (Explorer) prompt contains distinctive Explorer style substring."""
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description="exploring a crystal cave",
            character_name="the hero",
            style="children's book illustration",
            age=7,
            therapeutic_focus=None,
            character_appearance=None,
            companions=None,
        )
        # Explorer style contains "vibrant children's book illustration"
        assert (
            "vibrant children's book illustration" in prompt
        ), f"Explorer style not found in: {prompt}"

    def test_adventurer_style_in_prompt(self):
        """Age 10 (Adventurer) prompt contains distinctive Adventurer style substring."""
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description="exploring a crystal cave",
            character_name="the hero",
            style="children's book illustration",
            age=10,
            therapeutic_focus=None,
            character_appearance=None,
            companions=None,
        )
        # Adventurer style contains "middle-grade novel illustration"
        assert (
            "middle-grade novel illustration" in prompt
        ), f"Adventurer style not found in: {prompt}"

    def test_creator_style_in_prompt(self):
        """Age 13 (Creator) prompt contains distinctive Creator style substring."""
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description="exploring a crystal cave",
            character_name="the hero",
            style="children's book illustration",
            age=13,
            therapeutic_focus=None,
            character_appearance=None,
            companions=None,
        )
        # Creator style contains "young-adult novel art"
        assert (
            "young-adult novel art" in prompt
        ), f"Creator style not found in: {prompt}"

    def test_adolescent_style_in_prompt(self):
        """Age 16 (Adolescent) prompt contains distinctive Adolescent style substring."""
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description="exploring a crystal cave",
            character_name="the hero",
            style="children's book illustration",
            age=16,
            therapeutic_focus=None,
            character_appearance=None,
            companions=None,
        )
        # Adolescent style contains "graphic novel illustration"
        assert (
            "graphic novel illustration" in prompt
        ), f"Adolescent style not found in: {prompt}"


class TestTeenPromptsExcludePictureBookTone:
    """Test 5: Teen prompts (Creator/Adolescent) contain no picture-book suffix."""

    def test_creator_age_13_excludes_safe_for_children(self):
        """Age 13 (Creator) prompt must NOT contain 'safe for children'."""
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description="exploring a crystal cave",
            character_name="the hero",
            style="children's book illustration",
            age=13,
            therapeutic_focus=None,
            character_appearance=None,
            companions=None,
        )
        assert (
            "safe for children" not in prompt
        ), f"Age 13 prompt contains 'safe for children': {prompt}"

    def test_creator_age_13_excludes_friendly_atmosphere(self):
        """Age 13 (Creator) prompt must NOT contain 'friendly atmosphere'."""
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description="exploring a crystal cave",
            character_name="the hero",
            style="children's book illustration",
            age=13,
            therapeutic_focus=None,
            character_appearance=None,
            companions=None,
        )
        assert (
            "friendly atmosphere" not in prompt
        ), f"Age 13 prompt contains 'friendly atmosphere': {prompt}"

    def test_adolescent_age_16_excludes_safe_for_children(self):
        """Age 16 (Adolescent) prompt must NOT contain 'safe for children'."""
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description="exploring a crystal cave",
            character_name="the hero",
            style="children's book illustration",
            age=16,
            therapeutic_focus=None,
            character_appearance=None,
            companions=None,
        )
        assert (
            "safe for children" not in prompt
        ), f"Age 16 prompt contains 'safe for children': {prompt}"

    def test_adolescent_age_16_excludes_friendly_atmosphere(self):
        """Age 16 (Adolescent) prompt must NOT contain 'friendly atmosphere'."""
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description="exploring a crystal cave",
            character_name="the hero",
            style="children's book illustration",
            age=16,
            therapeutic_focus=None,
            character_appearance=None,
            companions=None,
        )
        assert (
            "friendly atmosphere" not in prompt
        ), f"Age 16 prompt contains 'friendly atmosphere': {prompt}"

    def test_sprout_age_4_includes_safe_for_children(self):
        """Age 4 (Sprout) prompt MUST still contain 'safe for children'."""
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description="exploring a crystal cave",
            character_name="the hero",
            style="children's book illustration",
            age=4,
            therapeutic_focus=None,
            character_appearance=None,
            companions=None,
        )
        assert (
            "safe for children" in prompt
        ), f"Age 4 prompt missing 'safe for children': {prompt}"

    def test_explorer_age_7_includes_safe_for_children(self):
        """Age 7 (Explorer) prompt MUST still contain 'safe for children'."""
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description="exploring a crystal cave",
            character_name="the hero",
            style="children's book illustration",
            age=7,
            therapeutic_focus=None,
            character_appearance=None,
            companions=None,
        )
        assert (
            "safe for children" in prompt
        ), f"Age 7 prompt missing 'safe for children': {prompt}"


class TestTextlessRule:
    """Test 6: Textless rule — every band's prompt carries TEXTLESS_ART_RULE."""

    def test_all_bands_have_textless_rule(self):
        """Prompts for every band must contain the full textless rule."""
        test_ages = [4, 7, 10, 13, 16]  # One from each band
        for age in test_ages:
            gen = ReplicateImageGenerator()
            prompt = gen._build_prompt(
                scene_description="exploring a crystal cave",
                character_name="the hero",
                style="children's book illustration",
                age=age,
                therapeutic_focus=None,
                character_appearance=None,
                companions=None,
            )
            assert (
                TEXTLESS_ART_RULE in prompt
            ), f"Age {age} prompt missing textless rule: {prompt}"


class TestCompanionVisuals:
    """Test 7: Companion visuals via _build_prompt."""

    def test_companion_with_color_and_species(self):
        """companions=[{"name": "Pebble", "species": "dragon", "color": "purple"}]
        → prompt contains 'purple dragon' and 'visible in the scene'."""
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description="exploring a crystal cave",
            character_name="the hero",
            style="children's book illustration",
            age=7,
            therapeutic_focus=None,
            character_appearance=None,
            companions=[{"name": "Pebble", "species": "dragon", "color": "purple"}],
        )
        assert "purple dragon" in prompt, f"'purple dragon' not in prompt: {prompt}"
        assert (
            "visible in the scene" in prompt
        ), f"'visible in the scene' not in prompt: {prompt}"

    def test_companion_with_description(self):
        """companions=[{"name": "Ember", "description": "a small fox with flame-colored fur and bright amber eyes"}]
        → prompt contains 'flame-colored fur'."""
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description="exploring a crystal cave",
            character_name="the hero",
            style="children's book illustration",
            age=7,
            therapeutic_focus=None,
            character_appearance=None,
            companions=[
                {
                    "name": "Ember",
                    "description": "a small fox with flame-colored fur and bright amber eyes",
                }
            ],
        )
        assert (
            "flame-colored fur" in prompt
        ), f"'flame-colored fur' not in prompt: {prompt}"

    def test_empty_companions_list(self):
        """Empty companions list → prompt does not contain 'accompanied by'."""
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description="exploring a crystal cave",
            character_name="the hero",
            style="children's book illustration",
            age=7,
            therapeutic_focus=None,
            character_appearance=None,
            companions=[],
        )
        assert (
            "accompanied by" not in prompt
        ), f"'accompanied by' should not be in prompt: {prompt}"

    def test_none_companions(self):
        """None companions → prompt does not contain 'accompanied by'."""
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description="exploring a crystal cave",
            character_name="the hero",
            style="children's book illustration",
            age=7,
            therapeutic_focus=None,
            character_appearance=None,
            companions=None,
        )
        assert (
            "accompanied by" not in prompt
        ), f"'accompanied by' should not be in prompt: {prompt}"

    def test_companion_as_bare_string_skipped(self):
        """A companion that is a bare string (not a dict) must not crash
        and must be skipped."""
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description="exploring a crystal cave",
            character_name="the hero",
            style="children's book illustration",
            age=7,
            therapeutic_focus=None,
            character_appearance=None,
            companions=["not a dict"],  # Should be skipped gracefully
        )
        # Should not crash and prompt should be valid
        assert isinstance(prompt, str)
        assert len(prompt) > 0


class TestBuildCompanionVisualsDirect:
    """Test 8: build_companion_visuals directly — truncation and plural/singular."""

    def test_description_longer_than_140_chars_gets_truncated(self):
        """description longer than 140 chars is capped at 137 chars + a
        visible '...' truncation marker inside the phrase."""
        long_desc = "a" * 150
        companions = [{"name": "LongDog", "description": long_desc}]
        phrase = build_companion_visuals(companions)
        assert "LongDog" in phrase
        assert "who is visible in the scene" in phrase
        assert ("a" * 137 + "...") in phrase, f"ellipsis marker missing: {phrase}"
        assert ("a" * 138) not in phrase, "description not capped at 137 chars"

    def test_two_companions_use_who_are(self):
        """Two companions → phrase uses 'who are'."""
        companions = [
            {"name": "Pebble", "species": "dragon", "color": "purple"},
            {"name": "Spark", "species": "phoenix", "color": "gold"},
        ]
        phrase = build_companion_visuals(companions)
        assert "who are" in phrase, f"'who are' not in phrase: {phrase}"

    def test_one_companion_uses_who_is(self):
        """One companion → 'who is'."""
        companions = [{"name": "Pebble", "species": "dragon", "color": "purple"}]
        phrase = build_companion_visuals(companions)
        assert "who is" in phrase, f"'who is' not in phrase: {phrase}"


class TestTruncation:
    """Test 9: Truncation — a benign 2000-char scene → len(prompt) <= 1200
    and prompt ends with '...'."""

    def test_long_scene_description_gets_truncated(self):
        """A benign 2000-char scene_description gets truncated to <=1200
        and ends with '...'."""
        long_scene = "a sunny meadow " * 150  # ~2250 chars
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description=long_scene,
            character_name="the hero",
            style="children's book illustration",
            age=7,
            therapeutic_focus=None,
            character_appearance=None,
            companions=None,
        )
        assert (
            len(prompt) <= 1200
        ), f"Prompt too long ({len(prompt)} chars): {prompt[:200]}"
        assert prompt.endswith("..."), f"Prompt does not end with '...': {prompt[-20:]}"


class TestVetStillWorks:
    """Test 10: Safety vet still works — scene_description containing 'scary'
    → returned prompt equals the safe fallback."""

    def test_scary_scene_triggers_safe_fallback(self):
        """scene_description containing 'scary' → returned prompt equals
        _SAFE_FALLBACK_IMAGE_PROMPT."""
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description="a scary dark forest with a scary monster",
            character_name="the hero",
            style="children's book illustration",
            age=7,
            therapeutic_focus=None,
            character_appearance=None,
            companions=None,
        )
        assert (
            prompt == _SAFE_FALLBACK_IMAGE_PROMPT
        ), f"Expected safe fallback, got: {prompt}"


class TestCharacterAppearanceThreading:
    """Test 11: Character appearance still threads through the prompt."""

    def test_appearance_details_in_prompt(self):
        """character_appearance={"hair_color": "lightBrown", "eye_color": "blue"}
        → prompt contains 'light brown' and 'blue'."""
        gen = ReplicateImageGenerator()
        prompt = gen._build_prompt(
            scene_description="exploring a crystal cave",
            character_name="the hero",
            style="children's book illustration",
            age=7,
            therapeutic_focus=None,
            character_appearance={"hair_color": "lightBrown", "eye_color": "blue"},
            companions=None,
        )
        # The _humanize function converts camelCase to "light brown"
        assert "light brown" in prompt, f"'light brown' not in prompt: {prompt}"
        assert "blue" in prompt, f"'blue' not in prompt: {prompt}"
