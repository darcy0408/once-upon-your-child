"""
Generate the 13 missing feeling images for Explorer, Adventurer, Creator,
Adolescent, and Adult bands.

Each band already has 8 images (angry, calm, confused, excited, happy, sad,
scared, surprised). This script generates the remaining 13 to match the full
21-image set that the Sprout band has.

Run from the repo root:
    python scripts/generate_missing_band_feelings.py

Requires GOOGLE_API_KEY in environment or backend/.env
"""

import os
import time
from pathlib import Path
from google import genai
from google.genai import types
from dotenv import load_dotenv

# ── Setup ────────────────────────────────────────────────────────────────────

dotenv_path = Path('backend/.env')
if dotenv_path.exists():
    load_dotenv(dotenv_path=dotenv_path)
else:
    load_dotenv()

# Collect all available API keys — add extras as GOOGLE_API_KEY_2, _3, etc.
_raw_keys = [
    os.getenv('GOOGLE_API_KEY') or os.getenv('GEMINI_API_KEY'),
    os.getenv('GOOGLE_API_KEY_2'),
    os.getenv('GOOGLE_API_KEY_3'),
    os.getenv('GOOGLE_API_KEY_4'),
]
API_KEYS = [k for k in _raw_keys if k]
if not API_KEYS:
    raise SystemExit("No API key found. Set GOOGLE_API_KEY (and optionally GOOGLE_API_KEY_2, _3...) in backend/.env")

_key_index = 0
CLIENTS = [genai.Client(api_key=k) for k in API_KEYS]

def get_client():
    return CLIENTS[_key_index]

def rotate_key():
    global _key_index
    _key_index = (_key_index + 1) % len(API_KEYS)
    print(f"  🔑 Rotating to API key {_key_index + 1} of {len(API_KEYS)}")

MODEL_ID = "imagen-4.0-generate-001"

# ── Art style per band ────────────────────────────────────────────────────────
# Each band has a distinct visual identity that matches the app's age-band theme.

_NO_TEXT = (
    "No text, no letters, no numbers, no labels, no watermarks, no captions, "
    "no hex codes, no dimensions anywhere in the image. "
)

BAND_STYLES = {
    "explorer": (
        "A 3D-rendered cute squishy blob character on a solid deep purple background. "
        "The character is a soft, round bean shape with simple cartoon face features and small stubby arms. "
        "Sparkly magical stars and tiny glowing motes float around the character. "
        "Warm purple-pink glow effect. Whimsical and magical feeling. High quality. "
        + _NO_TEXT
    ),
    "adventurer": (
        "A 3D-rendered squishy blob character on a deep cosmic indigo background. "
        "The character is a slightly more angular bean shape with expressive cartoon features and short stubby arms. "
        "Small constellation dots and a subtle star-field glow surround the character. "
        "Cool blue-indigo rim light. Epic and adventurous feeling. High quality. "
        + _NO_TEXT
    ),
    "creator": (
        "A stylized 2.5D blob character on a very dark charcoal background. "
        "The character has a clean editorial silhouette — slightly more geometric than round — "
        "with expressive minimalist features and slim arms. "
        "A subtle purple-to-teal gradient halo. Modern and artistic feeling. High quality. "
        + _NO_TEXT
    ),
    "adolescent": (
        "A sleek stylized character icon on a near-black background with a deep teal atmosphere. "
        "The character is an abstract rounded figure — less blob-like, more like a simplified person silhouette — "
        "with expressive eyes and restrained body language. "
        "Cinematic teal rim lighting. Moody and introspective feeling. High quality. "
        + _NO_TEXT
    ),
    "adult": (
        "A refined minimal character illustration on a very dark charcoal background. "
        "The character is an elegant abstract figure — clean geometric curves, sophisticated posture — "
        "with subtle expressive features. "
        "Warm amber-gold accent glow. Understated and refined feeling. High quality. "
        + _NO_TEXT
    ),
}

# ── The 13 missing feelings (descriptions reused across bands; style prefix varies) ──

MISSING_FEELINGS = {
    "bothered":           "Greenish-yellow toned character, annoyed expression, one eyebrow raised, arms crossed, small zigzag tension lines around head.",
    "bouncy":             "Bright orange-toned character mid-bounce, huge grin, arms up, motion lines below, energetic sparkles.",
    "gloomy":             "Dark blue-gray character, droopy eyes looking down, small rain cloud above head, arms hanging limp.",
    "grossed_out":        "Green-tinted character, tongue sticking out, squinted eyes, one arm pushing away, small wavy stink lines.",
    "hurt_mad":           "Reddish-purple character, watery angry eyes, clenched fists, small bandage mark on the side.",
    "hyper":              "Bright yellow-orange character spinning, huge wide eyes, big grin, speed lines and tiny stars.",
    "impatient":          "Orange-yellow character, one arm tapping, furrowed brow, glancing to the side, tiny clock icon nearby.",
    "let_down":           "Pale blue character, deflated posture, sad eyes looking to the side, small fallen star nearby.",
    "red_faced":          "Bright red character, embarrassed expression, hands covering cheeks, small sweat drops.",
    "stuck":              "Gray-brown character, confused expression, arms pushing against invisible walls, question mark floating above.",
    "what_if_y":          "Pale purple character, wide worried eyes looking upward, small thought bubbles with question marks, arms hugging self.",
    "wish_i_could_hide":  "Soft blue-green character partially hiding, only peeking eyes visible, shy expression, partially behind an edge.",
}

# ── Generator ─────────────────────────────────────────────────────────────────

def generate_image(band: str, feeling_name: str, description: str) -> bool:
    output_path = Path(f"assets/images/feelings/{band}/{feeling_name}.png")

    if output_path.exists():
        print(f"  ⏩ {feeling_name} already exists, skipping.")
        return True

    output_path.parent.mkdir(parents=True, exist_ok=True)
    prompt = BAND_STYLES[band] + description

    # Try every key up to 2 full rotations before giving up
    max_attempts = len(API_KEYS) * 2
    for attempt in range(max_attempts):
        try:
            print(f"  🎨 Generating {feeling_name} (key {_key_index + 1})...")
            response = get_client().models.generate_images(
                model=MODEL_ID,
                prompt=prompt,
                config=types.GenerateImagesConfig(
                    number_of_images=1,
                    output_mime_type="image/png",
                ),
            )
            if response.generated_images:
                output_path.write_bytes(response.generated_images[0].image.image_bytes)
                print(f"  ✅ Saved: {output_path}")
                return True
            else:
                print(f"  ❌ No image returned for {feeling_name}")
                return False

        except Exception as e:
            err = str(e)
            if "429" in err or "Too Many Requests" in err or "RESOURCE_EXHAUSTED" in err:
                if len(API_KEYS) > 1:
                    rotate_key()
                    time.sleep(5)  # brief pause before trying new key
                else:
                    wait = min(60 * (attempt + 1), 300)
                    print(f"  ⏳ Rate limited — waiting {wait}s (only 1 key available)...")
                    time.sleep(wait)
            else:
                print(f"  ❌ Error on {feeling_name}: {e}")
                return False

    print(f"  ❌ All keys exhausted for {feeling_name}")
    return False


def main():
    bands = ["explorer", "adventurer", "creator", "adolescent", "adult"]

    total = len(bands) * len(MISSING_FEELINGS)
    done = 0
    failed = []

    for band in bands:
        print(f"\n{'='*50}")
        print(f"  Band: {band.upper()}")
        print(f"{'='*50}")

        for feeling_name, description in MISSING_FEELINGS.items():
            success = generate_image(band, feeling_name, description)
            done += 1
            if not success:
                failed.append(f"{band}/{feeling_name}")
            # Small pause between requests to avoid rate limits
            time.sleep(8)

    print(f"\n{'='*50}")
    print(f"  Done! {done}/{total} processed.")
    if failed:
        print(f"  Failed ({len(failed)}): {', '.join(failed)}")
    else:
        print("  All images generated successfully!")
    print(f"{'='*50}")


if __name__ == "__main__":
    main()
