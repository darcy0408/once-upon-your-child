"""Consistency tests for the Adolescent (15-17) antihero "Edge" matrix.

Locks in the internal integrity of the hand-authored ADOLESCENT_* tables:
every power/villain cross-reference resolves, every villain has valid
problems, and server-side pairing is valid and deterministic.
"""

from __future__ import annotations

from backend.data.superhero_matrix import (
    ADOLESCENT_POWERS,
    ADOLESCENT_PROBLEMS,
    ADOLESCENT_VILLAIN_PROBLEMS,
    ADOLESCENT_VILLAINS,
    get_band_tables,
    pick_pairing,
)


def test_band_tables_resolve_to_adolescent_tables():
    villains, problems, powers, villain_problems = get_band_tables("adolescent")
    assert villains is ADOLESCENT_VILLAINS
    assert problems is ADOLESCENT_PROBLEMS
    assert powers is ADOLESCENT_POWERS
    assert villain_problems is ADOLESCENT_VILLAIN_PROBLEMS


def test_power_cross_references_are_valid():
    for pid, spec in ADOLESCENT_POWERS.items():
        assert spec["ideal"] in ADOLESCENT_VILLAINS, f"{pid} ideal"
        for also in spec["also"]:
            assert also in ADOLESCENT_VILLAINS, f"{pid} also -> {also}"
        assert spec["primary_problem"] in ADOLESCENT_PROBLEMS, f"{pid} problem"


def test_villain_problems_cover_all_villains_with_valid_problems():
    assert set(ADOLESCENT_VILLAIN_PROBLEMS) == set(ADOLESCENT_VILLAINS)
    for vid, probs in ADOLESCENT_VILLAIN_PROBLEMS.items():
        assert probs, f"{vid} has no problems"
        for prob in probs:
            assert prob in ADOLESCENT_PROBLEMS, f"{vid} -> {prob}"


def test_pick_pairing_valid_for_every_power():
    for pid in ADOLESCENT_POWERS:
        vid, prob = pick_pairing(pid, band="adolescent")
        assert vid in ADOLESCENT_VILLAINS, f"{pid} -> bad villain {vid}"
        assert prob in ADOLESCENT_PROBLEMS, f"{pid} -> bad problem {prob}"


def test_pick_pairing_is_deterministic_with_seed():
    for pid in ADOLESCENT_POWERS:
        a = pick_pairing(pid, seed=12345, band="adolescent")
        b = pick_pairing(pid, seed=12345, band="adolescent")
        assert a == b, f"{pid} not deterministic"


def test_edge_roster_has_eight_base_plus_two_extras():
    # 8 shared base power IDs + 2 Adolescent-only Edges (strategist/gadgeteer).
    assert len(ADOLESCENT_POWERS) == 10
    assert "strategist" in ADOLESCENT_POWERS
    assert "gadgeteer" in ADOLESCENT_POWERS


def test_archivist_and_ledger_are_no_longer_near_synonymous():
    """Editorial audit finding 3 (2026-07-07): the_archivist and ledger both
    used to run on "righteous public exposure of secrets" — a roster-overlap
    bug. the_archivist is now reworked onto a distinct axis: quiet leverage /
    surveillance-for-control that never exposes, vs. ledger's public
    ruin-by-exposure. Lock in the distinction so the two can't drift back
    together unnoticed.
    """
    archivist = ADOLESCENT_VILLAINS["the_archivist"]
    ledger = ADOLESCENT_VILLAINS["ledger"]

    # The Archivist now hoards and withholds — never releases what it holds.
    assert "never" in archivist["action"] and "releas" in archivist["action"]
    assert "leverage" in archivist["action"]

    # Ledger is unchanged: still runs on public exposure/ruin.
    assert "ruin" in ledger["action"] or "expose" in ledger["action"].lower()

    # The two entries must no longer share their old overlapping language.
    assert "total exposure" not in archivist["action"]
    assert "rank everyone" not in archivist["action"]
