#!/usr/bin/env python3
"""
Story Weaver — Story Quality Audit (prod provider chain)

Generates real AI stories across the 6 age bands and evaluates them for:
  · Content quality (title, word count, story structure)
  · Age-appropriateness (vocabulary complexity, sentence length, safety)
  · Companion inclusion (named companion appears in story)
  · Therapeutic vocabulary (emotional language present)
  · Band-specific tone (age-appropriate language markers)

Generation goes through the SAME orchestration the Celery task uses
(backend/tasks/story_tasks.py generate_story_task), so a harness run measures
exactly what production ships:

  1. ``AdvancedStoryEngine.generate_enhanced_prompt(...)`` — the real prompt
     builder for the standard story path.
  2. ``backend.tasks.story_tasks._generate_story_text_with_metadata(...)`` —
     the real provider sequencing. Provider selection respects
     ``STORY_GEN_PROVIDER`` exactly like prod (prod runs ``openai`` =
     GPT-5 mini direct).
  3. ``_safe_extract_title_and_gem(...)`` — the real response parser.

LOCAL RECIPE: set ``STORY_GEN_PROVIDER=openrouter`` with ``OPENROUTER_API_KEY``
in ``backend/.env`` — this hits gpt-5-mini via OpenRouter, the established
local test path. Do NOT point this harness at Gemini: the Gemini API terms
forbid under-18 apps, which is why prod migrated off it.

Each result is stamped with the resolved prompt ``(template_id,
revision_hash)`` from ``backend.services.prompt_versioning`` — the same values
prod persists on Story rows — so before/after prompt-change comparisons are
automatic. Use ``--compare old.json new.json`` for per-band deltas.

MANUAL / LOCAL ONLY — every story is a real, paid API call. This file is
deliberately NOT collected by pytest (the filename does not match the
``test_*.py`` collection pattern and it defines no ``test_`` functions);
keep it that way.

Usage (from repo root):
    python backend/tests/quality/run_story_quality.py
    python backend/tests/quality/run_story_quality.py --bands sprout,explorer
    python backend/tests/quality/run_story_quality.py --samples 3
    python backend/tests/quality/run_story_quality.py --output backend/tests/quality/results/my-run.json
    python backend/tests/quality/run_story_quality.py --compare old.json new.json

Results are saved to: backend/tests/quality/results/story-quality-<timestamp>.json
"""

import argparse
import collections
import datetime
import json
import os
import re
import sys
import time

# Windows consoles often default to cp1252, which can't render the harness's
# box-drawing/check-mark glyphs. Never let cosmetic output crash a paid run.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):  # pragma: no cover — non-tty/legacy
        pass

# ── Load backend/.env before anything reads env vars ─────────────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_BACKEND_DIR = os.path.abspath(os.path.join(_HERE, "../.."))
_REPO_ROOT = os.path.abspath(os.path.join(_BACKEND_DIR, ".."))
_ENV_FILE = os.path.join(_BACKEND_DIR, ".env")
if os.path.exists(_ENV_FILE):
    from dotenv import load_dotenv

    load_dotenv(dotenv_path=_ENV_FILE, override=False)

sys.path.insert(0, _REPO_ROOT)

# ── ANSI colour helpers ───────────────────────────────────────────────────────
_G = "\033[92m"
_R = "\033[91m"
_Y = "\033[93m"
_C = "\033[96m"
_B = "\033[1m"
_X = "\033[0m"
ok = lambda s: f"{_G}✓{_X} {s}"  # noqa: E731
fail = lambda s: f"{_R}✗{_X} {s}"  # noqa: E731
warn = lambda s: f"{_Y}⚠{_X} {s}"  # noqa: E731

# ── Canonical word ranges ─────────────────────────────────────────────────────
# Single source of truth is backend/services/word_ranges.get_word_range
# (PR #459, branch fix/word-range-unification). Until #459 merges, the
# fallback below mirrors its standard-mode math exactly (AGE_CONSTRAINTS
# "regular" table + the sprout page-driven override, FLOOR_RATIO=0.75,
# CAP_RATIO=1.20). DELETE the fallback once #459 lands on main.

_SpecTuple = collections.namedtuple(
    "WordRangeSpec", "target_min target_max floor cap source"
)

# Transcribed from word_ranges.py on fix/word-range-unification — keep in sync
# until the real module merges, then delete.
_FALLBACK_FLOOR_RATIO = 0.75
_FALLBACK_CAP_RATIO = 1.20
_FALLBACK_SPROUT_PAGES = {"short": 8, "medium": 10, "long": 12}
_FALLBACK_SPROUT_WORDS_PER_PAGE = (12, 25)

_word_ranges_source = None  # resolved on first call; recorded in the JSON


def _normalize_length_key(story_length):
    if story_length in ("short", "quick"):
        return "short"
    if story_length in ("long", "epic"):
        return "long"
    return "medium"


def _fallback_word_range(age, story_length):
    """Local mirror of word_ranges.get_word_range(mode='standard').

    HARNESS FALLBACK ONLY — used when backend.services.word_ranges is not
    importable (PR #459 not merged yet). Reads the same canonical prompt
    tables the real module reads.
    """
    from backend.services.story_service import AGE_CONSTRAINTS, _get_age_band

    age_int = int(age)
    length_key = _normalize_length_key(story_length)
    if age_int <= 5:
        pages = _FALLBACK_SPROUT_PAGES[length_key]
        lo = pages * _FALLBACK_SPROUT_WORDS_PER_PAGE[0]
        hi = pages * _FALLBACK_SPROUT_WORDS_PER_PAGE[1]
        source = f"standard:sprout:{length_key}:pages={pages}"
    else:
        band = _get_age_band(age_int)
        lo, hi = AGE_CONSTRAINTS[band]["regular"][length_key]
        source = f"standard:{band}:{length_key}"
    return _SpecTuple(
        target_min=int(lo),
        target_max=int(hi),
        floor=int(lo * _FALLBACK_FLOOR_RATIO),
        cap=int(hi * _FALLBACK_CAP_RATIO),
        source=source + " (harness fallback — merge PR #459)",
    )


def get_word_range_spec(age, story_length):
    """Canonical (target, floor, cap) word contract for a standard story."""
    global _word_ranges_source
    try:
        from backend.services.word_ranges import get_word_range

        _word_ranges_source = "backend.services.word_ranges"
        return get_word_range(age, mode="standard", story_length=story_length)
    except ImportError:
        _word_ranges_source = "harness fallback (PR #459 pending)"
        return _fallback_word_range(age, story_length)


# ── Safety: words that must never appear ─────────────────────────────────────
UNIVERSAL_RED_FLAGS = [
    "pornograph",
    "explicit sex",
    "graphic sex",
    "sexual assault",
    "rape",
    "child abuse",
]
# Additional bans for child-band stories (sprout / explorer / adventurer)
CHILD_RED_FLAGS = [
    "blood",
    "corpse",
    "murder",
    "stabbed",
    "decapitat",
    "nude",
    "naked body",
]

# ── Therapeutic / emotional vocabulary ───────────────────────────────────────
FEELING_WORDS = [
    "feel",
    "feeling",
    "heart",
    "brave",
    "courage",
    "scared",
    "worried",
    "happy",
    "sad",
    "angry",
    "calm",
    "safe",
    "love",
    "friend",
    "together",
    "hope",
    "trust",
    "help",
    "kind",
]

# ── Band-specific tone markers ────────────────────────────────────────────────
BAND_TONE = {
    "sprout": ["sparkle", "glow", "hug", "soft", "warm", "giggle", "bright", "cozy"],
    "explorer": ["discover", "magical", "quest", "wonder", "mysterious", "adventure"],
    "adventurer": ["challenge", "mystery", "secret", "power", "brave", "ancient"],
    "creator": ["create", "imagine", "decide", "design", "clever", "art", "story"],
    "adolescent": ["reflect", "real", "matter", "alone", "understand", "choice"],
    "adult": ["reflect", "journey", "meaning", "wisdom", "grown", "learn"],
}

# ── Test cases: one per band ──────────────────────────────────────────────────
TEST_CASES = [
    {
        "label": "Sprout (age 3)",
        "band": "sprout",
        "age": 3,
        "character": "Lily",
        "theme": "Ocean Adventure",
        "companion_pets": [{"name": "Bubbles", "species": "dolphin"}],
        "companion_characters": [],
        "story_length": "standard",
        "expected_companion": "Bubbles",
    },
    {
        "label": "Explorer (age 7)",
        "band": "explorer",
        "age": 7,
        "character": "Max",
        "theme": "Magical Forest",
        "companion_pets": [{"name": "Sparkle", "species": "unicorn"}],
        "companion_characters": [],
        "story_length": "standard",
        "expected_companion": "Sparkle",
    },
    {
        "label": "Adventurer (age 10)",
        "band": "adventurer",
        "age": 10,
        "character": "Zoe",
        "theme": "Crystal Cave",
        "companion_pets": [],
        "companion_characters": [
            {"name": "Finn", "description": "a brave explorer friend"}
        ],
        "story_length": "standard",
        "expected_companion": "Finn",
    },
    {
        "label": "Creator (age 13)",
        "band": "creator",
        "age": 13,
        "character": "Sam",
        "theme": "Art Gallery Mystery",
        "companion_pets": [],
        "companion_characters": [
            {"name": "Jordan", "description": "creative partner and best friend"}
        ],
        "story_length": "standard",
        "expected_companion": "Jordan",
    },
    {
        "label": "Adolescent (age 16)",
        "band": "adolescent",
        "age": 16,
        "character": "Alex",
        "theme": "Midnight Observatory",
        "companion_pets": [],
        "companion_characters": [
            {
                "name": "River",
                "description": "trusted friend with a different perspective",
            }
        ],
        "story_length": "standard",
        "expected_companion": "River",
    },
    {
        "label": "Adult (age 25)",
        "band": "adult",
        "age": 25,
        "character": "Morgan",
        "theme": "Mountain Journey",
        "companion_pets": [],
        "companion_characters": [],
        "story_length": "standard",
        "expected_companion": None,
    },
]

ALL_BANDS = [tc["band"] for tc in TEST_CASES]

# Which env var each STORY_GEN_PROVIDER choice needs. Never print the values —
# only whether they are present.
_PROVIDER_KEY_VARS = {
    "openrouter": ("OPENROUTER_API_KEY",),
    "openai": ("OPENAI_API_KEY",),
    "claude": ("ANTHROPIC_API_KEY",),
    "tiered": ("OPENAI_API_KEY", "ANTHROPIC_API_KEY"),
}

# ── Helper functions ──────────────────────────────────────────────────────────


def word_count(text: str) -> int:
    return len(re.findall(r"\b\w+\b", text))


def avg_sentence_length(text: str) -> float:
    sentences = [s.strip() for s in re.split(r"[.!?]+", text) if s.strip()]
    if not sentences:
        return 0.0
    return sum(len(re.findall(r"\b\w+\b", s)) for s in sentences) / len(sentences)


def red_flag_check(text: str, band: str) -> list:
    low = text.lower()
    hits = [
        w for w in UNIVERSAL_RED_FLAGS if re.search(r"\b" + re.escape(w) + r"\b", low)
    ]
    if band in ("sprout", "explorer", "adventurer"):
        hits += [
            w for w in CHILD_RED_FLAGS if re.search(r"\b" + re.escape(w) + r"\b", low)
        ]
    return hits


def evaluate(tc: dict, story_text: str, title: str, spec) -> dict:
    """Return {check_name: (passed: bool, detail: str)}.

    ``spec`` is the canonical word-range contract (get_word_range_spec) for
    this band/length — target_min/target_max are what the live prompt asks
    for; floor is the validation minimum prod retries below; cap is where
    prod's truncate/regen belt kicks in.
    """
    band = tc["band"]
    char = tc["character"]
    companion = tc.get("expected_companion")
    checks = {}

    # 1. Has content
    checks["has_content"] = (
        len(story_text) > 80,
        f"{len(story_text):,} chars",
    )

    # 2. Has title
    t = title.strip() if title else ""
    checks["has_title"] = (bool(t), f'"{t[:60]}"' if t else "— missing")

    # 3. Character name in story
    n = story_text.lower().count(char.lower())
    checks["character_named"] = (n > 0, f'"{char}" ×{n}')

    # 4. Companion named
    if companion:
        c = story_text.lower().count(companion.lower())
        checks["companion_named"] = (c > 0, f'"{companion}" ×{c}')
    else:
        checks["companion_named"] = (True, "no companion (expected none)")

    # 5. Word count vs the canonical contract
    wc = word_count(story_text)
    if wc < spec.floor:
        wc_pass, wc_tag = False, f"BELOW floor {spec.floor:,} (prod would retry)"
    elif wc < spec.target_min:
        wc_pass, wc_tag = True, "↓ low"
    elif wc > spec.cap:
        wc_pass, wc_tag = True, f"↑ above cap {spec.cap:,} (prod would truncate/regen)"
    elif wc > spec.target_max:
        wc_pass, wc_tag = True, "↑ high"
    else:
        wc_pass, wc_tag = True, "✓"
    checks["word_count"] = (
        wc_pass,
        f"{wc:,} words (target {spec.target_min:,}–{spec.target_max:,}) {wc_tag}",
    )

    # 6. No red flags
    flags = red_flag_check(story_text, band)
    checks["no_red_flags"] = (
        not flags,
        "clean" if not flags else f"FLAGGED: {', '.join(flags)}",
    )

    # 7. Therapeutic vocabulary
    hits = [w for w in FEELING_WORDS if w in story_text.lower()]
    checks["therapeutic_vocab"] = (
        len(hits) >= 2,
        f"{len(hits)} matches: {', '.join(hits[:6])}{'…' if len(hits) > 6 else ''}",
    )

    # 8. Sentence simplicity (Sprout only — target ≤14 avg words/sentence)
    if band == "sprout":
        avg = avg_sentence_length(story_text)
        checks["sentence_simplicity"] = (
            avg <= 14,
            f"avg {avg:.1f} words/sent (target ≤14)",
        )

    # 9. Band tone words
    tone_words = BAND_TONE.get(band, [])
    if tone_words:
        tone_hits = [w for w in tone_words if w in story_text.lower()]
        checks["band_tone"] = (
            len(tone_hits) >= 1,
            (
                f"{len(tone_hits)} matches: {', '.join(tone_hits[:4])}{'…' if len(tone_hits) > 4 else ''}"
                if tone_hits
                else "none found"
            ),
        )

    return checks


# ── Compare helper ────────────────────────────────────────────────────────────


def _band_rollup(report: dict) -> dict:
    """Aggregate a results JSON into per-band stats for comparison."""
    rollup = {}
    for r in report.get("results", []):
        band = r.get("band", "?")
        agg = rollup.setdefault(
            band,
            {
                "samples": 0,
                "errors": 0,
                "checks_passed": 0,
                "checks_total": 0,
                "word_counts": [],
                "template_id": None,
                "revision_hash": None,
            },
        )
        agg["samples"] += 1
        if r.get("error"):
            agg["errors"] += 1
        for v in r.get("checks", {}).values():
            agg["checks_total"] += 1
            if v.get("passed"):
                agg["checks_passed"] += 1
        if r.get("word_count"):
            agg["word_counts"].append(r["word_count"])
        # Older results (pre prompt-versioning) simply won't have these keys.
        agg["template_id"] = r.get("prompt_template_id") or agg["template_id"]
        agg["revision_hash"] = r.get("prompt_revision_hash") or agg["revision_hash"]
    return rollup


def compare_reports(old_path: str, new_path: str) -> int:
    with open(old_path, "r", encoding="utf-8") as f:
        old = json.load(f)
    with open(new_path, "r", encoding="utf-8") as f:
        new = json.load(f)

    old_roll = _band_rollup(old)
    new_roll = _band_rollup(new)

    print(f"\n{_B}Story-quality comparison{_X}")
    print(f"  old: {old_path}  (run_at {old.get('run_at', '?')})")
    print(f"  new: {new_path}  (run_at {new.get('run_at', '?')})")
    op, np_ = old.get("provider", "?"), new.get("provider", "?")
    tag = "" if op == np_ else f"  {_Y}(provider changed!){_X}"
    print(f"  provider: {op} → {np_}{tag}\n")

    header = (
        f"  {'band':<12} {'checks (old→new)':<22} {'avg words (old→new)':<24} prompt"
    )
    print(header)
    print("  " + "─" * (len(header) - 2))
    extra_bands = sorted((set(old_roll) | set(new_roll)) - set(ALL_BANDS))
    for band in ALL_BANDS + extra_bands:
        o, n = old_roll.get(band), new_roll.get(band)
        if not o and not n:
            continue

        def _fmt(agg):
            if not agg:
                return "—", "—"
            checks = f"{agg['checks_passed']}/{agg['checks_total']}"
            if agg["errors"]:
                checks += f" ({agg['errors']} err)"
            wcs = agg["word_counts"]
            avg_wc = f"{sum(wcs) / len(wcs):,.0f}" if wcs else "—"
            return checks, avg_wc

        o_checks, o_wc = _fmt(o)
        n_checks, n_wc = _fmt(n)

        o_hash = (o or {}).get("revision_hash")
        n_hash = (n or {}).get("revision_hash")
        if o_hash and n_hash:
            prompt_note = (
                f"{_Y}revision changed {o_hash[:8]}→{n_hash[:8]}{_X}"
                if o_hash != n_hash
                else f"same revision {n_hash[:8]}"
            )
        else:
            prompt_note = "no revision info (old-format run?)"

        print(
            f"  {band:<12} {o_checks + ' → ' + n_checks:<22} "
            f"{o_wc + ' → ' + n_wc:<24} {prompt_note}"
        )
    print()
    return 0


# ── Main ──────────────────────────────────────────────────────────────────────


def run_audit(bands: list, samples: int, output_path: str) -> int:
    print(f"\n{_B}{_C}╔══════════════════════════════════════════════════════════╗{_X}")
    print(f"{_B}{_C}║   Story Weaver — Quality Audit  (prod provider chain)    ║{_X}")
    print(f"{_B}{_C}║   Real paid API calls · quality · age-fit · companions   ║{_X}")
    print(f"{_B}{_C}╚══════════════════════════════════════════════════════════╝{_X}\n")

    # Import here (not at module top) so --compare works without backend deps
    # and so backend/.env is loaded first.
    from backend.services.prompt_versioning import resolve as resolve_prompt_version
    from backend.services.story_service import (
        AdvancedStoryEngine,
        _safe_extract_title_and_gem,
    )
    from backend.tasks.story_tasks import (
        _generate_story_text_with_metadata,
        _resolve_story_provider,
    )

    provider_choice = _resolve_story_provider()
    missing = [
        var
        for var in _PROVIDER_KEY_VARS.get(provider_choice, ())
        if not os.environ.get(var)
    ]
    print(f"  Provider : STORY_GEN_PROVIDER={provider_choice}")
    if provider_choice == "gemini":
        print(
            f"  {_R}ERROR: STORY_GEN_PROVIDER=gemini — prod no longer uses Gemini for"
            f" story text (its API terms forbid under-18 apps). Use openrouter"
            f" locally or openai.{_X}"
        )
        return 1
    if missing:
        print(
            f"  {_R}ERROR: {', '.join(missing)} not set — provider "
            f"'{provider_choice}' cannot run. Check backend/.env{_X}"
        )
        return 1

    cases = [tc for tc in TEST_CASES if tc["band"] in bands]
    total_runs = len(cases) * samples
    print(f"  Bands    : {', '.join(tc['band'] for tc in cases)}")
    print(f"  Samples  : {samples} per band → {total_runs} stories\n")

    engine = AdvancedStoryEngine()

    print(f"Running {total_runs} story generation(s)…\n")
    print("─" * 62)

    all_results = []
    prompt_versions = {}
    run_start = time.time()
    run_idx = 0

    for tc in cases:
        spec = get_word_range_spec(tc["age"], tc["story_length"])
        template_id, revision_hash = resolve_prompt_version(
            mode="standard", age=tc["age"]
        )
        prompt_versions[tc["band"]] = {
            "template_id": template_id,
            "revision_hash": revision_hash,
        }

        for sample_idx in range(1, samples + 1):
            run_idx += 1
            companion = tc.get("expected_companion") or "—"
            comp_note = f"  companion: {_B}{companion}{_X}" if companion != "—" else ""
            sample_note = f" [sample {sample_idx}/{samples}]" if samples > 1 else ""
            print(
                f"\n[{run_idx}/{total_runs}] {_B}{tc['label']}{_X}{sample_note}"
                f"  \"{tc['theme']}\"{comp_note}"
            )

            t0 = time.time()
            story_text = title = ""
            pages = []
            error = None
            checks = {}
            provider_name = None
            provider_sequence = []

            try:
                # Same prompt builder the Celery task's standard path calls.
                prompt = engine.generate_enhanced_prompt(
                    character=tc["character"],
                    age=tc["age"],
                    theme=tc["theme"],
                    companion_pets=tc.get("companion_pets", []),
                    companion_characters=tc.get("companion_characters", []),
                    story_length=tc["story_length"],
                )

                # Same provider sequencing the Celery task calls — respects
                # STORY_GEN_PROVIDER, falls back exactly like prod.
                raw, provider_name, provider_sequence = (
                    _generate_story_text_with_metadata(
                        prompt,
                        tc["theme"],
                        tc["character"],
                        tc.get("expected_companion"),
                        user_tier="free",
                    )
                )
                elapsed = time.time() - t0

                if provider_name == "static":
                    raise ValueError(
                        "all providers failed — static fallback returned "
                        f"(sequence: {', '.join(provider_sequence)})"
                    )

                title, _, story_text, pages, _, _ = _safe_extract_title_and_gem(
                    raw, tc["theme"]
                )
                if not story_text and pages:
                    story_text = "\n\n".join(pages)

                wc = word_count(story_text)
                print(
                    f"  Generated in {elapsed:.1f}s via {provider_name}"
                    f" — {wc:,} words, {len(pages)} page(s)"
                )

                checks = evaluate(tc, story_text, title, spec)
                for name, (passed, detail) in checks.items():
                    label = name.replace("_", " ")
                    line = (
                        ok(f"{label:<28} {detail}")
                        if passed
                        else fail(f"{label:<28} {detail}")
                    )
                    print(f"    {line}")

            except Exception as exc:
                elapsed = time.time() - t0
                error = str(exc)
                print(f"    {fail('FAILED')} ({elapsed:.1f}s) — {error[:140]}")

            all_results.append(
                {
                    "band": tc["band"],
                    "age": tc["age"],
                    "sample": sample_idx,
                    "character": tc["character"],
                    "theme": tc["theme"],
                    "companion": companion,
                    "provider": provider_name,
                    "provider_sequence": provider_sequence,
                    "prompt_template_id": template_id,
                    "prompt_revision_hash": revision_hash,
                    "word_range": {
                        "target_min": spec.target_min,
                        "target_max": spec.target_max,
                        "floor": spec.floor,
                        "cap": spec.cap,
                        "source": spec.source,
                    },
                    "error": error,
                    "title": title,
                    "word_count": word_count(story_text) if story_text else 0,
                    "page_count": len(pages),
                    "story_preview": story_text[:500] if story_text else "",
                    "elapsed_s": round(time.time() - t0, 1),
                    "checks": {
                        k: {"passed": v[0], "detail": v[1]} for k, v in checks.items()
                    },
                }
            )

    # ── Summary ───────────────────────────────────────────────────────────────
    total_elapsed = time.time() - run_start
    print("\n" + "─" * 62)

    generated = sum(1 for r in all_results if not r["error"])
    total_checks = sum(len(r["checks"]) for r in all_results)
    passed_checks = sum(
        sum(1 for v in r["checks"].values() if v["passed"]) for r in all_results
    )
    all_clean = all(
        not r["error"] and all(v["passed"] for v in r["checks"].values())
        for r in all_results
    )

    print(f"\n{_B}SUMMARY{_X}  (total time: {total_elapsed:.0f}s)")
    print(f"  Stories generated : {generated}/{len(all_results)}")
    print(f"  Checks passed     : {passed_checks}/{total_checks}")
    if _word_ranges_source and "fallback" in _word_ranges_source:
        print(f"  {warn('Word ranges from harness fallback — merge PR #459')}")

    if all_clean:
        print(f"\n  {_G}{_B}All bands passed all checks.{_X}")
    else:
        issues = sorted(
            {
                r["band"]
                for r in all_results
                if r["error"] or any(not v["passed"] for v in r["checks"].values())
            }
        )
        print(f"\n  {_Y}Issues in band(s): {', '.join(issues)}{_X}")
        for r in all_results:
            failed = [k for k, v in r["checks"].items() if not v["passed"]]
            if r["error"]:
                print(f"    {_R}✗{_X} {r['band']:<12} ERROR: {r['error'][:80]}")
            elif failed:
                for f_name in failed:
                    detail = r["checks"][f_name]["detail"]
                    print(f"    {_R}✗{_X} {r['band']:<12} {f_name}: {detail}")

    # ── Save JSON report ───────────────────────────────────────────────────────
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    ts = datetime.datetime.now().strftime("%Y-%m-%d-%H%M")
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(
            {
                "run_at": ts,
                "provider": provider_choice,
                "samples_per_band": samples,
                "word_ranges_source": _word_ranges_source,
                "prompt_versions": prompt_versions,
                "generated": generated,
                "total": len(all_results),
                "checks_passed": passed_checks,
                "checks_total": total_checks,
                "results": all_results,
            },
            f,
            indent=2,
            ensure_ascii=False,
        )

    print(f"\n  Report saved → {output_path}\n")
    return 0


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Story quality audit through the prod provider chain "
            "(manual/local only — real paid API calls)"
        )
    )
    parser.add_argument(
        "--bands",
        default=",".join(ALL_BANDS),
        help=f"comma-separated bands to run (default: all — {','.join(ALL_BANDS)})",
    )
    parser.add_argument(
        "--samples",
        type=int,
        default=1,
        help="stories to generate per band (default: 1)",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="output JSON path (default: results/story-quality-<timestamp>.json)",
    )
    parser.add_argument(
        "--compare",
        nargs=2,
        metavar=("OLD_JSON", "NEW_JSON"),
        help="compare two result files (per-band deltas) instead of running",
    )
    args = parser.parse_args()

    if args.compare:
        sys.exit(compare_reports(args.compare[0], args.compare[1]))

    bands = [b.strip().lower() for b in args.bands.split(",") if b.strip()]
    unknown = [b for b in bands if b not in ALL_BANDS]
    if unknown:
        print(
            f"{_R}Unknown band(s): {', '.join(unknown)} — valid: {', '.join(ALL_BANDS)}{_X}"
        )
        sys.exit(2)
    if args.samples < 1:
        print(f"{_R}--samples must be >= 1{_X}")
        sys.exit(2)

    if args.output:
        output_path = os.path.abspath(args.output)
    else:
        ts = datetime.datetime.now().strftime("%Y-%m-%d-%H%M")
        output_path = os.path.join(_HERE, "results", f"story-quality-{ts}.json")

    sys.exit(run_audit(bands, args.samples, output_path))


if __name__ == "__main__":
    main()
