"""
Compress age_band_assets/ images in-place using Pillow.
- PNGs: 256-colour quantisation (lossy, typically 50-70% smaller)
- JPGs: already well-compressed, skipped unless > 400 KB
Skips older_adolescents/ and toddlers/ (not used by the app).
"""
import os
import sys
from pathlib import Path
from PIL import Image

SKIP_BANDS = {"older_adolescents", "toddlers"}
ROOT = Path(__file__).parent.parent / "age_band_assets"

JPG_QUALITY = 78   # re-encode only if big
JPG_RECOMPRESS_ABOVE_KB = 400
PNG_COLORS = 256   # quantise to palette

total_before = 0
total_after = 0
count = 0

for img_path in sorted(ROOT.rglob("*")):
    if not img_path.is_file():
        continue
    band = img_path.parts[img_path.parts.index("age_band_assets") + 1]
    if band in SKIP_BANDS:
        continue
    if img_path.suffix.lower() not in (".jpg", ".jpeg", ".png"):
        continue

    size_before = img_path.stat().st_size
    total_before += size_before

    try:
        img = Image.open(img_path)

        if img_path.suffix.lower() in (".jpg", ".jpeg"):
            # Only re-encode large JPGs — most are already small
            if size_before > JPG_RECOMPRESS_ABOVE_KB * 1024:
                if img.mode in ("RGBA", "P"):
                    img = img.convert("RGB")
                img.save(img_path, "JPEG", quality=JPG_QUALITY, optimize=True, progressive=True)
            # else leave as-is

        else:  # PNG
            has_alpha = img.mode in ("RGBA", "LA") or (
                img.mode == "P" and "transparency" in img.info
            )
            if has_alpha:
                # RGBA requires FASTOCTREE — MEDIANCUT doesn't support alpha
                quantised = img.convert("RGBA").quantize(
                    colors=PNG_COLORS, method=Image.Quantize.FASTOCTREE
                )
                quantised.save(img_path, "PNG", optimize=True)
            else:
                quantised = img.convert("RGB").quantize(
                    colors=PNG_COLORS, method=Image.Quantize.MEDIANCUT
                )
                quantised.save(img_path, "PNG", optimize=True)

        size_after = img_path.stat().st_size
        total_after += size_after
        count += 1
        reduction = (1 - size_after / size_before) * 100
        rel = img_path.relative_to(ROOT.parent)
        print(f"  {rel}  {size_before//1024}KB -> {size_after//1024}KB  ({reduction:.0f}%)")
    except Exception as e:
        print(f"  SKIP {img_path.name}: {e}", file=sys.stderr)
        total_after += size_before

if total_before > 0:
    print(f"\n{count} files | {total_before/1024/1024:.1f} MB -> {total_after/1024/1024:.1f} MB"
          f"  ({(1 - total_after/total_before)*100:.0f}% reduction)")
