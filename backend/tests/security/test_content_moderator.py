"""
Security Tests: Post-Generation Content Moderation

Tests for the two-layer output safety system:
  Layer 1 — age-band-aware keyword filter (app_helpers.make_filter_story_content)
  Layer 2 — LLM-based contextual safety classifier (content_moderator.moderate_story_content)

These tests use mocked Gemini clients so no real API calls are made.
"""

import pytest
from unittest.mock import MagicMock, patch


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _mock_gemini_response(text: str):
    """Build a mock genai response object returning the given text."""
    response = MagicMock()
    response.text = text
    response.candidates = []
    return response


# ---------------------------------------------------------------------------
# Layer 1: age-band-aware keyword filter
# ---------------------------------------------------------------------------

class TestKeywordFilter:
    """Tests for the upgraded make_filter_story_content() in app_helpers."""

    def _make_filter(self):
        import logging
        from backend.utils.app_helpers import make_filter_story_content
        return make_filter_story_content(logging.getLogger("test"))

    def test_safe_story_not_flagged(self):
        """A completely safe story is not flagged for any age."""
        fn = self._make_filter()
        story = "Once upon a time there was a brave little fox who loved to explore the forest."
        for age in [4, 7, 10, 14]:
            _, flagged = fn(story, age)
            assert not flagged, f"Safe story incorrectly flagged for age {age}"

    def test_suicide_flagged_all_ages(self):
        """Suicide content is always flagged regardless of age."""
        fn = self._make_filter()
        story = "The hero thought about suicide after losing the battle."
        for age in [4, 10, 16]:
            _, flagged = fn(story, age)
            assert flagged, f"Suicide content not flagged for age {age}"

    def test_sexual_content_flagged_all_ages(self):
        """Sexual content is always flagged regardless of age."""
        fn = self._make_filter()
        story = "The story contained explicit sexual content between characters."
        for age in [5, 12, 17]:
            _, flagged = fn(story, age)
            assert flagged, f"Sexual content not flagged for age {age}"

    def test_kill_flagged_for_young_children(self):
        """'Kill' is flagged for age <= 7 but not for older children."""
        fn = self._make_filter()
        story = "The dragon tried to kill the knight in battle."
        _, flagged_young = fn(story, age=6)
        _, flagged_older = fn(story, age=11)
        assert flagged_young, "Violence not flagged for young child (age 6)"
        assert not flagged_older, "Age-appropriate conflict incorrectly flagged for age 11"

    def test_monster_flagged_only_for_youngest(self):
        """'Monster' triggers only for the youngest band (age <= 7)."""
        fn = self._make_filter()
        story = "The friendly monster helped the children cross the river."
        _, flagged_young = fn(story, age=5)
        _, flagged_adventurer = fn(story, age=10)
        assert flagged_young, "Monster not flagged for Sprout/Explorer band"
        assert not flagged_adventurer, "Monster incorrectly flagged for Adventurer band"

    def test_empty_story_not_flagged(self):
        """Empty story text does not raise errors."""
        fn = self._make_filter()
        _, flagged = fn("", age=5)
        assert not flagged

    def test_none_story_not_flagged(self):
        """None story text does not raise errors."""
        fn = self._make_filter()
        _, flagged = fn(None, age=5)
        assert not flagged

    def test_default_age_is_young(self):
        """When age is omitted, default (5) uses strict young-child rules."""
        fn = self._make_filter()
        story = "The monster growled at the children in the nightmare forest."
        _, flagged = fn(story)  # no age arg — defaults to 5
        assert flagged


# ---------------------------------------------------------------------------
# Layer 2: LLM-based content classifier
# ---------------------------------------------------------------------------

class TestContentModerator:
    """Tests for content_moderator.moderate_story_content()."""

    def test_safe_story_passes(self):
        """LLM returns safe=true → story is passed through."""
        from backend.utils.content_moderator import moderate_story_content
        mock_client = MagicMock()
        mock_client.models.generate_content.return_value = _mock_gemini_response('{"safe": true}')

        is_safe, reason = moderate_story_content("A lovely story about rabbits.", age=6, client=mock_client)

        assert is_safe is True
        assert reason == ""

    def test_unsafe_story_flagged(self):
        """LLM returns safe=false → story is flagged with reason."""
        from backend.utils.content_moderator import moderate_story_content
        mock_client = MagicMock()
        mock_client.models.generate_content.return_value = _mock_gemini_response(
            '{"safe": false, "reason": "graphic violence"}'
        )

        is_safe, reason = moderate_story_content("A violent story.", age=7, client=mock_client)

        assert is_safe is False
        assert "violence" in reason

    def test_classifier_exception_fails_open(self):
        """When the classifier raises an exception, the function fails open (safe=True)."""
        from backend.utils.content_moderator import moderate_story_content
        mock_client = MagicMock()
        mock_client.models.generate_content.side_effect = RuntimeError("API unavailable")

        is_safe, reason = moderate_story_content("Any story text.", age=8, client=mock_client)

        assert is_safe is True
        assert reason == ""

    def test_malformed_json_fails_open(self):
        """When classifier returns non-JSON, the function fails open."""
        from backend.utils.content_moderator import moderate_story_content
        mock_client = MagicMock()
        mock_client.models.generate_content.return_value = _mock_gemini_response("not json at all")

        is_safe, reason = moderate_story_content("Any story text.", age=8, client=mock_client)

        assert is_safe is True

    def test_empty_response_fails_open(self):
        """When classifier returns empty text, the function fails open."""
        from backend.utils.content_moderator import moderate_story_content
        mock_client = MagicMock()
        mock_client.models.generate_content.return_value = _mock_gemini_response("")

        is_safe, reason = moderate_story_content("Any story text.", age=8, client=mock_client)

        assert is_safe is True

    def test_empty_story_skips_classifier(self):
        """Empty story text returns safe without calling the client."""
        from backend.utils.content_moderator import moderate_story_content
        mock_client = MagicMock()

        is_safe, reason = moderate_story_content("", age=5, client=mock_client)

        assert is_safe is True
        mock_client.models.generate_content.assert_not_called()

    def test_markdown_wrapped_json_parsed(self):
        """Classifier response wrapped in markdown code fences is handled."""
        from backend.utils.content_moderator import moderate_story_content
        mock_client = MagicMock()
        mock_client.models.generate_content.return_value = _mock_gemini_response(
            '```json\n{"safe": false, "reason": "PII detected"}\n```'
        )

        is_safe, reason = moderate_story_content("Story with Emma at Lakeside School.", age=9, client=mock_client)

        assert is_safe is False
        assert "PII" in reason

    @pytest.mark.parametrize("age,expected_label", [
        (5, "young child aged 3-7"),
        (10, "child aged 8-12"),
        (15, "teenager aged 13-17"),
        (25, "adult"),
    ])
    def test_age_band_label_in_prompt(self, age, expected_label):
        """The classifier prompt includes the correct age-band description."""
        from backend.utils.content_moderator import moderate_story_content
        mock_client = MagicMock()
        mock_client.models.generate_content.return_value = _mock_gemini_response('{"safe": true}')

        moderate_story_content("A story.", age=age, client=mock_client)

        call_args = mock_client.models.generate_content.call_args
        # call_args.kwargs is the kwargs dict; fall back to string representation
        prompt_sent = call_args.kwargs.get("contents", "") or str(call_args)
        assert expected_label in prompt_sent, (
            f"Expected age label '{expected_label}' not found in classifier prompt for age {age}"
        )


# ---------------------------------------------------------------------------
# Integration: both layers together
# ---------------------------------------------------------------------------

class TestTwoLayerModeration:
    """Verify the keyword filter and LLM classifier work as a combined defence."""

    def test_keyword_layer_catches_obvious_violation(self):
        """Keyword filter catches clear violations without needing LLM call."""
        import logging
        from backend.utils.app_helpers import make_filter_story_content
        fn = make_filter_story_content(logging.getLogger("test"))
        story = "The hero was suicidal and wanted to end their life."
        _, flagged = fn(story, age=10)
        assert flagged  # keyword layer catches this

    def test_llm_layer_catches_subtle_violation(self):
        """LLM classifier catches contextual violations that keywords miss."""
        from backend.utils.content_moderator import moderate_story_content
        import logging
        from backend.utils.app_helpers import make_filter_story_content

        fn = make_filter_story_content(logging.getLogger("test"))
        subtle_story = "The story described the hero visiting their friend Sarah at Westwood Elementary School, 42 Oak Lane."

        # Keyword layer won't catch this (no explicit banned words)
        _, keyword_flagged = fn(subtle_story, age=8)
        assert not keyword_flagged, "Keyword layer over-blocked subtle PII story"

        # LLM layer should catch the PII
        mock_client = MagicMock()
        mock_client.models.generate_content.return_value = _mock_gemini_response(
            '{"safe": false, "reason": "Contains real school name and address"}'
        )
        is_safe, _ = moderate_story_content(subtle_story, age=8, client=mock_client)
        assert not is_safe, "LLM layer missed PII in story"
