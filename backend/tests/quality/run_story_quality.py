#!/usr/bin/env python3
"""
Story Weaver — Story Quality Audit

Generates real AI stories across all 6 age bands and evaluates them for:
  · Content quality (title, word count, story structure)
  · Age-appropriateness (vocabulary complexity, sentence length, safety)
  · Companion inclusion (named companion appears in story)
  · Therapeutic vocabulary (emotional language present)
  · Band-specific tone (age-appropriate language markers)

Calls Gemini directly via the story service layer — no Flask, Celery, or auth
overhead needed.  Reads GEMINI_API_KEY from backend/.env automatically.

Usage (from repo root):
    python backend/tests/quality/run_story_quality.py

Results are saved to: backend/tests/quality/results/story-quality-<timestamp>.json
"""

import os
import sys
import json
import re
import time
import datetime

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
ok = lambda s: f"{_G}✓{_X} {s}"
fail = lambda s: f"{_R}✗{_X} {s}"
warn = lambda s: f"{_Y}⚠{_X} {s}"

# ── Word-count targets for story_length="standard" (= medium in AGE_CONSTRAINTS)
# (absolute_minimum, expected_low, expected_high)
WORD_TARGETS = {
    "sprout": (100, 300, 750),
    "explorer": (300, 650, 1400),
    "adventurer": (600, 1200, 2600),
    "creator": (800, 1800, 3600),
    "adolescent": (800, 2400, 4800),
    "adult": (400, 1200, 4800),
}

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


def evaluate(tc: dict, story_text: str, title: str) -> dict:
    """Return {check_name: (passed: bool, detail: str)}."""
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

    # 5. Word count
    wc = word_count(story_text)
    lo_min, lo_ok, hi_ok = WORD_TARGETS[band]
    if wc < lo_min:
        wc_pass, wc_tag = False, f"BELOW min {lo_min:,}"
    elif wc < lo_ok:
        wc_pass, wc_tag = True, "↓ low"
    elif wc > hi_ok:
        wc_pass, wc_tag = True, "↑ high"
    else:
        wc_pass, wc_tag = True, "✓"
    checks["word_count"] = (
        wc_pass,
        f"{wc:,} words (target {lo_ok:,}–{hi_ok:,}) {wc_tag}",
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


# ── Main ──────────────────────────────────────────────────────────────────────


def main():
    print(f"\n{_B}{_C}╔══════════════════════════════════════════════════════════╗{_X}")
    print(f"{_B}{_C}║   Story Weaver — Quality Audit  (Real Gemini calls)      ║{_X}")
    print(f"{_B}{_C}║   All 6 age bands · quality · age-fit · companions       ║{_X}")
    print(f"{_B}{_C}╚══════════════════════════════════════════════════════════╝{_X}\n")

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print(f"{_R}ERROR: GEMINI_API_KEY not found. Check backend/.env{_X}")
        sys.exit(1)

    model = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
    print(f"  API key : {api_key[:8]}…")
    print(f"  Model   : {model}")
    print(f"  Tests   : {len(TEST_CASES)} stories (one per age band)\n")

    from backend.services.story_service import (
        AdvancedStoryEngine,
        _safe_extract_title_and_gem,
    )
    from backend.services.story_generation_service import StoryGenerationService

    engine = AdvancedStoryEngine()
    generator = StoryGenerationService()

    print(f"Running {len(TEST_CASES)} story generation tests…  (~2–5 min)\n")
    print("─" * 62)

    all_results = []
    run_start = time.time()

    for idx, tc in enumerate(TEST_CASES, 1):
        companion = tc.get("expected_companion") or "—"
        comp_note = f"  companion: {_B}{companion}{_X}" if companion != "—" else ""
        print(
            f"\n[{idx}/{len(TEST_CASES)}] {_B}{tc['label']}{_X}  \"{tc['theme']}\"{comp_note}"
        )

        t0 = time.time()
        story_text = title = ""
        pages = []
        error = None
        checks = {}

        try:
            prompt = engine.generate_enhanced_prompt(
                character=tc["character"],
                age=tc["age"],
                theme=tc["theme"],
                companion_pets=tc.get("companion_pets", []),
                companion_characters=tc.get("companion_characters", []),
                story_length=tc["story_length"],
            )

            raw = generator.generate_story(prompt)
            elapsed = time.time() - t0

            if not raw or "wasn't able" in raw[:80] or raw.startswith("Sorry"):
                raise ValueError(f"AI returned non-story response: {raw[:100]}")

            title, _, story_text, pages, _, _ = _safe_extract_title_and_gem(
                raw, tc["theme"]
            )
            if not story_text and pages:
                story_text = "\n\n".join(pages)

            wc = word_count(story_text)
            print(f"  Generated in {elapsed:.1f}s — {wc:,} words, {len(pages)} page(s)")

            checks = evaluate(tc, story_text, title)
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
                "character": tc["character"],
                "theme": tc["theme"],
                "companion": companion,
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

    if all_clean:
        print(f"\n  {_G}{_B}All bands passed all checks.{_X}")
    else:
        issues = [
            r["band"]
            for r in all_results
            if r["error"] or any(not v["passed"] for v in r["checks"].values())
        ]
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
    results_dir = os.path.join(_HERE, "results")
    os.makedirs(results_dir, exist_ok=True)
    ts = datetime.datetime.now().strftime("%Y-%m-%d-%H%M")
    out_path = os.path.join(results_dir, f"story-quality-{ts}.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(
            {
                "run_at": ts,
                "model": model,
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

    print(f"\n  Report saved → {out_path}\n")


if __name__ == "__main__":
    main()
