"""
Generate all image assets for the Toddlers (2-4) age band.
Targets: age_band_assets/toddlers/
Style: Warm flat cartoon — chunky outlines, bold fills, plush-toy aesthetic.
Therapeutic app: NO darkness, NO weapons, NO harsh tones. Warm and safe only.
"""

import os
import time
import logging
from pathlib import Path
from google import genai
from google.genai import types
from dotenv import load_dotenv

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

dotenv_path = Path('backend/.env')
if dotenv_path.exists():
    load_dotenv(dotenv_path=dotenv_path)
else:
    load_dotenv()

GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
if not GEMINI_API_KEY:
    logger.error("No GEMINI_API_KEY found in environment or .env file.")
    exit(1)

client = genai.Client(api_key=GEMINI_API_KEY)
MODEL_NAME = 'models/imagen-4.0-generate-001'


def generate_image(prompt, output_path, format='PNG', force_black_bg=False):
    output_path = Path(output_path)

    if output_path.exists() and output_path.stat().st_size > 1024:
        logger.info(f"Skipping {output_path} (already exists)")
        return True

    if force_black_bg:
        prompt = (
            f"{prompt} -- THE CHARACTER/ELEMENT MUST BE ISOLATED ON A PURE SOLID BLACK "
            "BACKGROUND. NO SCENERY. NO FLOOR. NO SHADOWS ON THE BACKGROUND. PURE BLACK #000000 ONLY."
        )

    while True:
        try:
            logger.info(f"Generating: {output_path}")
            mime_type = 'image/png' if format == 'PNG' else 'image/jpeg'
            response = client.models.generate_images(
                model=MODEL_NAME,
                prompt=prompt,
                config=types.GenerateImagesConfig(
                    number_of_images=1,
                    output_mime_type=mime_type
                )
            )
            if response.generated_images:
                image_bytes = response.generated_images[0].image.image_bytes
                output_path.parent.mkdir(parents=True, exist_ok=True)
                with open(output_path, 'wb') as f:
                    f.write(image_bytes)
                logger.info(f"Saved: {output_path}")
                return True
            else:
                logger.error(f"No image returned for: {output_path.name}")
                return False
        except Exception as e:
            err = str(e)
            if '429' in err or 'Too Many Requests' in err:
                logger.warning("Rate limited — waiting 60s...")
                time.sleep(60)
                continue
            elif '403' in err and 'billing' in err.lower():
                logger.error("Billing not enabled. Cannot use Imagen API.")
                return "STOP"
            else:
                logger.error(f"Error generating {output_path.name}: {e}")
                time.sleep(10)
                return False


def main():
    base_dir = Path("age_band_assets/toddlers")

    # Shared style anchor — warm flat cartoon, plush toy feel, child-safe
    S = (
        "Warm flat children's book digital illustration. "
        "Thick rounded outlines, bold flat colour fills, soft plush-toy aesthetic. "
        "Maximum four colours per asset. Child-safe, therapeutic app for ages 2-4. "
        "No violence, no darkness, no weapons, no frightening imagery. "
        "Colours: golden yellow #FFD700, coral pink #FF6B6B, sky teal #7ECECE, "
        "warm cream #FFF8F0, soft lavender #D4C5F9, deep plum #3D2C6E."
    )

    # fmt: off
    # (subfolder, filename, prompt, format, force_black_bg)
    assets = [

        # ── BACKGROUNDS ─────────────────────────────────────────────────────────
        ("backgrounds", "splash_bg.jpg",
         f"{S} Full-bleed portrait background. Sky fades from soft golden peach at "
         "the bottom to pale lavender blue at the top. One large friendly glowing "
         "golden star in the centre with a gentle radial glow. Tiny rounded stars "
         "scattered sparingly in the upper half. Soft rolling cream hill silhouette "
         "along the bottom edge. No characters, no text, no more than three colours.",
         "JPEG", False),

        ("backgrounds", "story_page_bg.jpg",
         f"{S} Full-bleed portrait background. Soft warm cream to pale peach gradient "
         "top to bottom. Rolling meadow silhouette in slightly darker warm cream along "
         "the very bottom. Three or four faint golden stars in the very top corners "
         "at low opacity. Nothing else — blank storybook page feel. No patterns, "
         "no characters, no text.",
         "JPEG", False),

        ("backgrounds", "feelings_bg.jpg",
         f"{S} Full-bleed portrait background for an emotion-selection screen. "
         "Upper half: pale lavender blue sky with a few small soft white cloud puffs. "
         "Lower half: rolling warm cream hill silhouette. Scattered across the "
         "midground: six to eight tiny floating rounded heart shapes in coral pink "
         "and golden yellow. Very minimal. No characters, no text.",
         "JPEG", False),

        # ── UI ELEMENTS ──────────────────────────────────────────────────────────
        ("ui", "app_logo.png",
         f"{S} Wide horizontal badge. Thick rounded plum-purple border on a warm cream "
         "background. Inside: a large cartoonish open storybook, thick rounded corners, "
         "warm yellow cover, glowing golden star bursting from the open pages. Words "
         "STORY WEAVER in large ultra-rounded white letterforms with a gentle plum "
         "drop shadow below the book. Friendly and toy-like. Transparent background "
         "outside the badge border.",
         "PNG", False),

        ("ui", "name_input_frame.png",
         f"{S} Wide rounded-rectangle frame for a text input field. Thick bubbly golden "
         "yellow border with a soft white inner highlight. Small sparkle star shapes "
         "at each corner. Interior: very soft translucent warm cream. Feels like a "
         "golden ticket border or gift tag. No text, no characters. Transparent "
         "background outside the frame.",
         "PNG", True),

        ("ui", "make_magic_normal.png",
         f"{S} Very wide rounded-rectangle button. Flat warm golden yellow face. Thick "
         "bubbly soft plum-purple border. Words MAKE MAGIC in large ultra-rounded bold "
         "white letters centred on the face with a gentle plum drop shadow. Three small "
         "cartoon sparkle stars around the letters: two left, one right. Cheerful and "
         "exciting. Transparent background.",
         "PNG", True),

        ("ui", "make_magic_pressed.png",
         f"{S} Same MAKE MAGIC button as the normal state but physically pressed down: "
         "golden face darkened fifteen percent, border thinner and no outer glow, "
         "sparkle stars compressed inward toward the centre, letters slightly smaller. "
         "Inner shadow replaces outer border highlight. Transparent background.",
         "PNG", True),

        ("ui", "continue_button.png",
         f"{S} Large rounded-square button filled with flat sky teal. Large bold white "
         "right-pointing chevron arrow centred on the face. Thick soft plum shadow on "
         "the bottom and right edges. No text. Minimal and immediately readable. "
         "Transparent background.",
         "PNG", True),

        ("ui", "age_tile_2.png",
         f"{S} Large square tile, very rounded corners, flat warm coral pink face. "
         "Single large bold rounded numeral 2 in white with a soft plum drop shadow "
         "centred on the face. Subtle thick shadow on the bottom and right edges like "
         "a foam block. No gradients on the face. Transparent background.",
         "PNG", True),

        ("ui", "age_tile_3.png",
         f"{S} Large square tile, very rounded corners, flat warm coral pink face. "
         "Single large bold rounded numeral 3 in white with a soft plum drop shadow "
         "centred on the face. Subtle thick shadow on the bottom and right edges like "
         "a foam block. No gradients on the face. Transparent background.",
         "PNG", True),

        ("ui", "age_tile_4.png",
         f"{S} Large square tile, very rounded corners, flat warm coral pink face. "
         "Single large bold rounded numeral 4 in white with a soft plum drop shadow "
         "centred on the face. Subtle thick shadow on the bottom and right edges like "
         "a foam block. No gradients on the face. Transparent background.",
         "PNG", True),

        ("ui", "choice_button.png",
         f"{S} Wide rounded-rectangle story-choice button, flat warm coral pink face. "
         "Small golden star icon centred on the left side of the interior. Right side "
         "has open space for text. Thick plum border. Soft plum shadow below "
         "suggesting it floats. Transparent background.",
         "PNG", True),

        # ── PROGRESS ORBS ────────────────────────────────────────────────────────
        ("orbs", "progress_idle.png",
         f"{S} Perfect circle orb. Flat light lavender-gray fill. Thin soft plum "
         "outline. No glow, no shine, no sparkle. Quiet and waiting. "
         "Transparent background.",
         "PNG", True),

        ("orbs", "progress_active.png",
         f"{S} Perfect circle orb. Flat warm golden yellow fill. Medium-weight plum "
         "outline. Single small white four-point star highlight in the upper-left "
         "quadrant. Glowing with warmth. Transparent background.",
         "PNG", True),

        ("orbs", "progress_done.png",
         f"{S} Perfect circle orb. Flat sky teal fill. Simple bold white checkmark "
         "centred inside. Medium-weight plum outline. Two tiny white sparkle stars "
         "outside the orb: one upper-right, one lower-left. Transparent background.",
         "PNG", True),

        # ── FEELINGS BUTTONS ─────────────────────────────────────────────────────
        ("feelings", "happy.png",
         f"{S} Large circle button, flat golden yellow background. Simple cartoon "
         "circular face: plum eyes curved upward in a wide smile, small rounded white "
         "teeth, rosy pink circles on each cheek. Label HAPPY below the face in deep "
         "plum ultra-rounded bold text. Thick plum border. Transparent background. "
         "No body, hair, or accessories on the face.",
         "PNG", True),

        ("feelings", "sad.png",
         f"{S} Large circle button, flat soft blue background. Simple cartoon "
         "circular face: downward-curved plum eyebrows, downward-curved closed eyes, "
         "small downturned mouth, single simplified teardrop on one cheek. Label SAD "
         "below the face. Thick plum border. Transparent background. Gentle sadness "
         "only — no frightening elements.",
         "PNG", True),

        ("feelings", "angry.png",
         f"{S} Large circle button, flat warm orange background. Simple cartoon "
         "circular face: thick angled V-shaped plum eyebrows, small tight-lipped "
         "frown. Expression reads as firmly grumpy, not threatening. Label ANGRY "
         "below. Thick plum border. Transparent background. No violent imagery.",
         "PNG", True),

        ("feelings", "scared.png",
         f"{S} Large circle button, flat soft lavender background. Simple cartoon "
         "circular face: wide open circular eyes with small pupils, slightly raised "
         "eyebrows, small oval open mouth expressing mild startled surprise. Mild "
         "startled expression only — not terrified. Label SCARED below. Thick plum "
         "border. Transparent background. No horror elements.",
         "PNG", True),

        ("feelings", "surprised.png",
         f"{S} Large circle button, flat sky teal background. Simple cartoon circular "
         "face: raised semicircle eyebrows, large open circular O-shaped mouth, wide "
         "circular eyes. Label SURPRISED below. Thick plum border. Transparent "
         "background.",
         "PNG", True),

        ("feelings", "calm.png",
         f"{S} Large circle button, flat soft mint green background. Simple cartoon "
         "circular face: gently closed or half-closed eyes, soft relaxed slight smile, "
         "smooth relaxed eyebrows. Peaceful quality. Label CALM below. Thick plum "
         "border. Transparent background.",
         "PNG", True),

        ("feelings", "excited.png",
         f"{S} Large circle button, flat coral pink background. Simple cartoon circular "
         "face: wide sparkly eyes with small star highlights, raised eyebrows, very "
         "wide open smile. Entire face radiates energy. Label EXCITED below. Thick "
         "plum border. Transparent background.",
         "PNG", True),

        ("feelings", "confused.png",
         f"{S} Large circle button, flat warm yellow background. Simple cartoon "
         "circular face: one raised eyebrow and one lowered eyebrow, face tilted "
         "slightly to one side, small lopsided mouth. Tiny simple question mark "
         "floating above the head. Label CONFUSED below. Thick plum border. "
         "Transparent background.",
         "PNG", True),

        # ── ARCHETYPE CARDS ──────────────────────────────────────────────────────
        # Each card: portrait rounded-rectangle, distinct warm skin tone per card,
        # large round cartoon head, big joyful eyes, tiny body.
        ("archetypes", "brave_hero.jpg",
         f"{S} Portrait-format rounded-rectangle card, warm peach gradient background. "
         "Large simple cartoon character: oversized round head, big joyful eyes, warm "
         "brown skin, tiny body. Wearing a simple red cape, holding a small golden "
         "star-tipped wand. Triumphant pose, arms raised. Label BRAVE HERO below in "
         "deep plum ultra-rounded text. Thick plum border. No background detail beyond "
         "the gradient.",
         "JPEG", False),

        ("archetypes", "kind_healer.jpg",
         f"{S} Portrait-format rounded-rectangle card, soft mint green gradient "
         "background. Large simple cartoon character: oversized round head, soft gentle "
         "eyes, golden skin tone, tiny body. Wearing a simple white tunic, holding a "
         "glowing golden heart. Small soft sparkle shapes floating around the character. "
         "Label KIND HEALER below in deep plum ultra-rounded text. Thick plum border.",
         "JPEG", False),

        ("archetypes", "clever_inventor.jpg",
         f"{S} Portrait-format rounded-rectangle card, warm sky blue gradient background. "
         "Large simple cartoon character: big round head, wide curious eyes, small round "
         "glasses, olive skin tone, tiny body. Holding a large cartoonish golden gear. "
         "Label CLEVER INVENTOR below in deep plum ultra-rounded text. Thick plum border. "
         "No complex machinery.",
         "JPEG", False),

        ("archetypes", "speedy_explorer.jpg",
         f"{S} Portrait-format rounded-rectangle card, warm yellow gradient background. "
         "Large simple cartoon character: big round head, bright eyes, rich dark skin "
         "tone, tiny body. Simple green jacket and wide-brimmed hat. Holding a small "
         "golden compass. Label SPEEDY EXPLORER below in deep plum ultra-rounded text. "
         "Thick plum border.",
         "JPEG", False),

        ("archetypes", "mighty_guardian.jpg",
         f"{S} Portrait-format rounded-rectangle card, soft lavender gradient background. "
         "Large simple cartoon character: big round head, strong determined eyes, medium "
         "warm skin tone, tiny body. Holding a round rainbow-coloured shield with flat "
         "bold concentric circles. Label MIGHTY GUARDIAN below in deep plum ultra-rounded "
         "text. Thick plum border.",
         "JPEG", False),

        ("archetypes", "gentle_dreamer.jpg",
         f"{S} Portrait-format rounded-rectangle card, soft pink-to-lavender gradient "
         "background. Large simple cartoon character: big round head, dreamy half-closed "
         "eyes, light warm skin tone, tiny body. Holding a small glowing crescent moon. "
         "Tiny soft stars drifting around the character. Label GENTLE DREAMER below in "
         "deep plum ultra-rounded text. Thick plum border.",
         "JPEG", False),

        # ── COMPANIONS ───────────────────────────────────────────────────────────
        ("companions", "fluffy_dragon.png",
         f"{S} Portrait-format rounded-rectangle card, soft green gradient background. "
         "Large simple cartoon baby dragon: round oversized head, big sweet eyes, tiny "
         "stubby wings, curly tail. Lavender-purple with soft green spots and a warm "
         "golden tummy. Joyful and cuddly expression. Label FLUFFY DRAGON below in "
         "deep plum ultra-rounded text. Thick plum border. Transparent background "
         "outside the card.",
         "PNG", False),

        ("companions", "tiny_fairy.png",
         f"{S} Portrait-format rounded-rectangle card, soft pink gradient background. "
         "Large simple cartoon fairy: big round head, huge sparkly eyes, simple rounded "
         "wings of soft golden light, tiny body in a simple lavender dress. Holding a "
         "small wand with a glowing star tip. Label TINY FAIRY below in deep plum "
         "ultra-rounded text. Thick plum border. Transparent background outside the card.",
         "PNG", False),

        ("companions", "magic_bunny.png",
         f"{S} Portrait-format rounded-rectangle card, soft sky blue gradient background. "
         "Large simple cartoon bunny: oversized round head, enormous soft floppy ears, "
         "big gentle eyes, tiny round body in a simple golden vest. Holding a tiny "
         "glowing crystal ball. Label MAGIC BUNNY below in deep plum ultra-rounded text. "
         "Thick plum border. Transparent background outside the card.",
         "PNG", False),

        ("companions", "shining_puppy.png",
         f"{S} Portrait-format rounded-rectangle card, warm yellow gradient background. "
         "Large simple cartoon puppy: big round head, floppy ears, enormous joyful eyes, "
         "small wagging tail. Simple teal bandana with a glowing golden star on the "
         "forehead. Label SHINING PUPPY below in deep plum ultra-rounded text. Thick "
         "plum border. Transparent background outside the card.",
         "PNG", False),
    ]
    # fmt: on

    logger.info(f"Starting toddlers band generation — {len(assets)} assets to generate")
    generated = 0
    skipped = 0
    failed = 0

    for subfolder, filename, prompt, fmt, black_bg in assets:
        output_path = base_dir / subfolder / filename
        result = generate_image(prompt, output_path, format=fmt, force_black_bg=black_bg)
        if result == "STOP":
            logger.error("Billing error — stopping early.")
            break
        elif result is True:
            if output_path.exists():
                generated += 1
            else:
                skipped += 1
        else:
            failed += 1
        time.sleep(20)

    logger.info(
        f"Toddlers generation complete — "
        f"generated/skipped: {generated} | failed: {failed}"
    )


if __name__ == "__main__":
    main()
