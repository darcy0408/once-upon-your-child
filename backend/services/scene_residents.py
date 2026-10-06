"""Scene residents: characters who live in a wizard scene (chunk 4).

Each ScenarioCard (lib/data/scenario_data.dart) names one or two characters
who live in that place. The client sends them as ``scene_residents`` with the
scene's ``scenario_id``. The story may let the hero meet them; on a later
visit to the same scene they greet the hero as an old friend.

Residents are deliberately NOT companions:

* they never travel with the hero, and
* they never enter a "MUST appear by name" list. The standard prompt's
  mandatory-names checklist and the Pick-a-Path Companion Contract are both
  fed only by companions. Putting residents there would force every story at
  a scene to stop and introduce them.

The prompt wording says what these characters are and leaves out craft
labels. The model copies rule nouns into prose (PR #454), so a label like
"resident" or "optional cast" could end up in a child's story.
"""

from __future__ import annotations

import logging
import re

from ..utils.sanitizer import sanitize_for_prompt

logger = logging.getLogger(__name__)

# Same window as the standard path's PRIOR ADVENTURES recall
# (story_service._PRIOR_ADVENTURES_LOOKBACK): a return visit is recognised
# when one of the hero's last five stories was set in this scene.
SCENE_VISIT_LOOKBACK = 5

# Scene ids are lowercase snake_case ScenarioCard ids ("vanishing_colors").
# Anything else is dropped rather than echoed into the prompt or the DB.
_SCENARIO_ID_RE = re.compile(r"^[a-z0-9_]{1,64}$")

_MAX_NAME = 60
_MAX_WHAT = 160
_MAX_PERSONALITY = 160


def max_residents_for_age(age) -> int:
    """One resident for ages 8 and under, two from 9 (mirrors residentsForAge)."""
    try:
        return 1 if int(age) <= 8 else 2
    except (TypeError, ValueError):
        return 1


def normalize_scenario_id(raw) -> str | None:
    """Return a clean scene id, or None if it is missing or malformed."""
    if not isinstance(raw, str):
        return None
    value = raw.strip().lower()
    return value if _SCENARIO_ID_RE.match(value) else None


def _clean(value, cap: int) -> str:
    if not isinstance(value, str):
        return ""
    return sanitize_for_prompt(value, cap).strip()


def normalize_scene_residents(raw, age) -> list[dict]:
    """Coerce the client's ``scene_residents`` into at most the band's count.

    Each entry becomes ``{"name", "what", "personality"}``. Entries with no name
    are dropped; blank ``what``/``personality`` are allowed. The client already
    sends the right count, but the server enforces it too so a direct API
    caller can't crowd the prompt.
    """
    if not isinstance(raw, list):
        return []
    limit = max_residents_for_age(age)
    out: list[dict] = []
    seen: set[str] = set()
    for item in raw:
        if not isinstance(item, dict):
            continue
        name = _clean(item.get("name"), _MAX_NAME)
        if not name or name.lower() in seen:
            continue
        seen.add(name.lower())
        out.append(
            {
                "name": name,
                "what": _clean(item.get("what"), _MAX_WHAT),
                "personality": _clean(item.get("personality"), _MAX_PERSONALITY),
            }
        )
        if len(out) >= limit:
            break
    return out


def _resident_names(entries) -> list[str]:
    names = []
    for entry in entries or []:
        if isinstance(entry, dict) and isinstance(entry.get("name"), str):
            name = entry["name"].strip()
            if name:
                names.append(name)
    return names


def find_prior_scene_visit(
    character_id: str | None, scenario_id: str | None
) -> tuple[bool, set[str]]:
    """Has this hero been to this scene before, and whom did they meet there?

    Looks at the hero's last ``SCENE_VISIT_LOOKBACK`` standard stories (the
    ``scenario_id`` / ``scene_residents`` kept in ``Story.content``) and their
    last ``SCENE_VISIT_LOOKBACK`` Pick-a-Path stories (kept in
    ``StoryState.additional_state``). Returns ``(visited, met_names_lower)``.

    Never raises: a failed lookup reads as a first visit, so recall can't break
    story generation.
    """
    if not character_id or not scenario_id:
        return False, set()

    try:
        from ..database import db
        from ..models.interactive_story import InteractiveStory
        from ..models.story import Story
    except ImportError:  # pragma: no cover — import layout fallback
        try:
            from database import db  # type: ignore[no-redef]
            from models.interactive_story import (  # type: ignore[no-redef]
                InteractiveStory,
            )
            from models.story import Story  # type: ignore[no-redef]
        except ImportError:
            return False, set()

    visited = False
    met: set[str] = set()
    try:
        story_rows = (
            db.session.query(Story)
            .filter(Story.character_id == character_id)
            .order_by(Story.created_at.desc())
            .limit(SCENE_VISIT_LOOKBACK)
            .all()
        )
        for row in story_rows:
            content = row.content if isinstance(row.content, dict) else {}
            if content.get("scenario_id") != scenario_id:
                continue
            visited = True
            met.update(
                n.lower() for n in _resident_names(content.get("scene_residents"))
            )

        pap_rows = (
            db.session.query(InteractiveStory)
            .filter(InteractiveStory.character_id == character_id)
            .order_by(InteractiveStory.created_at.desc())
            .limit(SCENE_VISIT_LOOKBACK)
            .all()
        )
        for row in pap_rows:
            extra = (row.state.additional_state or {}) if row.state else {}
            if not isinstance(extra, dict) or extra.get("scenario_id") != scenario_id:
                continue
            visited = True
            met.update(n.lower() for n in _resident_names(extra.get("scene_residents")))
    except Exception:  # noqa: BLE001 — recall is best-effort
        logger.warning(
            "scene visit lookup failed for character_id=%s", character_id, exc_info=True
        )
        return False, set()

    return visited, met


def known_resident_names(residents: list[dict], met_lower: set[str]) -> list[str]:
    """Today's residents the hero already met, in today's order and spelling."""
    return [r["name"] for r in residents if r["name"].lower() in met_lower]


def _join_names(names: list[str]) -> str:
    if len(names) <= 1:
        return "".join(names)
    return ", ".join(names[:-1]) + " and " + names[-1]


def build_scene_residents_line(
    residents: list[dict],
    hero: str,
    visited_before: bool = False,
    known_names: list[str] | None = None,
) -> str:
    """Prompt lines describing who lives here, and a return visit if any.

    Returns "" when there are no residents and no prior visit, so callers can
    splice it in unconditionally without changing the prompt for everyone else.
    """
    lines: list[str] = []
    if residents:
        people = "; ".join(
            r["name"]
            + (f" — {r['what']}" if r.get("what") else "")
            + (f" ({r['personality']})" if r.get("personality") else "")
            for r in residents
        )
        lines.append(
            f"- **WHO LIVES HERE**: {people}. They belong to this place and stay "
            f"here — they never join {hero} on the journey. {hero} may meet them "
            "if the story passes their way; they are welcome, never required."
        )
    if visited_before:
        if known_names:
            lines.append(
                f"- **BEEN HERE BEFORE**: {hero} has visited this place before and "
                f"already knows {_join_names(known_names)}. If they appear, they "
                f"recognise {hero} at once and greet {hero} as an old friend — no "
                "introductions. Keep any memory of that visit warm and vague "
                "rather than inventing specifics."
            )
        else:
            lines.append(
                f"- **BEEN HERE BEFORE**: {hero} has visited this place before, so "
                "it feels a little familiar."
            )
    return "\n".join(lines)
