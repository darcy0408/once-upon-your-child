#!/usr/bin/env python3
"""Adventurer-band (ages 9-11) story-quality audit generator.

Generates a small hybrid sample set used by audit-reports/14-story-quality.
Faithfully reproduces the companion payloads the Flutter WizardDataMapper
sends to the backend (including the dropped power/sensory fields for
companions whose ids do not match `magicCompanions`).

Run from repo root:  python backend/tests/quality/adventurer_audit_gen.py
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

OUT_DIR = os.path.join(_REPO_ROOT, "audit-reports", "generation-samples")
os.makedirs(OUT_DIR, exist_ok=True)

# Behavior patterns copied verbatim from lib/data/companion_personality_data.dart
ATLAS_BEHAVIOR = (
    "Atlas has mapped three routes before anyone finishes asking. He wears his "
    "compass because he actually needs it, not as a decoration. When the path is "
    "unclear he lifts his glasses and calculates. He is rarely surprised. He admits "
    "when the map was wrong."
)
NYX_BEHAVIOR = (
    "Nyx moves along edges - doorways, shadows, the space between light and dark - "
    "noticing what others walk past. She won't say what she senses until she's "
    "certain, which means her silence has weight. When she trusts you enough to speak "
    "first, the information is always worth waiting for. She always knows the way out."
)
ROBIN_BEHAVIOR = (
    "Robin scouts every step with a very low threshold for danger. Three sharp "
    "chirps: stop. One long note: safe. When she decides something is a threat she "
    "launches wings-first, loud and fearless - she has been wrong before and does not "
    "slow down. When danger clears she lands on your shoulder and often brings a small "
    "gift: a berry, a pebble, a feather from her chest."
)

# Atlas + Nyx reach the backend as name + behaviorPattern ONLY (id-match gap in
# WizardDataMapper._getCompanionData -> magicCompanions). Robin matches 'robin'
# and additionally carries power/constraint/sensory/description.
ATLAS = {"name": "Atlas", "behaviorPattern": ATLAS_BEHAVIOR}
NYX = {"name": "Nyx", "behaviorPattern": NYX_BEHAVIOR}
ROBIN = {
    "name": "Rockin' Robin",
    "description": "Flies ahead to scout the path and keeps the group safe from danger",
    "signaturePower": (
        "Guardian Flight: Darts ahead of the group to map the path, then calls back "
        "with her song - one long clear note means safe, three sharp chirps means stop "
        "and wait. She can distract or redirect anything threatening long enough for the "
        "group to find another way."
    ),
    "powerConstraint": (
        "She can warn, distract, and redirect - but she trusts the hero to be brave when "
        "the path is clear. She never fights alone."
    ),
    "sensoryTell": (
        "The faint smell of warm morning air, and a quick melodic whistle that sounds "
        "exactly like a hello."
    ),
    "behaviorPattern": ROBIN_BEHAVIOR,
}

CASES = [
    {
        "id": "A",
        "label": "Standard / age 9 / Crystal Cave",
        "age": 9,
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
    },
    {
        "id": "B",
        "label": "Standard / age 11 / Crystal Cave (same inputs as A)",
        "age": 11,
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
    },
    {
        "id": "C",
        "label": "Standard / age 10 / emotionally-charged (moving house) + Robin",
        "age": 10,
        "character": "Mateo",
        "theme": "The Last Day on Comet Street",
        "conflict_hook": "A move to a new town means leaving the only home the hero has known.",
        "sensory_palette": "Packing-tape squeak, late-summer dust, the smell of an empty room.",
        "companion_characters": [ROBIN],
        "character_details": {
            "strengths": ["Loyalty", "Imagination"],
            "interests": ["Building forts", "Stargazing"],
            "gender": "boy",
        },
        "therapeutic_prompt": "Current situation: moving house | Desired outcome: feel that change is survivable",
        "feelings_prompt": "worried about leaving home and friends behind",
        "story_length": "standard",
    },
]


def word_count(text):
    return len(re.findall(r"\b\w+\b", text))


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
    generator = StoryGenerationService()
    model = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
    ts = datetime.datetime.now().strftime("%Y%m%d-%H%M")

    index = []
    for tc in CASES:
        band = _get_age_band(tc["age"])
        print(f"\n[{tc['id']}] {tc['label']}  (backend band={band})")
        prompt = engine.generate_enhanced_prompt(
            character=tc["character"],
            age=tc["age"],
            theme=tc["theme"],
            conflict_hook=tc.get("conflict_hook"),
            sensory_palette=tc.get("sensory_palette"),
            companion_characters=tc.get("companion_characters", []),
            character_details=tc.get("character_details"),
            therapeutic_prompt=tc.get("therapeutic_prompt", ""),
            feelings_prompt=tc.get("feelings_prompt"),
            story_length=tc["story_length"],
        )
        raw = generator.generate_story(prompt)
        title, _, story_text, pages, _, meta = _safe_extract_title_and_gem(
            raw, tc["theme"]
        )
        if not story_text and pages:
            story_text = "\n\n".join(pages)
        wc = word_count(story_text)
        print(f"    -> band={band}  {wc} words  {len(pages)} pages  title={title!r}")

        record = {
            "id": tc["id"],
            "label": tc["label"],
            "age": tc["age"],
            "backend_band": band,
            "model": model,
            "title": title,
            "word_count": wc,
            "page_count": len(pages),
            "emotional_arc": meta.get("emotional_arc"),
            "themes": meta.get("themes"),
            "characters_featured": meta.get("characters_featured"),
            "pages": pages,
            "prompt": prompt,
        }
        out_path = os.path.join(OUT_DIR, f"sample-{tc['id']}-{ts}.json")
        with open(out_path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(record, f, indent=2, ensure_ascii=False)
        # Plain-text companion for easy reading / hashing.
        txt_path = os.path.join(OUT_DIR, f"sample-{tc['id']}-{ts}.txt")
        with open(txt_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(f"{title}\n{'=' * len(title)}\n\n")
            for i, pg in enumerate(pages, 1):
                f.write(f"[Page {i}]\n{pg}\n\n")
        index.append(
            {
                "id": tc["id"],
                "json": os.path.basename(out_path),
                "txt": os.path.basename(txt_path),
                "band": band,
                "words": wc,
                "pages": len(pages),
                "title": title,
            }
        )

    with open(
        os.path.join(OUT_DIR, f"adventurer-index-{ts}.json"),
        "w",
        encoding="utf-8",
        newline="\n",
    ) as f:
        json.dump(index, f, indent=2, ensure_ascii=False)
    print(f"\nSaved {len(index)} samples to {OUT_DIR}")


if __name__ == "__main__":
    main()
