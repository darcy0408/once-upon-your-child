"""
Redesigned Feelings Asset Generation — Adolescent & Adult Therapeutic Illustration System
See: docs/feelings_redesign_brief_2026-03-31.md

Outputs:
  1. assets/feelings_faces/{feeling}.png            — 7 global fallbacks (new Soft Geometric style)
  2. assets/images/feelings/adolescent/{feeling}.png — 10 mature feelings (new Webtoon style)
  3. assets/images/feelings/adult/{feeling}.png      — 10 mature feelings (new Warm Editorial style)

Backs up existing files to backup_pre_redesign_{feeling}.png before overwriting.
Logs results to scripts/feelings_generation_log.md.

Run from repo root:
    python scripts/generate_redesigned_feelings.py

    # Preview what would run without generating
    python scripts/generate_redesigned_feelings.py --dry-run

    # Specific set only
    python scripts/generate_redesigned_feelings.py --set global
    python scripts/generate_redesigned_feelings.py --set adolescent
    python scripts/generate_redesigned_feelings.py --set adult

    # Single feeling
    python scripts/generate_redesigned_feelings.py --feeling dread

    # Force regenerate even if output exists
    python scripts/generate_redesigned_feelings.py --force

Requires GOOGLE_API_KEY (+ optionally _2, _3, _4) in backend/.env
"""

import argparse
import os
import shutil
import time
from datetime import datetime
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

# ---------------------------------------------------------------------------
# Shared negative constraint appended to every prompt
# ---------------------------------------------------------------------------

_NO_TEXT = (
    'No text, no letters, no numbers, no labels, no watermarks, no captions '
    'anywhere in the image. '
)

# Shared negative for ALL sets — critical requirements
_SHARED_NEG = (
    'No human skin tone. No realistic human face. No racial features. '
    'No hair. No gender indicators. No clothing with cultural markers. '
    'Not photorealistic. Not a photograph. Not a stock illustration. '
    'No white background. No gradient background. Pure solid black background only. '
    + _NO_TEXT
)

# ---------------------------------------------------------------------------
# Style bases
# All three sets use the same abstract blob/cartoon character approach.
# The character has NO race, NO gender, NO skin — it is a pure abstract
# cartoon shape that conveys emotion entirely through color, posture,
# and simple dot-eyes + curved-mouth expression.
# BLACK background (#000000) required for clean ImageMagick removal.
# ---------------------------------------------------------------------------

# Shared character description used in all three styles
_BLOB_CHARACTER = (
    'The character is a smooth rounded abstract cartoon blob figure — '
    'a simple organic teardrop or egg shape with stubby rounded limbs. '
    'No hair. No nose. No ears. No clothing details. No skin tone. '
    'The entire character is a single bright solid color that conveys the emotion. '
    'Face has only two small round dot eyes and a simple curved line for a mouth — '
    'expressive but completely abstract, like a cartoon emoji given a body. '
    'The character reads as entirely universal — no race, no gender, no age. '
)

GLOBAL_STYLE = (
    'A high-quality 3D-rendered soft cartoon blob character illustration. '
    + _BLOB_CHARACTER +
    'Solid pure black background (#000000). '
    'The character is centered in frame, clearly legible at small thumbnail size. '
    'Emotion is expressed through the character\'s body posture, limb position, '
    'and the color and direction of accent lighting on the figure. '
    '3D render with smooth surfaces, subtle ambient occlusion, slight depth-of-field. '
    + _SHARED_NEG
)

ADOLESCENT_STYLE = (
    'A vibrant 3D-rendered cartoon blob character illustration with energetic style. '
    + _BLOB_CHARACTER +
    'Solid pure black background (#000000). '
    'The character glows with vivid saturated color — the emotion\'s accent color '
    'is bright and bold, with a subtle colored rim light halo effect. '
    'Emotion expressed through dynamic body posture and expressive dot-eyes. '
    'The overall feel is energetic, modern, and visually punchy. '
    '3D render, smooth surfaces, dramatic accent lighting. '
    + _SHARED_NEG
)

ADULT_STYLE = (
    'A refined 3D-rendered cartoon blob character illustration with sophisticated style. '
    + _BLOB_CHARACTER +
    'Solid pure black background (#000000). '
    'The character\'s color is rich and slightly more muted than the adolescent version — '
    'sophisticated rather than fluorescent. Soft directional lighting with warm '
    'and cool contrast to add depth. '
    'Emotion expressed primarily through considered body posture — the figure\'s '
    'relationship to space conveys the feeling\'s weight and texture. '
    '3D render, smooth surfaces, subtle cinematic lighting quality. '
    + _SHARED_NEG
)

# ---------------------------------------------------------------------------
# Per-feeling prompts
# Tuple: (global_desc, adolescent_desc, adult_desc)
# global_desc is None for feelings not in the 7-image global fallback set.
# ---------------------------------------------------------------------------

FEELINGS = {
    'anticipation': (
        # global — warm amber blob, perched forward on edge
        'Character color: warm amber-yellow. '
        'Posture: perched on the very edge of a surface, entire body weight '
        'shifted forward, stubby arms slightly raised and ready, dot-eyes wide '
        'and bright, mouth curved in a small eager smile. '
        'Accent lighting: golden-amber glow from the right side. '
        'Energy: coiled, ready, forward-leaning.',

        # adolescent — bolder, more vibrant amber
        'Character color: vivid electric amber. '
        'Posture: leaning sharply forward, arms reaching slightly toward '
        'something off-screen right, dot-eyes large and bright with excitement, '
        'mouth open in a surprised eager curve. '
        'Rim light: bright warm amber halo. '
        'Energy: dynamic, about to burst into motion.',

        # adult — richer, more contained amber
        'Character color: deep burnished amber-gold. '
        'Posture: standing at a threshold, weight on front foot, one stubby arm '
        'resting on an implied door frame, leaning slightly forward. '
        'Dot-eyes looking ahead with quiet alertness, mouth in a small composed '
        'curve. Lighting: warm directional glow from ahead. '
        'Energy: deliberate, considered, poised.',
    ),

    'contentment': (
        # global — sage green, settled and soft
        'Character color: soft sage green. '
        'Posture: seated comfortably, legs loosely crossed or tucked, arms '
        'resting in lap, shoulders dropped wide, dot-eyes half-closed in '
        'quiet pleasure, mouth in a gentle upward curve. '
        'Lighting: warm even ambient glow, no dramatic shadows. '
        'Energy: fully settled, nothing reaching, nothing guarded.',

        # adolescent — brighter green, casually settled
        'Character color: bright cheerful green. '
        'Posture: reclined or loosely seated, one arm draped over a knee, '
        'body fully relaxed with no tension, dot-eyes soft and half-closed, '
        'a wide easy smile. '
        'Rim light: soft warm green-gold halo. '
        'Energy: completely at ease, occupying the space fully.',

        # adult — forest green, quietly satisfied
        'Character color: deep forest green. '
        'Posture: reclined with a subtle stillness — weight fully given to '
        'the surface, arms loose at sides, dot-eyes gently closed, mouth in '
        'a small private smile. '
        'Lighting: soft warm side-light, long gentle shadow. '
        'Energy: earned rest, active peace.',
    ),

    'dread': (
        # global — deep violet, frozen and inward
        'Character color: deep violet-grey. '
        'Posture: standing very still, shoulders raised toward the top of the '
        'body, arms pulled close to the sides, dot-eyes wide and fixed on '
        'something off-screen lower-left, mouth pressed into a flat line. '
        'Accent lighting: cold blue-violet shadow from the lower-left. '
        'Energy: frozen, not fleeing — the body knows but cannot move.',

        # adolescent — vivid indigo, tight and alert
        'Character color: vivid indigo-purple. '
        'Posture: body pulled in tight, shoulders hunched high, dot-eyes '
        'wide and tracking something at lower-left, one arm wrapped around '
        'own body. '
        'Rim light: cold blue edge light, darker halo. '
        'Energy: alert stillness, the worst kind of waiting.',

        # adult — dark plum, still and weighted
        'Character color: dark plum-charcoal. '
        'Posture: very still, shoulders slightly elevated, weight settled '
        'downward, dot-eyes level and haunted, mouth in a flat pressed line. '
        'Lighting: cool directional shadow pressing in from one side, '
        'darkness gathering at the edges of the frame. '
        'Energy: heavy stillness, the body carrying foreknowledge.',
    ),

    'envious': (
        # global — teal-green, sideways attention
        'Character color: teal-green. '
        'Posture: body faces forward but head and dot-eyes cut hard to one '
        'side, one stubby arm slightly extended toward the off-screen subject, '
        'the other pulled back, mouth in a tight flat line. '
        'Lighting: green-tinted side light from the direction of attention. '
        'Energy: involuntary, magnetic pull toward something out of reach.',

        # adolescent — bright green, sharp sideways look
        'Character color: bright neon-green. '
        'Posture: leaning subtly toward one side, dot-eyes cut sharply '
        'sideways, one arm reaching slightly off-frame, expression caught '
        'mid-wanting — mouth open slightly. '
        'Rim light: vivid green edge glow. '
        'Energy: caught in the act of wanting what someone else has.',

        # adult — deep emerald, contained and aware
        'Character color: deep emerald green. '
        'Posture: still and composed, but dot-eyes distinctly averted to one '
        'side, one arm slightly extended then pulled back — a suppressed reach. '
        'Lighting: cool green reflected light from the direction of attention. '
        'Energy: self-aware wanting, deliberately contained.',
    ),

    'grief': (
        # global — not in 7-image fallback scope
        None,

        # adolescent — soft blue, curled and still
        'Character color: soft periwinkle blue. '
        'Posture: curled in on itself — knees drawn up if seated, arms '
        'wrapped around own body, head bowed slightly, one stubby hand '
        'pressed gently to chest. Dot-eyes closed. Mouth soft and neutral. '
        'Lighting: soft even light from behind, no harsh shadows. '
        'Energy: complete held stillness — grief that has settled.',

        # adult — deep blue, alone in space
        'Character color: deep navy blue. '
        'Posture: seated very low or on the floor, weight entirely given '
        'downward, arms at sides or loosely held, dot-eyes closed, '
        'no dramatic gesture. The figure is small relative to the frame — '
        'the surrounding darkness is part of the composition. '
        'Lighting: soft single ambient source from behind. '
        'Energy: the stillness of grief that has no more movement left in it.',
    ),

    'hopeful': (
        # global — not in 7-image fallback scope
        None,

        # adolescent — warm yellow, face tilted up
        'Character color: bright warm yellow. '
        'Posture: chin lifted upward, one stubby arm extended open at the '
        'side, body weight slightly on toes as if about to rise, dot-eyes '
        'bright and looking up, mouth in a genuine open smile. '
        'Rim light: warm golden glow from above-ahead. '
        'Energy: open, rising, reaching toward something real.',

        # adult — golden amber, quietly upward
        'Character color: warm golden amber. '
        'Posture: standing with open chest, chin gently lifted, dot-eyes '
        'directed upward with quiet intent, one arm loosely open at the side. '
        'Lighting: warm directional light from above, illuminating the '
        'upper part of the figure. '
        'Energy: contemplative aspiration — hopeful, not naive.',
    ),

    'indignation': (
        # global — terracotta, upright and composed
        'Character color: terracotta orange. '
        'Posture: standing straight and tall, chin raised, dot-eyes direct '
        'and sharp, mouth set in a controlled pressed line, arms at sides '
        'or crossed — not raised. Chest open and elevated. '
        'Lighting: warm terracotta-tinted light, even and direct. '
        'Energy: dignified outrage — being right, not being out of control.',

        # adolescent — vivid orange-red, assertive
        'Character color: vivid burnt orange. '
        'Posture: straight-backed, chin up, dot-eyes looking directly at '
        'the viewer with clear offense, brow furrowed shape implied in the '
        'dot-eyes, arms crossed or held deliberately. '
        'Rim light: bright orange-red edge glow. '
        'Energy: justified, assertive, contained — not explosive.',

        # adult — deep terracotta, measured
        'Character color: deep terracotta-brown. '
        'Posture: standing in profile or three-quarter view, spine straight, '
        'dot-eyes level and direct, jaw set, arms deliberate at sides. '
        'Lighting: warm directional side light, strong composed shadow. '
        'Energy: fully considered outrage — the posture of someone who has '
        'decided they are right and will not be moved.',
    ),

    'melancholy': (
        # global — dusty blue, wistful and still
        'Character color: dusty blue-grey. '
        'Posture: three-quarter view, body in a middle stillness — not '
        'collapsed, not upright. Dot-eyes looking away toward a diffuse '
        'light source, mouth in a soft downward neutral curve. '
        'One arm loosely at side. '
        'Lighting: soft diffuse blue-grey light from upper-right. '
        'Energy: wistful, somewhere else — not despairing, just not here.',

        # adolescent — blue-violet, paused mid-task
        'Character color: blue-violet. '
        'Posture: sitting with one arm extended as if holding something '
        'forgotten, dot-eyes looking off to the side and slightly down, '
        'mouth in a soft neutral line. Weight settled but not collapsed. '
        'Rim light: cool blue edge glow. '
        'Energy: the pause of someone whose mind has drifted far away.',

        # adult — deep slate blue, window-light stillness
        'Character color: deep slate blue. '
        'Posture: still, one stubby arm raised and touching an implied '
        'surface (window glass), dot-eyes directed to the side in '
        'soft unfocused gaze, mouth neutral. Weight settled. '
        'Lighting: cool window light from the side — the blue carries '
        'the emotional temperature. '
        'Energy: the quiet weight of something unresolved.',
    ),

    'resentful': (
        # global — not in 7-image fallback scope
        None,

        # adolescent — rose-red, closed and tight
        'Character color: muted rose-red. '
        'Posture: arms crossed tight across the body, dot-eyes averted to '
        'the side and slightly down, mouth pressed flat, shoulders slightly '
        'elevated with tension. '
        'Rim light: cool rose edge glow. '
        'Energy: something being held in — a deliberate withholding.',

        # adult — deep rose-brown, single point of tension
        'Character color: deep muted rose-brown. '
        'Posture: standing or seated, body composed and still except for '
        'one stubby hand gripping something slightly too tightly. '
        'Dot-eyes averted to the side, mouth controlled and flat. '
        'Lighting: warm side light with a cool cast on the averted side. '
        'Energy: controlled surface with internal heat — the grip is the tell.',
    ),

    'restless': (
        # global — warm peach-orange, kinetic
        'Character color: warm peach-orange. '
        'Posture: mid-motion — weight shifted off-center, one foot lifted '
        'or one arm in motion, body at an angle as if about to move '
        'but with no clear direction. Dot-eyes unfocused, mouth open '
        'slightly. '
        'Lighting: warm orange kinetic glow, slight motion impression. '
        'Energy: contained motion without destination — full and unable to settle.',

        # adolescent — bright orange, bouncing energy
        'Character color: vivid bright orange. '
        'Posture: seated but with one leg raised or in motion, arms slightly '
        'spread as if unsure which way to go, dot-eyes darting, mouth open '
        'in an unsettled expression. '
        'Rim light: vivid warm orange rim light. '
        'Energy: bouncing, directionless, pent — needs to move but has nowhere to go.',

        # adult — warm amber-brown, scattered and unfocused
        'Character color: warm amber-brown. '
        'Posture: standing or at a table, one arm in mid-reach toward nothing '
        'particular, weight uneven, dot-eyes unfocused and looking nowhere. '
        'Lighting: warm directional light with softened edges. '
        'Energy: the adult version — quieter but no less unresolved, '
        'a mind that cannot settle on anything.',
    ),
}

# ---------------------------------------------------------------------------
# Generation helpers
# ---------------------------------------------------------------------------

def get_client() -> genai.Client:
    return CLIENTS[_key_index]


def rotate_key():
    global _key_index
    _key_index = (_key_index + 1) % len(API_KEYS)
    print(f'  Rotating to API key {_key_index + 1}/{len(API_KEYS)}')


def backup_existing(output_path: Path):
    if output_path.exists():
        backup = output_path.with_name(f'backup_pre_redesign_{output_path.name}')
        shutil.copy2(output_path, backup)
        print(f'  Backed up: {backup.name}')


def generate_image(output_path: Path, prompt: str, dry_run: bool, force: bool) -> bool:
    if output_path.exists() and not force:
        print(f'  Skip (exists): {output_path}')
        return True
    if dry_run:
        print(f'  DRY RUN -- would generate: {output_path}')
        return True

    output_path.parent.mkdir(parents=True, exist_ok=True)
    backup_existing(output_path)

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
                    print(f'  Rate limited — waiting {wait}s...')
                    time.sleep(wait)
            else:
                print(f'  Error: {e}')
                return False

    print(f'  All keys exhausted for {output_path.name}')
    return False


def write_log(log_entries: list[tuple[str, str, str, str]]):
    log_path = Path('scripts/feelings_generation_log.md')
    timestamp = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    lines = [
        f'# Feelings Generation Log — {timestamp}\n\n',
        '| File | Style | Result | Notes |\n',
        '|------|-------|--------|-------|\n',
    ]
    for file_path, style, result, notes in log_entries:
        lines.append(f'| `{file_path}` | {style} | {result} | {notes} |\n')
    log_path.write_text(''.join(lines), encoding='utf-8')
    print(f'\nLog written: {log_path}')


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description='Generate redesigned feelings assets')
    parser.add_argument('--dry-run', action='store_true', help='Preview without generating')
    parser.add_argument('--force', action='store_true', help='Regenerate even if file exists')
    parser.add_argument(
        '--set',
        choices=['global', 'adolescent', 'adult', 'all'],
        default='all',
        help='Which asset set to generate (default: all)',
    )
    parser.add_argument(
        '--feeling',
        choices=list(FEELINGS.keys()),
        help='Generate only this specific feeling across all selected sets',
    )
    args = parser.parse_args()

    # Global fallback scope: 7 feelings (grief, hopeful, resentful have no global version)
    GLOBAL_SCOPE = {k for k, v in FEELINGS.items() if v[0] is not None}

    tasks = []
    for feeling, (global_desc, adolescent_desc, adult_desc) in FEELINGS.items():
        if args.feeling and feeling != args.feeling:
            continue

        if args.set in ('global', 'all') and feeling in GLOBAL_SCOPE:
            tasks.append((
                Path(f'assets/feelings_faces/{feeling}.png'),
                GLOBAL_STYLE + global_desc,
                'Soft Geometric Character (global fallback)',
            ))

        if args.set in ('adolescent', 'all'):
            tasks.append((
                Path(f'assets/images/feelings/adolescent/{feeling}.png'),
                ADOLESCENT_STYLE + adolescent_desc,
                'Webtoon Expressive Character (adolescent)',
            ))

        if args.set in ('adult', 'all'):
            tasks.append((
                Path(f'assets/images/feelings/adult/{feeling}.png'),
                ADULT_STYLE + adult_desc,
                'Warm Editorial Character (adult)',
            ))

    total = len(tasks)
    if total == 0:
        print('No tasks matched the given filters.')
        return

    sets_label = args.set if args.set != 'all' else 'global + adolescent + adult'
    feeling_label = f' [{args.feeling}]' if args.feeling else ''
    print(f'\nGenerating {total} images — {sets_label}{feeling_label}\n')

    log_entries = []
    failed = []

    for i, (output_path, prompt, style_label) in enumerate(tasks, 1):
        print(f'[{i}/{total}] {output_path}')
        ok = generate_image(output_path, prompt, args.dry_run, args.force)
        result = 'PASS' if ok else 'FAIL'
        log_entries.append((str(output_path), style_label, result, ''))
        if not ok:
            failed.append(str(output_path))
        if not args.dry_run and i < total:
            time.sleep(8)

    if not args.dry_run:
        write_log(log_entries)

    print(f'\n{"=" * 55}')
    print(f'Done. {total - len(failed)}/{total} generated.')
    if failed:
        print(f'Failed ({len(failed)}):')
        for f in failed:
            print(f'  {f}')
    print('=' * 55)


if __name__ == '__main__':
    main()
