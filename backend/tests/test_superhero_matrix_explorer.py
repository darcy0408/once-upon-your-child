"""Unit tests for the Explorer-band (ages 6-8) section of superhero_matrix.

Parallel to test_superhero_matrix.py — exercises the same invariants
against the EXPLORER_* tables plus the band-aware pick_pairing path.
"""

from __future__ import annotations

import pytest

from backend.data.superhero_matrix import (
    EXPLORER_POWERS,
    EXPLORER_PROBLEMS,
    EXPLORER_VILLAIN_PROBLEMS,
    EXPLORER_VILLAINS,
    POWERS,
    VILLAINS,
    get_band_tables,
    pick_pairing,
)


def test_explorer_matrix_has_expected_cardinality():
    assert len(EXPLORER_VILLAINS) == 8
    assert len(EXPLORER_PROBLEMS) == 8
    assert len(EXPLORER_POWERS) == 10  # 8 Sprout IDs + feeling_sense + invisibility
    assert set(EXPLORER_VILLAIN_PROBLEMS.keys()) == set(EXPLORER_VILLAINS.keys())


def test_explorer_reuses_sprout_power_ids_plus_two():
    """Frontend keeps the 8 Sprout power IDs and adds 2 Explorer-only."""
    sprout_ids = set(POWERS.keys())
    explorer_only = {"feeling_sense", "invisibility"}
    assert set(EXPLORER_POWERS.keys()) == sprout_ids | explorer_only


def test_explorer_power_specs_reference_real_villains():
    for power_id, spec in EXPLORER_POWERS.items():
        assert (
            spec["ideal"] in EXPLORER_VILLAINS
        ), f"{power_id}.ideal must reference a real Explorer villain"
        also = spec.get("also", [])
        assert len(also) >= 4, f"{power_id} needs >=4 also-works villains"
        for v in also:
            assert (
                v in EXPLORER_VILLAINS
            ), f"{power_id}.also contains unknown villain '{v}'"
        assert spec["ideal"] not in also, f"{power_id}.ideal duplicated in .also"


def test_explorer_villain_problem_entries_reference_real_problems():
    for villain_id, problem_list in EXPLORER_VILLAIN_PROBLEMS.items():
        assert len(problem_list) >= 1
        for p in problem_list:
            assert (
                p in EXPLORER_PROBLEMS
            ), f"{villain_id} references unknown problem '{p}'"


def test_explorer_villains_and_problems_are_namespaced_distinct_from_sprout():
    """No accidental ID collisions — Sprout and Explorer share the schema
    but never share an ID for villains or problems."""
    assert not (
        set(EXPLORER_VILLAINS) & set(VILLAINS)
    ), "Sprout/Explorer villain IDs collide — rename one set"
    # Problems intentionally do NOT collide either; the IDs are different
    # phrases (e.g. clean_up vs restore_what_taken).
    from backend.data.superhero_matrix import PROBLEMS as SPROUT_PROBLEMS

    assert not (set(EXPLORER_PROBLEMS) & set(SPROUT_PROBLEMS))


def test_pick_pairing_explorer_returns_sensible_pair_for_each_power():
    for power_id, spec in EXPLORER_POWERS.items():
        allowed = {spec["ideal"], *spec.get("also", [])}
        for seed in range(10):
            villain_id, problem_id = pick_pairing(power_id, seed=seed, band="explorer")
            assert (
                villain_id in allowed
            ), f"{power_id} returned villain={villain_id} not in {allowed}"
            assert problem_id in EXPLORER_VILLAIN_PROBLEMS[villain_id], (
                f"villain={villain_id} returned problem={problem_id} "
                f"not in {EXPLORER_VILLAIN_PROBLEMS[villain_id]}"
            )


def test_pick_pairing_explorer_unknown_power_raises():
    with pytest.raises(ValueError):
        pick_pairing("super_potato", band="explorer")


def test_pick_pairing_sprout_unknown_power_raises():
    """Regression — make sure the band kwarg didn't break the Sprout error path."""
    with pytest.raises(ValueError):
        pick_pairing("super_potato")  # default band=sprout


def test_pick_pairing_default_band_is_sprout():
    """Backwards-compat — calls that don't pass band keep returning Sprout pairs."""
    villain_id, _ = pick_pairing("super_smile", seed=1)
    assert villain_id in VILLAINS
    assert villain_id not in EXPLORER_VILLAINS


def test_pick_pairing_explorer_only_powers_route_correctly():
    """feeling_sense and invisibility must not exist on Sprout band, but
    must work on Explorer band."""
    with pytest.raises(ValueError):
        pick_pairing("feeling_sense", band="sprout")
    with pytest.raises(ValueError):
        pick_pairing("invisibility", band="sprout")

    v1, _ = pick_pairing("feeling_sense", seed=0, band="explorer")
    v2, _ = pick_pairing("invisibility", seed=0, band="explorer")
    assert v1 in EXPLORER_VILLAINS
    assert v2 in EXPLORER_VILLAINS


def test_explorer_every_villain_reachable_from_some_power():
    referenced = set()
    for spec in EXPLORER_POWERS.values():
        referenced.add(spec["ideal"])
        referenced.update(spec.get("also", []))
    missing = set(EXPLORER_VILLAINS.keys()) - referenced
    assert not missing, f"Orphan Explorer villains: {missing}"


def test_explorer_every_problem_reachable_from_some_villain():
    referenced = set()
    for plist in EXPLORER_VILLAIN_PROBLEMS.values():
        referenced.update(plist)
    missing = set(EXPLORER_PROBLEMS.keys()) - referenced
    assert not missing, f"Orphan Explorer problems: {missing}"


def test_pick_pairing_explorer_seed_is_reproducible():
    for power_id in EXPLORER_POWERS:
        a = pick_pairing(power_id, seed=12345, band="explorer")
        b = pick_pairing(power_id, seed=12345, band="explorer")
        assert a == b


def test_pick_pairing_explorer_respects_recent_villains():
    spec = EXPLORER_POWERS["super_smile"]
    allowed = [spec["ideal"]] + spec["also"]
    survivor = allowed[-1]
    blocked = [v for v in allowed if v != survivor]
    for seed in range(5):
        villain_id, _ = pick_pairing(
            "super_smile",
            seed=seed,
            recent_villains=blocked,
            band="explorer",
        )
        assert villain_id == survivor


def test_get_band_tables_returns_correct_set():
    v_s, p_s, pw_s, vp_s = get_band_tables("sprout")
    v_e, p_e, pw_e, vp_e = get_band_tables("explorer")
    assert v_s is VILLAINS
    assert v_e is EXPLORER_VILLAINS
    assert pw_e is EXPLORER_POWERS
    assert vp_e is EXPLORER_VILLAIN_PROBLEMS


def test_get_band_tables_unknown_band_falls_back_to_sprout():
    v, _, _, _ = get_band_tables("creator")  # not a superhero band
    assert v is VILLAINS
