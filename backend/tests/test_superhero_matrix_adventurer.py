"""Unit tests for the Adventurer-band (ages 9-12) section of superhero_matrix.

Parallel to test_superhero_matrix.py / test_superhero_matrix_explorer.py —
exercises the same invariants against the ADVENTURER_* tables plus the
band-aware pick_pairing path.
"""

from __future__ import annotations

import pytest

from backend.data.superhero_matrix import (
    ADVENTURER_POWERS,
    ADVENTURER_PROBLEMS,
    ADVENTURER_VILLAIN_PROBLEMS,
    ADVENTURER_VILLAINS,
    EXPLORER_PROBLEMS,
    EXPLORER_VILLAINS,
    POWERS,
    PROBLEMS,
    VILLAINS,
    get_band_tables,
    pick_pairing,
)


def test_adventurer_matrix_has_expected_cardinality():
    assert len(ADVENTURER_VILLAINS) == 10
    assert len(ADVENTURER_PROBLEMS) == 10
    assert len(ADVENTURER_POWERS) == 10  # 8 base IDs + strategist + gadgeteer
    assert set(ADVENTURER_VILLAIN_PROBLEMS.keys()) == set(ADVENTURER_VILLAINS.keys())


def test_adventurer_reuses_base_power_ids_plus_two():
    """Frontend keeps the 8 base power IDs and adds 2 Adventurer-only."""
    base_ids = set(POWERS.keys())
    adventurer_only = {"strategist", "gadgeteer"}
    assert set(ADVENTURER_POWERS.keys()) == base_ids | adventurer_only


def test_adventurer_power_specs_reference_real_villains():
    for power_id, spec in ADVENTURER_POWERS.items():
        assert (
            spec["ideal"] in ADVENTURER_VILLAINS
        ), f"{power_id}.ideal must reference a real Adventurer villain"
        also = spec.get("also", [])
        assert len(also) >= 4, f"{power_id} needs >=4 also-works villains"
        for v in also:
            assert (
                v in ADVENTURER_VILLAINS
            ), f"{power_id}.also contains unknown villain '{v}'"
        assert spec["ideal"] not in also, f"{power_id}.ideal duplicated in .also"
        assert (
            spec["primary_problem"] in ADVENTURER_PROBLEMS
        ), f"{power_id}.primary_problem references unknown problem"


def test_adventurer_villain_problem_entries_reference_real_problems():
    for villain_id, problem_list in ADVENTURER_VILLAIN_PROBLEMS.items():
        assert len(problem_list) >= 1
        for p in problem_list:
            assert (
                p in ADVENTURER_PROBLEMS
            ), f"{villain_id} references unknown problem '{p}'"


def test_adventurer_ids_are_namespaced_distinct_from_other_bands():
    """No accidental ID collisions across Sprout / Explorer / Adventurer."""
    assert not (
        set(ADVENTURER_VILLAINS) & set(VILLAINS)
    ), "Adventurer/Sprout villain IDs collide"
    assert not (
        set(ADVENTURER_VILLAINS) & set(EXPLORER_VILLAINS)
    ), "Adventurer/Explorer villain IDs collide"
    assert not (set(ADVENTURER_PROBLEMS) & set(PROBLEMS))
    assert not (set(ADVENTURER_PROBLEMS) & set(EXPLORER_PROBLEMS))


def test_pick_pairing_adventurer_returns_sensible_pair_for_each_power():
    for power_id, spec in ADVENTURER_POWERS.items():
        allowed = {spec["ideal"], *spec.get("also", [])}
        for seed in range(10):
            villain_id, problem_id = pick_pairing(
                power_id, seed=seed, band="adventurer"
            )
            assert (
                villain_id in allowed
            ), f"{power_id} returned villain={villain_id} not in {allowed}"
            assert problem_id in ADVENTURER_VILLAIN_PROBLEMS[villain_id], (
                f"villain={villain_id} returned problem={problem_id} "
                f"not in {ADVENTURER_VILLAIN_PROBLEMS[villain_id]}"
            )


def test_pick_pairing_adventurer_unknown_power_raises():
    with pytest.raises(ValueError):
        pick_pairing("super_potato", band="adventurer")


def test_pick_pairing_adventurer_only_powers_route_correctly():
    """strategist and gadgeteer must not exist on Sprout/Explorer bands, but
    must work on Adventurer band."""
    for bad_band in ("sprout", "explorer"):
        with pytest.raises(ValueError):
            pick_pairing("strategist", band=bad_band)
        with pytest.raises(ValueError):
            pick_pairing("gadgeteer", band=bad_band)

    v1, _ = pick_pairing("strategist", seed=0, band="adventurer")
    v2, _ = pick_pairing("gadgeteer", seed=0, band="adventurer")
    assert v1 in ADVENTURER_VILLAINS
    assert v2 in ADVENTURER_VILLAINS


def test_adventurer_every_villain_reachable_from_some_power():
    referenced = set()
    for spec in ADVENTURER_POWERS.values():
        referenced.add(spec["ideal"])
        referenced.update(spec.get("also", []))
    missing = set(ADVENTURER_VILLAINS.keys()) - referenced
    assert not missing, f"Orphan Adventurer villains: {missing}"


def test_adventurer_every_problem_reachable_from_some_villain():
    referenced = set()
    for plist in ADVENTURER_VILLAIN_PROBLEMS.values():
        referenced.update(plist)
    missing = set(ADVENTURER_PROBLEMS.keys()) - referenced
    assert not missing, f"Orphan Adventurer problems: {missing}"


def test_pick_pairing_adventurer_seed_is_reproducible():
    for power_id in ADVENTURER_POWERS:
        a = pick_pairing(power_id, seed=12345, band="adventurer")
        b = pick_pairing(power_id, seed=12345, band="adventurer")
        assert a == b


def test_pick_pairing_adventurer_respects_recent_villains():
    spec = ADVENTURER_POWERS["super_smile"]
    allowed = [spec["ideal"]] + spec["also"]
    survivor = allowed[-1]
    blocked = [v for v in allowed if v != survivor]
    for seed in range(5):
        villain_id, _ = pick_pairing(
            "super_smile",
            seed=seed,
            recent_villains=blocked,
            band="adventurer",
        )
        assert villain_id == survivor


def test_get_band_tables_returns_adventurer_set():
    v_a, p_a, pw_a, vp_a = get_band_tables("adventurer")
    assert v_a is ADVENTURER_VILLAINS
    assert p_a is ADVENTURER_PROBLEMS
    assert pw_a is ADVENTURER_POWERS
    assert vp_a is ADVENTURER_VILLAIN_PROBLEMS
