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


# ---------------------------------------------------------------------------
# Explorer-band (ages 6-8) matrix — parallel to the Sprout tables above.
# Villains are mischief-makers with motives a 6-8-year-old can decode
# (lonely, curious, misunderstood); never frightening. Problems include
# actual puzzle/agency verbs (decode, see-through, bridge) on top of the
# kindness-based ones. All resolutions still come through empathy,
# cleverness, sharing, or inviting in — never force.
# ---------------------------------------------------------------------------
EXPLORER_VILLAINS: dict[str, dict] = {
    "shadow_trickster": {
        "name": "the Shadow Trickster",
        "action": "copy everyone's moves to confuse them",
        "softens": "stopped hiding once someone finally noticed them — they were just lonely",
    },
    "forgetting_fog": {
        "name": "the Forgetting Fog",
        "action": "drift through town making important things slip from memory",
        "softens": "thinned out once it understood what it was doing and rolled away gently",
    },
    "tangle_knot_twins": {
        "name": "the Tangle-Knot Twins",
        "action": "twist ropes, laces, and headphones into giggly knots",
        "softens": "untied everything and asked to learn a new game instead",
    },
    "echo_bandit": {
        "name": "the Echo Bandit",
        "action": "snatch important sounds — the school bell, a friend's laugh — into a bottle",
        "softens": "uncorked the bottle and gave every sound back",
    },
    "the_grumblestorm": {
        "name": "the Grumblestorm",
        "action": "follow one person around like a tiny cranky thundercloud",
        "softens": "turned soft pink once someone helped it name what was bothering it",
    },
    "glitchworm": {
        "name": "the Glitchworm",
        "action": "wriggle into screens and scramble pictures and words",
        "softens": "blinked, said sorry, and slithered off to learn how things work",
    },
    "wishing_thief": {
        "name": "the Wishing Thief",
        "action": "scoop up wishes from fountains without asking",
        "softens": "poured every wish back and asked permission next time",
    },
    "captain_boast": {
        "name": "Captain Boast",
        "action": "puff up so big that everyone else feels small",
        "softens": "got a little quieter and admitted they just wanted to be seen too",
    },
}

EXPLORER_PROBLEMS: dict[str, dict] = {
    "find_missing_piece": {
        "name": "Find the missing piece",
        "verb": "search for and recover",
        "summary": "track down what's gone missing",
    },
    "decode_signal": {
        "name": "Decode the signal",
        "verb": "figure out",
        "summary": "read a clue or message",
    },
    "calm_the_storm": {
        "name": "Calm the storm",
        "verb": "settle",
        "summary": "help a big feeling cool down",
    },
    "restore_what_taken": {
        "name": "Restore what was taken",
        "verb": "return and mend",
        "summary": "give back what was taken and patch what broke",
    },
    "bridge_the_divide": {
        "name": "Bridge the divide",
        "verb": "bring together",
        "summary": "help two sides understand each other",
    },
    "see_through_trick": {
        "name": "See through the trick",
        "verb": "notice",
        "summary": "spot what's really going on",
    },
    "light_the_way": {
        "name": "Light the way",
        "verb": "guide",
        "summary": "help someone find their courage or direction",
    },
    "trade_fair": {
        "name": "Make a fair trade",
        "verb": "swap fairly",
        "summary": "find a deal where everyone wins",
    },
}

# Explorer powers reuse the 8 Sprout IDs (so existing frontend pickers keep
# working) but with Explorer-tier display names and verbs, plus 2 Explorer-
# only powers (feeling_sense, invisibility).
EXPLORER_POWERS: dict[str, dict] = {
    "super_speed": {
        "name": "Lightning Speed",
        "verb": "dash",
        "ideal": "tangle_knot_twins",
        "also": ["forgetting_fog", "echo_bandit", "glitchworm", "captain_boast"],
        "primary_problem": "restore_what_taken",
    },
    "flying": {
        "name": "Sky Glide",
        "verb": "glide up",
        "ideal": "the_grumblestorm",
        "also": ["echo_bandit", "forgetting_fog", "shadow_trickster", "wishing_thief"],
        "primary_problem": "calm_the_storm",
    },
    "super_strength": {
        "name": "Strong Lift",
        "verb": "lift gently",
        "ideal": "tangle_knot_twins",
        "also": ["wishing_thief", "echo_bandit", "glitchworm", "captain_boast"],
        "primary_problem": "restore_what_taken",
    },
    "super_hearing": {
        "name": "Keen Ears",
        "verb": "listen close",
        "ideal": "echo_bandit",
        "also": ["glitchworm", "shadow_trickster", "forgetting_fog", "the_grumblestorm"],
        "primary_problem": "decode_signal",
    },
    "super_smile": {
        "name": "Bright Smile",
        "verb": "beam bright",
        "ideal": "the_grumblestorm",
        "also": ["captain_boast", "shadow_trickster", "wishing_thief", "forgetting_fog"],
        "primary_problem": "calm_the_storm",
    },
    "super_hugs": {
        "name": "Big Heart Hug",
        "verb": "hug warmly",
        "ideal": "captain_boast",
        "also": ["the_grumblestorm", "shadow_trickster", "forgetting_fog", "wishing_thief"],
        "primary_problem": "bridge_the_divide",
    },
    "super_whisper": {
        "name": "Quiet Voice",
        "verb": "speak quietly",
        "ideal": "the_grumblestorm",
        "also": ["captain_boast", "glitchworm", "shadow_trickster", "echo_bandit"],
        "primary_problem": "calm_the_storm",
    },
    "super_sharing": {
        "name": "Fair Share",
        "verb": "share fairly",
        "ideal": "wishing_thief",
        "also": ["captain_boast", "tangle_knot_twins", "echo_bandit", "glitchworm"],
        "primary_problem": "trade_fair",
    },
    # Explorer-only powers — frontend exposes these only when band==explorer.
    "feeling_sense": {
        "name": "Feeling Sense",
        "verb": "sense what they feel",
        "ideal": "shadow_trickster",
        "also": ["captain_boast", "the_grumblestorm", "echo_bandit", "wishing_thief"],
        "primary_problem": "see_through_trick",
    },
    "invisibility": {
        "name": "Soft Step",
        "verb": "move unseen",
        "ideal": "captain_boast",
        "also": ["shadow_trickster", "glitchworm", "forgetting_fog", "echo_bandit"],
        "primary_problem": "see_through_trick",
    },
}

EXPLORER_VILLAIN_PROBLEMS: dict[str, list[str]] = {
    "shadow_trickster": ["see_through_trick", "light_the_way", "find_missing_piece"],
    "forgetting_fog": ["find_missing_piece", "decode_signal", "light_the_way"],
    "tangle_knot_twins": ["restore_what_taken", "trade_fair", "bridge_the_divide"],
    "echo_bandit": ["restore_what_taken", "decode_signal", "find_missing_piece"],
    "the_grumblestorm": ["calm_the_storm", "bridge_the_divide", "light_the_way"],
    "glitchworm": ["decode_signal", "see_through_trick", "restore_what_taken"],
    "wishing_thief": ["restore_what_taken", "trade_fair", "light_the_way"],
    "captain_boast": ["bridge_the_divide", "see_through_trick", "light_the_way"],
}


_BAND_TABLES: dict[str, tuple[dict, dict, dict, dict]] = {
    "sprout": (VILLAINS, PROBLEMS, POWERS, VILLAIN_PROBLEMS),
    "explorer": (
        EXPLORER_VILLAINS,
        EXPLORER_PROBLEMS,
        EXPLORER_POWERS,
        EXPLORER_VILLAIN_PROBLEMS,
    ),
}


def _band_tables(band: str) -> tuple[dict, dict, dict, dict]:
    """Return (villains, problems, powers, villain_problems) for ``band``.

    Defaults to Sprout if an unknown band is passed — keeps legacy callers
    that don't know about bands working unchanged.
    """
    key = (band or "sprout").strip().lower()
    return _BAND_TABLES.get(key, _BAND_TABLES["sprout"])


def _power_villains(power_id: str, band: str = "sprout") -> list[str]:
    """Ordered list (ideal first) of villains compatible with ``power_id``."""
    _, _, powers_t, _ = _band_tables(band)
    if power_id not in powers_t:
        raise ValueError(
            f"Unknown power '{power_id}' for band '{band}'. "
            f"Valid powers: {sorted(powers_t.keys())}"
        )
    spec = powers_t[power_id]
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
    *,
    band: str = "sprout",
) -> tuple[str, str]:
    """Return a (villain_id, problem_id) pair that fits the hero's ``power``.

    Selection is biased — but not locked — to the power's ideal villain:
    when the ideal is allowed, it's weighted 2x the others. The chosen
    problem is intersected with the band's villain-problem table so the
    pair is always narratively sensible.

    Args:
        power: A power ID valid for ``band`` (see :data:`POWERS` /
            :data:`EXPLORER_POWERS`).
        seed: Optional deterministic seed (for tests / reproducibility).
        recent_villains: Villain IDs to avoid (last-1 or last-N history).
        recent_problems: Problem IDs to avoid in the same way.
        band: 'sprout' (default, ages 3-5) or 'explorer' (ages 6-8).
            Unknown bands fall back to sprout so legacy callers keep
            working.

    Returns:
        Tuple of (villain_id, problem_id), both valid keys into the
        band's villain/problem tables.
    """
    _villains_t, _problems_t, powers_t, villain_problems_t = _band_tables(band)
    rng = random.Random(seed) if seed is not None else random
    candidates = _power_villains(power, band=band)
    candidates = _filter_recents(candidates, recent_villains)

    # Weighted choice: ideal gets weight 2 (only if still present after the
    # recent-villain filter), every other candidate gets weight 1.
    ideal = powers_t[power]["ideal"]
    weights = [2 if c == ideal else 1 for c in candidates]
    villain_id = rng.choices(candidates, weights=weights, k=1)[0]

    problem_pool = villain_problems_t.get(villain_id, [])
    if not problem_pool:
        # Defensive: fall back to the power's primary problem so we never
        # return an invalid pair, even if a future villain row is missing.
        problem_pool = [powers_t[power]["primary_problem"]]

    problem_pool = _filter_recents(problem_pool, recent_problems)
    problem_id = rng.choice(problem_pool)
    return villain_id, problem_id


def get_band_tables(band: str) -> tuple[dict, dict, dict, dict]:
    """Public accessor for a band's (villains, problems, powers, villain_problems).

    Used by the prompt service to render the band-specific story without
    importing the private helper.
    """
    return _band_tables(band)


__all__ = [
    "VILLAINS",
    "PROBLEMS",
    "POWERS",
    "VILLAIN_PROBLEMS",
    "EXPLORER_VILLAINS",
    "EXPLORER_PROBLEMS",
    "EXPLORER_POWERS",
    "EXPLORER_VILLAIN_PROBLEMS",
    "pick_pairing",
    "get_band_tables",
]
