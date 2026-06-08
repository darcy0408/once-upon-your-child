"""
Generate mature-band (Creator 12-14, Adolescent 15-17, Adult 18+) scene-picker
art via Imagen 4.0 — extends the Adventurer S-02 fix to the older bands.

Same problem as Adventurer: the scene-picker tiles shared one flat asset set
authored for the YOUNG bands, so the mature "Choose your setting" step reads
far too young (a 13-year-old sees the picture-book owl / ~5-6yo girl card as
babyish and disengages — audit band-shift check). This produces a distinct,
theme-tuned set per mature band, matching each band's visual identity AND the
introspective mature framing of the scenarios (e.g. vanishing_colors is
"The Fading Realm — what would you save if everything faded?", not a literal
rainbow). Textless, no babyish anything, no people, 16:9.

Per-band aesthetics (mirrors the companion-art escalation):
  creator     — clean editorial / dark-mode, polished contemporary digital art
  adolescent  — cinematic dark, teal accent, film-still atmosphere
  adult       — refined minimal, warm amber, fine-art painterly restraint

Usage:
    python scripts/generate_mature_scenes.py                       # all 15
    python scripts/generate_mature_scenes.py --band adult          # one band
    python scripts/generate_mature_scenes.py --band creator --only imagine_it
    python scripts/generate_mature_scenes.py --dry-run
    python scripts/generate_mature_scenes.py --force
"""

import argparse
import io
import sys
import time
from pathlib import Path

from PIL import Image

_MAIN_ENV = Path(r"C:\dev\story-weaver-app\backend\.env")
_THIS_REPO = Path(__file__).resolve().parent.parent
SCENARIOS_DIR = _THIS_REPO / "assets" / "images" / "scenarios"

MODEL = "models/imagen-4.0-generate-001"

# Universal constraints appended to every prompt.
_COMMON = (
    "Full-bleed landscape scene with a noticeably darker lower third so a "
    "caption stays legible over it. Absolutely no people, no faces, no "
    "characters. Absolutely no text, letters, words, numbers, signs or labels "
    "anywhere in the image. Nothing cute, toddler-ish, or childish. 16:9 "
    "landscape."
)

# Per-band visual identity (the "how it's rendered" layer).
_BAND_STYLE = {
    "creator": (
        "Style: clean contemporary editorial illustration with a dark-mode "
        "sensibility — confident graphic composition, refined limited palette, "
        "crisp modern digital art, a little bold and stylish. Sophisticated and "
        "identity-forward, made for a 12-14 year old, never childish."
    ),
    "adolescent": (
        "Style: cinematic film-still atmosphere, moody and dramatic — deep "
        "shadows, volumetric light, teal and cyan accents against dark tones, "
        "emotionally evocative and introspective, high production value. Made "
        "for a 15-17 year old."
    ),
    "adult": (
        "Style: refined minimalist fine-art painterly illustration — restrained "
        "composition, generous negative space, contemplative mood, warm amber "
        "light against muted tones, quiet and symbolic, gallery quality. Made "
        "for an adult."
    ),
}

# Per-scene concept (the "what it depicts" layer), pitched at the mature,
# introspective framing the older bands use for each scenario.
_SCENE_CONCEPT = {
    # The Fading Realm — "what would you save if everything faded?"
    "vanishing_colors": (
        "A vast landscape slowly dissolving into colorless ash and greyscale, "
        "the world fading at its edges, with a single small held point of warm "
        "living color persisting at the heart of it — a memory worth keeping "
        "against the fade. Themes of loss and what we choose to preserve."
    ),
    # The Resonance Caverns / The Echo Inside — "what have you been telling yourself?"
    "crystal_cavern": (
        "A vast, still underground cavern of luminous resonant crystals, with "
        "sound made visible as concentric rings of light rippling outward and a "
        "mirror-calm pool reflecting it all back — an inner echo chamber. "
        "Introspective, hushed, profound scale."
    ),
    # The Dragon's Lair / What Wakes the Fire Inside — "what wakes the fire inside?"
    "volcano_dragons": (
        "A dormant volcanic mountain at dusk with banked embers glowing deep "
        "within its caldera and the immense coiled silhouette of a sleeping "
        "dragon merged into the rock — power and fire held in reserve, waiting "
        "to wake. Brooding, majestic, charged with latent energy."
    ),
    # The Stormrunner Citadel — "what storm are you running from?"
    "big_feelings_quest": (
        "A lone resolute citadel-lighthouse on a rocky promontory facing a vast "
        "approaching storm, with a break of hopeful light on the horizon and "
        "calm water at the tower's base — standing your ground as the storm of "
        "feeling passes, rather than running from it. Steady, hopeful, never "
        "bleak."
    ),
    # Imagine It — boundless authorship / creation
    "imagine_it": (
        "A boundless creative void where new worlds form out of pure thought — "
        "drifting fragments of landscapes, floating geometry and constellations "
        "assembling from light into fully realized terrain, a sense of a blank "
        "canvas becoming a cosmos. Authorship, possibility, limitless invention."
    ),
}

BANDS = list(_BAND_STYLE.keys())
SCENES = list(_SCENE_CONCEPT.keys())


def _prompt(band: str, scene: str) -> str:
    return f"{_SCENE_CONCEPT[scene]} {_BAND_STYLE[band]} {_COMMON}"


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
    seen = set()
    out = []
    for k in keys:
        if k not in seen:
            seen.add(k)
            out.append(k)
    return out


def _generate_one(keys: list[str], prompt: str) -> bytes:
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
    print(f"Loaded {len(keys)} API key(s).")

    bands = [args.band] if args.band else BANDS
    scenes = [args.only] if args.only else SCENES
    ok = 0
    for band in bands:
        out_dir = SCENARIOS_DIR / band
        out_dir.mkdir(parents=True, exist_ok=True)
        print(f"\n=== {band.upper()} -> {out_dir} ===")
        for scene in scenes:
            webp = out_dir / f"{scene}.webp"
            png = out_dir / f"{scene}.png"
            if webp.exists() and not args.force:
                print(f"  SKIP (exists): {scene}.webp")
                continue
            if args.dry_run:
                print(f"  WOULD GENERATE: {band}/{scene}")
                continue
            print(f"  Generating {scene} ...", end="", flush=True)
            try:
                png_bytes = _generate_one(keys, _prompt(band, scene))
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


if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Generate mature-band scene-picker art (Imagen 4.0)")
    p.add_argument("--band", choices=BANDS, help="only this band")
    p.add_argument("--only", choices=SCENES, help="only this scene")
    p.add_argument("--force", action="store_true", help="overwrite existing files")
    p.add_argument("--dry-run", action="store_true", help="list without generating")
    run(p.parse_args())
