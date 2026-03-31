"""
Generate mad.png for explorer, adventurer, creator, adolescent, and adult bands.

'mad' is a core feeling (Explorer+) that was omitted from the original
generate_missing_band_feelings.py batch. All 5 non-sprout bands need it.

Run from repo root:
    python scripts/generate_mad_feeling.py

    # Dry run
    python scripts/generate_mad_feeling.py --dry-run

    # Force regenerate existing files
    python scripts/generate_mad_feeling.py --force

Requires GOOGLE_API_KEY (+ optionally _2, _3, _4) in backend/.env
"""

import argparse
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
    raise SystemExit('No API key found. Set GOOGLE_API_KEY in backend/.env')

_key_index = 0
CLIENTS = [genai.Client(api_key=k) for k in API_KEYS]
MODEL_ID = 'imagen-4.0-generate-001'

_NO_TEXT = (
    'No text, no letters, no numbers, no labels, no watermarks, no captions, '
    'no hex codes, no dimensions anywhere in the image. '
)

# Art styles matching generate_missing_band_feelings.py
BAND_STYLES = {
    'explorer': (
        'A 3D-rendered cute squishy blob character on a solid deep purple background. '
        'The character is a soft, round bean shape with simple cartoon face features and small stubby arms. '
        'Sparkly magical stars and tiny glowing motes float around the character. '
        'Warm purple-pink glow effect. Whimsical and magical feeling. High quality. '
        + _NO_TEXT
    ),
    'adventurer': (
        'A 3D-rendered squishy blob character on a deep cosmic indigo background. '
        'The character is a slightly more angular bean shape with expressive cartoon features and short stubby arms. '
        'Small constellation dots and a subtle star-field glow surround the character. '
        'Cool blue-indigo rim light. Epic and adventurous feeling. High quality. '
        + _NO_TEXT
    ),
    'creator': (
        'A stylized 2.5D blob character on a very dark charcoal background. '
        'The character has a clean editorial silhouette — slightly more geometric than round — '
        'with expressive minimalist features and slim arms. '
        'A subtle purple-to-teal gradient halo. Modern and artistic feeling. High quality. '
        + _NO_TEXT
    ),
    'adolescent': (
        'A sleek stylized character icon on a near-black background with a deep teal atmosphere. '
        'The character is an abstract rounded figure — less blob-like, more like a simplified person silhouette — '
        'with expressive eyes and restrained body language. '
        'Cinematic teal rim lighting. Moody and introspective feeling. High quality. '
        + _NO_TEXT
    ),
    'adult': (
        'A refined minimal character illustration on a very dark charcoal background. '
        'The character is an elegant abstract figure — clean geometric curves, sophisticated posture — '
        'with subtle expressive features. '
        'Warm amber-gold accent glow. Understated and refined feeling. High quality. '
        + _NO_TEXT
    ),
}

# Band-appropriate descriptions for "mad"
MAD_DESCRIPTIONS = {
    'explorer': (
        'Bright red squishy blob character, deep furrowed brow, eyes squinted with anger, '
        'small clenched fists raised, cheeks puffed out, hot orange-red sparks popping off the body, '
        'tiny steam wisps rising from the head.'
    ),
    'adventurer': (
        'Deep red blob character, jaw tight and fists clenched at sides, '
        'eyebrows pushed hard inward, eyes sharp and narrowed, '
        'small jagged red anger sparks radiating outward.'
    ),
    'creator': (
        'Dark crimson-red 2.5D character, tense rigid posture, '
        'hard furrowed brow, mouth pressed flat, one fist clenched, '
        'hot ember glow at the edges of the silhouette.'
    ),
    'adolescent': (
        'Teal-lit silhouette, jaw clenched, hands balled into fists at sides, '
        'shoulders raised and tense, sharp angular energy lines around the form. '
        'Controlled but unmistakable anger.'
    ),
    'adult': (
        'Amber-lit figure, spine straight, jaw tight, eyes level and intense, '
        'hands loosely clenched at sides, '
        'subtle heat distortion rising around the edges. '
        'Anger held in composure — measured but undeniable.'
    ),
}


def get_client():
    return CLIENTS[_key_index]


def rotate_key():
    global _key_index
    _key_index = (_key_index + 1) % len(API_KEYS)
    print(f'  Rotating to key {_key_index + 1}/{len(API_KEYS)}')


def generate_image(output_path: Path, prompt: str, dry_run: bool, force: bool) -> bool:
    if output_path.exists() and not force:
        print(f'  Skip (exists): {output_path}')
        return True
    if dry_run:
        print(f'  DRY RUN -- would generate: {output_path}')
        return True

    output_path.parent.mkdir(parents=True, exist_ok=True)
    max_attempts = len(API_KEYS) * 2
    for attempt in range(max_attempts):
        try:
            print(f'  Generating {output_path} (key {_key_index + 1})...')
            response = get_client().models.generate_images(
                model=MODEL_ID,
                prompt=prompt,
                config=types.GenerateImagesConfig(
                    number_of_images=1,
                    output_mime_type='image/png',
                ),
            )
            if response.generated_images:
                output_path.write_bytes(response.generated_images[0].image.image_bytes)
                print(f'  Saved: {output_path}')
                return True
            else:
                print(f'  No image returned for {output_path.name}')
                return False
        except Exception as e:
            err = str(e)
            if '429' in err or 'Too Many Requests' in err or 'RESOURCE_EXHAUSTED' in err:
                if len(API_KEYS) > 1:
                    rotate_key()
                    time.sleep(5)
                else:
                    wait = min(60 * (attempt + 1), 300)
                    print(f'  Rate limited -- waiting {wait}s...')
                    time.sleep(wait)
            else:
                print(f'  Error: {e}')
                return False

    print(f'  All keys exhausted for {output_path.name}')
    return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--force', action='store_true', help='Regenerate even if file exists')
    args = parser.parse_args()

    bands = ['explorer', 'adventurer', 'creator', 'adolescent', 'adult']
    tasks = [
        (
            Path(f'assets/images/feelings/{band}/mad.png'),
            BAND_STYLES[band] + MAD_DESCRIPTIONS[band],
        )
        for band in bands
    ]

    print(f'\nGenerating mad.png for {len(tasks)} bands\n')
    failed = []
    for i, (output_path, prompt) in enumerate(tasks, 1):
        print(f'[{i}/{len(tasks)}] {output_path}')
        ok = generate_image(output_path, prompt, args.dry_run, args.force)
        if not ok:
            failed.append(str(output_path))
        if not args.dry_run and i < len(tasks):
            time.sleep(8)

    print(f'\n{"="*50}')
    print(f'Done! {len(tasks) - len(failed)}/{len(tasks)} generated.')
    if failed:
        print(f'Failed ({len(failed)}):')
        for f in failed:
            print(f'  {f}')
    print('=' * 50)


if __name__ == '__main__':
    main()
