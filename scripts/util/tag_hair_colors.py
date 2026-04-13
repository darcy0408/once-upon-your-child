#!/usr/bin/env python3
"""Tag hairColor for all 150 avatars in metadata.json using Gemini Vision.

Usage:
    python tag_hair_colors.py            # tag all untagged avatars
    python tag_hair_colors.py --retag    # re-tag everything from scratch

Canonical colours: black | brown | blonde | red | gray | colorful
  - colorful = pink, blue, purple, green, rainbow, any fantasy colour
  - gray     = white, silver, platinum
"""

import json
import os
import sys
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
AVATARS_DIR = SCRIPT_DIR / "assets" / "avatars" / "midjourney"
METADATA_FILE = AVATARS_DIR / "metadata.json"
ENV_FILE = SCRIPT_DIR / "backend" / ".env"

CANONICAL = ["black", "brown", "blonde", "red", "gray", "colorful"]

PROMPT = (
    "Look at this cartoon character image. "
    "What is the hair color of the character? "
    "Choose EXACTLY ONE word from this list: black, brown, blonde, red, gray, colorful. "
    "Rules: use 'colorful' for pink, blue, purple, green, teal, rainbow, or any "
    "unusual/fantasy colour. Use 'gray' for white, silver, or platinum hair. "
    "Reply with ONLY the single word, nothing else."
)


def load_api_key() -> str:
    """Read GEMINI_API_KEY from backend/.env."""
    if not ENV_FILE.exists():
        raise FileNotFoundError(f".env not found at {ENV_FILE}")
    for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
        if line.startswith("GEMINI_API_KEY="):
            return line.split("=", 1)[1].strip()
    raise KeyError("GEMINI_API_KEY not found in backend/.env")


def classify(client, types_module, image_path: Path) -> str:
    image_bytes = image_path.read_bytes()
    response = client.models.generate_content(
        model="gemini-2.0-flash",
        contents=[
            types_module.Part.from_bytes(data=image_bytes, mime_type="image/webp"),
            PROMPT,
        ],
    )
    raw = response.text.strip().lower()
    # Exact match first
    if raw in CANONICAL:
        return raw
    # Substring match
    for color in CANONICAL:
        if color in raw:
            return color
    # Fallbacks for common synonyms not in the canonical list
    fallbacks = {
        "auburn": "red",
        "ginger": "red",
        "chestnut": "brown",
        "dark": "brown",
        "light": "blonde",
        "golden": "blonde",
        "white": "gray",
        "silver": "gray",
        "platinum": "gray",
    }
    for word, canonical in fallbacks.items():
        if word in raw:
            return canonical
            print(f"  [WARN] Unexpected response '{raw}', defaulting to 'brown'")
    return "brown"


def main():
    retag = "--retag" in sys.argv

    try:
        api_key = load_api_key()
    except (FileNotFoundError, KeyError) as e:
        print(f"Error: {e}")
        sys.exit(1)

    from google import genai
    from google.genai import types

    client = genai.Client(api_key=api_key)

    with open(METADATA_FILE, encoding="utf-8") as f:
        metadata = json.load(f)

    avatars: dict = metadata["avatars"]
    total = len(avatars)
    tagged = 0
    skipped = 0
    errors = 0

    print(f"Processing {total} avatars (retag={retag}) ...\n")

    for i, (filename, entry) in enumerate(avatars.items(), 1):
        if not retag and entry.get("hairColor") is not None:
            skipped += 1
            print(f"[{i:3}/{total}] {filename} - already: {entry['hairColor']}")
            continue

        image_path = AVATARS_DIR / filename
        if not image_path.exists():
            print(f"[{i:3}/{total}] {filename} - FILE NOT FOUND, skipping")
            errors += 1
            continue

        try:
            color = classify(client, types, image_path)
            entry["hairColor"] = color
            tagged += 1
            print(f"[{i:3}/{total}] {filename} -> {color}")
        except Exception as e:
            errors += 1
            print(f"[{i:3}/{total}] {filename} - ERROR: {e}")

        # Checkpoint: save every 10 avatars so progress isn't lost on failure
        if i % 10 == 0:
            with open(METADATA_FILE, "w", encoding="utf-8") as f:
                json.dump(metadata, f, indent=2)
            print(f"  [SAVED] Checkpoint at {i}/{total}")
            time.sleep(0.5)  # gentle rate-limit buffer

    # Final save
    with open(METADATA_FILE, "w", encoding="utf-8") as f:
        json.dump(metadata, f, indent=2)

    print(f"\n[DONE] tagged={tagged}, skipped={skipped}, errors={errors}")

    # Print distribution summary
    from collections import Counter
    counts = Counter(e["hairColor"] for e in avatars.values() if e.get("hairColor"))
    print("\nHair colour distribution:")
    for color, count in sorted(counts.items(), key=lambda x: -x[1]):
        bar = "█" * count
        print(f"  {color:<10} {count:3}  {bar}")


if __name__ == "__main__":
    main()
