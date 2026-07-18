"""Tests for Sprout (ages 3-5) post-generation word-cap enforcement.

The Sprout Superhero prompt instructs the model to stop at 130 words, but the
model overshoots. These tests cover the two-stage safety belt in
``backend.tasks.story_tasks._enforce_sprout_word_cap``:

  1. Regenerate once with a stricter prompt prefix.
  2. If regen is still over, drop trailing pages/sentences until the story
     fits under the canonical cap (word_ranges.get_word_range(...).cap —
     156 for Sprout Superhero), re-appending the cheer beat for superhero
     stories only.

We mock the regen function so no real LLM calls are made.
"""

from __future__ import annotations

import json
from unittest.mock import MagicMock

from backend.services.prompt_service import PromptService
from backend.services.word_ranges import get_word_range
from backend.tasks.story_tasks import (
    _count_words,
    _enforce_sprout_word_cap,
    _has_cheer_beat,
    _truncate_pages_to_word_cap,
)

# Canonical Sprout Superhero cap (prompt targets 100-130; +20% headroom).
SPROUT_SH_CAP = get_word_range(age=4, mode="superhero").cap


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _make_story_json(pages: list[str], title: str = "A Test Adventure") -> str:
    """Build the JSON envelope that ``_safe_extract_title_and_gem`` expects."""
    return json.dumps({"title": title, "pages": [{"text": p} for p in pages]})


def _words_n(text: str, n: int) -> str:
    """Build a body of exactly n words, ending with the cheer beat."""
    base = ("word " * n).strip()
    return base + ". Everyone cheered. Mia saved the day!"


# ---------------------------------------------------------------------------
# Stage-0: under cap → unchanged
# ---------------------------------------------------------------------------
class TestSproutUnderCap:
    def test_sprout_word_count_under_cap_passes(self):
        """A 100-word Sprout story is returned unchanged (no regen, no truncate)."""
        body = " ".join(["word"] * 100)
        pages = [body]
        regen_fn = MagicMock(side_effect=AssertionError("regen must NOT be called"))

        out_body, out_pages, info = _enforce_sprout_word_cap(
            age=4,
            theme="superhero",
            pages=pages,
            story_body=body,
            title="t",
            post_story={},
            character_name="Mia",
            base_prompt="ORIGINAL PROMPT",
            regen_fn=regen_fn,
            cap=SPROUT_SH_CAP,
        )

        assert out_body == body
        assert out_pages == pages
        assert info["regen_used"] is False
        assert info["truncated"] is False
        assert info["final_words"] == 100
        regen_fn.assert_not_called()


# ---------------------------------------------------------------------------
# Stage-1: over cap → regen with stricter prompt
# ---------------------------------------------------------------------------
class TestSproutRegen:
    def test_sprout_word_count_over_cap_triggers_regen(self):
        """A 200-word Sprout story triggers regen with a stricter prompt prefix."""
        long_body = " ".join(["word"] * 200)
        pages = [long_body]

        # Regen returns a tidy 90-word story — well under the cap.
        short_pages = [" ".join(["tiny"] * 90)]
        regen_fn = MagicMock(return_value=_make_story_json(short_pages))

        out_body, out_pages, info = _enforce_sprout_word_cap(
            age=5,
            theme="superhero",
            pages=pages,
            story_body=long_body,
            title="t",
            post_story={},
            character_name="Mia",
            base_prompt="ORIGINAL PROMPT",
            regen_fn=regen_fn,
            cap=SPROUT_SH_CAP,
        )

        # Regen was invoked exactly once.
        regen_fn.assert_called_once()
        regen_prompt = regen_fn.call_args[0][0]
        assert "STRICT CONSTRAINT" in regen_prompt
        assert "200 words" in regen_prompt
        assert f"MAXIMUM is {SPROUT_SH_CAP}" in regen_prompt
        assert "ORIGINAL PROMPT" in regen_prompt

        # Output reflects the regen result, not truncation.
        assert info["regen_used"] is True
        assert info["truncated"] is False
        assert info["final_words"] == 90
        assert out_pages == short_pages

    def test_sprout_word_count_still_over_after_regen_truncates(self):
        """If regen is still over (180 words), we truncate at sentence boundary ≤150."""
        long_body = " ".join(["word"] * 200)
        pages = [long_body]

        # Build a 180-word regen body composed of fixed-size sentences.
        # 30 sentences × 6 words each = 180 words, each ending with ". ".
        sentence = "the quiet hero walked very far"  # 6 words
        regen_pages = [
            ". ".join([sentence] * 30) + ". Everyone cheered. Mia saved the day!"
        ]
        # That cheer beat tail itself contains additional words — keep total > 150.
        regen_fn = MagicMock(return_value=_make_story_json(regen_pages))

        out_body, out_pages, info = _enforce_sprout_word_cap(
            age=4,
            theme="superhero",
            pages=pages,
            story_body=long_body,
            title="t",
            post_story={},
            character_name="Mia",
            base_prompt="ORIGINAL PROMPT",
            regen_fn=regen_fn,
            cap=SPROUT_SH_CAP,
        )

        regen_fn.assert_called_once()
        assert info["regen_used"] is True
        assert info["truncated"] is True
        assert info["final_words"] <= SPROUT_SH_CAP
        # Cheer beat must remain after truncation (superhero theme).
        assert _has_cheer_beat(out_body)

    def test_sprout_cheer_beat_appended_if_cut(self):
        """When truncation drops the cheer line, it is re-appended with the hero name."""
        # Construct a body where the cheer beat is the last sentence and the
        # body is too long to fit it; truncation should re-append a generic one.
        # 200 words of plain sentences, then the cheer beat at the very end.
        sentence = "the hero walked very far again"  # 6 words
        body = ". ".join([sentence] * 35) + ". Everyone cheered. Mia saved the day!"
        # Force truncation only (no regen): regen returns the SAME body so we
        # land in stage 2.
        regen_fn = MagicMock(return_value=_make_story_json([body]))

        out_body, _out_pages, info = _enforce_sprout_word_cap(
            age=3,
            theme="superhero",
            pages=[body],
            story_body=body,
            title="t",
            post_story={},
            character_name="Mia",
            base_prompt="ORIGINAL PROMPT",
            regen_fn=regen_fn,
            cap=SPROUT_SH_CAP,
        )

        assert info["truncated"] is True
        assert _has_cheer_beat(out_body)
        assert "Mia saved the day!" in out_body
        # Even with the appended cheer suffix, we should be at or under cap.
        # (Truncation reserves words for the cheer beat in advance.)
        assert _count_words(out_body) <= SPROUT_SH_CAP


# ---------------------------------------------------------------------------
# Non-Sprout: no cap enforced
# ---------------------------------------------------------------------------
class TestNonSprout:
    def test_non_sprout_no_cap_enforced(self):
        """An age-8 story of 400 words is returned unchanged."""
        body = " ".join(["word"] * 400)
        pages = [body]
        regen_fn = MagicMock(side_effect=AssertionError("regen must NOT be called"))

        out_body, out_pages, info = _enforce_sprout_word_cap(
            age=8,
            theme="adventure",
            pages=pages,
            story_body=body,
            title="t",
            post_story={},
            character_name="Leo",
            base_prompt="ORIGINAL PROMPT",
            regen_fn=regen_fn,
            cap=SPROUT_SH_CAP,
        )

        assert out_body == body
        assert out_pages == pages
        assert info["regen_used"] is False
        assert info["truncated"] is False
        assert info["final_words"] == 400
        regen_fn.assert_not_called()


# ---------------------------------------------------------------------------
# Theme coverage: superhero path also goes through enforcement
# ---------------------------------------------------------------------------
class TestSuperheroThemeEnforced:
    def test_superhero_theme_word_count_enforced(self):
        """Superhero theme on Sprout still triggers regen on overshoot."""
        long_body = " ".join(["word"] * 220)
        regen_pages = [" ".join(["tiny"] * 100)]
        regen_fn = MagicMock(return_value=_make_story_json(regen_pages))

        _out_body, _out_pages, info = _enforce_sprout_word_cap(
            age=4,
            theme="superhero",  # superhero theme specifically
            pages=[long_body],
            story_body=long_body,
            title="t",
            post_story={},
            character_name="Mia",
            base_prompt="ORIGINAL SUPERHERO PROMPT",
            regen_fn=regen_fn,
            cap=SPROUT_SH_CAP,
        )

        regen_fn.assert_called_once()
        assert info["regen_used"] is True
        assert info["final_words"] == 100
        assert info["theme"] == "superhero"


# ---------------------------------------------------------------------------
# Direct truncate-helper coverage (page-preserving truncation)
# ---------------------------------------------------------------------------
class TestTruncateHelper:
    def test_truncate_keeps_under_cap(self):
        body = ". ".join(["a b c d e f"] * 30) + "."  # 180 words
        out_body, out_pages = _truncate_pages_to_word_cap([body], 150, "Mia")
        assert _count_words(out_body) <= 150
        assert out_pages

    def test_truncate_preserves_multiple_pages(self):
        """Regression: the old helper collapsed the whole story into ONE
        page. Trailing pages are dropped instead."""
        page = ". ".join(["a b c d e f g h i j"] * 4) + "."  # 40 words/page
        pages = [page] * 6  # 240 words
        out_body, out_pages = _truncate_pages_to_word_cap(pages, 150, "Mia")
        assert 1 < len(out_pages) <= 4
        assert sum(_count_words(p) for p in out_pages) <= 150
        assert out_body == "\n\n".join(out_pages)

    def test_truncate_preserves_cheer_for_superhero(self):
        body = (
            ". ".join(["a b c d e f"] * 30) + ". Everyone cheered. Mia saved the day!"
        )
        out_body, _pages = _truncate_pages_to_word_cap(
            [body], 150, "Mia", superhero=True
        )
        assert _has_cheer_beat(out_body)
        assert _count_words(out_body) <= 150

    def test_truncate_does_not_append_cheer_for_non_superhero(self):
        """Even when the original text happens to contain a cheer-beat-shaped
        ending, a NON-superhero story never gets the suffix re-appended."""
        body = (
            ". ".join(["a b c d e f"] * 30) + ". Everyone cheered. Mia saved the day!"
        )
        out_body, _pages = _truncate_pages_to_word_cap([body], 150, "Mia")
        assert not _has_cheer_beat(out_body)

    def test_truncate_does_not_append_cheer_if_original_lacked_one(self):
        body = ". ".join(["a b c d e f"] * 30) + "."  # no cheer beat
        out_body, _pages = _truncate_pages_to_word_cap(
            [body], 150, "Mia", superhero=True
        )
        # We never invent a cheer beat for stories that didn't have one.
        assert not _has_cheer_beat(out_body)


# ---------------------------------------------------------------------------
# Superhero prompts must emit the same metadata schema as the standard prompt
# (themes / characters_featured / emotional_arc) so Superhero stories don't
# silently persist _EMPTY_METADATA. Regression for the gap left by 2706b347
# which only patched the 5 templates inside story_service.py.
# ---------------------------------------------------------------------------
class TestSuperheroPromptEmitsMetadataSchema:
    def test_sprout_superhero_prompt_includes_metadata_keys(self):
        prompt = PromptService.build_story_prompt(
            character="Mia",
            theme="superhero",
            age=4,
            hero_costume_color="purple",
            hero_cape_style="matching",
            hero_emblem="star",
            hero_power="super_smile",
        )
        assert '"themes":' in prompt
        assert '"characters_featured":' in prompt
        assert '"emotional_arc":' in prompt

    def test_explorer_superhero_prompt_includes_metadata_keys(self):
        prompt = PromptService.build_story_prompt(
            character="Leo",
            theme="superhero",
            age=7,
            hero_costume_color="blue",
            hero_cape_style="matching",
            hero_emblem="lightning",
            hero_power="super_speed",
        )
        assert '"themes":' in prompt
        assert '"characters_featured":' in prompt
        assert '"emotional_arc":' in prompt


# ---------------------------------------------------------------------------
# Sprout-band read-aloud + vocabulary hardening (editorial audit, 2026-07-07).
#
# Covers 5 findings from a prod-story audit of Sprout (ages 3-5) output:
#   1. Onomatopoeia was never prompted for.
#   2. Singular "they" reads as plural to a 3-5 year old listener.
#   3. Sensory motifs mixed modalities ("soft pink song").
#   4. Vocabulary drifted into literary words despite a "simple words" line.
#   5. Throwaway objects/side-characters were introduced with no payoff.
# ---------------------------------------------------------------------------
class TestSproutSuperheroPromptReadAloudHardening:
    def _prompt(self, character="Mia", age=4, hero_power="super_smile"):
        return PromptService.build_story_prompt(
            character=character,
            theme="superhero",
            age=age,
            hero_costume_color="purple",
            hero_cape_style="matching",
            hero_emblem="star",
            hero_power=hero_power,
        )

    def test_onomatopoeia_rule_present(self):
        prompt = self._prompt()
        assert "ALL-CAPS onomatopoeia" in prompt
        assert "SPLASH" in prompt and "WHOOSH" in prompt
        assert (
            "tied directly to a specific action" in prompt
            or "tie each one directly" in prompt
        )

    def test_singular_they_is_banned_for_named_hero(self):
        prompt = self._prompt(character="Mia")
        assert 'NEVER refer to Mia as "they"' in prompt
        assert "repeat the name" in prompt
        # The old bare "(he/she/they)" pronoun offer must be gone.
        assert "(he/she/they)" not in prompt

    def test_sensory_motif_single_sense_rule_present(self):
        prompt = self._prompt()
        assert "SINGLE sense" in prompt
        assert "soft pink song" in prompt  # cited as the counter-example to avoid
        assert "color cannot be heard or smelled" in prompt

    def test_object_and_character_economy_rule_present(self):
        prompt = self._prompt()
        assert "Object & character economy" in prompt
        assert "TROUBLE beat" in prompt
        assert "CHEER beat" in prompt
        assert "must pay off" in prompt

    def test_hard_rules_still_include_word_cap_and_villain_softness(self):
        # Regression guard: new rules were appended, not swapped in for the
        # pre-existing safety-critical hard rules.
        prompt = self._prompt()
        assert "MAXIMUM 130 words TOTAL" in prompt
        assert "NEVER through force or punishment" in prompt

    # --- Round-2 fix: "Page N —" label leak (verification run, 2026-07-07) --
    def test_page_label_leak_instruction_present(self):
        prompt = self._prompt()
        assert (
            "do NOT include any page numbers or labels inside the page text" in prompt
        )
        assert "never begin a page's text with a page number or label" in prompt.lower()

    def test_output_format_example_pages_have_no_page_labels(self):
        prompt = self._prompt()
        # The old regression: the JSON example itself modeled "Page 1 -- ..."
        # as the page text, and the model copied that literal prefix onto
        # every generated page. The example text must no longer start that way.
        assert '"text": "Page 1' not in prompt
        assert '"text": "Page 2' not in prompt


class TestSproutGenericAgeGuidelinesHardening:
    def _guidelines(self, age=4):
        return PromptService._get_age_guidelines(age)

    def test_onomatopoeia_rule_present_for_ages_3_5(self):
        guidelines = self._guidelines()
        assert "ALL-CAPS onomatopoeia" in guidelines
        assert "SPLASH" in guidelines

    def test_allowed_vocabulary_list_and_banned_words_present(self):
        guidelines = self._guidelines()
        assert "ALLOWED verbs/adjectives" in guidelines
        for word in ["run", "jump", "happy", "big", "soft"]:
            assert word in guidelines
        for banned in ["spattered", "arced", "flared", "steady", "curious"]:
            assert banned in guidelines  # named explicitly as banned examples
        assert "BANNED" in guidelines

    def test_final_vocabulary_check_step_present(self):
        guidelines = self._guidelines()
        assert "FINAL VOCABULARY CHECK" in guidelines
        assert (
            "do this last" in guidelines.lower()
            or "after drafting" in guidelines.lower()
        )

    def test_older_bands_are_unaffected(self):
        # Regression guard: hardening must stay scoped to the age<=5 branch.
        older = PromptService._get_age_guidelines(9)
        assert "ALLOWED verbs/adjectives" not in older
        assert "ALL-CAPS onomatopoeia" not in older


# ---------------------------------------------------------------------------
# Explorer-band wow-words + anti-template hardening (editorial audit,
# 2026-07-07).
#
# Covers 5 findings from a prod-story audit of an Explorer (ages 6-8) story
# that was spec-compliant but templated:
#   1. No vocabulary instruction at all — zero "wow words" in the story.
#   2. The villain-softening line and closing line were pasted verbatim from
#      the seed text, so every child fighting the same villain gets the same
#      ending.
#   3. The power "solved" the plot via generic noticing any power could do
#      (not load-bearing / not unique to that power).
#   4. A 35-word triple-clause sentence landed at the climax despite the
#      "12 words or fewer on average" rule.
#   5. The refrain appeared once (paragraph 2) and never recurred.
# ---------------------------------------------------------------------------
class TestExplorerSuperheroPromptAntiTemplateHardening:
    def _prompt(self, character="Nova", age=7, hero_power="super_speed"):
        return PromptService.build_story_prompt(
            character=character,
            theme="superhero",
            age=age,
            hero_costume_color="blue",
            hero_cape_style="matching",
            hero_emblem="star",
            hero_power=hero_power,
        )

    def test_wow_words_rule_present(self):
        prompt = self._prompt()
        assert "WOW WORDS" in prompt
        assert "3-4" in prompt
        assert "context clue" in prompt

    def test_seeds_are_plot_ideas_only_rule_present(self):
        prompt = self._prompt()
        assert "SEEDS ARE PLOT IDEAS ONLY" in prompt
        assert "NEVER SENTENCE TEXT TO COPY" in prompt
        # Each per-beat seed label should also carry the "not sentence text to
        # copy" framing, not just the bare "rewrite naturally" phrasing.
        assert "NOT sentence text to copy" in prompt
        assert "rewrite naturally" not in prompt

    def test_power_load_bearing_rule_present(self):
        prompt = self._prompt(hero_power="super_speed")
        assert "POWER MUST BE LOAD-BEARING" in prompt
        assert "mechanism unique to that power" in prompt
        assert "swap in a different power" in prompt or "swapped in" in prompt

    def test_per_sentence_length_cap_present(self):
        prompt = self._prompt()
        assert "NO SINGLE SENTENCE over 16 words" in prompt
        assert "POWER MOMENT sentence especially must be short and punchy" in prompt

    def test_refrain_must_recur_rule_present(self):
        prompt = self._prompt()
        assert "RECURS VERBATIM" in prompt
        assert "paragraph 4 or 5" in prompt

    def test_hard_rules_still_include_existing_explorer_spine(self):
        # Regression guard: new rules were appended, not swapped in for the
        # pre-existing safety-critical hard rules.
        prompt = self._prompt()
        assert "LENGTH: 250-350 words TOTAL" in prompt
        assert "NEVER through force or punishment" in prompt
        assert "NO weapons. NO fighting." in prompt
        assert "mischievous, lonely, or misunderstood" in prompt

    def test_older_and_younger_bands_are_unaffected(self):
        # Regression guard: hardening must stay scoped to the Explorer builder.
        sprout_prompt = PromptService.build_story_prompt(
            character="Mia",
            theme="superhero",
            age=4,
            hero_costume_color="purple",
            hero_cape_style="matching",
            hero_emblem="star",
            hero_power="super_smile",
        )
        assert "WOW WORDS" not in sprout_prompt
        assert "POWER MUST BE LOAD-BEARING" not in sprout_prompt


# ---------------------------------------------------------------------------
# Adventurer-band (9-12) pronoun-plumbing + stakes/structure hardening
# (editorial audit, 2026-07-07). See docstring/comment block above
# ``PromptService._build_superhero_prompt_adventurer`` for the full finding
# list; these tests cover: #1 optional hero_gender/pronoun param, #2 the
# one-beat moral rule, #3 the exactly-6-pages output contract, #4 power
# must gate the solve, and #5 personal-edge stakes.
# ---------------------------------------------------------------------------
class TestAdventurerSuperheroPromptPronounAndStakesHardening:
    def _prompt(self, character="Quinn", age=10, hero_power="strategist", **kwargs):
        return PromptService._build_superhero_prompt_adventurer(
            character=character,
            age=age,
            hero_costume_color="violet",
            hero_cape_style="matching",
            hero_emblem="star",
            hero_power=hero_power,
            villain_id="gigawatt",
            problem_id="outsmart_the_trap",
            **kwargs,
        )

    # --- Finding #1: pronoun plumbing -------------------------------------
    def test_gender_boy_yields_he_him_his_pronoun_rule(self):
        prompt = self._prompt(hero_gender="boy")
        assert "PRONOUNS" in prompt
        assert "he/him/his" in prompt
        assert "Quinn" in prompt

    def test_gender_male_alias_also_resolves_to_he(self):
        prompt = self._prompt(hero_gender="male")
        assert "he/him/his" in prompt

    def test_gender_girl_yields_she_her_her_pronoun_rule(self):
        prompt = self._prompt(hero_gender="girl")
        assert "she/her/her" in prompt

    def test_gender_female_alias_also_resolves_to_she(self):
        prompt = self._prompt(hero_gender="female")
        assert "she/her/her" in prompt

    def test_gender_absent_falls_back_to_repeat_name_no_guess(self):
        prompt = self._prompt(hero_gender=None)
        assert "was not specified" in prompt
        assert "Do NOT" in prompt and "guess" in prompt
        assert "he/him/his" not in prompt
        assert "she/her/her" not in prompt

    def test_gender_unrecognized_value_falls_back_to_repeat_name(self):
        prompt = self._prompt(hero_gender="non-binary")
        assert "was not specified" in prompt

    def test_gender_param_is_backward_compatible_default(self):
        # Existing callers that omit hero_gender entirely must still work.
        prompt = PromptService._build_superhero_prompt_adventurer(
            character="Sam",
            age=10,
            hero_costume_color="green",
            hero_cape_style="matching",
            hero_emblem="leaf",
            hero_power="super_hearing",
            villain_id="gigawatt",
            problem_id="outsmart_the_trap",
        )
        assert isinstance(prompt, str) and len(prompt) > 0
        assert "was not specified" in prompt

    def test_hero_gender_routes_through_build_story_prompt(self):
        prompt = PromptService.build_story_prompt(
            character="Quinn",
            theme="superhero",
            age=10,
            hero_power="strategist",
            hero_gender="boy",
        )
        assert "he/him/his" in prompt

    def test_hero_gender_ignored_for_other_bands(self):
        # Scope guard: only the Adventurer builder consumes hero_gender today.
        explorer_prompt = PromptService.build_story_prompt(
            character="Nova",
            theme="superhero",
            age=7,
            hero_power="super_speed",
            hero_gender="girl",
        )
        assert "PRONOUNS: Nova uses" not in explorer_prompt

    # --- Finding #2: one-beat moral rule -----------------------------------
    def test_one_beat_moral_rule_present(self):
        prompt = self._prompt()
        assert "ONE-BEAT MORAL RULE" in prompt
        assert "ONLY ONCE" in prompt
        assert "UNDERSTANDING scene" in prompt

    def test_power_moment_and_resolution_forbid_re_explaining_need(self):
        prompt = self._prompt()
        assert "Do NOT re-explain or restate the villain's need" in prompt
        assert "Do NOT have the villain re-confess their motive in full" in prompt

    # --- Finding #3: exactly 6 pages, never split ---------------------------
    def test_output_contract_requires_exactly_six_pages(self):
        prompt = self._prompt()
        assert "OUTPUT CONTRACT" in prompt
        assert "EXACTLY 6 entries" in prompt
        assert "NEVER split a single scene" in prompt

    # --- Finding #4: power must gate the solve ------------------------------
    def test_power_must_be_load_bearing_rule_present(self):
        prompt = self._prompt()
        assert "POWER MUST BE LOAD-BEARING" in prompt
        assert "mechanism unique to that power" in prompt
        assert "swapped in" in prompt

    def test_strategist_power_gets_decoy_contingency_language(self):
        prompt = self._prompt(hero_power="strategist")
        assert "decoy" in prompt or "contingency" in prompt or "misdirection" in prompt

    # --- Finding #5: personal-edge stakes -----------------------------------
    def test_personal_stakes_rule_present(self):
        prompt = self._prompt()
        assert "PERSONAL STAKES" in prompt
        assert "felt urgency, not physical danger" in prompt

    # --- Round-2 fix: villain motive/need line must not be copyable verbatim
    def test_villain_motive_anti_copy_rule_present(self):
        prompt = self._prompt()
        assert "SEEDS ARE PLOT IDEAS ONLY" in prompt
        assert "NEVER SENTENCE TEXT TO COPY" in prompt
        assert "villain's stated need in the UNDERSTANDING scene" in prompt

    def test_understanding_seed_marked_plot_idea_not_sentence_text(self):
        prompt = self._prompt()
        assert "Seed idea — a plot idea only, NEVER sentence text to copy" in prompt
        assert "rewrite the need completely in your own words" in prompt

    def test_villain_backstory_line_marked_plot_idea_not_sentence_text(self):
        prompt = self._prompt()
        assert "This is a plot idea only, NEVER sentence text to copy" in prompt

    # --- Regression guards ---------------------------------------------------
    def test_hard_rules_still_include_existing_adventurer_spine(self):
        prompt = self._prompt()
        assert "LENGTH: 900-1500 words TOTAL" in prompt
        assert "NO weapons. NO fighting." in prompt
        assert "NEVER through force, punishment, or fear." in prompt

    def test_older_and_younger_bands_unaffected_by_new_rules(self):
        sprout_prompt = PromptService.build_story_prompt(
            character="Mia",
            theme="superhero",
            age=4,
            hero_power="super_hugs",
        )
        assert "ONE-BEAT MORAL RULE" not in sprout_prompt
        assert "PERSONAL STAKES" not in sprout_prompt
        assert "OUTPUT CONTRACT" not in sprout_prompt

        explorer_prompt = PromptService.build_story_prompt(
            character="Nova",
            theme="superhero",
            age=7,
            hero_power="super_speed",
        )
        assert "ONE-BEAT MORAL RULE" not in explorer_prompt
        assert "PERSONAL STAKES" not in explorer_prompt
        assert "OUTPUT CONTRACT" not in explorer_prompt


# ---------------------------------------------------------------------------
# Creator-band (13-14) editorial-audit hardening (2026-07-07).
#
# Prod "Closed Files" audit findings: near-zero dialogue, the nemesis existed
# only via off-page artifacts, a custom "expose a friend's secret" idea got
# defused by vindicating the friend, essay-voice moralizing in narration, and
# saga_state/page-count drift (8 pages, missing keys). These tests cover the
# prompt-side instructions added to close each gap. Server-side validation of
# the same findings is out of scope (a parallel branch owns that).
# ---------------------------------------------------------------------------
class TestCreatorSuperheroPromptDialogueVillainIntegrityHardening:
    def _prompt(self, character="Maya", age=13, hero_power="strategist", **kwargs):
        return PromptService._build_superhero_prompt_creator(
            character=character,
            age=age,
            hero_costume_color="charcoal",
            hero_cape_style="none",
            hero_emblem="star",
            hero_power=hero_power,
            villain_id="the_optimizer",
            problem_id="outwit_the_mastermind",
            **kwargs,
        )

    # --- Finding #1: dialogue floor -----------------------------------------
    def test_dialogue_hard_rule_present(self):
        prompt = self._prompt()
        assert "DIALOGUE (non-negotiable)" in prompt
        assert "at least 3 of the 7 beats" in prompt
        assert "quoted dialogue" in prompt
        assert "internal-monologue essay" in prompt

    # --- Finding #2: nemesis must appear on-page ----------------------------
    def test_nemesis_on_page_rule_present(self):
        prompt = self._prompt()
        assert "THE NEMESIS ON-PAGE (non-negotiable)" in prompt
        assert "in person, by voice" in prompt
        assert "not solely through leaked files, logs, news reports" in prompt
        assert "THE TRUTH + THE CHOICE or THE RESOLUTION" in prompt

    # --- Finding #3: custom-element integrity -------------------------------
    def test_custom_element_integrity_instruction_present_when_idea_given(self):
        prompt = self._prompt(
            custom_elements="a choice about whether to expose a friend's secret"
        )
        assert "CUSTOM-ELEMENT INTEGRITY" in prompt
        assert "REAL and COSTLY" in prompt
        assert "blameless or innocent all along" in prompt

    def test_custom_element_integrity_instruction_absent_when_no_idea(self):
        prompt = self._prompt(custom_elements="")
        assert "CUSTOM-ELEMENT INTEGRITY" not in prompt
        assert "[USER_INPUT]" not in prompt

    # --- Finding #4: essay-voice anti-moralizing extended to narration -----
    def test_essay_voice_moralizing_forbidden_in_narration_too(self):
        prompt = self._prompt()
        assert "essay-voice moralizing" in prompt
        assert '"it is X, not Y" moralizing' in prompt
        assert "whether spoken in dialogue OR narrated by the prose" in prompt
        assert "never be named" in prompt

    # --- Finding #5: saga_state completeness + exactly 7 pages -------------
    def test_saga_state_all_keys_required_instruction_present(self):
        prompt = self._prompt()
        assert "SAGA STATE IS ALL-REQUIRED" in prompt
        for key in (
            "nemesis",
            "nemesis_status",
            "what_changed",
            "what_it_cost",
            "next_hook",
            "allies",
            "defining_choice",
        ):
            assert key in prompt
        assert 'write "none"' in prompt
        assert "never simply omit the key" in prompt

    def test_output_contract_requires_exactly_seven_pages(self):
        prompt = self._prompt()
        assert "OUTPUT CONTRACT" in prompt
        assert "EXACTLY 7 entries" in prompt
        assert "NEVER split a single beat" in prompt
        assert "EXACTLY 7 pages" in prompt

    # --- Round-2 fix: extend the "learned that" essay-voice ban to Creator --
    def test_learned_that_theme_naming_ban_present(self):
        prompt = self._prompt()
        assert '"learned that"' in prompt
        assert '"understood that"' in prompt
        assert '"realized that"' in prompt
        assert "THE RESOLUTION and AFTERMATH" in prompt

    # --- Regression guards --------------------------------------------------
    def test_existing_creator_spine_untouched(self):
        prompt = self._prompt()
        assert "1100-1800 words" in prompt
        assert "NO weapons" in prompt
        assert "must be ONE of these named Creator villains" in prompt

    def test_other_bands_unaffected_by_new_creator_rules(self):
        adventurer_prompt = PromptService.build_story_prompt(
            character="Quinn",
            theme="superhero",
            age=10,
            hero_power="strategist",
        )
        assert "DIALOGUE (non-negotiable)" not in adventurer_prompt
        assert "THE NEMESIS ON-PAGE" not in adventurer_prompt
        assert "CUSTOM-ELEMENT INTEGRITY" not in adventurer_prompt
        assert "SAGA STATE IS ALL-REQUIRED" not in adventurer_prompt

        explorer_prompt = PromptService.build_story_prompt(
            character="Nova",
            theme="superhero",
            age=7,
            hero_power="super_speed",
        )
        assert "DIALOGUE (non-negotiable)" not in explorer_prompt
        assert "THE NEMESIS ON-PAGE" not in explorer_prompt


class TestAdolescentSuperheroPromptLengthVillainSecretHardening:
    """Editorial audit (2026-07-07): two real prod Adolescent stories (one
    antihero, one classic) both ran ~38% over the 1400-2200 word ceiling AND
    kept the nemesis entirely off-page (reported exposition only) AND, in the
    antihero case, laundered the user's hero_secret into a substitute
    conflict. These tests lock in the prompt-side fixes for both hero_mode
    branches of ``_build_superhero_prompt_adolescent`` (T10).
    """

    def _prompt(self, hero_mode=None, character="Maya", age=16, **kwargs):
        base = dict(
            character=character,
            age=age,
            hero_costume_color="charcoal",
            hero_emblem="star",
            hero_power="strategist",
            hero_mode=hero_mode,
            villain_id="the_double",
            problem_id="expose_the_setup",
        )
        base.update(kwargs)
        return PromptService._build_superhero_prompt_adolescent(**base)

    # --- Finding #1: word ceiling is a hard maximum, with a self-check -----
    def test_antihero_length_is_hard_maximum_with_cut_instruction(self):
        prompt = self._prompt(hero_mode="antihero")
        assert "1400-1900 words" in prompt
        assert "HARD MAXIMUM" in prompt
        assert "cut scene-by-scene until it fits" in prompt
        assert "cut re-explanations" in prompt

    def test_classic_length_is_hard_maximum_with_cut_instruction(self):
        prompt = self._prompt(hero_mode="classic")
        assert "1400-1900 words" in prompt
        assert "HARD MAXIMUM" in prompt
        assert "cut scene-by-scene until it fits" in prompt
        assert "cut re-explanations" in prompt

    def test_antihero_final_length_self_check_before_output(self):
        prompt = self._prompt(hero_mode="antihero")
        assert "final length check" in prompt
        assert "if the draft runs past 1900 words" in prompt

    def test_classic_final_length_self_check_before_output(self):
        prompt = self._prompt(hero_mode="classic")
        assert "final length check" in prompt
        assert "if the draft runs past 1900 words" in prompt

    # --- Round-3 fix: per-page word budget is a hard maximum, with the
    # never-split rule restated immediately adjacent (findings.md — length
    # control; round-2's 200-280 "budget" was read as permission to split a
    # beat across two pages rather than compress it).
    def test_antihero_per_beat_budget_present(self):
        prompt = self._prompt(hero_mode="antihero")
        assert "PER-PAGE BUDGET (HARD MAXIMUM)" in prompt
        assert "180-260 words" in prompt
        assert "HARD MAXIMUM 280" in prompt
        assert "tempted to split a beat into two pages" in prompt
        assert "DON'T — compress the beat instead" in prompt

    def test_classic_per_beat_budget_present(self):
        prompt = self._prompt(hero_mode="classic")
        assert "PER-PAGE BUDGET (HARD MAXIMUM)" in prompt
        assert "180-260 words" in prompt
        assert "HARD MAXIMUM 280" in prompt
        assert "tempted to split a beat into two pages" in prompt
        assert "DON'T — compress the beat instead" in prompt

    # --- Round-2 fix: essay-voice "learned that" routing + concrete AFTERMATH
    def test_antihero_bans_learned_that_theme_naming_in_final_beats(self):
        prompt = self._prompt(hero_mode="antihero")
        assert "NO THEME-NAMING IN THE FINAL TWO BEATS" in prompt
        assert '"learned that"' in prompt
        assert '"understood that"' in prompt
        assert '"realized that"' in prompt
        assert "THE RESOLUTION and AFTERMATH" in prompt
        assert (
            "NEVER a sentence summarizing the lesson or how {character} grew".format(
                character="Maya"
            )
            in prompt
        )

    def test_classic_bans_learned_that_theme_naming_in_final_beats(self):
        prompt = self._prompt(hero_mode="classic")
        assert "NO THEME-NAMING IN THE FINAL TWO BEATS" in prompt
        assert '"learned that"' in prompt
        assert '"understood that"' in prompt
        assert '"realized that"' in prompt
        assert "THE RISE and AFTERMATH" in prompt
        assert (
            "NEVER a sentence summarizing what {character} learned or how they grew".format(
                character="Maya"
            )
            in prompt
        )

    # --- Finding #2: villain must appear on-page, not just reported --------
    def test_antihero_villain_on_page_rule_present(self):
        prompt = self._prompt(hero_mode="antihero")
        assert "THE VILLAIN ON-PAGE (non-negotiable)" in prompt
        assert "in person, by voice" in prompt
        assert (
            "not solely through rumor, hearsay, or reported-about exposition" in prompt
        )
        assert "RELATIONSHIP is the engine" in prompt

    def test_classic_villain_on_page_rule_present(self):
        prompt = self._prompt(hero_mode="classic")
        assert "THE VILLAIN ON-PAGE (non-negotiable)" in prompt
        assert "in person, by voice" in prompt
        assert (
            "not solely through rumor, hearsay, or reported-about exposition" in prompt
        )
        assert "RELATIONSHIP is the engine" in prompt

    # --- Finding #4: anti-aphorism dialogue + essay-voice narration ---------
    def test_antihero_bans_aphorism_dialogue_and_thesis_narration(self):
        prompt = self._prompt(hero_mode="antihero")
        assert "aphorism dialogue that NAMES the lesson" in prompt
        assert '"it is X, not Y" thesis construction' in prompt
        assert "whether spoken in dialogue OR narrated by the prose" in prompt
        assert "fragments, deflections, and specifics" in prompt

    def test_classic_bans_aphorism_dialogue_and_thesis_narration(self):
        prompt = self._prompt(hero_mode="classic")
        assert "aphorism dialogue that NAMES the lesson" in prompt
        assert '"it is X, not Y" thesis construction' in prompt
        assert "whether spoken in dialogue OR narrated by the prose" in prompt
        assert "fragments, deflections, and specifics" in prompt

    # --- Finding #5: hero_secret must surface on the page, verbatim --------
    def test_secret_must_be_spoken_or_thought_on_page(self):
        prompt = self._prompt(hero_mode="antihero", hero_secret="I'm not okay")
        assert "SECRET ON-PAGE (non-negotiable)" in prompt
        assert "must be spoken aloud or explicitly" in prompt
        assert "I'm not okay" in prompt

    def test_secret_on_page_rule_absent_when_no_secret(self):
        prompt = self._prompt(hero_mode="antihero", hero_secret="")
        assert "SECRET ON-PAGE" not in prompt

    def test_secret_care_mandate_must_engage_that_secret_not_a_substitute(self):
        prompt = self._prompt(hero_mode="antihero", hero_secret="I'm not okay")
        # Existing MT-266 care mandate must still be present (not weakened).
        assert "move them at least one step toward being SEEN" in prompt
        assert "isolation is never the" in prompt
        # New: it must engage THIS secret, not a stand-in.
        assert "must engage THIS secret specifically" in prompt
        assert "I'm not okay" in prompt
        assert "not let the case or the villain's scheme stand in for it" in prompt

    def test_secret_care_mandate_absent_from_classic_mode(self):
        # Classic mode intentionally drops the concealment engine entirely.
        prompt = self._prompt(hero_mode="classic", hero_secret="I'm not okay")
        assert "SECRET ON-PAGE" not in prompt
        assert "must engage THIS secret specifically" not in prompt

    # --- Regression guards --------------------------------------------------
    def test_existing_antihero_spine_untouched(self):
        prompt = self._prompt(hero_mode="antihero")
        assert "DOUBLE LIFE" in prompt
        assert "NO weapons" in prompt
        assert "must be ONE of these named figures" in prompt
        assert "morally grey" in prompt.lower()

    def test_existing_classic_spine_untouched(self):
        prompt = self._prompt(hero_mode="classic")
        assert "THE CALLING" in prompt
        assert "NO weapons" in prompt
        assert "must be ONE of these named figures" in prompt
        assert "Aspirational" in prompt

    def test_other_bands_unaffected_by_new_adolescent_rules(self):
        creator_prompt = PromptService.build_story_prompt(
            character="Quinn",
            theme="superhero",
            age=13,
            hero_power="strategist",
        )
        assert "THE VILLAIN ON-PAGE" not in creator_prompt
        assert "SECRET ON-PAGE" not in creator_prompt
        assert "HARD MAXIMUM" not in creator_prompt

        adventurer_prompt = PromptService.build_story_prompt(
            character="Quinn",
            theme="superhero",
            age=10,
            hero_power="strategist",
        )
        assert "THE VILLAIN ON-PAGE" not in adventurer_prompt
        assert "SECRET ON-PAGE" not in adventurer_prompt
