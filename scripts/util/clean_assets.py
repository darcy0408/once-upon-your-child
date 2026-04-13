#!/usr/bin/env python
"""Clean checkerboard artifacts from UI PNG assets.

Primary behavior:
- Removes faux transparency checker colors (~#e0e0e0 and #ffffff) with tolerance.
- Uses checker-pattern detection + edge-connected masking to avoid deleting true highlights.
- Applies selective alpha feathering to soften jagged removal edges.
- Applies a hard pill alpha mask for Make Magic button assets.

Usage:
  python clean_assets.py
  python clean_assets.py --tolerance 10 --alpha-blur 1.5
  python clean_assets.py --input-dir assets/images/ui/glassy --in-place
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# Requested target aliases mapped to repo filenames.
TARGET_ALIASES = {
    "progress_check.png": "progress_active_orb.png",
    "progress_check_done.png": "progress_done_orb.png",
    "mode_tales.png": "tales_orb.png",
    "mode_rhyme.png": "rhyme_time_orb.png",
    "mode_read.png": "easy_read_orb.png",
    "mode_path.png": "pick_path_orb.png",
    "duration_quick.png": "quick_orb.png",
    "duration_classic.png": "classic_orb.png",
    "duration_epic.png": "epic_orb.png",
    "btn_make_magic.png": "make_magic_button.png",
}

DEFAULT_INPUT_DIR = Path("assets/images/ui/glassy")
DEFAULT_OUTPUT_DIR = Path("assets/images/ui/clean")
CHECKER_COLORS = np.array([[224, 224, 224], [255, 255, 255]], dtype=np.int16)


@dataclass
class CleanStats:
    path: Path
    removed_pixels: int
    total_pixels: int
    alpha_pixels_after: int


def _dilate_mask(mask: np.ndarray, size: int = 5) -> np.ndarray:
    mask_img = Image.fromarray((mask.astype(np.uint8) * 255), mode="L")
    dilated = mask_img.filter(ImageFilter.MaxFilter(size=size))
    return np.array(dilated) > 0


def _edge_connected_components(mask: np.ndarray) -> np.ndarray:
    """Return mask of True pixels connected to any image edge (4-connectivity)."""
    h, w = mask.shape
    visited = np.zeros_like(mask, dtype=bool)

    edge_points = []
    if h == 0 or w == 0:
        return visited

    xs = np.arange(w)
    ys = np.arange(h)

    top = np.column_stack([np.zeros_like(xs), xs])
    bottom = np.column_stack([np.full_like(xs, h - 1), xs])
    left = np.column_stack([ys, np.zeros_like(ys)])
    right = np.column_stack([ys, np.full_like(ys, w - 1)])

    for y, x in np.vstack([top, bottom, left, right]):
        if mask[y, x] and not visited[y, x]:
            edge_points.append((int(y), int(x)))

    for sy, sx in edge_points:
        stack = [(sy, sx)]
        visited[sy, sx] = True
        while stack:
            y, x = stack.pop()
            if y > 0 and mask[y - 1, x] and not visited[y - 1, x]:
                visited[y - 1, x] = True
                stack.append((y - 1, x))
            if y + 1 < h and mask[y + 1, x] and not visited[y + 1, x]:
                visited[y + 1, x] = True
                stack.append((y + 1, x))
            if x > 0 and mask[y, x - 1] and not visited[y, x - 1]:
                visited[y, x - 1] = True
                stack.append((y, x - 1))
            if x + 1 < w and mask[y, x + 1] and not visited[y, x + 1]:
                visited[y, x + 1] = True
                stack.append((y, x + 1))

    return visited


def _build_checker_mask(rgb: np.ndarray, tolerance: int) -> np.ndarray:
    rgb16 = rgb.astype(np.int16)
    d0 = np.max(np.abs(rgb16 - CHECKER_COLORS[0]), axis=2)
    d1 = np.max(np.abs(rgb16 - CHECKER_COLORS[1]), axis=2)

    m0 = d0 <= tolerance
    m1 = d1 <= tolerance
    candidate = m0 | m1

    # Checkerboard-like regions should have both colors nearby.
    d0_near = _dilate_mask(m0, size=5)
    d1_near = _dilate_mask(m1, size=5)
    checker_like = candidate & d0_near & d1_near

    # Edge-connected candidate regions are likely faux background.
    edge_connected = _edge_connected_components(candidate)

    # Union both masks; this is strict enough to avoid most true highlights.
    return checker_like | edge_connected


def _apply_selective_alpha_feather(alpha: np.ndarray, removed_mask: np.ndarray, blur_radius: float) -> np.ndarray:
    if blur_radius <= 0:
        return alpha

    alpha_img = Image.fromarray(alpha, mode="L")
    blurred = np.array(alpha_img.filter(ImageFilter.GaussianBlur(radius=blur_radius)))

    feather_zone = _dilate_mask(removed_mask, size=7)
    out = alpha.copy()
    out[feather_zone] = np.minimum(out[feather_zone], blurred[feather_zone])
    return out


def _apply_pill_mask(alpha: np.ndarray, inset_x: int = 2, inset_y: int = 2) -> np.ndarray:
    h, w = alpha.shape
    mask_img = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask_img)

    left = inset_x
    top = inset_y
    right = max(left + 1, w - inset_x - 1)
    bottom = max(top + 1, h - inset_y - 1)
    radius = max(1, (bottom - top) // 2)

    draw.rounded_rectangle([left, top, right, bottom], radius=radius, fill=255)
    pill = np.array(mask_img)
    return np.minimum(alpha, pill)


def _resolve_targets(input_dir: Path, extra_paths: Iterable[Path] | None = None) -> list[Path]:
    files: list[Path] = []

    for alias, real_name in TARGET_ALIASES.items():
        if (input_dir / alias).exists():
            files.append(input_dir / alias)
        elif (input_dir / real_name).exists():
            files.append(input_dir / real_name)

    if extra_paths:
        for p in extra_paths:
            if p.exists() and p.suffix.lower() == ".png":
                files.append(p)

    unique = []
    seen = set()
    for p in files:
        key = str(p.resolve())
        if key not in seen:
            seen.add(key)
            unique.append(p)
    return unique


def clean_image(path: Path, out_path: Path, tolerance: int, alpha_blur: float, apply_button_mask: bool) -> CleanStats:
    img = Image.open(path).convert("RGBA")
    arr = np.array(img)
    rgb = arr[:, :, :3]
    alpha = arr[:, :, 3].copy()

    checker_mask = _build_checker_mask(rgb, tolerance=tolerance)

    # Only remove where currently visible.
    remove_mask = checker_mask & (alpha > 0)
    alpha[remove_mask] = 0

    alpha = _apply_selective_alpha_feather(alpha, remove_mask, blur_radius=alpha_blur)

    if apply_button_mask and "make_magic_button" in path.name.lower():
        alpha = _apply_pill_mask(alpha, inset_x=2, inset_y=2)

    arr[:, :, 3] = alpha
    cleaned = Image.fromarray(arr, mode="RGBA")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    cleaned.save(out_path)

    return CleanStats(
        path=path,
        removed_pixels=int(remove_mask.sum()),
        total_pixels=int(alpha.size),
        alpha_pixels_after=int((alpha > 0).sum()),
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Remove checkerboard artifacts from UI assets.")
    parser.add_argument("--input-dir", type=Path, default=DEFAULT_INPUT_DIR)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--tolerance", type=int, default=10, help="RGB tolerance for checker color match")
    parser.add_argument("--alpha-blur", type=float, default=1.4, help="Gaussian blur radius for alpha feathering")
    parser.add_argument("--in-place", action="store_true", help="Write cleaned files over originals")
    parser.add_argument("--no-button-mask", action="store_true", help="Disable pill alpha mask for make_magic_button.png")
    parser.add_argument(
        "--extra",
        nargs="*",
        type=Path,
        default=[],
        help="Additional PNG files to process",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    input_dir: Path = args.input_dir
    output_dir: Path = input_dir if args.in_place else args.output_dir

    targets = _resolve_targets(input_dir=input_dir, extra_paths=args.extra)
    if not targets:
        print(f"No target PNG files found in: {input_dir}")
        print("Expected one or more of:")
        for alias, real in TARGET_ALIASES.items():
            print(f"  - {alias} (or {real})")
        return 1

    print(f"Cleaning {len(targets)} asset(s) from {input_dir}")
    print(f"Output directory: {output_dir}")
    print(f"Tolerance={args.tolerance}, AlphaBlur={args.alpha_blur}")

    all_stats: list[CleanStats] = []
    for src in targets:
        dest = output_dir / src.name
        stats = clean_image(
            src,
            dest,
            tolerance=args.tolerance,
            alpha_blur=args.alpha_blur,
            apply_button_mask=not args.no_button_mask,
        )
        all_stats.append(stats)
        pct = (stats.removed_pixels / max(1, stats.total_pixels)) * 100.0
        print(f"- {src.name}: removed {stats.removed_pixels} px ({pct:.2f}%), alpha>0 now {stats.alpha_pixels_after}")

    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
