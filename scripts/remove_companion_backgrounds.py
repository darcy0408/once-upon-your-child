"""
Remove backgrounds from sprout companion images so they show as transparent PNGs.
This lets the UI's per-companion backgroundColor show through cleanly.

Usage:
    python scripts/remove_companion_backgrounds.py

Requires: pip install rembg Pillow
"""

from pathlib import Path
from rembg import remove
from PIL import Image
import io

SPROUT_DIR = Path("assets/images/companions/sprout")
COMPANIONS = ["fluffy_dragon", "magic_bunny", "shining_puppy", "robin"]


def process(name: str) -> None:
    src = SPROUT_DIR / f"{name}.png"
    if not src.exists():
        print(f"  SKIP  {src} (not found)")
        return

    print(f"  Processing {name}...", end=" ", flush=True)
    with open(src, "rb") as f:
        original = f.read()

    result = remove(original)

    # Verify the result is a valid PNG with transparency
    img = Image.open(io.BytesIO(result)).convert("RGBA")

    # Save back in-place (overwrite)
    img.save(src, "PNG")
    print(f"done  ({img.size[0]}x{img.size[1]})")


def main() -> None:
    print("Removing backgrounds from sprout companion images...")
    for name in COMPANIONS:
        process(name)
    print("Done! Rebuild the Flutter app to pick up the new images.")


if __name__ == "__main__":
    main()
