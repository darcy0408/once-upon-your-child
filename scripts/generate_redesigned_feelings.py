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

_GLOBAL_NEG = (
    'Not photorealistic. Not a photograph. Not clipart. Not a children\'s TV '
    'character. Not a stock illustration. Not cool-palette dominant. '
    'No silhouettes as the only element. No traced face outlines. '
)

_ADOLESCENT_NEG = (
    'Not photorealistic. Not a photograph. Not a children\'s cartoon. '
    'Not babyish proportions. Not cold-teal dominant. Not a silhouette without '
    'facial features. Not corporate. Not a school worksheet. '
    'No brand logos. No specific branded style. '
)

_ADULT_NEG = (
    'Not photorealistic. Not a photograph. Not a stock photo. '
    'Not a corporate wellness app aesthetic. Not an AI-generated human face. '
    'Not cool-palette dominant. Not a children\'s illustration. '
    'Not clinical or medical in feeling. '
)

# ---------------------------------------------------------------------------
# Style bases
# ---------------------------------------------------------------------------

GLOBAL_STYLE = (
    'Soft geometric character illustration in the style of Headspace app '
    '(2018-2021 era). Rounded simplified human figure with clear limb '
    'differentiation, adult-adjacent head proportions, warm mocha skin tone '
    '(#C49A6C), minimal but legible facial features (simple eyes and mouth). '
    'Warm brown outline (#5C3D2E), approximately 2px weight. '
    'Background: warm cream (#F5EFE6) with a subtle radial gradient slightly '
    'cooler at edges. Square composition, character centered and clearly legible '
    'at thumbnail size. Single warm-toned accent color as the dominant emotional '
    'signal. Emotional expression carried 70% by body language and posture, '
    '30% by facial expression. High quality illustration render. '
    + _NO_TEXT + _GLOBAL_NEG
)

ADOLESCENT_STYLE = (
    'Webtoon-influenced digital illustration. Contemporary graphic novel / '
    'webtoon aesthetic (Lore Olympus, Heartstopper register). '
    'Adolescent character with medium warm skin tone, large expressive eyes '
    'with clear iris and catch-light, clean digital linework at consistent '
    '2px weight in warm dark plum (#2C1A3A). '
    'Background: soft lavender-cream (#F0EBF8) with loose impressionistic '
    'strokes suggesting a space. Character is the clear focal point. '
    'Emotional expression: 50% eyes and brows, 50% body language. '
    'Gender-neutral or softly ambiguous character presentation. '
    'The character\'s emotion should feel authentic and non-performative. '
    'High quality digital illustration. '
    + _NO_TEXT + _ADOLESCENT_NEG
)

ADULT_STYLE = (
    'Warm editorial character illustration. Style references: Marion Barraud '
    'figure warmth, Olimpia Zagnoli palette restraint. Abstracted human form — '
    'face may be simplified, seen from three-quarter view, or partially turned. '
    'Warm muted skin tone (#B08060) with warm umber shadow (#7A5030). '
    'Minimal linework — color shapes define the figure. Where lines appear, '
    'they are deliberate and match the dominant scene color. '
    'Background: warm greige (#EDE8E3) with a spare environmental element '
    '(window, table, chair edge) to ground the figure. '
    'Emotional expression: 80% body language and environmental relationship, '
    '20% facial expression. The posture tells the story. '
    'Sophisticated, intimate, and warm — never clinical, never corporate. '
    'High quality editorial illustration. '
    + _NO_TEXT + _ADULT_NEG
)

# ---------------------------------------------------------------------------
# Per-feeling prompts
# Tuple: (global_desc, adolescent_desc, adult_desc)
# global_desc is None for feelings not in the 7-image global fallback set.
# ---------------------------------------------------------------------------

FEELINGS = {
    'anticipation': (
        # global (in scope)
        'The figure sits perched on the edge of a simple surface, weight '
        'shifted forward onto the balls of the feet, hands clasped together '
        'in the lap, eyes wide and bright. Warm amber light (#F5A623) falls '
        'from the right edge of the frame as if from a source just off-screen. '
        'Expression: quietly alert, slightly held breath. Body language carries '
        'forward-leaning potential energy.',

        # adolescent
        'The adolescent character leans forward at the edge of their seat, '
        'hands pressed together, eyes bright with slight dilation, looking '
        'toward the right. Warm amber accent (#F5A623) in the light from that '
        'direction. Background strokes suggest an opening, something beyond. '
        'The body language has gathering, tension-before-motion energy.',

        # adult
        'An abstracted adult figure stands at a threshold — hand resting on '
        'a door frame or window edge, leaning slightly forward, weight on the '
        'front foot. Deep amber light (#C8860A) fills the space beyond. '
        'The posture is deliberate and contained — an adult\'s anticipation, '
        'considered not impulsive. Environmental context: a doorway or window '
        'frame visible as a compositional element.',
    ),

    'contentment': (
        # global
        'The figure sits with legs loosely crossed, shoulders dropped, a faint '
        'upward curve of the mouth, eyes half-closed in quiet pleasure. '
        'Sage green accent (#A8C5A0) in the character\'s clothing. '
        'A simple warm object — a cup edge or blanket corner — visible nearby. '
        'Light is warm and even with no drama. The figure fully occupies the '
        'space — nothing reaching, nothing guarded.',

        # adolescent
        'The adolescent character in a casual seated position — headphones '
        'loosely around the neck (not on ears), legs loosely crossed, a soft '
        'genuine smile. Sage green accent (#A8C5A0) in the clothing or ambient '
        'light. Background warm and soft. The character has fully inhabited '
        'their space — no urgency in any limb.',

        # adult
        'An abstracted adult figure reclined — book or cup held loosely, '
        'eyes closed or softly directed at the object. Afternoon window light '
        'falls across them in one warm bar. Forest sage accent (#7D9E77) in '
        'clothing or a plant near the frame edge. Domestic and dignified. '
        'The rest is active and chosen, not collapsed.',
    ),

    'dread': (
        # global
        'The figure stands or sits slightly smaller in the frame than usual, '
        'shoulders raised slightly toward the ears, eyes directed toward the '
        'lower-left as if tracking something unseen. Muted indigo light '
        '(#7B7FA8) as a shadow source from that lower-left direction. '
        'Background very slightly cooler at the left edge. '
        'The figure is frozen — not retreating, just held still.',

        # adolescent
        'The adolescent character slightly smaller in frame than usual, '
        'shoulders elevated, eyes tracking something off-screen at lower-left. '
        'Background color shifts from lavender-cream to cooler muted indigo '
        '(#7B7FA8) at that corner. The posture is frozen alert — '
        'not fleeing, just held. Expressive webtoon eyes carry the weight.',

        # adult
        'An abstracted adult figure at a desk or table interior, shoulders '
        'carried slightly forward, gaze level on an unseen point. '
        'Background shifts from warm greige (#EDE8E3) to cooler muted indigo '
        '(#6B6FA0) at the edge toward which the figure looks. '
        'Tension held in the upper body — the body knows something. '
        'The environmental detail (desk surface, nearby objects) adds weight.',
    ),

    'envious': (
        # global
        'The figure in three-quarter profile, gaze cut sharply sideways '
        'toward the left edge of the frame, expression tight and controlled — '
        'small closed mouth, slight narrowing of eyes. One hand near the chin. '
        'Teal-green accent (#5FA888) in clothing or a reflected light element. '
        'The object of attention is entirely off-screen.',

        # adolescent
        'The adolescent character with a sideways glance and closed-mouth '
        'expression, one arm pulled in slightly. In the background, a softly '
        'out-of-focus window or screen element suggests the object of comparison. '
        'Teal-green accent (#5FA888) in the background ambient light. '
        'Controlled involuntary attention to the off-screen subject.',

        # adult
        'An abstracted adult figure partially reflected in a window pane, '
        'looking at something on the other side. The reflection in the glass '
        'is slightly more vivid or luminous than the figure\'s environment. '
        'Teal-green accent (#4E9078) in the reflected light. '
        'The comparison is the subject — handled with restraint and sophistication.',
    ),

    'grief': (
        # global — not in 7-image fallback scope, skip
        None,

        # adolescent
        'The adolescent character seated with knees drawn up or weight forward, '
        'one hand pressed gently and deliberately to the chest. Eyes closed. '
        'Soft, even light behind them — not dramatic. Soft periwinkle accent '
        '(#8B9CC4). The posture is complete and still, not performative. '
        'Background deepens slightly around the figure. '
        'The stillness signals that this feeling has settled, not just arrived.',

        # adult
        'An abstracted adult figure alone in a spare room interior — seated '
        'on the floor or a low chair. Complete held stillness. No dramatic '
        'gesture. The empty space in the composition carries as much weight as '
        'the figure. Soft periwinkle accent (#7A87B0) in the ambient light. '
        'The room itself feels held, paused.',
    ),

    'hopeful': (
        # global — not in 7-image fallback scope, skip
        None,

        # adolescent
        'The adolescent character looking slightly upward and ahead, a small '
        'genuine smile (not a wide grin, not forced), one open hand extended '
        'or slightly lifted at the side. Warm yellow accent (#F5C842) from '
        'above-ahead — an aspirational direction. Background gains warmth '
        'toward that light source.',

        # adult
        'An abstracted adult figure at a window or facing upward, posture open '
        'and grounded, a small contemplative expression. Warm yellow accent '
        '(#D4A82F) as the light source the figure is oriented toward. '
        'The figure is directed toward something, not simply open to nothing. '
        'Background shifts from warm greige to gold at the light source.',
    ),

    'indignation': (
        # global
        'The figure standing or sitting upright with deliberately raised chin, '
        'brow furrowed with clear intent, mouth set in a controlled line. '
        'Arms at sides or crossed — not raised, not aggressive. Chest open and '
        'elevated. Terracotta accent (#D4845A) in clothing. '
        'The posture signals dignity under assault: being right, not out of control.',

        # adolescent
        'The adolescent character straight-backed with chin elevated, brow '
        'furrowed, looking directly at the viewer or slightly above — offended '
        'and composed, not explosive. Terracotta accent (#D4845A) in clothing. '
        'Posture controlled and assertive. The emotion is held, not performed.',

        # adult
        'An abstracted adult figure in profile or three-quarter view, standing, '
        'jaw set, gaze measured and direct. Hands deliberate at sides — not '
        'raised. Terracotta accent (#B8634A) in clothing. Composed outrage: '
        'this emotion has been fully examined before being worn. Spine straight.',
    ),

    'melancholy': (
        # global
        'The figure in three-quarter view, gaze directed toward a soft diffuse '
        'light source at the upper right, expression neutral-to-wistful, slight '
        'downward set of the mouth. Dusty blue accent (#8FAFC4) in the light '
        'direction and in character shadow tones. '
        'The figure is in a middle stillness — neither collapsed nor upright. '
        'Wistful, not despairing.',

        # adolescent
        'The adolescent character looking out of frame toward soft diffuse light, '
        'an object — a pen, a phone — held in the hand but entirely unused. '
        'Expression neutrally wistful, eyes soft. Dusty blue accent (#8FAFC4) '
        'in the light source. The character has paused mid-task and is '
        'somewhere else entirely. The outward gaze is key.',

        # adult
        'An abstracted adult figure at a window in late afternoon light, '
        'partial reflection visible in the glass pane, one hand resting gently '
        'on the glass. Dusty blue accent (#6891A8) in the light. The palette '
        'carries most of the emotional weight — warm greige ground with blue '
        'window light creating a contemplative temperature difference.',
    ),

    'resentful': (
        # global — not in 7-image fallback scope, skip
        None,

        # adolescent
        'The adolescent character with arms crossed or gripping one arm tightly, '
        'jaw set, gaze averted to the side and slightly down. Muted '
        'rose-terracotta accent (#C17C6B) in clothing. The body is holding '
        'something in — tension stored in the upper body, especially shoulders '
        'and jaw. A deliberate withholding.',

        # adult
        'An abstracted adult figure in profile — jaw set, standing or seated. '
        'The single tell: one hand grips a railing, cup, or table edge slightly '
        'too firmly. The rest of the body is composed and still. Muted '
        'rose-terracotta accent (#A86655) in clothing. Controlled whole-body '
        'posture with only the grip revealing the inner state.',
    ),

    'restless': (
        # global
        'The figure mid-motion or with implied multiple positions — hand on '
        'knee about to push up, weight shifted forward, one foot slightly '
        'raised. Warm peach accent (#E8A87C) in clothing or a warm glow on '
        'the moving limb. The figure has no settled weight — '
        'kinetic and unresolved but warm.',

        # adolescent
        'The adolescent character seated with one leg implying a bouncing '
        'motion, weight on the front edge of their seat, one hand mid-motion. '
        'Expression of pent, directionless energy — not anxious, just full '
        'and unable to settle. Warm peach accent (#E8A87C) in clothing. '
        'Motion-without-destination energy.',

        # adult
        'An abstracted adult figure in a lived-in interior — table with '
        'scattered objects nearby, one hand mid-motion through hair or '
        'reaching toward something, gaze unfocused. Warm peach accent '
        '(#CC7F58) in the ambient light. Energy without object. '
        'The environmental clutter externalizes the directionlessness.',
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
