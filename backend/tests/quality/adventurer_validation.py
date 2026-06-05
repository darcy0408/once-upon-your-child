#!/usr/bin/env python3
"""Audit 14 — consolidated multi-draw validation of the R1+R2+R4+R3 stack.

Generates N draws each at age 9 and age 11 with the post-R3 Adventurer companion
payload (Atlas + Nyx now carry `description`, so the model learns their species).
Prints cheap automated signals to triage which drafts to read closely:
  - species (R3): does Atlas read as a dragon and Nyx as a cat (vs humans)?
  - setback (try/fail tweak): is there visible failure language mid-story?
  - told-want anti-pattern: count of "wanted ..." tells (should trend down).

Run from repo root:  python backend/tests/quality/adventurer_validation.py
"""

import datetime
import json
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_BACKEND_DIR = os.path.abspath(os.path.join(_HERE, "../.."))
_REPO_ROOT = os.path.abspath(os.path.join(_BACKEND_DIR, ".."))
_ENV_FILE = os.path.join(_BACKEND_DIR, ".env")
if os.path.exists(_ENV_FILE):
    from dotenv import load_dotenv

    load_dotenv(dotenv_path=_ENV_FILE, override=False)

sys.path.insert(0, _REPO_ROOT)

OUT_DIR = os.path.join(_REPO_ROOT, "audit-reports", "generation-samples", "validation")
os.makedirs(OUT_DIR, exist_ok=True)

DRAWS = 3

# Post-R3 mapper output: Atlas + Nyx now carry description + behaviorPattern
# (no signaturePower — they still miss the magicCompanions id match, which is
# the content follow-up; description is what R3 added).
ATLAS = {
    "name": "Atlas",
    "description": "A blue-green scholar dragon with a compass medallion who knows every constellation. When the path is unclear he lifts his glasses and calculates. He admits when the map was wrong.",
    "behaviorPattern": "Atlas has mapped three routes before anyone finishes asking. He wears his compass because he actually needs it, not as a decoration. When the path is unclear he lifts his glasses and calculates. He is rarely surprised. He admits when the map was wrong.",
}
NYX = {
    "name": "Nyx",
    "description": "A sleek black cat wrapped in cosmic purple energy who moves through shadows like smoke. When she trusts you enough to speak first, the information is always worth waiting for.",
    "behaviorPattern": "Nyx moves along edges - doorways, shadows, the space between light and dark - noticing what others walk past. She won't say what she senses until she's certain, which means her silence has weight. When she trusts you enough to speak first, the information is always worth waiting for. She always knows the way out.",
}

CASE = {
    "character": "Zoe",
    "theme": "The Crystal Cavern",
    "conflict_hook": "The cave's crystals are going dark, and the way back is vanishing with them.",
    "sensory_palette": "Echoing drips, violet crystal glow, cold mineral air.",
    "companion_characters": [ATLAS, NYX],
    "character_details": {
        "strengths": ["Curiosity", "Problem solving"],
        "interests": ["Maps", "Rocks"],
        "gender": "girl",
    },
    "story_length": "standard",
}

_SETBACK = re.compile(
    r"\b(fail(ed|s)?|didn'?t work|wasn'?t enough|backfire(d)?|"
    r"made it worse|got worse|slipped|crumbled|too late|wrong again|"
    r"no use|not enough)\b",
    re.IGNORECASE,
)
_TOLD_WANT = re.compile(r"\b(want(ed|s)?)\b", re.IGNORECASE)


def wc(t):
    return len(re.findall(r"\b\w+\b", t))


def main():
    if not os.environ.get("GEMINI_API_KEY"):
        print("ERROR: GEMINI_API_KEY not found in backend/.env")
        sys.exit(1)
    from backend.services.story_generation_service import StoryGenerationService
    from backend.services.story_service import (
        AdvancedStoryEngine,
        _get_age_band,
        _safe_extract_title_and_gem,
    )

    engine = AdvancedStoryEngine()
    gen = StoryGenerationService()
    ts = datetime.datetime.now().strftime("%Y%m%d-%H%M")
    index = []

    print(f"Validation run {ts} — {DRAWS} draws x age 9 + age 11 (full stack)\n")
    for age in (9, 11):
        for d in range(1, DRAWS + 1):
            prompt = engine.generate_enhanced_prompt(
                character=CASE["character"],
                age=age,
                theme=CASE["theme"],
                conflict_hook=CASE["conflict_hook"],
                sensory_palette=CASE["sensory_palette"],
                companion_characters=CASE["companion_characters"],
                character_details=CASE["character_details"],
                story_length=CASE["story_length"],
            )
            raw = gen.generate_story(prompt)
            title, _, body, pages, _, meta = _safe_extract_title_and_gem(
                raw, CASE["theme"]
            )
            if not body and pages:
                body = "\n\n".join(pages)
            low = body.lower()
            species_atlas = "dragon" in low
            species_nyx = "cat" in low or "feline" in low
            setback = bool(_SETBACK.search(body))
            told_wants = len(_TOLD_WANT.findall(body))
            band = _get_age_band(age)
            stem = f"val-age{age}-draw{d}-{ts}"
            with open(
                os.path.join(OUT_DIR, stem + ".txt"),
                "w",
                encoding="utf-8",
                newline="\n",
            ) as f:
                f.write(f"{title}\n{'=' * len(title)}\n\n")
                for i, pg in enumerate(pages, 1):
                    f.write(f"[Page {i}]\n{pg}\n\n")
            rec = {
                "age": age,
                "draw": d,
                "band": band,
                "title": title,
                "words": wc(body),
                "pages": len(pages),
                "r3_atlas_is_dragon": species_atlas,
                "r3_nyx_is_cat": species_nyx,
                "tryfail_setback_language": setback,
                "told_want_count": told_wants,
                "file": stem + ".txt",
            }
            index.append(rec)
            print(
                f"age{age} d{d} band={band} {rec['words']}w/{rec['pages']}p "
                f"| Atlas=dragon:{species_atlas} Nyx=cat:{species_nyx} "
                f"setback:{setback} told_wants:{told_wants} | {title!r}"
            )

    with open(
        os.path.join(OUT_DIR, f"validation-index-{ts}.json"),
        "w",
        encoding="utf-8",
        newline="\n",
    ) as f:
        json.dump(index, f, indent=2, ensure_ascii=False)
    print(f"\nSaved {len(index)} drafts to {OUT_DIR}")


if __name__ == "__main__":
    main()
