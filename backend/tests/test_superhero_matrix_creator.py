"""Unit tests for the Creator-band (ages 12-14) section of superhero_matrix.

Parallel to test_superhero_matrix_adventurer.py — exercises the same invariants
against the CREATOR_* tables ("Hero Saga" Phase 1) plus the band-aware
pick_pairing path.
"""

from __future__ import annotations

import pytest

from backend.data.superhero_matrix import (
    ADVENTURER_PROBLEMS,
    ADVENTURER_VILLAINS,
    CREATOR_POWERS,
    CREATOR_PROBLEMS,
    CREATOR_VILLAIN_PROBLEMS,
    CREATOR_VILLAINS,
    EXPLORER_PROBLEMS,
    EXPLORER_VILLAINS,
    POWERS,
    PROBLEMS,
    VILLAINS,
    apply_nemesis_override,
    get_band_tables,
    pick_pairing,
)


def test_creator_matrix_has_expected_cardinality():
    assert len(CREATOR_VILLAINS) == 10
    assert len(CREATOR_PROBLEMS) == 10
    assert len(CREATOR_POWERS) == 10  # 8 base IDs + strategist + gadgeteer
    assert set(CREATOR_VILLAIN_PROBLEMS.keys()) == set(CREATOR_VILLAINS.keys())


def test_creator_reuses_base_power_ids_plus_two():
    base_ids = set(POWERS.keys())
    creator_only = {"strategist", "gadgeteer"}
    assert set(CREATOR_POWERS.keys()) == base_ids | creator_only


def test_creator_power_specs_reference_real_villains():
    for power_id, spec in CREATOR_POWERS.items():
        assert spec["ideal"] in CREATOR_VILLAINS, f"{power_id}.ideal unknown"
        also = spec.get("also", [])
        assert len(also) >= 4, f"{power_id} needs >=4 also-works villains"
        for v in also:
            assert v in CREATOR_VILLAINS, f"{power_id}.also unknown villain '{v}'"
        assert spec["ideal"] not in also, f"{power_id}.ideal duplicated in .also"
        assert spec["primary_problem"] in CREATOR_PROBLEMS, f"{power_id} bad primary"


def test_creator_villain_problem_entries_reference_real_problems():
    for villain_id, problem_list in CREATOR_VILLAIN_PROBLEMS.items():
        assert len(problem_list) >= 1
        for p in problem_list:
            assert p in CREATOR_PROBLEMS, f"{villain_id} unknown problem '{p}'"


def test_creator_ids_are_namespaced_distinct_from_other_bands():
    """No accidental ID collisions across the younger bands."""
    assert not (set(CREATOR_VILLAINS) & set(VILLAINS))
    assert not (set(CREATOR_VILLAINS) & set(EXPLORER_VILLAINS))
    assert not (set(CREATOR_VILLAINS) & set(ADVENTURER_VILLAINS))
    assert not (set(CREATOR_PROBLEMS) & set(PROBLEMS))
    assert not (set(CREATOR_PROBLEMS) & set(EXPLORER_PROBLEMS))
    assert not (set(CREATOR_PROBLEMS) & set(ADVENTURER_PROBLEMS))


def test_pick_pairing_creator_returns_sensible_pair_for_each_power():
    for power_id, spec in CREATOR_POWERS.items():
        allowed = {spec["ideal"], *spec.get("also", [])}
        for seed in range(10):
            villain_id, problem_id = pick_pairing(power_id, seed=seed, band="creator")
            assert villain_id in allowed, f"{power_id} -> {villain_id} not in {allowed}"
            assert problem_id in CREATOR_VILLAIN_PROBLEMS[villain_id]


def test_pick_pairing_creator_unknown_power_raises():
    with pytest.raises(ValueError):
        pick_pairing("super_potato", band="creator")


def test_creator_only_powers_route_correctly():
    """strategist/gadgeteer exist on creator; still rejected on younger bands
    that don't define them."""
    for bad_band in ("sprout", "explorer"):
        with pytest.raises(ValueError):
            pick_pairing("strategist", band=bad_band)
    v1, _ = pick_pairing("strategist", seed=0, band="creator")
    v2, _ = pick_pairing("gadgeteer", seed=0, band="creator")
    assert v1 in CREATOR_VILLAINS
    assert v2 in CREATOR_VILLAINS


def test_creator_every_villain_reachable_from_some_power():
    referenced = set()
    for spec in CREATOR_POWERS.values():
        referenced.add(spec["ideal"])
        referenced.update(spec.get("also", []))
    missing = set(CREATOR_VILLAINS.keys()) - referenced
    assert not missing, f"Orphan Creator villains: {missing}"


def test_creator_every_problem_reachable_from_some_villain():
    referenced = set()
    for plist in CREATOR_VILLAIN_PROBLEMS.values():
        referenced.update(plist)
    missing = set(CREATOR_PROBLEMS.keys()) - referenced
    assert not missing, f"Orphan Creator problems: {missing}"


def test_pick_pairing_creator_seed_is_reproducible():
    for power_id in CREATOR_POWERS:
        a = pick_pairing(power_id, seed=12345, band="creator")
        b = pick_pairing(power_id, seed=12345, band="creator")
        assert a == b


def test_get_band_tables_returns_creator_set():
    v, p, pw, vp = get_band_tables("creator")
    assert v is CREATOR_VILLAINS
    assert p is CREATOR_PROBLEMS
    assert pw is CREATOR_POWERS
    assert vp is CREATOR_VILLAIN_PROBLEMS


def test_apply_nemesis_override_creator_swaps_and_repairs():
    chosen = list(CREATOR_VILLAINS)[3]
    good_problem = CREATOR_VILLAIN_PROBLEMS[chosen][0]
    villain, problem = apply_nemesis_override(
        "creator", list(CREATOR_VILLAINS)[0], good_problem, chosen
    )
    assert villain == chosen
    assert problem == good_problem
    # An incompatible problem gets re-paired to one the chosen villain fits.
    bad = next(p for p in CREATOR_PROBLEMS if p not in CREATOR_VILLAIN_PROBLEMS[chosen])
    villain2, problem2 = apply_nemesis_override(
        "creator", list(CREATOR_VILLAINS)[0], bad, chosen
    )
    assert villain2 == chosen
    assert problem2 in CREATOR_VILLAIN_PROBLEMS[chosen]
