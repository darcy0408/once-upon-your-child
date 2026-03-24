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

COMPANION_PROMPTS = {
    'sprout': {
        'fluffy_dragon': (
            "A tiny, round baby dragon with soft fluffy fur instead of scales, in gentle watercolor style. "
            "Pastel lavender body with a cream-colored belly. Oversized sparkling eyes full of wonder. "
            "Tiny wings that look like cotton candy puffs. A small, harmless flame-shaped glow on the tip of its tail (no actual fire). "
            "Sitting in a meadow of oversized daisies. Cheerful, cozy, and non-threatening. "
            "Children's storybook illustration, ages 2-4. Square format, no text."
        ),
        'magic_bunny': (
            "An adorable round bunny with impossibly soft white fur and a faint shimmer of magic sparkles, in gentle watercolor style. "
            "Big floppy ears with pink insides. Holding a tiny glowing star between its paws. "
            "Wearing a small flower crown of daisies. Sitting on a puffy cloud in a pastel sky. "
            "Warm, dreamy, and huggable. Children's storybook illustration, ages 2-4. Square format, no text."
        ),
        'shining_puppy': (
            "A small golden puppy with a warm, glowing aura around it, in gentle watercolor style. "
            "Soft, fluffy fur that catches the light like sunshine. Big round brown eyes full of love. "
            "A tiny cape made of rainbow ribbons trailing behind. Playfully bouncing in a field of soft grass and butterflies. "
            "Joyful and energetic but gentle. Children's storybook illustration, ages 2-4. Square format, no text."
        ),
        'tiny_fairy': (
            "A miniature fairy no bigger than a daisy, in gentle watercolor style. "
            "Soft peach skin with rosy cheeks. Translucent iridescent wings like soap bubbles. "
            "Wearing a dress made of flower petals (pink and yellow). Sprinkling tiny golden sparkles from fingertips. "
            "Standing on a mushroom cap in a mossy garden. Sweet, magical, and delicate. "
            "Children's storybook illustration, ages 2-4. Square format, no text."
        ),
        'robin': (
            "A friendly round robin bird with bright red-orange breast, in gentle watercolor style. "
            "Soft brown feathers on wings and back. Big bright eyes full of curiosity. "
            "Slightly oversized head for extra cuteness. Perched on a wooden fence post with wildflowers nearby. "
            "Warm morning light. Cheerful and approachable. Children's storybook illustration, ages 2-4. Square format, no text."
        ),
    },
    'explorer': {
        'ember_dragon': (
            "A small friendly dragon with deep orange and amber scales that flicker like candlelight, in bright storybook illustration style. "
            "Soft expressive eyes, rounded snout, small functional wings. Wearing a tiny explorer's backpack and a compass around its neck. "
            "Breathing a small puff of colorful sparkles (not fire). Standing at the entrance of a candy-colored cave. "
            "Curious and adventurous expression. Children's storybook illustration, ages 5-7. Square format, no text."
        ),
        'moon_owl': (
            "A charming small owl with silver-white feathers and large luminous golden eyes, in bright storybook illustration style. "
            "A crescent moon symbol on its forehead that glows softly. Slightly oversized head with tufted ears. "
            "Perched on a glowing lantern in a twilight garden with fireflies. One wing extended as if pointing the way. "
            "Wise and gentle expression. Children's storybook illustration, ages 5-7. Square format, no text."
        ),
        'bloom_sprite': (
            "A cheerful tiny fairy with green hair made of flower petals and vine-like arms, in bright storybook illustration style. "
            "Delicate butterfly-like wings with flower patterns. Surrounded by blooming flowers that open as she passes. "
            "Wearing a dress woven from leaves and tiny blossoms. Flying in a sun-dappled forest with a trail of flower petals behind her. "
            "Warm and nurturing expression. Children's storybook illustration, ages 5-7. Square format, no text."
        ),
        'star_fox': (
            "A playful young fox with bright amber fur and a bushy tail that sparkles with tiny stars, in bright storybook illustration style. "
            "Sharp friendly eyes and perky pointed ears. Wearing a celestial navigator's scarf with constellation patterns. "
            "Running through a meadow at night, leaving a glittery trail. Stars visible in a twilight sky behind. "
            "Swift and clever expression. Children's storybook illustration, ages 5-7. Square format, no text."
        ),
        'robin': (
            "A cheerful robin bird with bright red-orange breast, in bright storybook illustration style. "
            "Wearing a tiny leather aviator cap and goggles pushed up. Slightly larger and more detailed than a toddler illustration. "
            "Perched on a signpost at a forest crossroads, pointing the way with one wing. "
            "A tiny satchel with adventure stickers. Confident and helpful expression. "
            "Children's storybook illustration, ages 5-7. Square format, no text."
        ),
    },
    'adventurer': {
        'storm_hawk': (
            "A fierce and noble hawk with storm-grey feathers edged in electric blue, in dynamic semi-realistic illustration style. "
            "Sharp intelligent eyes that miss nothing. Powerful wingspan partially spread, wind-ruffled feathers. "
            "A leather scout's harness with a tiny mission badge. Banking in flight over a dramatic mountain range with storm clouds building. "
            "Alert, fearless, and trustworthy expression. Middle-grade book illustration, ages 8-10. Square format, no text."
        ),
        'shadow_lynx': (
            "A sleek lynx with dark charcoal fur and subtle silver dappling, in dynamic semi-realistic illustration style. "
            "Tufted ears, observant amber eyes that shift to gold when trusting. Moving silently along the shadowed edge of a forest. "
            "Barely visible among dappled light and shadow. A single glowing eye visible from the darkness. "
            "Mysterious and watchful expression. Middle-grade book illustration, ages 8-10. Square format, no text."
        ),
        'iron_golem': (
            "A medium-sized golem built from smooth river stones and ancient bronze, in dynamic semi-realistic illustration style. "
            "Surprisingly gentle for its size — rounded edges, no sharp protrusions. Mossy patches where old and new meet. "
            "A warm amber glow in its chest like a hearth fire. Standing steady in a forest clearing, hand extended to help. "
            "Steadfast and protective expression. Middle-grade book illustration, ages 8-10. Square format, no text."
        ),
        'void_sprite': (
            "A curious small sprite made of living shadow and stardust, in dynamic semi-realistic illustration style. "
            "Body is deep indigo and translucent, stars visible within. Wispy edges that dissolve into darkness. "
            "Two bright teal eyes and a faint smile. Floating just above the ground in a moonlit clearing. "
            "Leaves a trail of tiny floating stars. Playful and mysterious expression. Middle-grade book illustration, ages 8-10. Square format, no text."
        ),
        'robin': (
            "A robin bird rendered with realistic proportions and rich detail, in dynamic semi-realistic illustration style. "
            "Vivid red-orange breast feathers with fine texture. Alert posture on a lichen-covered branch. "
            "Wearing a tiny hand-forged copper leg band with runic markings. "
            "A misty forest clearing with shafts of golden light. Brave and steadfast expression. "
            "Middle-grade book illustration, ages 8-10. Square format, no text."
        ),
    },
    'creator': {
        'storm_hawk': (
            "A powerful hawk with storm-grey and electric-blue plumage, in polished digital art style with anime influence. "
            "Sleek aerodynamic build, wings partially folded in a precision dive. Crackling energy traces along flight feathers. "
            "Battle-tested tactical gear — a lightweight communications earpiece, mission markings on wing. "
            "Mid-dive above a thunderstorm, lightning visible in the background. "
            "Intense and focused expression. Young adult illustration, ages 11-13. Square format, no text."
        ),
        'shadow_lynx': (
            "A lithe lynx with deep charcoal fur and a shifting shadow aura, in polished digital art style with anime influence. "
            "Gold eyes that glow when he trusts you, silver-grey otherwise. Shadow tendrils trail from his paws as he moves. "
            "A runic collar that dampens sound. Moving along rooftop edges in a rain-soaked urban fantasy setting. "
            "Calculating and quietly loyal expression. Young adult illustration, ages 11-13. Square format, no text."
        ),
        'iron_golem': (
            "A golem forged from dark iron and living stone, in polished digital art style with anime influence. "
            "Runes etched into armor-like plating that glow amber. Towering but balanced — clearly built to protect, not destroy. "
            "Moss and vines growing in the joints between stones, softening the silhouette. "
            "Standing guard at the entrance of an ancient library. "
            "Unshakeable and dependable expression. Young adult illustration, ages 11-13. Square format, no text."
        ),
        'void_sprite': (
            "A sprite woven from living void and captured starlight, in polished digital art style with anime influence. "
            "Body is deep cosmic black with nebula swirls visible within. Bright teal eyes and a knowing smile. "
            "Trailing stardust with every movement. Small but radiating an aura larger than its form. "
            "Hovering in a dark space environment, stars and galaxies visible through its semi-transparent form. "
            "Impish and wiser-than-they-look expression. Young adult illustration, ages 11-13. Square format, no text."
        ),
        'robin': (
            "A robin reimagined with artistic flair, in polished digital art style with anime influence. "
            "Feathers have a metallic sheen — copper breast, dark bronze wings. "
            "Perched on a steampunk-style mechanical branch with tiny gears. "
            "A glowing runic symbol floating near one eye like a monocle. "
            "Background: a twilight cityscape blending nature and technology. "
            "Creative and resourceful expression. Young adult illustration, ages 11-13. Square format, no text."
        ),
    },
    'adolescent': {
        'storm_hawk': (
            "A battle-hardened hawk of commanding presence, in refined concept art style. "
            "Storm-grey and midnight-blue plumage, each feather razor-precise. Electric arcs trace along wingtips. "
            "Tactical combat harness with encrypted comms gear. Hovering in the eye of a massive storm, debris swirling around. "
            "Expression: she has already assessed the situation and knows exactly what needs to happen. Ages 14-17. Square format, no text."
        ),
        'shadow_lynx': (
            "A lynx that is more shadow than substance, in refined concept art style. "
            "Dark charcoal form with glowing gold eyes — the only fixed points in shifting darkness. "
            "Shadow tendrils extend outward, probing. Crouched at the edge of a rooftop, city lights reflecting below. "
            "A sense of contained power and sharp intelligence. "
            "Watchful, unreadable, quietly present expression. Ages 14-17. Square format, no text."
        ),
        'iron_golem': (
            "An ancient golem of immense stature and quiet dignity, in refined concept art style. "
            "Dark iron and volcanic stone, glowing amber rune lines tracing complex geometric patterns. "
            "Lichens and centuries of moss in every crevice. One massive hand extended, offering to carry something for you. "
            "Background: ruins of a great library being slowly reclaimed by forest. "
            "Timeless and immovable loyalty expression. Ages 14-17. Square format, no text."
        ),
        'void_sprite': (
            "A sprite at the edge between something and nothing, in refined concept art style. "
            "Form is pure cosmic void — deep space visible through a silhouette rimmed with teal bioluminescence. "
            "Stars drift through its body like slow-moving thoughts. Hovering at the event horizon of a small black hole. "
            "The vastness around it makes it seem paradoxically intimate. "
            "Ancient, unknowable, yet somehow deeply friendly expression. Ages 14-17. Square format, no text."
        ),
        'robin': (
            "A robin rendered with photorealistic detail and dramatic composition, in refined concept art style. "
            "Rich russet-red breast with individual feather detail. "
            "Perched on a weathered iron sword planted in mossy earth. "
            "Rain-soaked scene with a single ray of golden light. Background: ancient battlefield returning to nature. "
            "Resilient and hopeful expression. Ages 14-17. Square format, no text."
        ),
    },
    'adult': {
        'storm_hawk': (
            "A hawk that has become the storm itself, in fine art painterly style. "
            "Feathers are indistinguishable from lightning — the silhouette holds, but the substance shifts. "
            "Flying at the apex of a massive tempest, eye of the storm visible behind. "
            "Below, the world is turbulent. Here, there is only clarity. "
            "Expression of complete composure within chaos. Fine art quality, ages 18+. Square format, no text."
        ),
        'shadow_lynx': (
            "A lynx that exists at the threshold between seen and unseen, in fine art painterly style. "
            "Painted in deep shadow and golden negative space. Only the eyes are fully rendered — everything else bleeds into dark. "
            "The composition suggests presence without insisting on it. "
            "The feeling of being known by something that chooses not to reveal itself. "
            "Deeply still expression. Fine art quality, ages 18+. Square format, no text."
        ),
        'iron_golem': (
            "An iron golem in the late autumn of its existence, in fine art painterly style. "
            "Most of the iron has given way to moss, stone, and root. It is more garden than golem now. "
            "But the amber glow in the chest still burns steady. Sitting in the center of a forest that grew up around it. "
            "Small animals nest in the joints. Trees grow through the arms. "
            "Peaceful, patient, enduring expression. Fine art quality, ages 18+. Square format, no text."
        ),
        'void_sprite': (
            "A void sprite that has drifted long enough to become something almost like starlight, in fine art painterly style. "
            "The form is barely there — a suggestion of eyes, a warmth at the center that doesn't require a body. "
            "Painted as though you are not sure whether you are looking at a sprite or at a memory. "
            "Background of infinite dark space, a single distant galaxy visible. "
            "Expression of profound peace with uncertainty. Fine art quality, ages 18+. Square format, no text."
        ),
        'robin': (
            "A single robin perched on a weathered garden fence at dawn, in fine art painterly style reminiscent of classical naturalist painting. "
            "Every feather rendered with extraordinary detail. "
            "Warm morning light catches the red breast like a small flame of hope. Dew drops on the fence post. "
            "A cottage garden in soft bokeh behind. Simple, honest beauty. "
            "Contemplative and grounding. Fine art quality, ages 18+. Square format, no text."
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
                safety_filter_level='block_only_high',
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
                # robin is referenced as .jpg in companion_selector_step.dart
                ext = 'jpg' if char_name == 'robin' else 'png'
                out = COMPANIONS_DIR / band / f'{char_name}.{ext}'
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
