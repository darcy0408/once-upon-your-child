"""Single source of truth for story word-count ranges.

Why this module exists (word-range unification, 2026-07): the prompt's stated
word target, the post-generation validation floor, and the post-generation
word caps used to come from THREE independent hardcoded tables that
contradicted each other. Several band/mode combinations were mathematically
unsatisfiable — e.g. the Explorer (6-8) Superhero prompt demanded 250-350
words while the validator's floor demanded 500-700, so every such story
failed validation on every attempt, burned 2-3 full LLM generations, and then
got truncated back to 350 anyway.

Now all three numbers derive from ONE canonical range — the range the live
prompt actually states (the prompts are the tuned artifact; the validator and
caps are what drifted):

    floor = FLOOR_RATIO * target_min   (tolerant: catches pathologically
                                        short output, not exact counts)
    cap   = CAP_RATIO   * target_max   (modest headroom before the post-gen
                                        truncate/regen belt kicks in)

Import direction (deliberate, to avoid cycles):

    word_ranges  ->  story_service         (canonical prompt tables:
                                            AGE_CONSTRAINTS, bedtime ranges,
                                            sprout page override, duration
                                            helper)
    word_ranges  ->  superhero_validation  (canonical superhero band specs,
                                            already transcribed from the
                                            prompt builders)
    story_tasks  ->  word_ranges           (validation floor + post-gen caps)

``story_service`` must NOT import this module — its prompt builders OWN the
canonical numbers this module reads.
"""

from __future__ import annotations

from dataclasses import dataclass

from .story_service import (
    _BEDTIME_WORD_RANGES,
    AGE_CONSTRAINTS,
    _duration_minutes_to_word_range,
    _get_age_band,
    _narration_wpm_for_age,
    _story_duration_to_minutes,
)
from .superhero_validation import SUPERHERO_BAND_SPECS

# Floor is deliberately BELOW target_min: the validation loop exists to catch
# pathologically short output (a 3-sentence "story" for a 12-year-old), not to
# re-litigate exact word counts the model already landed near.
FLOOR_RATIO = 0.75
# Cap is deliberately ABOVE target_max: a story a bit over target reads fine;
# the truncate/regen belt should only fire on real overshoots.
CAP_RATIO = 1.20

# Sprout (ages <=5) standard stories are page-driven: the live prompt
# (story_service.generate_enhanced_prompt) overrides the band word range to
# pages*12..pages*25 with short=8 / medium=10 / long=12 pages.
_SPROUT_PAGES_BY_LENGTH = {"short": 8, "medium": 10, "long": 12}
_SPROUT_WORDS_PER_PAGE = (12, 25)


@dataclass(frozen=True)
class WordRangeSpec:
    """Canonical word-count contract for one (age, mode, length/duration)."""

    target_min: int  # what the prompt asks for (lower bound)
    target_max: int  # what the prompt asks for (upper bound)
    floor: int  # validation minimum (below this -> retry)
    cap: int  # post-generation maximum (above this -> regen/truncate belt)
    source: str  # human-readable provenance, for logs/tests


def normalize_length_key(story_length: str | None) -> str:
    """Map the API's story_length vocabulary onto short/medium/long.

    Mirrors the mapping used by every prompt builder ('quick'->short,
    'epic'->long, everything else including 'standard'->medium).
    """
    if story_length in ("short", "quick"):
        return "short"
    if story_length in ("long", "epic"):
        return "long"
    return "medium"


def superhero_band_for_age(age) -> str:
    """Map a hero's age to the Superhero Mode band.

    3-5 -> sprout, 6-8 -> explorer, 9-12 -> adventurer, 13-14 -> creator,
    15-17 -> adolescent, 18+ -> creator. Anything else (invalid/negative/
    unparseable age) defaults to sprout so legacy callers keep working.

    MUST mirror ``PromptService.build_story_prompt``'s age-band routing
    (backend/services/prompt_service.py ~L96-197) EXACTLY, same thresholds.
    That function computes its OWN band from `age` and re-derives the
    villain/problem pairing whenever the id it's handed isn't valid for ITS
    band — so if this derivation drifts from prompt_service's, the prompt
    builder silently re-picks a DIFFERENT pairing than the one reported back
    in `superhero_meta`, breaking saga continuity and analytics.
    """
    try:
        age_int = int(age) if age is not None else 5
    except (TypeError, ValueError):
        age_int = 5
    if 6 <= age_int <= 8:
        return "explorer"
    if 9 <= age_int <= 12:
        return "adventurer"
    if 13 <= age_int <= 14:
        return "creator"
    if age_int >= 18:
        # No dedicated Adult superhero template; prompt_service routes 18+
        # to the Creator "Hero Saga" builder too.
        return "creator"
    if 15 <= age_int <= 17:
        return "adolescent"
    return "sprout"


def _normalize_age(age) -> int:
    try:
        return int(age) if age is not None else 5
    except (TypeError, ValueError):
        return 5


def get_word_range(
    age,
    mode: str = "standard",
    story_length: str | None = "standard",
    story_duration: str | None = None,
    duration_minutes: int | None = None,
    superhero_band: str | None = None,
) -> WordRangeSpec:
    """Return the canonical (target, floor, cap) word-count contract.

    Args:
        age: hero age (int-ish; invalid values default to 5, like the task).
        mode: 'standard' | 'superhero' | 'bedtime' | 'rhyme' | 'ltr'.
            Bedtime WINS over superhero for a bedtime saga chapter — the
            bedtime overlay explicitly overrides the base prompt's length
            rules — so callers pass mode='bedtime' for that combination.
        story_length: 'quick'/'short'/'standard'/'medium'/'long'/'epic'.
        story_duration: API duration string ('5_minutes'/'10_minutes'); used
            by STANDARD mode only, at an age-appropriate narration WPM.
        duration_minutes: explicit minutes (bedtime's duration override).
            When set for bedtime it OVERRIDES the band table — that is the
            designed behavior, preserved here.
        superhero_band: explicit band from superhero_meta; derived from age
            when omitted.

    Notes:
        - Sprout (<=5) STANDARD stories are page-driven (8-12 pages x 10-25
          words); the page-based range wins over story_duration, mirroring
          the prompt builder's own override order.
        - LTR is validated in PAGES, not words; its word range here is a
          pages*10..pages*25 proxy used only for the cap/floor invariants.
    """
    age_int = _normalize_age(age)
    mode_key = (mode or "standard").strip().lower()
    length_key = normalize_length_key(story_length)
    band = _get_age_band(age_int)

    if mode_key == "bedtime":
        minutes = duration_minutes or _story_duration_to_minutes(story_duration)
        if minutes and minutes > 0:
            # Explicit duration OVERRIDES band caps — bedtime design.
            lo, hi = _duration_minutes_to_word_range(minutes)
            source = f"bedtime:duration:{minutes}m"
        else:
            lo, hi = _BEDTIME_WORD_RANGES.get(band, _BEDTIME_WORD_RANGES["5-7"])[
                length_key
            ]
            source = f"bedtime:{band}:{length_key}"
    elif mode_key == "superhero":
        sh_band = superhero_band or superhero_band_for_age(age_int)
        spec = SUPERHERO_BAND_SPECS.get(sh_band) or SUPERHERO_BAND_SPECS["sprout"]
        lo, hi = spec["word_range"]
        source = f"superhero:{sh_band}"
    elif mode_key in ("rhyme", "rhyme_time"):
        lo, hi = AGE_CONSTRAINTS[band]["rhyme"][length_key]
        source = f"rhyme:{band}:{length_key}"
    elif mode_key in ("ltr", "learning_to_read"):
        pages = AGE_CONSTRAINTS[band]["ltr"][length_key]
        lo, hi = pages * 10, pages * 25
        source = f"ltr:{band}:{length_key}:pages={pages}"
    else:  # standard enhanced prompt
        if age_int <= 5:
            pages = _SPROUT_PAGES_BY_LENGTH[length_key]
            lo = pages * _SPROUT_WORDS_PER_PAGE[0]
            hi = pages * _SPROUT_WORDS_PER_PAGE[1]
            source = f"standard:sprout:{length_key}:pages={pages}"
        else:
            minutes = _story_duration_to_minutes(story_duration)
            if minutes and minutes > 0:
                lo, hi = _duration_minutes_to_word_range(
                    minutes, wpm=_narration_wpm_for_age(age_int)
                )
                source = f"standard:duration:{minutes}m"
            else:
                lo, hi = AGE_CONSTRAINTS[band]["regular"][length_key]
                source = f"standard:{band}:{length_key}"

    return WordRangeSpec(
        target_min=int(lo),
        target_max=int(hi),
        floor=int(lo * FLOOR_RATIO),
        cap=int(hi * CAP_RATIO),
        source=source,
    )


__all__ = [
    "CAP_RATIO",
    "FLOOR_RATIO",
    "WordRangeSpec",
    "get_word_range",
    "normalize_length_key",
    "superhero_band_for_age",
]
