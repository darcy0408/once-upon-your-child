"""Live prompt-template versioning for F-01 attribution (MT-187).

Each story generation resolves to a stable ``(template_id, revision_hash)``
tuple that gets persisted on the ``Story`` row. The revision hash is the
sha256[:16] of the builder function's source, computed at import time via
``inspect.getsource``. Any code change to a builder produces a new hash
without anyone needing to remember to run ``snapshot --refresh`` — drift
attribution falls out naturally from a DB query.

The static ``content_hash`` values in ``backend/eval/prompt_registry.py``
remain the snapshot baseline used by the offline audit harness; the values
here are what production writes alongside each generated story.

Note: LTR has three sub-branches (CVC ≤5, Seuss age-6, limericks 7-12, prose
13+) that all live inside a single ``_build_learning_to_read_prompt`` function.
The hash is therefore the whole function — limerick vs non-limerick is
distinguished by ``template_id`` (T2 vs T3); finer attribution would require
splitting the function or threading the branch through the resolver.
"""

from __future__ import annotations

import hashlib
import inspect
import logging
from typing import Callable

try:
    from .prompt_service import PromptService
    from .story_service import (
        AdvancedStoryEngine,
        _build_bedtime_prompt,
        _build_learning_to_read_prompt,
        _build_rhyme_time_prompt,
    )
except ImportError:  # pragma: no cover — legacy bare-import fallback
    from services.prompt_service import PromptService  # type: ignore[no-redef]
    from services.story_service import (  # type: ignore[no-redef]
        AdvancedStoryEngine,
        _build_bedtime_prompt,
        _build_learning_to_read_prompt,
        _build_rhyme_time_prompt,
    )

logger = logging.getLogger(__name__)


def _hash_source(fn: Callable) -> str:
    try:
        src = inspect.getsource(fn)
    except (OSError, TypeError):
        return ""
    return hashlib.sha256(src.encode("utf-8")).hexdigest()[:16]


_REVISION_HASHES: dict[str, str] = {
    "T1_STANDARD": _hash_source(AdvancedStoryEngine.generate_enhanced_prompt),
    "T2_LTR_LIMERICK": _hash_source(_build_learning_to_read_prompt),
    "T3_LTR_SEUSSIAN": _hash_source(_build_learning_to_read_prompt),
    "T4_RHYME_TIME": _hash_source(_build_rhyme_time_prompt),
    "T5_BEDTIME": _hash_source(_build_bedtime_prompt),
    "T6_SUPERHERO_SPROUT": _hash_source(PromptService._build_superhero_prompt),
    "T7_SUPERHERO_EXPLORER": _hash_source(
        PromptService._build_superhero_prompt_explorer
    ),
    "T8_SUPERHERO_ADVENTURER": _hash_source(
        PromptService._build_superhero_prompt_adventurer
    ),
}


def resolve(*, mode: str, age: int | None) -> tuple[str, str]:
    """Resolve ``(template_id, revision_hash)`` for a generation cell.

    ``mode`` is one of: ``"standard"``, ``"bedtime"``, ``"ltr"``,
    ``"rhyme_time"``, ``"superhero"``. ``age`` disambiguates Superhero
    (Sprout vs Explorer) and LTR (limerick vs everything else). Unknown
    modes fall back to ``T1_STANDARD`` so persistence never raises.
    """
    age_int: int | None
    try:
        age_int = int(age) if age is not None else None
    except (TypeError, ValueError):
        age_int = None

    if mode == "superhero":
        if age_int is not None and 6 <= age_int <= 8:
            template_id = "T7_SUPERHERO_EXPLORER"
        elif age_int is not None and 9 <= age_int <= 12:
            template_id = "T8_SUPERHERO_ADVENTURER"
        else:
            template_id = "T6_SUPERHERO_SPROUT"
    elif mode == "bedtime":
        template_id = "T5_BEDTIME"
    elif mode == "ltr":
        if age_int is not None and 7 <= age_int <= 12:
            template_id = "T2_LTR_LIMERICK"
        else:
            template_id = "T3_LTR_SEUSSIAN"
    elif mode == "rhyme_time":
        template_id = "T4_RHYME_TIME"
    else:
        if mode != "standard":
            logger.warning(
                "prompt_versioning: unknown mode=%r — defaulting to T1_STANDARD", mode
            )
        template_id = "T1_STANDARD"

    return template_id, _REVISION_HASHES.get(template_id, "")


__all__ = ["resolve"]
