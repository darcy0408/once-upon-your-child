"""Post-generation structural validation for Superhero Mode stories.

Context: ``superhero_meta`` (surfaced in the /generate-story response) and the
prompt itself both make concrete, checkable promises per age band — a total
word-count range, a required page/beat count, and (Creator/Adolescent only) a
saga_state contract used for cross-Issue continuity. Nothing enforced any of
this after generation: ``validation_issues`` came back empty regardless of how
far the model drifted from spec (e.g. an Adolescent chapter at 3044 words vs
the prompt's stated 1400-2200, or a Creator Issue with 8 pages vs the required
7). This module is the read side of that check.

The band specs below are transcribed from — and must be kept in sync with —
the HARD RULES / OUTPUT FORMAT sections of the per-band prompt builders in
``backend/services/prompt_service.py`` (line refs are a pointer, not a
guarantee against drift; re-check them if a prompt's stated range changes):
  - sprout      (ages 3-5):  ``_build_superhero_prompt``            ~L569-571
  - explorer    (ages 6-8):  ``_build_superhero_prompt_explorer``   ~L831
  - adventurer  (ages 9-12): ``_build_superhero_prompt_adventurer`` ~L1175
  - creator     (ages 13-14/18+): ``_build_superhero_prompt_creator`` ~L1431
  - adolescent  (ages 15-17): ``_build_superhero_prompt_adolescent`` ~L2226/L2294

Sprout and Explorer already have a dedicated truncation-based safety belt
(``_enforce_sprout_word_cap`` in backend/tasks/story_tasks.py) that keeps them
within bounds pre-response; this module's retry orchestration (see
``should_retry``) is intended for Adventurer/Creator/Adolescent, which have no
such belt today. The word/page spec constants below still cover all five
bands so a single source of truth exists and Sprout/Explorer can be wired in
for flag-only reporting without duplicating numbers.
"""

from __future__ import annotations

# ---------------------------------------------------------------------------
# Per-band word-count / page-count specs (see module docstring for sources).
# ---------------------------------------------------------------------------
SUPERHERO_BAND_SPECS: dict[str, dict] = {
    "sprout": {"word_range": (100, 130), "page_range": (8, 12)},
    "explorer": {"word_range": (250, 350), "page_range": (5, 5)},
    "adventurer": {"word_range": (900, 1500), "page_range": (6, 6)},
    "creator": {"word_range": (1100, 1800), "page_range": (7, 7)},
    # Adolescent prompt (both hero_mode branches) states "1400-1900 words —
    # this is a HARD MAXIMUM" (prompt_service.py ~L2392/L2462); the earlier
    # (1400, 2200) here was drift from a pre-hardening prompt revision.
    "adolescent": {"word_range": (1400, 1900), "page_range": (7, 7)},
}

# Creator/Adolescent are the two bands whose saga_state carries the full
# continuity contract (nemesis + cost + allies + defining choice) that the
# next Issue's "consequence callback" mandate reads (prompt_service.py's
# callback_mandate block, ~L1355-1365 / ~L1610-1613). Sprout/Explorer/
# Adventurer emit a lighter saga_state (no what_it_cost) and aren't part of
# the returnable-saga continuity feature, so completeness isn't enforced for
# them here.
SAGA_STATE_REQUIRED_KEYS: dict[str, tuple[str, ...]] = {
    "creator": (
        "nemesis",
        "nemesis_status",
        "what_changed",
        "what_it_cost",
        "next_hook",
        "allies",
        "defining_choice",
    ),
    "adolescent": (
        "nemesis",
        "nemesis_status",
        "what_changed",
        "what_it_cost",
        "next_hook",
        "allies",
        "defining_choice",
    ),
}

# Word-count overage thresholds, expressed as a fraction over the band's
# stated ceiling (SUPERHERO_BAND_SPECS[band]["word_range"][1]).
WORD_COUNT_FLAG_OVER_RATIO = 0.15  # record a (non-retry) issue past this point
WORD_COUNT_RETRY_OVER_RATIO = 0.25  # warrants the one-shot regen past this point


def _default_for_key(key: str):
    """Neutral backfill value for a missing saga_state key."""
    return [] if key == "allies" else ""


def validate_word_count(total_words: int, band: str) -> dict | None:
    """Return a structured issue if `total_words` exceeds `band`'s ceiling.

    Returns None when the band is unknown or the count is within range.
    Severity is ``"retry"`` once over by more than WORD_COUNT_RETRY_OVER_RATIO,
    else ``"flag"`` once over by more than WORD_COUNT_FLAG_OVER_RATIO. Being
    under the floor is not flagged here — the existing per-attempt
    ``min_words_threshold`` retry loop in story_tasks.py already guards that.
    """
    spec = SUPERHERO_BAND_SPECS.get(band)
    if not spec:
        return None
    lo, hi = spec["word_range"]
    if not hi or total_words <= hi:
        return None
    over_ratio = (total_words - hi) / hi
    if over_ratio <= WORD_COUNT_FLAG_OVER_RATIO:
        return None
    return {
        "type": "word_count",
        "band": band,
        "word_count": total_words,
        "expected_range": [lo, hi],
        "over_ratio": round(over_ratio, 3),
        "severity": "retry" if over_ratio > WORD_COUNT_RETRY_OVER_RATIO else "flag",
    }


def validate_page_count(page_count: int, band: str) -> dict | None:
    """Return a structured issue if `page_count` is outside `band`'s required
    page/beat count. Always severity "retry" — an off-count page/beat
    structure is a structural mismatch (e.g. a Creator Issue collapsing 7
    beats into 8 or 6 pages), not a soft overage.
    """
    spec = SUPERHERO_BAND_SPECS.get(band)
    if not spec:
        return None
    lo, hi = spec["page_range"]
    if lo <= page_count <= hi:
        return None
    return {
        "type": "page_count",
        "band": band,
        "page_count": page_count,
        "expected_range": [lo, hi],
        "severity": "retry",
    }


def backfill_saga_state(
    saga_state: dict | None, band: str
) -> tuple[dict | None, dict | None]:
    """Ensure `saga_state` carries every key `band`'s prompt promises.

    Bands outside SAGA_STATE_REQUIRED_KEYS (sprout/explorer/adventurer) are
    returned unchanged — completeness is only enforced for Creator/Adolescent
    (see module docstring). Missing keys are backfilled with a neutral default
    (``[]`` for ``allies``, ``""`` otherwise) so the next Issue's continuity
    block / consequence-callback mandate (prompt_service.py) can read the key
    and skip cleanly via its existing truthy checks, rather than KeyError or
    silently losing the mechanic.

    Returns ``(backfilled_saga_state, issue_or_None)``.
    """
    required = SAGA_STATE_REQUIRED_KEYS.get(band)
    if not required:
        return saga_state, None
    state = dict(saga_state) if isinstance(saga_state, dict) else {}
    missing = [k for k in required if not state.get(k)]
    if not missing:
        return (state or None), None
    for key in missing:
        state[key] = _default_for_key(key)
    issue = {
        "type": "saga_state_incomplete",
        "band": band,
        "missing_keys": missing,
        "severity": "flag",
    }
    return state, issue


def should_retry(issues: list[dict]) -> bool:
    """True if any issue in `issues` warrants the capped-at-one regen retry."""
    return any(issue.get("severity") == "retry" for issue in issues)


__all__ = [
    "SUPERHERO_BAND_SPECS",
    "SAGA_STATE_REQUIRED_KEYS",
    "WORD_COUNT_FLAG_OVER_RATIO",
    "WORD_COUNT_RETRY_OVER_RATIO",
    "validate_word_count",
    "validate_page_count",
    "backfill_saga_state",
    "should_retry",
]
