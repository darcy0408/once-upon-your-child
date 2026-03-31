"""
Generate images for the 10 mature feelings added in the Adolescent/Adult UX
redesign (grief, resentful, envious, restless, hopeful, melancholy,
contentment, indignation, dread, anticipation).

Outputs:
  1. assets/feelings_faces/{feeling}.png           — global fallback (all 10)
  2. assets/images/feelings/adolescent/{feeling}.png — band-specific adolescent style
  3. assets/images/feelings/adult/{feeling}.png     — band-specific adult style

Skips files that already exist (grief, hopeful, resentful already have
feelings_faces/ versions).

Run from repo root:
    python scripts/generate_mature_feelings.py

    # Dry run
    python scripts/generate_mature_feelings.py --dry-run

    # Force regenerate existing files
    python scripts/generate_mature_feelings.py --force

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

# ---------------------------------------------------------------------------
# Art styles
# ---------------------------------------------------------------------------

# Global feelings_faces style — consistent with existing files in that dir:
# 3D cartoon blob/character on a solid colored or dark background, expressive face.
GLOBAL_STYLE = (
    'A 3D-rendered soft cartoon blob character with expressive face, '
    'simple stubby arms, smooth rounded body. '
    'Placed on a solid dark deep-purple background. '
    'High quality render. Slight depth-of-field. '
    + _NO_TEXT
)

ADOLESCENT_STYLE = (
    'A sleek stylized character icon on a near-black background with a deep teal atmosphere. '
    'The character is an abstract rounded figure — less blob-like, more like a simplified person silhouette — '
    'with expressive eyes and restrained body language. '
    'Cinematic teal rim lighting. Moody and introspective feeling. High quality. '
    + _NO_TEXT
)

ADULT_STYLE = (
    'A refined minimal character illustration on a very dark charcoal background. '
    'The character is an elegant abstract figure — clean geometric curves, sophisticated posture — '
    'with subtle expressive features. '
    'Warm amber-gold accent glow. Understated and refined feeling. High quality. '
    + _NO_TEXT
)

# ---------------------------------------------------------------------------
# Mature feeling descriptions
# ---------------------------------------------------------------------------

MATURE_FEELINGS = {
    'grief': (
        'Dark navy-blue toned character, hunched posture, head bowed, '
        'silent tears on cheeks, fists loosely closed, heavy stillness around the figure. '
        'Small falling leaves or petals drifting nearby.',

        # adolescent variant — more internal, symbolic
        'Silhouette figure sitting with knees drawn up, arms wrapped around legs, '
        'deep blue-black tones, single tear catching teal light, '
        'faint stars slowly dimming around the figure.',

        # adult variant — dignified, held grief
        'Elegant abstract figure standing still, head slightly bowed, '
        'one hand resting on chest, warm amber light catching the side of the face, '
        'empty space around the figure feels weighted.',
    ),
    'resentful': (
        'Burnt-orange and red-tinted character, jaw set, eyes narrowed, '
        'arms crossed tightly, small ember sparks drifting off the body. '
        'Tense rigid posture. Subtle heat shimmer.',

        'Teal-accented silhouette, rigid crossed arms, sharp sideways glance, '
        'jaw tight, small ember lines rising from the shoulders. Controlled fury.',

        'Amber-lit figure, straight-backed, arms crossed, '
        'one corner of the mouth pressed flat, '
        'faint heat distortion rising around the form.',
    ),
    'envious': (
        'Green-tinted character, sideways glance with wide eyes, '
        'one hand reaching slightly toward something out of frame, '
        'other arm pulled back, small sparkle trail drifting away from them.',

        'Teal-lit silhouette, leaning slightly toward the edge of the frame, '
        'gaze off to the side, one hand partly extended, '
        'faint green shimmer around the outstretched hand.',

        'Amber-accented figure, subtle lean toward one side, '
        'eyes tracking something off-frame, '
        'one hand loosely open at the side, quiet yearning posture.',
    ),
    'restless': (
        'Orange-yellow character mid-shift, feet moving, '
        'arms slightly spread as if unsure which direction, '
        'motion blur on hands, small spiraling wind lines nearby.',

        'Teal-lit silhouette pacing, weight on one foot, '
        'arms slightly raised and uncertain, '
        'dynamic diagonal composition suggesting movement.',

        'Amber-lit figure, weight shifting between feet, '
        'hands half-raised, gaze unfixed, '
        'subtle kinetic blur on the edges.',
    ),
    'hopeful': (
        'Warm golden-yellow character, face tilted slightly upward, '
        'soft smile, one hand loosely open at the chest level, '
        'small sunrise glow behind the figure, tiny stars or light motes.',

        'Teal-lit silhouette, chin lifted, '
        'face turned slightly upward, '
        'faint dawn-light glow rimming the top of the figure.',

        'Amber-gold lit figure, relaxed upright posture, '
        'gaze directed gently upward, '
        'warm light gathering at the top of the frame.',
    ),
    'melancholy': (
        'Soft blue-gray character, eyes half-open and distant, '
        'slight downward tilt of the head, arms loosely at sides, '
        'slow rain of tiny droplets nearby, bittersweet stillness.',

        'Teal-rimmed silhouette, seated posture, gaze soft and downward, '
        'slow drift of light particles descending around the figure. '
        'Quiet. Still. Neither happy nor devastated.',

        'Amber-accented figure, standing but slightly curved inward, '
        'eyes cast down and soft, '
        'delicate falling light like slow-motion rain around the form.',
    ),
    'contentment': (
        'Warm golden character, eyes gently closed or half-closed, '
        'soft smile, relaxed posture, arms loosely at sides or lightly clasped, '
        'small warm glow emanating from the body. Peaceful stillness.',

        'Teal-lit silhouette, relaxed seated pose, '
        'head slightly bowed in quiet satisfaction, '
        'gentle light bloom around the figure.',

        'Amber-gold figure, still upright posture, '
        'eyes softly closed, hands loosely clasped, '
        'warm radiant glow. No urgency anywhere in the composition.',
    ),
    'indignation': (
        'Red and gold character, upright and alert posture, '
        'chin raised, eyes sharp and direct, '
        'one fist loosely raised, righteous energy lines radiating outward.',

        'Teal-lit silhouette, tall straight posture, '
        'chin lifted, shoulders back, sharp gaze forward, '
        'subtle energy lines rising around the figure like heat off pavement.',

        'Amber-accented figure, spine straight, '
        'shoulders squared, direct level gaze, '
        'quiet power in the stillness — the posture of someone who has decided.',
    ),
    'dread': (
        'Deep violet-gray character, slightly hunched, '
        'eyes wide and fixed ahead, arms close to the body, '
        'shadow looming faintly behind, heavy atmosphere pressing down.',

        'Teal-rimmed silhouette, still and tense, '
        'gaze fixed on something in the distance, '
        'shadow pressing in from above, subtle weight in the composition.',

        'Amber-lit figure, very still, shoulders slightly raised, '
        'gaze level but haunted, '
        'darkness gathering at the edges of the frame.',
    ),
    'anticipation': (
        'Electric blue-white character, leaning slightly forward, '
        'wide alert eyes, hands slightly raised, '
        'motion-ready posture, small sparks and question-mark motes drifting nearby.',

        'Teal-lit silhouette, weight forward on the front foot, '
        'gaze fixed ahead, body coiled with potential energy, '
        'faint electric shimmer at the edge of the form.',

        'Amber figure, balanced on the balls of the feet, '
        'gaze ahead and alert, '
        'slight forward lean — poised on the threshold of something.',
    ),
}

# ---------------------------------------------------------------------------
# Generation helpers
# ---------------------------------------------------------------------------

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
            print(f'  Generating {output_path.name} (key {_key_index + 1})...')
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
                print(f'  ❌ No image returned for {output_path.name}')
                return False
        except Exception as e:
            err = str(e)
            if '429' in err or 'Too Many Requests' in err or 'RESOURCE_EXHAUSTED' in err:
                if len(API_KEYS) > 1:
                    rotate_key()
                    time.sleep(5)
                else:
                    wait = min(60 * (attempt + 1), 300)
                    print(f'  ⏳ Rate limited — waiting {wait}s...')
                    time.sleep(wait)
            else:
                print(f'  ❌ Error: {e}')
                return False

    print(f'  ❌ All keys exhausted for {output_path.name}')
    return False


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--force', action='store_true', help='Regenerate even if file exists')
    args = parser.parse_args()

    tasks = []
    for feeling, (global_desc, adolescent_desc, adult_desc) in MATURE_FEELINGS.items():
        tasks.append((
            Path(f'assets/feelings_faces/{feeling}.png'),
            GLOBAL_STYLE + global_desc,
        ))
        tasks.append((
            Path(f'assets/images/feelings/adolescent/{feeling}.png'),
            ADOLESCENT_STYLE + adolescent_desc,
        ))
        tasks.append((
            Path(f'assets/images/feelings/adult/{feeling}.png'),
            ADULT_STYLE + adult_desc,
        ))

    total = len(tasks)
    failed = []
    print(f'\nGenerating {total} mature feeling images ({len(MATURE_FEELINGS)} feelings x 3 targets)\n')

    for i, (output_path, prompt) in enumerate(tasks, 1):
        print(f'[{i}/{total}] {output_path}')
        ok = generate_image(output_path, prompt, args.dry_run, args.force)
        if not ok:
            failed.append(str(output_path))
        if not args.dry_run and i < total:
            time.sleep(8)

    print(f'\n{"="*50}')
    print(f'Done! {total - len(failed)}/{total} generated.')
    if failed:
        print(f'Failed ({len(failed)}):')
        for f in failed:
            print(f'  {f}')
    print('='*50)


if __name__ == '__main__':
    main()
