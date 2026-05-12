"""Superhero Mode (Ages 3-5) — villain/problem/power compatibility matrix.

This module is a pure-data file plus a small selector. It is consumed by
the superhero prompt builder when ``theme == 'superhero'``. Keeping the
matrix here (instead of inside the prompt service) lets us unit-test the
pairing logic in isolation and lets the frontend hit a thin endpoint
later if we ever want to surface the catalogue to clients.

Design rules:
- Every power has ONE ideal villain (best narrative fit) plus 4-5 "also-works"
  options so we don't repeat the same hero-vs-villain pair every session.
- Every villain advertises 3 compatible problem types. The selector
  intersects the power's available villains with each villain's problem
  list to ensure the chosen (villain, problem) pair is always sensible.
- All resolution verbs are non-violent: tidy, cheer, share, comfort,
  invite, calm, find, repair. Villains soften / say sorry / join in —
  never get defeated. This is a Sprout-band (ages 3-5) story chain.
"""
from __future__ import annotations

import random
from typing import Iterable

# ---------------------------------------------------------------------------
# Villains — silly, never frightening. The ``action`` phrase is dropped into
# Beat 2 of the 6-beat chain ("Oh no! [Villain] came to [villain-action].").
# ---------------------------------------------------------------------------
VILLAINS: dict[str, dict] = {
    "mess_monster": {
        "name": "Mess Monster",
        "action": "scatters crumbs and toys everywhere",
        "softens": "smiled and helped tidy up",
    },
    "grumpy_cloud": {
        "name": "Grumpy Cloud",
        "action": "rains on picnics until cheered up",
        "softens": "turned pink and floated away happy",
    },
    "sock_goblin": {
        "name": "Sock Goblin",
        "action": "steals one sock from every pair",
        "softens": "giggled and gave the socks back",
    },
    "no_share_shark": {
        "name": "No-Share Shark",
        "action": "won't share the slide, swing, or snack",
        "softens": "said sorry and took turns",
    },
    "bedtime_bandit": {
        "name": "Bedtime Bandit",
        "action": "hides bedtime stories and stuffed animals",
        "softens": "tiptoed back with everything safe",
    },
    "noise_beast": {
        "name": "Noise Beast",
        "action": "roars too loud and scares baby animals",
        "softens": "whispered a tiny, kind hello",
    },
    "sticky_mcgoo": {
        "name": "Sticky McGoo",
        "action": "gets jam and goo on everything",
        "softens": "said sorry and helped wipe it clean",
    },
    "the_frownerator": {
        "name": "The Frownerator",
        "action": "collects smiles in a jar",
        "softens": "smiled too and let the smiles go free",
    },
    "lost_things_sprite": {
        "name": "Lost-Things Sprite",
        "action": "moves toys so kids can't find them",
        "softens": "fluttered close and showed where they were",
    },
    "cranky_crab": {
        "name": "Cranky Crab",
        # Phrased as a verb-phrase so Beat 2 reads naturally: "came to {action}".
        # The "short-tempered but secretly lonely" backstory is communicated
        # via the "softens" beat instead.
        "action": "snap at everyone on the beach",
        "softens": "smiled — really, the crab was just lonely — and joined the fun",
    },
}

# ---------------------------------------------------------------------------
# Problems — the *goal* the hero pursues during beats 3-5. ``verb`` is the
# child-friendly action verb the prompt asks the model to use.
# ---------------------------------------------------------------------------
PROBLEMS: dict[str, dict] = {
    "get_back": {
        "name": "Get it back",
        "verb": "find and return",
        "summary": "return a taken object",
    },
    "clean_up": {
        "name": "Clean up",
        "verb": "tidy",
        "summary": "tidy what was scattered",
    },
    "cheer_up": {
        "name": "Cheer up",
        "verb": "cheer up",
        "summary": "restore joy to a sad friend",
    },
    "make_peace": {
        "name": "Make peace",
        "verb": "calm",
        "summary": "calm a cranky character",
    },
    "share_fairly": {
        "name": "Share fairly",
        "verb": "share",
        "summary": "split a snack or turn",
    },
    "quiet_down": {
        "name": "Quiet down",
        "verb": "gentle",
        "summary": "gentle the loud",
    },
    "find_friend": {
        "name": "Find a friend",
        "verb": "search for",
        "summary": "search and rescue",
    },
    "comfort_scared": {
        "name": "Comfort the scared",
        "verb": "comfort",
        "summary": "soothe fears",
    },
    "include_left_out": {
        "name": "Include the left-out",
        "verb": "invite in",
        "summary": "invite someone in",
    },
    "help_say_sorry": {
        "name": "Help say sorry",
        "verb": "help repair",
        "summary": "model repair",
    },
}

# ---------------------------------------------------------------------------
# Powers — the hero's signature super-ability. The ``verb`` is the action
# verb used in Beat 4 ("[Name] used [power-verb] to [problem-action].").
# ``ideal`` is the single most thematic villain match; ``also`` lists the
# other villains the power can credibly pair with. ``primary_problem`` is
# a sensible default if a frontend chooses to skip random pairing.
# ---------------------------------------------------------------------------
POWERS: dict[str, dict] = {
    "super_speed": {
        "name": "Super Speed",
        "verb": "zoom",
        "ideal": "sock_goblin",
        "also": ["lost_things_sprite", "mess_monster", "bedtime_bandit", "sticky_mcgoo"],
        "primary_problem": "get_back",
    },
    "flying": {
        "name": "Flying",
        "verb": "fly up",
        "ideal": "grumpy_cloud",
        "also": ["noise_beast", "lost_things_sprite", "the_frownerator", "sock_goblin"],
        "primary_problem": "cheer_up",
    },
    "super_strength": {
        "name": "Super Strength",
        "verb": "lift",
        "ideal": "mess_monster",
        "also": ["sticky_mcgoo", "lost_things_sprite", "bedtime_bandit", "sock_goblin"],
        "primary_problem": "clean_up",
    },
    "super_hearing": {
        "name": "Super Hearing",
        "verb": "listen carefully",
        "ideal": "lost_things_sprite",
        "also": ["sock_goblin", "bedtime_bandit", "sticky_mcgoo", "the_frownerator"],
        "primary_problem": "find_friend",
    },
    "super_smile": {
        "name": "Super Smile",
        "verb": "smile big",
        "ideal": "the_frownerator",
        "also": ["grumpy_cloud", "cranky_crab", "no_share_shark", "noise_beast"],
        "primary_problem": "cheer_up",
    },
    "super_hugs": {
        "name": "Super Hugs",
        "verb": "give a warm hug",
        "ideal": "cranky_crab",
        "also": ["grumpy_cloud", "the_frownerator", "no_share_shark", "bedtime_bandit"],
        "primary_problem": "make_peace",
    },
    "super_whisper": {
        "name": "Super Whisper",
        "verb": "whisper softly",
        "ideal": "noise_beast",
        "also": ["cranky_crab", "grumpy_cloud", "the_frownerator", "bedtime_bandit"],
        "primary_problem": "quiet_down",
    },
    "super_sharing": {
        "name": "Super Sharing",
        "verb": "share",
        "ideal": "no_share_shark",
        "also": ["sticky_mcgoo", "cranky_crab", "mess_monster", "sock_goblin"],
        "primary_problem": "share_fairly",
    },
}

# ---------------------------------------------------------------------------
# Villain -> sensible problem types. Used both to validate pairings and to
# pick a problem given a chosen villain.
# ---------------------------------------------------------------------------
VILLAIN_PROBLEMS: dict[str, list[str]] = {
    "mess_monster": ["clean_up", "share_fairly", "get_back"],
    "grumpy_cloud": ["cheer_up", "make_peace", "comfort_scared"],
    "sock_goblin": ["get_back", "find_friend", "share_fairly"],
    "no_share_shark": ["share_fairly", "make_peace", "include_left_out"],
    "bedtime_bandit": ["get_back", "comfort_scared", "find_friend"],
    "noise_beast": ["quiet_down", "make_peace", "comfort_scared"],
    "sticky_mcgoo": ["clean_up", "help_say_sorry", "get_back"],
    "the_frownerator": ["cheer_up", "get_back", "help_say_sorry"],
    "lost_things_sprite": ["find_friend", "get_back", "help_say_sorry"],
    "cranky_crab": ["make_peace", "include_left_out", "cheer_up"],
}


def _power_villains(power_id: str) -> list[str]:
    """Ordered list (ideal first) of villains compatible with ``power_id``."""
    if power_id not in POWERS:
        raise ValueError(
            f"Unknown power '{power_id}'. Valid powers: {sorted(POWERS.keys())}"
        )
    spec = POWERS[power_id]
    return [spec["ideal"]] + list(spec.get("also", []))


def _filter_recents(items: Iterable[str], recents: Iterable[str] | None) -> list[str]:
    """Drop ``recents`` from ``items`` but never return an empty list — if all
    candidates are recent, return the full original list so the story can still
    be generated. Frontend uses this to avoid back-to-back duplicates without
    blocking when the recent-list grows to cover everything.
    """
    items = list(items)
    if not recents:
        return items
    blocked = {r for r in recents if r}
    filtered = [i for i in items if i not in blocked]
    return filtered or items


def pick_pairing(
    power: str,
    seed: int | None = None,
    recent_villains: Iterable[str] | None = None,
    recent_problems: Iterable[str] | None = None,
) -> tuple[str, str]:
    """Return a (villain_id, problem_id) pair that fits the hero's ``power``.

    Selection is biased — but not locked — to the power's ideal villain:
    when the ideal is allowed, it's weighted 2x the others. The chosen
    problem is intersected with ``VILLAIN_PROBLEMS[villain]`` so the pair
    is always narratively sensible.

    Args:
        power: One of the 8 power IDs in :data:`POWERS`.
        seed: Optional deterministic seed (for tests / reproducibility).
        recent_villains: Villain IDs to avoid (last-1 or last-N history).
        recent_problems: Problem IDs to avoid in the same way.

    Returns:
        Tuple of (villain_id, problem_id), both valid keys into the
        :data:`VILLAINS` / :data:`PROBLEMS` dicts.
    """
    rng = random.Random(seed) if seed is not None else random
    candidates = _power_villains(power)
    candidates = _filter_recents(candidates, recent_villains)

    # Weighted choice: ideal gets weight 2 (only if still present after the
    # recent-villain filter), every other candidate gets weight 1.
    ideal = POWERS[power]["ideal"]
    weights = [2 if c == ideal else 1 for c in candidates]
    villain_id = rng.choices(candidates, weights=weights, k=1)[0]

    problem_pool = VILLAIN_PROBLEMS.get(villain_id, [])
    if not problem_pool:
        # Defensive: fall back to the power's primary problem so we never
        # return an invalid pair, even if a future villain row is missing.
        problem_pool = [POWERS[power]["primary_problem"]]

    problem_pool = _filter_recents(problem_pool, recent_problems)
    problem_id = rng.choice(problem_pool)
    return villain_id, problem_id


__all__ = [
    "VILLAINS",
    "PROBLEMS",
    "POWERS",
    "VILLAIN_PROBLEMS",
    "pick_pairing",
]
