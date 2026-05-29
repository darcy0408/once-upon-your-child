"""Unit tests for backend.data.superhero_matrix.

These tests exercise the villain/problem/power compatibility matrix
that backs Superhero Mode (ages 3-5). They do NOT hit Gemini, the
Flask app, or the database — only the pure data module.
"""

from __future__ import annotations

import pytest

from backend.data.superhero_matrix import (
    POWERS,
    PROBLEMS,
    VILLAIN_PROBLEMS,
    VILLAINS,
    pick_pairing,
)


# ---------------------------------------------------------------------------
# Sanity-check the static data shape — guards against future edits that
# would silently break the matrix.
# ---------------------------------------------------------------------------
def test_matrix_has_expected_cardinality():
    assert len(VILLAINS) == 10, "Spec calls for exactly 10 villains"
    assert len(PROBLEMS) == 10, "Spec calls for exactly 10 problems"
    assert len(POWERS) == 8, "Spec calls for exactly 8 powers"
    assert set(VILLAIN_PROBLEMS.keys()) == set(
        VILLAINS.keys()
    ), "Every villain must have a problem-compatibility row"


def test_each_power_has_ideal_and_at_least_four_alternatives():
    for power_id, spec in POWERS.items():
        assert (
            spec["ideal"] in VILLAINS
        ), f"{power_id}.ideal must reference a real villain"
        also = spec.get("also", [])
        assert len(also) >= 4, f"{power_id} needs >=4 also-works villains"
        for v in also:
            assert v in VILLAINS, f"{power_id}.also contains unknown villain '{v}'"
        # No duplicates between ideal and also.
        assert spec["ideal"] not in also, f"{power_id}.ideal duplicated in .also"


def test_every_villain_problem_entry_references_real_problems():
    for villain_id, problem_list in VILLAIN_PROBLEMS.items():
        assert len(problem_list) >= 1, f"{villain_id} has no compatible problems"
        for p in problem_list:
            assert p in PROBLEMS, f"{villain_id} references unknown problem '{p}'"


# ---------------------------------------------------------------------------
# pick_pairing — behavioural tests.
# ---------------------------------------------------------------------------
def test_pick_pairing_returns_sensible_pair_for_each_power():
    """For each of the 8 powers, pick_pairing must return a (villain, problem)
    pair where the villain is in the power's compatibility list AND the
    problem is in that villain's compatible problems."""
    for power_id, spec in POWERS.items():
        allowed_villains = {spec["ideal"], *spec.get("also", [])}
        # Seed each call so the test is deterministic across CI runs.
        for seed in range(10):
            villain_id, problem_id = pick_pairing(power_id, seed=seed)
            assert (
                villain_id in allowed_villains
            ), f"{power_id} returned villain={villain_id} not in {allowed_villains}"
            assert problem_id in VILLAIN_PROBLEMS[villain_id], (
                f"villain={villain_id} returned problem={problem_id} "
                f"not in {VILLAIN_PROBLEMS[villain_id]}"
            )


def test_pick_pairing_unknown_power_raises():
    with pytest.raises(ValueError):
        pick_pairing("super_potato")


def test_pick_pairing_varies_across_seeds():
    """With 10 different seeds, a single power must not yield 10 identical
    pairs. (The ideal villain is weight-2 but ``also`` candidates are
    weight-1, so we expect some spread.)"""
    pairs = {pick_pairing("super_speed", seed=i) for i in range(10)}
    assert (
        len(pairs) > 1
    ), "10 seeded calls all returned the same pair — distribution is broken"


def test_pick_pairing_respects_recent_villains():
    """If the caller passes a recent-villain history, those villains
    should be skipped — UNLESS the recent list eats every option, in
    which case the function falls back to the full pool so generation
    is never blocked."""
    spec = POWERS["super_smile"]
    allowed = [spec["ideal"]] + spec["also"]

    # Block all but one — the survivor must be picked every time.
    survivor = allowed[-1]
    blocked = [v for v in allowed if v != survivor]
    for seed in range(5):
        villain_id, _ = pick_pairing(
            "super_smile",
            seed=seed,
            recent_villains=blocked,
        )
        assert villain_id == survivor

    # Block ALL — must still return something, not raise.
    villain_id, _ = pick_pairing(
        "super_smile",
        seed=0,
        recent_villains=allowed,
    )
    assert villain_id in allowed


def test_pick_pairing_respects_recent_problems():
    """Same fallback rule for problems."""
    villain_id, problem_id = pick_pairing(
        "super_speed",
        seed=42,
        recent_problems=["get_back"],
    )
    # If the chosen villain's pool only had get_back, the fallback rule
    # would return get_back anyway. Otherwise it must NOT be get_back.
    pool = VILLAIN_PROBLEMS[villain_id]
    if len(pool) > 1:
        assert problem_id != "get_back" or pool == ["get_back"]


def test_pick_pairing_covers_all_villains_across_powers():
    """Every villain must appear in at least one valid (power, villain)
    relationship — i.e. no orphan villains the heroes can never face."""
    referenced_villains = set()
    for power_id, spec in POWERS.items():
        referenced_villains.add(spec["ideal"])
        referenced_villains.update(spec.get("also", []))
    missing = set(VILLAINS.keys()) - referenced_villains
    assert not missing, f"Orphan villains never reachable from any power: {missing}"


def test_pick_pairing_covers_all_problems_across_villains():
    """Every problem must appear in at least one villain's compatible-problem
    list — no orphan problems."""
    referenced_problems = set()
    for problems in VILLAIN_PROBLEMS.values():
        referenced_problems.update(problems)
    missing = set(PROBLEMS.keys()) - referenced_problems
    assert not missing, f"Orphan problems never reachable from any villain: {missing}"


def test_pick_pairing_seed_is_reproducible():
    """Same seed = same result. Required so the frontend (or tests) can
    pin down a specific pairing for snapshot tests."""
    for power_id in POWERS:
        a = pick_pairing(power_id, seed=12345)
        b = pick_pairing(power_id, seed=12345)
        assert a == b, f"{power_id}: seeded pick_pairing is not deterministic"
