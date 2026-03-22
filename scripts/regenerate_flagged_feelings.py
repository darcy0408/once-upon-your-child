"""
Regenerate the 5 flagged core emotion images that had clarity issues.
Run from repo root: python scripts/regenerate_flagged_feelings.py
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

ADOLESCENT_STYLE = (
    "A cinematic 3D-rendered portrait bust of a teenager (ages 15-17) "
    "on a clean white or very light neutral background, transparent-ready cutout style. "
    "Highly detailed facial features, modern streetwear styling. "
    "The emotion must be unmistakably clear from the face and body language. "
    + NO_TEXT
)

ADULT_STYLE = (
    "A cinematic 3D-rendered portrait bust of an adult (ages 25-40) "
    "on a clean white or very light neutral background, transparent-ready cutout style. "
    "Highly detailed facial features, refined professional styling. "
    "The emotion must be unmistakably clear from the face and body language. "
    + NO_TEXT
)

TARGETS = [
    ("adolescent", "confused",
     ADOLESCENT_STYLE +
     "Teen tilting head sideways, one eyebrow raised higher than the other, "
     "lips slightly parted, hands raised palms-up in an 'I have no idea' shrug. "
     "Clear puzzlement and uncertainty."),

    ("adolescent", "scared",
     ADOLESCENT_STYLE +
     "Teen with wide-open eyes, pupils dilated, mouth open in a silent gasp, "
     "leaning back slightly, shoulders raised. "
     "Pure fear and alarm — no tears, just shock and fright."),

    ("adolescent", "surprised",
     ADOLESCENT_STYLE +
     "Teen with jaw visibly dropped, eyes wide and round, eyebrows raised high, "
     "hands up near face in shock. "
     "Unmistakable surprise and astonishment."),

    ("adult", "angry",
     ADULT_STYLE +
     "Adult with jaw clenched, brows furrowed hard together, narrowed intense eyes, "
     "nostrils slightly flared, lips pressed tight. "
     "Visible tension in neck and jaw. Clear controlled fury."),

    ("adult", "scared",
     ADULT_STYLE +
     "Adult with wide fearful eyes, raised eyebrows, mouth slightly open, "
     "body turned slightly as if recoiling. "
     "Clear fear and alarm — no supernatural elements, just a very human frightened expression."),
]


def generate(band, feeling, prompt):
    path = Path(f"assets/images/feelings/{band}/{feeling}.png")
    path.parent.mkdir(parents=True, exist_ok=True)

    max_attempts = len(API_KEYS) * 2
    for attempt in range(max_attempts):
        try:
            print(f"  Generating {band}/{feeling} (key {_key_index + 1})...")
            response = get_client().models.generate_images(
                model=MODEL_ID,
                prompt=prompt,
                config=types.GenerateImagesConfig(
                    number_of_images=1,
                    output_mime_type="image/png",
                ),
            )
            if response.generated_images:
                path.write_bytes(response.generated_images[0].image.image_bytes)
                print(f"  Saved: {path}")
                return True
            print(f"  No image returned for {feeling}")
            return False
        except Exception as e:
            err = str(e)
            if "429" in err or "RESOURCE_EXHAUSTED" in err:
                rotate_key()
                time.sleep(5)
            else:
                print(f"  Error: {e}")
                return False
    print(f"  All keys exhausted for {feeling}")
    return False


if __name__ == "__main__":
    for band, feeling, prompt in TARGETS:
        generate(band, feeling, prompt)
        time.sleep(8)
    print("Done.")
