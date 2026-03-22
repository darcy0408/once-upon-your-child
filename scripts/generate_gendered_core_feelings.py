"""
Generate gendered (boy/girl) core-8 emotion images for Creator, Adolescent, and Adult bands.

Output structure:
  assets/images/feelings/{band}/{gender}/{emotion}.png

Run from repo root:
    python scripts/generate_gendered_core_feelings.py

Requires GOOGLE_API_KEY (+ _2, _3, _4) in backend/.env
"""

import os
import time
from pathlib import Path
from google import genai
from google.genai import types
from dotenv import load_dotenv

load_dotenv(dotenv_path=Path('backend/.env'))

_raw_keys = [
    os.getenv('GOOGLE_API_KEY') or os.getenv('GEMINI_API_KEY'),
    os.getenv('GOOGLE_API_KEY_2'),
    os.getenv('GOOGLE_API_KEY_3'),
    os.getenv('GOOGLE_API_KEY_4'),
]
API_KEYS = [k for k in _raw_keys if k]
if not API_KEYS:
    raise SystemExit("No API key found.")

_key_index = 0
CLIENTS = [genai.Client(api_key=k) for k in API_KEYS]

def get_client(): return CLIENTS[_key_index]
def rotate_key():
    global _key_index
    _key_index = (_key_index + 1) % len(API_KEYS)
    print(f"  Rotating to key {_key_index + 1}")

MODEL_ID = "imagen-4.0-generate-001"

NO_TEXT = (
    "No text, no letters, no numbers, no labels, no watermarks, "
    "no hex codes, no dimensions anywhere in the image. "
)

# ── Art direction per band + gender ──────────────────────────────────────────
# Warm, therapeutic, emotionally safe. Clear expressions without being harsh.
# Each band gets progressively more mature/realistic but always soft and relatable.

STYLES = {
    "creator": {
        "boy": (
            "A warm 3D-rendered portrait bust of a boy aged 12 to 14, "
            "soft golden amber backlight, deep warm charcoal background. "
            "Gentle illustrated style — stylish but approachable, not edgy. "
            "Warm skin tones, expressive eyes, subtle depth of field. "
            "The emotion must be unmistakably clear from the face and posture. "
            "Therapeutic and safe feeling — the kind of image that makes you feel understood. "
            + NO_TEXT
        ),
        "girl": (
            "A warm 3D-rendered portrait bust of a girl aged 12 to 14, "
            "soft golden amber backlight, deep warm charcoal background. "
            "Gentle illustrated style — stylish but approachable, not edgy. "
            "Warm skin tones, expressive eyes, subtle depth of field. "
            "The emotion must be unmistakably clear from the face and posture. "
            "Therapeutic and safe feeling — the kind of image that makes you feel understood. "
            + NO_TEXT
        ),
    },
    "adolescent": {
        "boy": (
            "A warm painterly portrait bust of a young man aged 15 to 17, "
            "soft warm amber and teal ambient glow, dark gradient background. "
            "Authentic illustrated style — real and relatable, not performative or posed. "
            "Vulnerable and emotionally present. Slightly loose brushstroke texture. "
            "The emotion must be unmistakably clear from the face and body language. "
            "Therapeutic and empathetic feeling — honest without being distressing. "
            + NO_TEXT
        ),
        "girl": (
            "A warm painterly portrait bust of a young woman aged 15 to 17, "
            "soft warm amber and teal ambient glow, dark gradient background. "
            "Authentic illustrated style — real and relatable, not performative or posed. "
            "Vulnerable and emotionally present. Slightly loose brushstroke texture. "
            "The emotion must be unmistakably clear from the face and body language. "
            "Therapeutic and empathetic feeling — honest without being distressing. "
            + NO_TEXT
        ),
    },
    "adult": {
        "boy": (
            "A warm painterly portrait bust of an adult man aged 25 to 35, "
            "gentle golden warm candlelight glow, soft dark warm background. "
            "Refined illustrated style — emotionally mature, dignified, and present. "
            "Soft painterly texture, warm amber and brown tones. "
            "The emotion must be unmistakably clear from the face and subtle body language. "
            "Therapeutic and grounding feeling — safe, deeply human, and relatable. "
            + NO_TEXT
        ),
        "girl": (
            "A warm painterly portrait bust of an adult woman aged 25 to 35, "
            "gentle golden warm candlelight glow, soft dark warm background. "
            "Refined illustrated style — emotionally mature, dignified, and present. "
            "Soft painterly texture, warm amber and brown tones. "
            "The emotion must be unmistakably clear from the face and subtle body language. "
            "Therapeutic and grounding feeling — safe, deeply human, and relatable. "
            + NO_TEXT
        ),
    },
}

# ── Emotion descriptions — warm, safe, non-distressing ──────────────────────
# Even for negative emotions, the expression is honest but not alarming.

EMOTIONS = {
    "angry": (
        "Brows furrowed together, jaw lightly clenched, lips pressed into a firm line. "
        "Eyes intense but controlled — frustrated anger, not rage. "
        "A feeling of tension held inside, not exploding outward."
    ),
    "calm": (
        "Eyes softly closed or looking down with a peaceful gaze. "
        "Shoulders relaxed, face completely at ease. "
        "A quiet, settled expression — deeply at rest and at peace."
    ),
    "confused": (
        "Head tilted slightly to one side, one eyebrow raised higher than the other. "
        "Lips slightly parted, eyes searching — genuinely puzzled and uncertain. "
        "One hand raised near the chin in thought."
    ),
    "excited": (
        "Bright wide eyes lit up with anticipation, genuine open smile. "
        "Slightly forward-leaning posture, energy in the expression. "
        "Warm, radiant happiness about something coming."
    ),
    "happy": (
        "Soft warm smile, crinkled eyes, relaxed open face. "
        "A settled, contented happiness — not giddy, just genuinely well. "
        "Warm glow in the eyes."
    ),
    "sad": (
        "Eyes downcast or glistening, corners of the mouth softly turned down. "
        "A quiet, tender sadness — not despair, just the gentle weight of a hard feeling. "
        "Perhaps a single tear or just the stillness of grief held softly."
    ),
    "scared": (
        "Eyes wide and alert, eyebrows raised, shoulders slightly lifted. "
        "Mouth just barely open — a sharp intake of breath. "
        "Visible vulnerability and alarm, but not terror — a human moment of fear."
    ),
    "surprised": (
        "Jaw dropped, eyes wide and round, eyebrows raised high. "
        "Hands near the face or chest in a startled gesture. "
        "Pure astonishment — delighted or shocked, clearly caught off guard."
    ),
}

BANDS = ["creator", "adolescent", "adult"]
GENDERS = ["boy", "girl"]


def generate(band, gender, emotion):
    out = Path(f"assets/images/feelings/{band}/{gender}/{emotion}.png")
    if out.exists():
        print(f"  Skipping {band}/{gender}/{emotion} (exists)")
        return True
    out.parent.mkdir(parents=True, exist_ok=True)

    prompt = STYLES[band][gender] + EMOTIONS[emotion]
    max_attempts = len(API_KEYS) * 2

    for attempt in range(max_attempts):
        try:
            print(f"  Generating {band}/{gender}/{emotion} (key {_key_index + 1})...")
            r = get_client().models.generate_images(
                model=MODEL_ID,
                prompt=prompt,
                config=types.GenerateImagesConfig(
                    number_of_images=1,
                    output_mime_type="image/png",
                ),
            )
            if r.generated_images:
                out.write_bytes(r.generated_images[0].image.image_bytes)
                print(f"  Saved: {out}")
                return True
            print(f"  No image returned")
            return False
        except Exception as e:
            err = str(e)
            if "429" in err or "RESOURCE_EXHAUSTED" in err:
                rotate_key()
                time.sleep(5)
            else:
                print(f"  Error: {e}")
                return False

    print(f"  All keys exhausted for {band}/{gender}/{emotion}")
    return False


def main():
    targets = [
        (band, gender, emotion)
        for band in BANDS
        for gender in GENDERS
        for emotion in EMOTIONS
    ]
    total = len(targets)
    failed = []

    print(f"Generating {total} images (3 bands x 2 genders x 8 emotions)...\n")

    for i, (band, gender, emotion) in enumerate(targets, 1):
        print(f"[{i}/{total}]")
        if not generate(band, gender, emotion):
            failed.append(f"{band}/{gender}/{emotion}")
        time.sleep(8)

    print(f"\nDone. {total - len(failed)}/{total} succeeded.")
    if failed:
        print(f"Failed: {', '.join(failed)}")


if __name__ == "__main__":
    main()
EOF