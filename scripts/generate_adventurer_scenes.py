"""
Generate Adventurer-band (9-11) scene-picker art via Imagen 4.0.

Fixes audit finding S-02 (audit-reports/age-review-choose-your-setting-adventurer-20260605.md):
the scene tiles share one flat asset set authored for the YOUNG bands, so the
Adventurer "Choose your setting" step reads ~2 years too young (picture-book
owl + ~5-6yo girl on the Imagine It card). This produces a band-specific set
tuned older: soft painterly magical-realism, cinematic, NO people (sidesteps
the babyish-child-face problem and Imagen person-gen limits), NO text.

Usage:
    python scripts/generate_adventurer_scenes.py            # all five
    python scripts/generate_adventurer_scenes.py --only imagine_it
    python scripts/generate_adventurer_scenes.py --dry-run
    python scripts/generate_adventurer_scenes.py --force    # overwrite existing

Reads the API key from the MAIN checkout's backend/.env (worktrees don't carry
the gitignored .env). Writes WebP (for the app) + a PNG preview (for review)
to assets/images/scenarios/adventurer/.
"""

import argparse
import io
import sys
import time
from pathlib import Path

from PIL import Image

# Worktree-safe: load the key from the canonical main checkout's backend/.env.
_MAIN_ENV = Path(r"C:\dev\story-weaver-app\backend\.env")
_THIS_REPO = Path(__file__).resolve().parent.parent
OUT_DIR = _THIS_REPO / "assets" / "images" / "scenarios" / "adventurer"

MODEL = "models/imagen-4.0-generate-001"

# Shared style spine so the five tiles read as one set, aged up for 9-11.
_STYLE = (
    "Soft painterly magical-realism, cinematic depth, gentle rim-light, rich "
    "atmospheric color. Full-bleed scene with a noticeably darker lower third "
    "so a caption stays legible over it. Adventurous and awe-inspiring, NOT "
    "cute or toddler-ish. Absolutely no people, no faces, no characters. "
    "Absolutely no text, letters, words, numbers, signs, or labels anywhere "
    "in the image. 16:9 landscape."
)

PROMPTS = {
    # "The Land of Vanishing Colors" — someone is erasing the world; paint it back.
    "vanishing_colors": (
        "An epic sweeping fantasy vista where a grey, drained, colorless half of "
        "the land is being flooded back to life with vivid color — ribbons and "
        "rivers of luminous paint-light surging across hills, restoring saturated "
        "blues, golds and magentas as they go. A clear dramatic boundary between "
        "the desaturated world and the rescued color. Sense of stakes and wonder. "
        + _STYLE
    ),
    # "The Crystal Cavern of Echoes" — echoes steal voices; speak in whispers.
    "crystal_cavern": (
        "A vast cathedral-scale underground crystal cavern, deep and luminous, "
        "with towering glowing resonant crystals in teal and violet, faint "
        "concentric shimmer-rings rippling through the air like visible echoes. "
        "Mysterious, hushed, awe-inspiring scale. Cool glow with warm amber "
        "accents deep in the tunnels. " + _STYLE
    ),
    # "The Volcano of Sleeping Dragons" — wake the kindest dragon before it erupts.
    "volcano_dragons": (
        "A majestic dusk landscape of a great smoldering volcano, with an "
        "enormous noble dragon curled asleep around the mountainside, scales "
        "catching warm ember light, faint smoke drifting from the crater. "
        "Grand and a little perilous but not frightening — the dragon is "
        "serene and magnificent, not a cartoon. Deep twilight blues with molten "
        "amber glow. " + _STYLE
    ),
    # "Life Quest" — ride worry and anger like waves (figureless emotional mastery).
    "big_feelings_quest": (
        "A symbolic emotional-mastery seascape: a single small steady rock-island "
        "holding firm amid great rolling storm-clouds and swelling teal waves, "
        "with a hopeful warm sunbreak opening through the clouds and calm water "
        "spreading outward from the rock. Conveys staying steady while big "
        "feelings pass — hopeful and in-control, never distressed. Slate-blue and "
        "teal with amber sunlight. " + _STYLE
    ),
    # "Imagine It" — describe any world you can dream up (replaces the young-girl card).
    "imagine_it": (
        "A wide-open imaginative dreamscape signalling 'you invent the world': "
        "floating islands, a glowing doorway of light, drifting constellations and "
        "half-formed sketch-line worlds materializing into full color, aurora "
        "ribbons overhead. Boundless, adventurous, full of possibility. Deep "
        "indigo and violet base with warm gold and aurora accents. " + _STYLE
    ),
}


def _load_keys() -> list[str]:
    keys: list[str] = []
    if _MAIN_ENV.exists():
        for line in _MAIN_ENV.read_text(encoding="utf-8", errors="ignore").splitlines():
            line = line.strip()
            for name in ("GEMINI_API_KEY", "GOOGLE_API_KEY_2", "GOOGLE_API_KEY_3", "GOOGLE_API_KEY_4"):
                if line.startswith(name + "="):
                    val = line.split("=", 1)[1].strip().strip('"').strip("'")
                    if val:
                        keys.append(val)
    # de-dup, preserve order
    seen = set()
    out = []
    for k in keys:
        if k not in seen:
            seen.add(k)
            out.append(k)
    return out


def _generate_one(keys: list[str], prompt: str) -> bytes:
    """Try each key on quota error; return PNG bytes of the first image."""
    from google import genai
    from google.genai import types

    last_exc = None
    for key in keys:
        client = genai.Client(api_key=key)
        try:
            resp = client.models.generate_images(
                model=MODEL,
                prompt=prompt,
                config=types.GenerateImagesConfig(
                    number_of_images=1,
                    aspect_ratio="16:9",
                    safety_filter_level="block_low_and_above",
                    person_generation="dont_allow",
                ),
            )
            if not resp.generated_images:
                raise RuntimeError("no images returned")
            return resp.generated_images[0].image.image_bytes
        except Exception as e:  # noqa: BLE001
            msg = str(e).lower()
            if "429" in str(e) or "quota" in msg or "exhausted" in msg or "resource_exhausted" in msg:
                print("    (quota on this key, rotating...)")
                last_exc = e
                continue
            raise
    raise last_exc or RuntimeError("all keys exhausted")


def run(args):
    keys = _load_keys()
    if not keys:
        print(f"ERROR: no API keys found in {_MAIN_ENV}")
        sys.exit(1)
    print(f"Loaded {len(keys)} API key(s). Output -> {OUT_DIR}")
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    targets = {args.only: PROMPTS[args.only]} if args.only else PROMPTS
    ok = 0
    for name, prompt in targets.items():
        webp = OUT_DIR / f"{name}.webp"
        png = OUT_DIR / f"{name}.png"
        if webp.exists() and not args.force:
            print(f"  SKIP (exists): {name}.webp")
            continue
        if args.dry_run:
            print(f"  WOULD GENERATE: {name}")
            continue
        print(f"  Generating {name} ...", end="", flush=True)
        try:
            png_bytes = _generate_one(keys, prompt)
            with Image.open(io.BytesIO(png_bytes)) as img:
                img = img.convert("RGB")
                img.thumbnail((1280, 1280), Image.Resampling.LANCZOS)
                img.save(webp, format="WEBP", quality=88, method=6)
                img.save(png, format="PNG")  # review-only preview
            print(f" OK ({webp.stat().st_size // 1024}KB webp)")
            ok += 1
            time.sleep(1)
        except Exception as e:  # noqa: BLE001
            print(f" ERROR: {e}")

    if not args.dry_run:
        print(f"\nDone. Generated {ok} image(s).")
        print("Review the .png previews, then the .webp files feed the app.")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Generate Adventurer scene-picker art (Imagen 4.0)")
    p.add_argument("--only", choices=list(PROMPTS.keys()), help="generate just one tile")
    p.add_argument("--force", action="store_true", help="overwrite existing files")
    p.add_argument("--dry-run", action="store_true", help="list without generating")
    run(p.parse_args())
