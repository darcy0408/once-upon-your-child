"""
Generate assets/images/hero_placeholder.webp — the fallback avatar.

Why this exists: three screens referenced 'assets/images/hero_placeholder.jpg'
through a raw AssetImage, but the file had never been committed, so the fallback
path threw instead of showing anything.

Why it is a star and not a person: the call sites are small CircleAvatars
standing in for a hero whose avatar is missing or failed to decode. The wizard's
own comment is explicit that these surfaces must never show a real or fake child
photo, and the scene-art pipeline has no way to enforce "no people" any more
(person_generation is Vertex-only). Drawing a non-person emblem locally sidesteps
both problems and costs nothing to regenerate.

Palette matches the deep-purple avatar backdrop already used at the call site
(0xFF3A2363) with the gold accent the app pairs with it.

Usage:
    python scripts/generate_hero_placeholder.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "images" / "hero_placeholder.webp"

SIZE = 512
SS = 4  # supersample factor; drawn big, then reduced for clean antialiased edges

BG_CENTER = (74, 43, 122)  # lifted purple, reads as a glow behind the emblem
BG_EDGE = (36, 21, 64)  # deep purple, close to the 0xFF3A2363 backdrop
GOLD = (232, 196, 104)
GOLD_SOFT = (150, 122, 62)


def _radial_background(size: int) -> Image.Image:
    """Vertical-ish radial gradient, painted as concentric circles."""
    img = Image.new("RGB", (size, size), BG_EDGE)
    d = ImageDraw.Draw(img)
    cx = cy = size / 2
    max_r = size * 0.72
    steps = 160
    for i in range(steps, 0, -1):
        t = i / steps
        r = max_r * t
        colour = tuple(
            round(BG_EDGE[c] + (BG_CENTER[c] - BG_EDGE[c]) * (1 - t) ** 1.6)
            for c in range(3)
        )
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=colour)
    return img


def _star_points(cx: float, cy: float, outer: float, inner: float, n: int = 5):
    import math

    pts = []
    for i in range(n * 2):
        r = outer if i % 2 == 0 else inner
        # -90° so a point faces up.
        a = math.radians(i * (360 / (n * 2)) - 90)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def main() -> None:
    size = SIZE * SS
    img = _radial_background(size)
    d = ImageDraw.Draw(img)
    cx = cy = size / 2

    # Thin ring, so the emblem still reads as deliberate when cropped to a circle.
    ring_r = size * 0.375
    d.ellipse(
        [cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r],
        outline=GOLD_SOFT,
        width=int(size * 0.012),
    )

    # Soft halo behind the star.
    for i in range(18, 0, -1):
        t = i / 18
        r = size * (0.20 + 0.10 * t)
        shade = tuple(
            round(BG_CENTER[c] + (GOLD_SOFT[c] - BG_CENTER[c]) * (1 - t) * 0.30)
            for c in range(3)
        )
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=shade)

    d.polygon(_star_points(cx, cy, size * 0.235, size * 0.098), fill=GOLD)

    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, format="WEBP", quality=92, method=6)
    print(f"wrote {OUT}  {SIZE}x{SIZE}  {OUT.stat().st_size // 1024}KB")


if __name__ == "__main__":
    main()
