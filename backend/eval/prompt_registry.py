"""Versioned snapshot of every prompt template in the story-generation pipeline.

Snapshot date: 2026-08-03
Snapshot git SHA: 3e17a911 (HEAD when the anchors were re-baselined)

This module does NOT import from backend.services. It records source-file
pointers and content hashes so `snapshot.py --verify` can detect drift.

Templates are pinned by ``anchors`` — dotted symbol paths (``Class.method``,
``module_function``, ``MODULE_CONSTANT``) resolved against the current source
with `ast`. They were pinned by absolute line number until 2026-08-03, by which
point every window had slid off its builder and the detector had been reporting
on unrelated code for months (MT-392). Never reintroduce line numbers here: an
anchor must move when its builder is edited and stay put when anything above it
is edited, and only a symbol does both.

A template may list several anchors when its prompt text is split across a
builder and the data it reads (e.g. T11 = ``_get_virtue_instruction`` plus
``VIRTUE_MAP``, which holds the actual virtue prose). Spans are concatenated in
listed order before hashing.

To add or update a template: edit the entry, then run
`python -m backend.eval.snapshot --refresh` to recompute content_hash.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Sequence

SNAPSHOT_GIT_SHA = "3e17a911"
SNAPSHOT_DATE = "2026-08-03"

# Code-side age band keys. Note these differ from memory's customer-facing
# names (Sprout 3-5, Explorer 6-8, Adventurer 9-12) — see findings F-04.
# Each entry's age_bands is the nearest-overlapping key, with the real range
# in a trailing comment; F-04 (realigning these keys) remains open.
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
    anchors: Sequence[str]
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
        content_hash="33ef5b2089822340",
        source_file="backend/services/story_service.py",
        anchors=("AdvancedStoryEngine.generate_enhanced_prompt",),
        mode="standard",
        age_bands=AGE_BANDS,
        builder_function="AdvancedStoryEngine.generate_enhanced_prompt",
        output_format="json: title, themes, characters_featured, emotional_arc, pages[].text",
        interpolated_vars=(
            "character",
            "age",
            "theme",
            "gender",
            "strengths",
            "special_ability",
            "companion_name",
            "companion_kind",
            "custom_elements",
            "world_bible",
            "conflict_hook",
            "sensory_palette",
            "mood_rules",
            "feelings_instruction",
            "virtue_instruction",
            "word_range",
            "per_page_words",
            "word_ceiling_note",
            "sprout_page_rule",
            "complexity_instruction",
            "hard_complexity_constraints",
            "young_delight_rules",
        ),
        description="Master Storyteller persona; 3-act arc; hero-centric; emotion/virtue modeling.",
    ),
    # T2 and T3 share one builder: LTR's CVC / Seuss / limerick / prose branches
    # all live inside _build_learning_to_read_prompt, so both hash the whole
    # function and an edit to either branch drifts both. Over-flagging is the
    # safe direction; finer attribution needs the function split (see the same
    # note in backend/services/prompt_versioning.py).
    PromptTemplate(
        template_id="T2_LTR_LIMERICK",
        content_hash="cde8a82daaa09eb0",
        source_file="backend/services/story_service.py",
        anchors=("_build_learning_to_read_prompt",),
        mode="ltr_limerick",
        age_bands=("5-7", "8-10", "11-13", "13-15"),  # 6+ per Explore map
        builder_function="_build_learning_to_read_prompt (limericks branch)",
        output_format="json: title, rhyme_scheme, themes, characters_featured, emotional_arc, pages[].text",
        interpolated_vars=(
            "num_pages",
            "character_name",
            "theme",
            "comp_str",
            "mandatory_names_str",
            "custom_elements",
        ),
        description="Connected limericks, AABBA rhyme, phonics-friendly, Seussian humor.",
    ),
    PromptTemplate(
        template_id="T3_LTR_SEUSSIAN",
        content_hash="cde8a82daaa09eb0",
        source_file="backend/services/story_service.py",
        anchors=("_build_learning_to_read_prompt",),
        mode="ltr_seussian",
        age_bands=AGE_BANDS,
        builder_function="_build_learning_to_read_prompt (non-limerick branch)",
        output_format="json: title, rhyme_scheme, themes, characters_featured, emotional_arc, pages[].text",
        interpolated_vars=(
            "num_pages",
            "character_name",
            "theme",
            "comp_str",
            "mandatory_names_str",
            "custom_elements",
            "format_instruction",
            "vocab_instruction",
            "rhyme_scheme_instruction",
        ),
        description="Dr. Seuss bouncy rhythm, AABB couplets, hard cap 25 words/page.",
    ),
    PromptTemplate(
        template_id="T4_RHYME_TIME",
        content_hash="7c8cbe11d09d7258",
        source_file="backend/services/story_service.py",
        anchors=("_build_rhyme_time_prompt",),
        mode="rhyme_time",
        age_bands=AGE_BANDS,
        builder_function="_build_rhyme_time_prompt",
        output_format="json: title, themes, characters_featured, emotional_arc, pages[].text",
        interpolated_vars=(
            "character_name",
            "gender_text",
            "age",
            "theme",
            "conflict_hook",
            "world_bible",
            "sensory_palette",
            "strengths",
            "special_ability",
            "age_instruction",
            "rhyme_scheme_instruction",
            "requirements_line",
            "comp_str",
            "mandatory_names_str",
            "custom_elements",
            "config_notes",
        ),
        description="Narrative poetry; ballad/sonnet/limerick scaled by age band.",
    ),
    PromptTemplate(
        template_id="T5_BEDTIME",
        content_hash="1616846927f93e82",
        source_file="backend/services/story_service.py",
        anchors=("_build_bedtime_prompt",),
        mode="bedtime",
        age_bands=AGE_BANDS,
        builder_function="_build_bedtime_prompt",
        output_format="json: title, themes, characters_featured, emotional_arc, pages[].text",
        interpolated_vars=(
            "heroes_str",
            "all_mandatory",
            "comp_str",
            "world_desc",
            "tone_hint",
            "age_notes",
            "word_range",
            "SAFETY_GUARDRAILS",
            "STRICT_OUTPUT_CONSTRAINTS",
        ),
        description="Soothing prose; no chases/battles; cozy ending; sleep cues.",
    ),
    PromptTemplate(
        template_id="T6_SUPERHERO_SPROUT",
        content_hash="a25cc46433ddb955",
        source_file="backend/services/prompt_service.py",
        anchors=("PromptService._build_superhero_prompt",),
        mode="superhero",
        age_bands=("3-4",),  # Sprout, ages 3-5
        builder_function="PromptService._build_superhero_prompt",
        output_format="json: same shape as T1",
        interpolated_vars=(
            "character",
            "age",
            "hero_costume_color",
            "hero_cape_style",
            "hero_emblem",
            "hero_power",
            "villain_name",
            "villain_weakness",
            "villain_problem_desc",
            "problem_consequence",
        ),
        description="6-beat villain matrix; 100-150 word cap; cheer-beat ending.",
    ),
    PromptTemplate(
        template_id="T7_SUPERHERO_EXPLORER",
        content_hash="92f08e223ac8a999",
        source_file="backend/services/prompt_service.py",
        anchors=("PromptService._build_superhero_prompt_explorer",),
        mode="superhero",
        age_bands=("5-7",),  # Explorer, ages 6-8
        builder_function="PromptService._build_superhero_prompt_explorer",
        output_format="json: same shape as T1",
        interpolated_vars=(
            "character",
            "age",
            "hero_costume_color",
            "hero_cape_style",
            "hero_emblem",
            "hero_power",
            "villain_name",
            "villain_power",
            "villain_weakness",
            "problem_desc",
            "problem_consequence",
        ),
        description="6-beat villain matrix; 250-350 word cap; richer prose than Sprout.",
    ),
    PromptTemplate(
        template_id="T8_SUPERHERO_ADVENTURER",
        content_hash="ef8790251753f0ca",
        source_file="backend/services/prompt_service.py",
        anchors=("PromptService._build_superhero_prompt_adventurer",),
        mode="superhero",
        age_bands=("8-10",),  # Adventurer, ages 9-12
        builder_function="PromptService._build_superhero_prompt_adventurer",
        output_format="json: same shape as T1",
        interpolated_vars=(
            "character",
            "age",
            "hero_costume_color",
            "hero_cape_style",
            "hero_emblem",
            "hero_power",
            "villain_name",
            "villain_motive",
            "problem_desc",
            "problem_summary",
        ),
        description=(
            "6-scene hero arc; real villain WITH a motive (sometimes a point); "
            "900-1500 words; non-violent, understanding-based resolution."
        ),
    ),
    PromptTemplate(
        template_id="T9_SUPERHERO_CREATOR",
        content_hash="743b11c0cea5195b",
        source_file="backend/services/prompt_service.py",
        anchors=("PromptService._build_superhero_prompt_creator",),
        mode="superhero",
        age_bands=("13-15", "adult"),  # Creator, ages 13-14 and 18+
        builder_function="PromptService._build_superhero_prompt_creator",
        output_format="json: same shape as T1, plus saga_state for continuity",
        interpolated_vars=(
            "character",
            "age",
            "hero_costume_color",
            "hero_cape_style",
            "hero_emblem",
            "hero_power",
            "villain_id",
            "problem_id",
            "hero_catchphrase",
            "hero_alias",
            "custom_elements",
            "prior_saga",
        ),
        description=(
            "Creator-band Hero Saga Issue; villain/problem pairing via "
            "pick_pairing(band='creator'); emits saga_state so Phase 2 can "
            "serialize continuity."
        ),
    ),
    PromptTemplate(
        template_id="T10_ANTIHERO_ADOLESCENT",
        content_hash="92dd42ec74527076",
        source_file="backend/services/prompt_service.py",
        anchors=("PromptService._build_superhero_prompt_adolescent",),
        mode="superhero",
        age_bands=("15-18",),  # Adolescent, ages 15-17
        builder_function="PromptService._build_superhero_prompt_adolescent",
        output_format="json: same shape as T1, plus saga_state for continuity",
        interpolated_vars=(
            "character",
            "age",
            "hero_costume_color",
            "hero_emblem",
            "hero_power",
            "hero_mode",
            "villain_id",
            "problem_id",
            "hero_catchphrase",
            "hero_secret",
            "hero_tell",
            "hero_line",
            "hero_seen_by",
            "custom_elements",
            "prior_saga",
        ),
        description=(
            "Adolescent antihero 'double life' Issue; Edge matrix "
            "(social/identity-scale antagonists, powers with a built-in cost); "
            "mirrors Creator's saga_state/JSON contract."
        ),
    ),
    # The fragment entries below are injections, not standalone prompts: the
    # harness records whether each was active for a given generation in the
    # metadata column but does not score them as independent cells.
    #
    # Numbering caveat: the "T<n>" labels are display labels, not a namespace,
    # and two pairs collide — T8_SAFETY_GUARDRAILS with T8_SUPERHERO_ADVENTURER,
    # and T9_STRICT_OUTPUT with T9_SUPERHERO_CREATOR. Within each pair the
    # template_ids are distinct, so lookups are unambiguous. The sendable ids
    # are the ones that win a collision: prompt_versioning.py persists them on
    # Story rows, so renaming those would orphan production attribution data.
    PromptTemplate(
        template_id="T8_SAFETY_GUARDRAILS",
        content_hash="e6902fa9d691680c",
        source_file="backend/services/story_service.py",
        anchors=("SAFETY_GUARDRAILS",),
        mode="*",
        age_bands=AGE_BANDS,
        builder_function="(static const, injected into all prompts)",
        output_format="(no direct output)",
        interpolated_vars=(),
        description="No sexual/violent/self-harm/illegal; warm age-appropriate tone.",
    ),
    PromptTemplate(
        template_id="T9_STRICT_OUTPUT",
        content_hash="1fe0d2f5081e954b",
        source_file="backend/services/story_service.py",
        anchors=("STRICT_OUTPUT_CONSTRAINTS",),
        mode="*",
        age_bands=AGE_BANDS,
        builder_function="(static const, injected into all prompts)",
        output_format="(no direct output)",
        interpolated_vars=(),
        description="USER_INPUT boundary, immersion rules, no AI preambles, JSON-only.",
    ),
    PromptTemplate(
        template_id="T11_VIRTUE",
        content_hash="5757d83972e1e117",
        source_file="backend/services/story_service.py",
        # VIRTUE_MAP holds the virtue prose itself, so it is part of the
        # template — hashing the builder alone would miss every wording change.
        anchors=("_get_virtue_instruction", "VIRTUE_MAP"),
        mode="standard",
        age_bands=AGE_BANDS,
        builder_function="_get_virtue_instruction",
        output_format="(conditional injection into T1)",
        interpolated_vars=("therapeutic_prompt", "age"),
        description="Invisible virtue modeling; keyword-mapped; never named in story.",
    ),
    PromptTemplate(
        template_id="T12_FEELINGS",
        content_hash="353143dc59eff9ff",
        source_file="backend/services/story_service.py",
        anchors=("_build_feelings_instruction",),
        mode="standard",
        age_bands=AGE_BANDS,
        builder_function="_build_feelings_instruction",
        output_format="(conditional injection into T1)",
        interpolated_vars=("feelings_prompt", "age", "theme"),
        description="Feelings-first scaffolding; body clues, coping-action plot beat.",
    ),
    PromptTemplate(
        template_id="T13_PRIOR_ADVENTURES",
        content_hash="cba50a615cb027c1",
        source_file="backend/services/story_service.py",
        anchors=("_build_prior_adventures_block",),
        mode="standard",
        age_bands=AGE_BANDS,
        builder_function="_build_prior_adventures_block",
        output_format="(conditional injection at top of T1)",
        interpolated_vars=("character_id",),
        description="Recall of prior themes/cast; vary or build on rather than repeat.",
    ),
)


# Templates that are directly sent to the LLM as a complete prompt.
# T8_SAFETY_GUARDRAILS/T9_STRICT_OUTPUT (static injections) and T11/T12/T13
# (conditional injections) are fragments composed into T1 — they don't define
# independent cells.
SENDABLE_TEMPLATE_IDS = frozenset(
    {
        "T1_STANDARD",
        "T2_LTR_LIMERICK",
        "T3_LTR_SEUSSIAN",
        "T4_RHYME_TIME",
        "T5_BEDTIME",
        "T6_SUPERHERO_SPROUT",
        "T7_SUPERHERO_EXPLORER",
        "T8_SUPERHERO_ADVENTURER",
        "T9_SUPERHERO_CREATOR",
        "T10_ANTIHERO_ADOLESCENT",
    }
)


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
    return tuple(t for t in TEMPLATES if t.mode == mode and age_band in t.age_bands)
