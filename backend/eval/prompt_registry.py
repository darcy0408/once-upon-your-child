"""Versioned snapshot of every prompt template in the story-generation pipeline.

Snapshot date: 2026-05-21
Snapshot git SHA: 390de0e5 (HEAD when this file was first written)

This module does NOT import from backend.services. It records source-file
pointers and content hashes so `snapshot.py --verify` can detect drift.

To add or update a template: edit the entry, then run
`python -m backend.eval.snapshot --refresh` to recompute content_hash.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Sequence

SNAPSHOT_GIT_SHA = "390de0e5"
SNAPSHOT_DATE = "2026-05-21"

# Code-side age band keys. Note these differ from memory's customer-facing
# names (Sprout 3-5, Explorer 6-8, Adventurer 9-12) — see findings F-04.
AGE_BANDS = ("3-4", "5-7", "8-10", "11-13", "13-15", "15-18", "adult")

# Code-side mode names. Pick-a-Path / Interactive is a different endpoint
# (not story_service.py); excluded from this registry. See finding F-05.
MODES = (
    "standard",
    "ltr_limerick",
    "ltr_seussian",
    "rhyme_time",
    "bedtime",
    "superhero",
)


@dataclass(frozen=True)
class PromptTemplate:
    template_id: str
    source_file: str
    line_start: int
    line_end: int
    mode: str
    age_bands: Sequence[str]
    builder_function: str
    output_format: str
    interpolated_vars: Sequence[str]
    description: str
    content_hash: str = ""  # filled by snapshot.py
    version_metadata_present: bool = False  # always False today — see F-01


TEMPLATES: tuple[PromptTemplate, ...] = (
    PromptTemplate(
        template_id="T1_STANDARD",
        content_hash="d02a08ad670b20f3",
        source_file="backend/services/story_service.py",
        line_start=770,
        line_end=816,
        mode="standard",
        age_bands=AGE_BANDS,
        builder_function="AdvancedStoryEngine.generate_enhanced_prompt",
        output_format="json: title, themes, characters_featured, emotional_arc, pages[].text, pages[].image_prompt",
        interpolated_vars=(
            "character", "age", "theme", "gender", "strengths", "special_ability",
            "companion_name", "companion_kind", "custom_elements", "world_bible",
            "conflict_hook", "sensory_palette", "mood_rules", "feelings_instruction",
            "virtue_instruction", "word_range", "per_page_words", "word_ceiling_note",
            "sprout_page_rule", "complexity_instruction", "hard_complexity_constraints",
            "young_delight_rules",
        ),
        description="Master Storyteller persona; 3-act arc; hero-centric; emotion/virtue modeling.",
    ),
    PromptTemplate(
        template_id="T2_LTR_LIMERICK",
        content_hash="a4cfef301ab55f21",
        source_file="backend/services/story_service.py",
        line_start=1268,
        line_end=1306,
        mode="ltr_limerick",
        age_bands=("5-7", "8-10", "11-13", "13-15"),  # 6+ per Explore map
        builder_function="_build_learning_to_read_prompt (limericks branch)",
        output_format="json: title, rhyme_scheme, themes, characters_featured, emotional_arc, pages[].text",
        interpolated_vars=(
            "num_pages", "character_name", "theme", "comp_str",
            "mandatory_names_str", "custom_elements",
        ),
        description="Connected limericks, AABBA rhyme, phonics-friendly, Seussian humor.",
    ),
    PromptTemplate(
        template_id="T3_LTR_SEUSSIAN",
        content_hash="1b102c5638049c1a",
        source_file="backend/services/story_service.py",
        line_start=1308,
        line_end=1354,
        mode="ltr_seussian",
        age_bands=AGE_BANDS,
        builder_function="_build_learning_to_read_prompt (non-limerick branch)",
        output_format="json: title, rhyme_scheme, themes, characters_featured, emotional_arc, pages[].text",
        interpolated_vars=(
            "num_pages", "character_name", "theme", "comp_str",
            "mandatory_names_str", "custom_elements", "format_instruction",
            "vocab_instruction", "rhyme_scheme_instruction",
        ),
        description="Dr. Seuss bouncy rhythm, AABB couplets, hard cap 25 words/page.",
    ),
    PromptTemplate(
        template_id="T4_RHYME_TIME",
        content_hash="9255c50fc20ab829",
        source_file="backend/services/story_service.py",
        line_start=1510,
        line_end=1542,
        mode="rhyme_time",
        age_bands=AGE_BANDS,
        builder_function="_build_rhyme_time_prompt",
        output_format="json: title, themes, characters_featured, emotional_arc, pages[].text",
        interpolated_vars=(
            "character_name", "gender_text", "age", "theme", "conflict_hook",
            "world_bible", "sensory_palette", "strengths", "special_ability",
            "age_instruction", "rhyme_scheme_instruction", "requirements_line",
            "comp_str", "mandatory_names_str", "custom_elements", "config_notes",
        ),
        description="Narrative poetry; ballad/sonnet/limerick scaled by age band.",
    ),
    PromptTemplate(
        template_id="T5_BEDTIME",
        content_hash="9c50e9e35bfc9aee",
        source_file="backend/services/story_service.py",
        line_start=1691,
        line_end=1753,
        mode="bedtime",
        age_bands=AGE_BANDS,
        builder_function="_build_bedtime_prompt",
        output_format="json: title, themes, characters_featured, emotional_arc, pages[].text",
        interpolated_vars=(
            "heroes_str", "all_mandatory", "comp_str", "world_desc", "tone_hint",
            "age_notes", "word_range", "SAFETY_GUARDRAILS", "STRICT_OUTPUT_CONSTRAINTS",
        ),
        description="Soothing prose; no chases/battles; cozy ending; sleep cues.",
    ),
    PromptTemplate(
        template_id="T6_SUPERHERO_SPROUT",
        content_hash="765a868cabf7309f",
        source_file="backend/services/prompt_service.py",
        line_start=284,
        line_end=414,
        mode="superhero",
        age_bands=("3-4",),
        builder_function="_build_superhero_prompt",
        output_format="json: same shape as T1",
        interpolated_vars=(
            "character", "age", "hero_costume_color", "hero_cape_style",
            "hero_emblem", "hero_power", "villain_name", "villain_weakness",
            "villain_problem_desc", "problem_consequence",
        ),
        description="6-beat villain matrix; 100-150 word cap; cheer-beat ending.",
    ),
    PromptTemplate(
        template_id="T7_SUPERHERO_EXPLORER",
        content_hash="f23efcafd6cea63f",
        source_file="backend/services/prompt_service.py",
        line_start=415,
        line_end=574,
        mode="superhero",
        age_bands=("5-7",),
        builder_function="_build_superhero_prompt_explorer",
        output_format="json: same shape as T1",
        interpolated_vars=(
            "character", "age", "hero_costume_color", "hero_cape_style",
            "hero_emblem", "hero_power", "villain_name", "villain_power",
            "villain_weakness", "problem_desc", "problem_consequence",
        ),
        description="6-beat villain matrix; 250-350 word cap; richer prose than Sprout.",
    ),
    # T8-T14 are injection fragments not directly sent to the LLM; the harness
    # records whether they were active for a given generation in the metadata
    # column, but does not score them as standalone templates.
    PromptTemplate(
        template_id="T8_SAFETY_GUARDRAILS",
        content_hash="d22eae8afc8d11d8",
        source_file="backend/services/story_service.py",
        line_start=149,
        line_end=155,
        mode="*",
        age_bands=AGE_BANDS,
        builder_function="(static const, injected into all prompts)",
        output_format="(no direct output)",
        interpolated_vars=(),
        description="No sexual/violent/self-harm/illegal; warm age-appropriate tone.",
    ),
    PromptTemplate(
        template_id="T9_STRICT_OUTPUT",
        content_hash="d5821a3f674a9f2e",
        source_file="backend/services/story_service.py",
        line_start=126,
        line_end=137,
        mode="*",
        age_bands=AGE_BANDS,
        builder_function="(static const, injected into all prompts)",
        output_format="(no direct output)",
        interpolated_vars=(),
        description="USER_INPUT boundary, immersion rules, no AI preambles, JSON-only.",
    ),
    PromptTemplate(
        template_id="T11_VIRTUE",
        content_hash="6c68bf3ea15fe035",
        source_file="backend/services/story_service.py",
        line_start=159,
        line_end=214,
        mode="standard",
        age_bands=AGE_BANDS,
        builder_function="_get_virtue_instruction",
        output_format="(conditional injection into T1)",
        interpolated_vars=("therapeutic_prompt", "age"),
        description="Invisible virtue modeling; keyword-mapped; never named in story.",
    ),
    PromptTemplate(
        template_id="T12_FEELINGS",
        content_hash="5c396364fca19032",
        source_file="backend/services/story_service.py",
        line_start=217,
        line_end=259,
        mode="standard",
        age_bands=AGE_BANDS,
        builder_function="_build_feelings_instruction",
        output_format="(conditional injection into T1)",
        interpolated_vars=("feelings_prompt", "age", "theme"),
        description="Feelings-first scaffolding; body clues, coping-action plot beat.",
    ),
    PromptTemplate(
        template_id="T13_PRIOR_ADVENTURES",
        content_hash="c8d7a5b1ef3b7809",
        source_file="backend/services/story_service.py",
        line_start=405,
        line_end=504,
        mode="standard",
        age_bands=AGE_BANDS,
        builder_function="_build_prior_adventures_block",
        output_format="(conditional injection at top of T1)",
        interpolated_vars=("character_id",),
        description="Recall of prior themes/cast; vary or build on rather than repeat.",
    ),
)


# Templates that are directly sent to the LLM as a complete prompt.
# T8/T9 (static injections) and T11/T12/T13 (conditional injections) are
# fragments composed into T1 — they don't define independent cells.
SENDABLE_TEMPLATE_IDS = frozenset({
    "T1_STANDARD", "T2_LTR_LIMERICK", "T3_LTR_SEUSSIAN",
    "T4_RHYME_TIME", "T5_BEDTIME",
    "T6_SUPERHERO_SPROUT", "T7_SUPERHERO_EXPLORER",
})

# Valid (mode, age_band) cells. Deduped — multiple fragments may share a mode.
def _build_valid_cells() -> tuple[tuple[str, str], ...]:
    seen: set[tuple[str, str]] = set()
    for t in TEMPLATES:
        if t.template_id not in SENDABLE_TEMPLATE_IDS:
            continue
        for band in t.age_bands:
            seen.add((t.mode, band))
    return tuple(sorted(seen))


VALID_CELLS: tuple[tuple[str, str], ...] = _build_valid_cells()


def by_id(template_id: str) -> PromptTemplate:
    for t in TEMPLATES:
        if t.template_id == template_id:
            return t
    raise KeyError(template_id)


def for_cell(mode: str, age_band: str) -> tuple[PromptTemplate, ...]:
    return tuple(
        t for t in TEMPLATES
        if t.mode == mode and age_band in t.age_bands
    )
