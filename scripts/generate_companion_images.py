"""
Generate companion character and sprout tile images using Imagen 4.0.

Usage:
    # Generate all missing companion images
    python scripts/generate_companion_images.py

    # Generate for a specific band
    python scripts/generate_companion_images.py --band sprout

    # Generate a specific character
    python scripts/generate_companion_images.py --band explorer --character robin

    # Generate sprout tiles only
    python scripts/generate_companion_images.py --tiles

    # Dry run (show what would be generated)
    python scripts/generate_companion_images.py --dry-run

    # Force regenerate even if file exists
    python scripts/generate_companion_images.py --force

Reads prompts from docs/COMPANION_IMAGE_PROMPTS.md.
Saves images to assets/images/companions/<band>/<character>.png
               and assets/images/ui/sprout/tiles/<tile>.png
"""

import argparse
import base64
import os
import sys
import time
from pathlib import Path

# Allow running from project root or scripts/
sys.path.insert(0, str(Path(__file__).parent.parent / 'backend'))

from config import Config
from google import genai
from google.genai import types

PROJECT_ROOT = Path(__file__).parent.parent
ASSETS_DIR = PROJECT_ROOT / 'assets' / 'images'
COMPANIONS_DIR = ASSETS_DIR / 'companions'
TILES_DIR = ASSETS_DIR / 'ui' / 'sprout' / 'tiles'

MODEL = 'models/imagen-4.0-generate-001'

# ---------------------------------------------------------------------------
# Prompts — kept in sync with docs/COMPANION_IMAGE_PROMPTS.md
# ---------------------------------------------------------------------------

# Style note: all images use a deep dark background (near-black or deep navy)
# baked into the image so there is no transparency/checkerboard.
# Characters are lit warmly from below-front to feel inviting, not cold.

COMPANION_PROMPTS = {
    'sprout': {
        'fluffy_dragon': (
            "A tiny round baby dragon with soft fluffy fur instead of scales, on a deep dark velvety background. "
            "Pastel lavender body, cream belly, oversized sparkling eyes. Cotton-candy puff wings. "
            "Harmless warm glow at tail tip. Warm golden front lighting. "
            "Deep near-black background, no transparency. Soft watercolor style. Ages 2-4. Square format, no text."
        ),
        'magic_bunny': (
            "An adorable round bunny with soft white fur and a shimmer of magic sparkles, on a deep dark background. "
            "Big floppy ears, pink insides. Holding a tiny glowing star. Daisy flower crown. "
            "Warm golden rim light. Deep near-black background, no transparency. "
            "Soft watercolor style. Ages 2-4. Square format, no text."
        ),
        'shining_puppy': (
            "A small golden puppy with a warm glowing aura, on a deep dark background. "
            "Fluffy fur in warm amber light. Big round brown eyes full of love. Tiny rainbow ribbon cape. "
            "Warm amber front lighting, dark background with soft glow behind. "
            "Deep near-black background, no transparency. Soft watercolor style. Ages 2-4. Square format, no text."
        ),
        'robin': (
            "A round friendly robin with a bright red-orange breast, on a deep dark background. "
            "Slightly oversized cute head, big bright curious eyes. Perched on a short wooden post. "
            "Warm front lighting, soft amber glow behind. "
            "Deep near-black background, no transparency. Soft watercolor style. Ages 2-4. Square format, no text."
        ),
    },
    'explorer': {
        'ember_dragon': (
            "A friendly small dragon with warm amber-orange scales, on a deep dark background. "
            "Rounded snout, soft expressive eyes, small wings. Tiny explorer's backpack and compass. "
            "Puff of colorful sparkles (not fire). Warm amber front lighting. "
            "Deep near-black background, no transparency. Bright storybook style. Ages 5-7. Square format, no text."
        ),
        'moon_owl': (
            "A charming small owl with silver-white feathers and large golden eyes, on a deep dark background. "
            "Soft crescent moon symbol glowing on forehead. Tufted ears, warm welcoming expression. "
            "One wing extended. Warm amber-silver lighting. "
            "Deep near-black background, no transparency. Bright storybook style. Ages 5-7. Square format, no text."
        ),
        'star_fox': (
            "A playful young fox with amber fur and a tail sparkling with tiny stars, on a deep dark background. "
            "Friendly eyes, perky ears, star-patterned neckerchief. Sitting alert and happy, tail wrapped around paws. "
            "Warm golden-amber lighting, tiny star specks in dark background. "
            "Deep near-black background, no transparency. Bright storybook style. Ages 5-7. Square format, no text."
        ),
        'robin': (
            "A cheerful robin with a bright red-orange breast, on a deep dark background. "
            "Tiny aviator cap with goggles pushed up. Perched on a signpost, one wing pointing forward. "
            "Adventure sticker satchel. Warm amber front lighting. "
            "Deep near-black background, no transparency. Bright storybook style. Ages 5-7. Square format, no text."
        ),
    },
    'adventurer': {
        'thunder_wolf': (
            "A noble wolf with silver-grey fur and warm amber eyes, lit by firelight from below. "
            "Deep dark forest background — near-black with glowing ember tones. No transparency. "
            "Powerful but approachable: sitting alert, one paw forward, tail curved. "
            "A worn leather scout's collar with a carved wooden charm. "
            "Warm inviting glow on the fur, dark background. Semi-realistic illustration, ages 8-10. Square format, no text."
        ),
        'shadow_panther': (
            "A sleek black panther with golden eyes that catch the light, emerging from deep shadow. "
            "Deep dark background — near-black, with subtle blue-purple undertones. No transparency. "
            "Sitting calmly, body relaxed but watchful. Golden eyes are the warmest point of the image. "
            "A single amber gem on a simple collar. Warm rim light on the fur edge. "
            "Semi-realistic illustration, ages 8-10. Square format, no text."
        ),
        'crystal_phoenix': (
            "A phoenix with warm amber and rose-gold feathers that glow like embers. "
            "Deep dark background — near-black with warm ember glow. No transparency. "
            "Medium-sized, wings half-spread, comfortable and welcoming rather than dramatic. "
            "Feathers transition from deep burgundy to glowing gold at the tips. Warm and inviting light. "
            "Semi-realistic illustration, ages 8-10. Square format, no text."
        ),
        'robin': (
            "A robin with a vivid red-orange breast, perched on a mossy branch. "
            "Deep dark background — near-black with soft warm glow. No transparency. "
            "Rich feather detail. Alert, bright-eyed, completely focused on you. "
            "Warm rim light on feathers, soft amber background glow. "
            "Semi-realistic illustration, ages 8-10. Square format, no text."
        ),
    },
    'creator': {
        'thunder_wolf': (
            "A wolf with storm-silver fur and deep amber eyes, in polished digital art style. "
            "Deep dark background — near-black with cool blue-silver ambient light. No transparency. "
            "Standing, confident and focused. Glowing rune-like markings faintly visible in the fur. "
            "A crescent moon pendant on a leather cord. Dramatic side lighting, warm on one side. "
            "Digital art, ages 11-13. Square format, no text."
        ),
        'shadow_panther': (
            "A sleek panther that seems to be made partly of shadow, in polished digital art style. "
            "Deep dark background — near-black with purple-indigo tones. No transparency. "
            "Gold eyes glow with warmth. Shadow aura trails softly from paws and tail. "
            "Crouched low, watching — but the expression is warm, not threatening. "
            "Digital art, ages 11-13. Square format, no text."
        ),
        'crystal_phoenix': (
            "A phoenix with crystalline feathers that fracture light into warm prismatic colors, in polished digital art style. "
            "Deep dark background — near-black with scattered light refraction. No transparency. "
            "Feathers are translucent rose-gold crystal tipped with amber fire. Wings spread confidently. "
            "Light radiates from the bird itself, warming the scene. "
            "Digital art, ages 11-13. Square format, no text."
        ),
        'robin': (
            "A robin with copper-metallic breast feathers and dark bronze wings, in polished digital art style. "
            "Deep dark background — near-black with warm copper-toned lighting. No transparency. "
            "Perched on a mechanical branch with tiny softly glowing gears. "
            "A faint runic symbol glows near one eye. Warm amber lighting. "
            "Digital art, ages 11-13. Square format, no text."
        ),
    },
    'adolescent': {
        'thunder_wolf': (
            "A wolf that carries the weight of experience — scars healed over, eyes steady. "
            "Deep dark background — near-black with moonlit blue-grey atmosphere. No transparency. "
            "Sitting still in a night forest, snow on the ground, breath just visible. "
            "Eyes catch the moonlight: calm, present, chosen. Warm rim light on fur. "
            "Refined digital art, ages 14-17. Square format, no text."
        ),
        'shadow_panther': (
            "A black panther at the edge of light and shadow, in refined digital art style. "
            "Deep dark background — near-black. No transparency. "
            "Only the amber eyes and the warm edge of fur are clearly visible. "
            "The sense of presence is larger than the visible form. Poised, reading the room. "
            "Refined digital art, ages 14-17. Square format, no text."
        ),
        'crystal_phoenix': (
            "A phoenix mid-rise — not at peak, not at ash — caught in the act of becoming. "
            "Deep dark background — near-black with warm amber light radiating from the bird. No transparency. "
            "Feathers shift from grey-ash at the roots to glowing amber and rose-gold at the tips. "
            "Wings spread wide but unhurried. The fire is quiet, not dramatic. "
            "Refined digital art, ages 14-17. Square format, no text."
        ),
        'robin': (
            "A robin in dramatic composition, photorealistic detail. "
            "Deep dark background — near-black with a single beam of warm golden light. No transparency. "
            "Red-orange breast feathers rendered individually. Perched on mossy stone in a rain-damp forest. "
            "The bird is small but the light finds it anyway. "
            "Refined digital art, ages 14-17. Square format, no text."
        ),
    },
    'adult': {
        'thunder_wolf': (
            "A wolf that has run many storms and chosen to stay, in fine art painterly style. "
            "Deep dark background — near-black with warm amber firelight. No transparency. "
            "Sitting by a low fire, head up, watching the dark beyond. Fur is warm and rich. "
            "The expression is not protection — it is companionship. "
            "Fine art painterly, ages 18+. Square format, no text."
        ),
        'shadow_panther': (
            "A black panther painted mostly in shadow, in fine art painterly style. "
            "Deep dark background — near-black. No transparency. "
            "The body is suggestion and shadow. The eyes are fully present — warm amber, seeing you. "
            "A sense of something that has chosen to be here. "
            "Fine art painterly, ages 18+. Square format, no text."
        ),
        'crystal_phoenix': (
            "A phoenix at rest after many cycles, feathers soft amber and grey-rose, in fine art painterly style. "
            "Deep dark background — near-black with warm ember light. No transparency. "
            "Not triumphant. Not fallen. Simply present. The fire is interior now — visible through feathers. "
            "Wings folded. Eyes open. At peace with the count. "
            "Fine art painterly, ages 18+. Square format, no text."
        ),
        'robin': (
            "A robin at dawn on a garden fence, in fine art painterly style — classical naturalist quality. "
            "Deep dark background — near-black at the edges, warming to soft amber behind the bird. No transparency. "
            "Every feather painted with care. The red breast catches early light like a small steady flame. "
            "Dew on the fence post. The bird is just a bird. That is the whole point. "
            "Fine art painterly, ages 18+. Square format, no text."
        ),
    },
}

TILE_PROMPTS = {
    'castle': (
        "A whimsical fairy-tale castle with round towers and colorful flags, in soft watercolor style for toddlers. "
        "Pastel pink and purple stone walls. A friendly drawbridge is down, welcoming visitors. "
        "Puffy white clouds and a smiling sun in the sky. Flowers growing along the castle walls. "
        "Simple, warm, and inviting. No text. Square format. Ages 2-4."
    ),
    'ocean': (
        "A cheerful underwater scene with friendly cartoon fish and colorful coral, in soft watercolor style for toddlers. "
        "A smiling sea turtle swims by. Gentle bubbles float upward. Soft blue-green water with shafts of warm sunlight filtering down. "
        "A treasure chest sits open on the sandy bottom with sparkles coming out. No text. Square format. Ages 2-4."
    ),
    'space': (
        "A cute outer space scene with a friendly rocket ship and smiling stars, in soft watercolor style for toddlers. "
        "A round, happy moon with a gentle face. Pastel-colored planets with rings. "
        "A small astronaut (gender-neutral, simple) waves from the rocket window. "
        "Deep blue-purple sky with soft sparkles. No text. Square format. Ages 2-4."
    ),
    'forest': (
        "An enchanted forest clearing with oversized mushrooms and tiny glowing fireflies, in soft watercolor style for toddlers. "
        "Friendly woodland animals peeking from behind trees — a bunny, a deer, a squirrel. "
        "Dappled golden sunlight through the canopy. A winding path of soft moss leads into the trees. "
        "Warm greens and golds. No text. Square format. Ages 2-4."
    ),
    'candy_land': (
        "A magical candy landscape with lollipop trees and a gumdrop path, in soft watercolor style for toddlers. "
        "A chocolate river with a wafer bridge. Cotton candy clouds in a pastel sky. "
        "Ice cream cone mountains in the background. Everything looks delicious and fun, "
        "with warm candy colors (pink, mint, lavender, butter yellow). No text. Square format. Ages 2-4."
    ),
    'dinosaurs': (
        "A friendly baby dinosaur (green brontosaurus) in a prehistoric meadow, in soft watercolor style for toddlers. "
        "Oversized eyes and a big smile. A tiny pterodactyl flies overhead. "
        "Lush tropical plants with big colorful leaves. A volcano in the far background with a tiny puff of white smoke (not scary). "
        "Warm earthy greens and sky blue. No text. Square format. Ages 2-4."
    ),
}

BANDS = list(COMPANION_PROMPTS.keys())


def get_client():
    key = Config.GEMINI_API_KEY or os.environ.get('GEMINI_API_KEY', '')
    if not key:
        print('ERROR: No GEMINI_API_KEY found. Set it in .env or environment.')
        sys.exit(1)
    return genai.Client(api_key=key)


def generate_image(client, prompt: str, output_path: Path, force: bool = False) -> bool:
    if output_path.exists() and not force:
        print(f'  SKIP (exists): {output_path.name}')
        return False

    print(f'  Generating: {output_path.name} ...', end='', flush=True)
    try:
        response = client.models.generate_images(
            model=MODEL,
            prompt=prompt,
            config=types.GenerateImagesConfig(
                number_of_images=1,
                aspect_ratio='1:1',
                safety_filter_level='block_low_and_above',
                person_generation='dont_allow',
            ),
        )
        if not response.generated_images:
            print(' FAILED (no images returned)')
            return False

        img_bytes = response.generated_images[0].image.image_bytes
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_bytes(img_bytes)
        print(f' OK ({len(img_bytes)//1024}KB)')
        return True

    except Exception as e:
        print(f' ERROR: {e}')
        return False


def run(args):
    client = get_client()
    generated = 0
    skipped = 0
    failed = 0

    if args.tiles or not (args.band or args.character):
        # Generate sprout tiles
        print('\n=== Sprout Tiles ===')
        for tile_name, prompt in TILE_PROMPTS.items():
            out = TILES_DIR / f'{tile_name}.png'
            if args.dry_run:
                status = 'EXISTS' if out.exists() else 'WOULD GENERATE'
                print(f'  {tile_name}: {status}')
                continue
            ok = generate_image(client, prompt, out, force=args.force)
            if ok:
                generated += 1
            elif out.exists():
                skipped += 1
            else:
                failed += 1
            if ok:
                time.sleep(1)  # Rate limiting

    if not args.tiles:
        # Generate companion images
        bands_to_run = [args.band] if args.band else BANDS
        for band in bands_to_run:
            if band not in COMPANION_PROMPTS:
                print(f'ERROR: Unknown band "{band}". Valid: {BANDS}')
                continue
            print(f'\n=== {band.upper()} ===')
            chars = COMPANION_PROMPTS[band]
            if args.character:
                if args.character not in chars:
                    print(f'ERROR: Unknown character "{args.character}" for band "{band}". Valid: {list(chars.keys())}')
                    continue
                chars = {args.character: chars[args.character]}

            for char_name, prompt in chars.items():
                out = COMPANIONS_DIR / band / f'{char_name}.png'
                if args.dry_run:
                    status = 'EXISTS' if out.exists() else 'WOULD GENERATE'
                    print(f'  {char_name}: {status}')
                    continue
                ok = generate_image(client, prompt, out, force=args.force)
                if ok:
                    generated += 1
                elif out.exists():
                    skipped += 1
                else:
                    failed += 1
                if ok:
                    time.sleep(1)  # Rate limiting between API calls

    if not args.dry_run:
        print(f'\nDone. Generated: {generated}, Skipped: {skipped}, Failed: {failed}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate companion/tile images with Imagen 4.0')
    parser.add_argument('--band', choices=BANDS, help='Only generate for this band')
    parser.add_argument('--character', help='Only generate this character (use with --band)')
    parser.add_argument('--tiles', action='store_true', help='Generate sprout tiles only')
    parser.add_argument('--force', action='store_true', help='Regenerate even if file exists')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be generated without doing it')
    args = parser.parse_args()
    run(args)
