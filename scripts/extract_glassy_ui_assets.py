from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np


ROOT = Path(r"C:\dev\story-weaver-app")
SOURCE_DIR = ROOT / "StoryWeaverImagestoShare"
OUT_DIR = ROOT / "assets" / "images" / "ui" / "glassy"


ASSET_MAP = {
    "quick story.jpg": "quick_orb.png",
    "Classic.jpg": "classic_orb.png",
    "epic.jpg": "epic_orb.png",
    "easyRead.jpg": "easy_read_orb.png",
    "PickAPath.jpg": "pick_path_orb.png",
    "RhymeTime.jpg": "rhyme_time_orb.png",
    "Tales.jpg": "tales_orb.png",
    "Progress Indicator.jpg": "progress_done_orb.png",
    "Progress indicator2.jpg": "progress_active_orb.png",
    "make magic button.jpg": "make_magic_button.png",
}


def _refine_alpha(mask: np.ndarray) -> np.ndarray:
    kernel3 = np.ones((3, 3), np.uint8)
    kernel5 = np.ones((5, 5), np.uint8)
    cleaned = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel3, iterations=1)
    cleaned = cv2.morphologyEx(cleaned, cv2.MORPH_CLOSE, kernel5, iterations=2)
    cleaned = cv2.GaussianBlur(cleaned, (5, 5), sigmaX=0.0, sigmaY=0.0)
    return cleaned


def _extract_foreground(image_bgr: np.ndarray, *, is_button: bool) -> np.ndarray:
    h, w = image_bgr.shape[:2]

    # Start with GrabCut around the center artwork.
    gc_mask = np.zeros((h, w), np.uint8)
    if is_button:
        rect = (int(w * 0.1), int(h * 0.28), int(w * 0.8), int(h * 0.45))
    else:
        rect = (int(w * 0.18), int(h * 0.08), int(w * 0.64), int(h * 0.82))

    bgd_model = np.zeros((1, 65), np.float64)
    fgd_model = np.zeros((1, 65), np.float64)
    cv2.grabCut(
        image_bgr,
        gc_mask,
        rect,
        bgd_model,
        fgd_model,
        5,
        cv2.GC_INIT_WITH_RECT,
    )

    fg = np.where(
        (gc_mask == cv2.GC_FGD) | (gc_mask == cv2.GC_PR_FGD), 255, 0
    ).astype(np.uint8)

    # Remove typical checkerboard grays aggressively from uncertain edges.
    gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)
    sat = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2HSV)[:, :, 1]
    checker_like = ((sat < 42) & (gray > 60) & (gray < 210)).astype(np.uint8) * 255
    fg = cv2.bitwise_and(fg, cv2.bitwise_not(checker_like))

    # Keep only largest connected component to avoid floating background islands.
    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(fg, connectivity=8)
    if num_labels > 1:
        largest_idx = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
        fg = np.where(labels == largest_idx, 255, 0).astype(np.uint8)

    return _refine_alpha(fg)


def _center_on_canvas(rgba: np.ndarray, *, is_button: bool) -> np.ndarray:
    alpha = rgba[:, :, 3]
    ys, xs = np.where(alpha > 6)
    if len(xs) == 0 or len(ys) == 0:
        return rgba

    x0, x1 = xs.min(), xs.max() + 1
    y0, y1 = ys.min(), ys.max() + 1
    crop = rgba[y0:y1, x0:x1]

    if is_button:
        out_w, out_h = 1024, 380
    else:
        out_w, out_h = 560, 560
    out = np.zeros((out_h, out_w, 4), dtype=np.uint8)

    scale = min(out_w / crop.shape[1], out_h / crop.shape[0]) * (0.92 if is_button else 0.88)
    nw = max(1, int(crop.shape[1] * scale))
    nh = max(1, int(crop.shape[0] * scale))
    resized = cv2.resize(crop, (nw, nh), interpolation=cv2.INTER_AREA)

    x = (out_w - nw) // 2
    y = (out_h - nh) // 2
    out[y : y + nh, x : x + nw] = resized
    return out


def process_one(src_name: str, dst_name: str) -> None:
    src = SOURCE_DIR / src_name
    is_button = "button" in src_name.lower()
    image_bgr = cv2.imread(str(src), cv2.IMREAD_COLOR)
    if image_bgr is None:
        raise RuntimeError(f"Failed to load source image: {src}")

    alpha = _extract_foreground(image_bgr, is_button=is_button)
    b, g, r = cv2.split(image_bgr)
    rgba = cv2.merge((b, g, r, alpha))
    centered = _center_on_canvas(rgba, is_button=is_button)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    dst = OUT_DIR / dst_name
    cv2.imwrite(str(dst), centered)
    print(f"Wrote {dst}")


def main() -> None:
    for src_name, dst_name in ASSET_MAP.items():
        process_one(src_name, dst_name)


if __name__ == "__main__":
    main()
