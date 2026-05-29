"""Scoring rubrics for generated stories.

Per audit-05 spec:
- narrative_coherence: 1-5
- age_band_fit: 1-5
- mode_adherence: binary (0 / 1)
- illustration_coherence: 1-5  (only on cells where illustrations are generated)
- refusal_flag: binary (0 / 1) — story missing, safety-blocked, or fell to static fallback

Critical-finding threshold per spec: a cell where >= 20% of outputs fail
the age_band_fit rubric (score < 3) is a Critical finding.

These rubrics are passed verbatim to the LLM judge as part of its system
message. Changes here are audit-significant — bump RUBRIC_VERSION when
editing.
"""

from __future__ import annotations

from dataclasses import dataclass

RUBRIC_VERSION = "1.0"


@dataclass(frozen=True)
class Rubric:
    name: str
    scale: str
    description: str
    judge_prompt: str
    critical_threshold_pct: float | None = None  # cell-failure threshold per audit spec


NARRATIVE_COHERENCE = Rubric(
    name="narrative_coherence",
    scale="1-5 integer",
    description=(
        "Does the story hang together — beginning/middle/end, cause and effect, "
        "no plot holes, characters behave consistently?"
    ),
    judge_prompt=(
        "Score the narrative coherence 1-5:\n"
        "5 = arc complete, internally consistent, every beat earned\n"
        "4 = arc complete, one weak transition or minor inconsistency\n"
        "3 = arc identifiable but one major hole OR two minor ones\n"
        "2 = beats present but disconnected; reads as scenes not a story\n"
        "1 = incoherent, contradictory, or no arc at all"
    ),
)

AGE_BAND_FIT = Rubric(
    name="age_band_fit",
    scale="1-5 integer",
    description=(
        "Is the vocabulary, sentence complexity, emotional register, and theme "
        "treatment correct for the declared age band?"
    ),
    judge_prompt=(
        "The target age band is {age_band}. Score age fit 1-5:\n"
        "5 = pitch-perfect for this band; nothing too young, nothing too old\n"
        "4 = mostly correct; 1-2 word/concept slips up or down a band\n"
        "3 = recognizable for the band but several mismatches\n"
        "2 = consistently mis-pitched (e.g., too sophisticated for 3-5, too simple for teen)\n"
        "1 = wrong band entirely — would belong to a different cell\n"
        "Be strict on Sprout (3-4) — CVC words and 5-8 word sentences are mandatory."
    ),
    critical_threshold_pct=20.0,  # per audit spec
)

MODE_ADHERENCE = Rubric(
    name="mode_adherence",
    scale="0 or 1",
    description=("Did the output follow the structural rules of the requested mode?"),
    judge_prompt=(
        "The requested mode is {mode}. Score binary:\n"
        "1 = mode rules followed (e.g., rhyme present for LTR/Rhyme Time, "
        "soothing for Bedtime, villain/cheer-beat for Superhero)\n"
        "0 = mode rules violated or ignored"
    ),
)

ILLUSTRATION_COHERENCE = Rubric(
    name="illustration_coherence",
    scale="1-5 integer or null",
    description=(
        "Does each illustration depict what its page's text describes? "
        "Null if the cell does not generate illustrations in this run."
    ),
    judge_prompt=(
        "For each (page_text, image_caption) pair, score 1-5:\n"
        "5 = caption describes exactly the page's key action and characters\n"
        "4 = right scene, minor detail mismatch\n"
        "3 = right characters but wrong action, or vice versa\n"
        "2 = same world but wrong scene\n"
        "1 = no visible relationship to the page text\n"
        "Report the page-level mean for the story."
    ),
)

REFUSAL_FLAG = Rubric(
    name="refusal_flag",
    scale="0 or 1",
    description=(
        "Did this cell fail to produce a usable story (safety block, empty "
        "response, static-fallback, JSON parse failure persisted through retry)?"
    ),
    judge_prompt=(
        "Score binary:\n"
        "1 = no usable story (static fallback returned, safety block, or "
        "validation failed all retries)\n"
        "0 = a real story was returned"
    ),
)

ALL_RUBRICS: tuple[Rubric, ...] = (
    NARRATIVE_COHERENCE,
    AGE_BAND_FIT,
    MODE_ADHERENCE,
    ILLUSTRATION_COHERENCE,
    REFUSAL_FLAG,
)


def by_name(name: str) -> Rubric:
    for r in ALL_RUBRICS:
        if r.name == name:
            return r
    raise KeyError(name)
