"""
Process boy/girl images for each age band:
  - BFS flood-fill from corners to remove solid black backgrounds (sprout, explorer)
  - Convert JPG → PNG (adventurer, 13-15 girl)
  - Copy remaining PNGs as-is
Output: assets/images/ui/gender/
"""
import sys
from pathlib import Path
from collections import deque

try:
    from PIL import Image
    import numpy as np
except ImportError:
    sys.exit("Pillow and numpy are required: pip install pillow numpy")

SRC = Path("C:/dev/story-weaver-app/assets/BoyGirl images")
DST = Path("C:/dev/story-weaver-app/assets/images/ui/gender")
DST.mkdir(parents=True, exist_ok=True)


def remove_black_bg(src_path: Path, dst_path: Path, threshold: int = 35) -> None:
    """BFS flood-fill from all four corners; make connected near-black pixels transparent."""
    img = Image.open(src_path).convert("RGBA")
    data = np.array(img)
    h, w = data.shape[:2]

    visited = np.zeros((h, w), dtype=bool)
    mask = np.zeros((h, w), dtype=bool)

    queue = deque()
    for r, c in [(0, 0), (0, w - 1), (h - 1, 0), (h - 1, w - 1)]:
        if not visited[r, c]:
            queue.append((r, c))
            visited[r, c] = True

    while queue:
        r, c = queue.popleft()
        pixel = data[r, c, :3].astype(int)
        if np.all(pixel < threshold):
            mask[r, c] = True
            for dr, dc in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nr, nc = r + dr, c + dc
                if 0 <= nr < h and 0 <= nc < w and not visited[nr, nc]:
                    visited[nr, nc] = True
                    queue.append((nr, nc))

    data[mask, 3] = 0
    Image.fromarray(data).save(dst_path)
    print(f"  bg-removed -> {dst_path.name}")


def convert_copy(src_path: Path, dst_path: Path) -> None:
    """Open and re-save as PNG (handles JPG→PNG conversion)."""
    img = Image.open(src_path).convert("RGBA")
    img.save(dst_path)
    print(f"  copied/converted -> {dst_path.name}")


JOBS = [
    # (source filename,              output filename,             remove_bg)
    ("sprouts_boy.png",              "gender_sprout_boy.png",      True),
    ("sprouts_girl.png",             "gender_sprout_girl.png",     True),
    ("5-7 year old boy.png",         "gender_explorer_boy.png",    True),
    ("5-7 year old girl.png",        "gender_explorer_girl.png",   True),
    ("8-10 year old boy.jpg",        "gender_adventurer_boy.png",  False),
    ("8-10 year old girl.jpg",       "gender_adventurer_girl.png", False),
    # creator boy is missing; adolescent boy is reused as fallback in code
    ("11-13 girl.png",               "gender_creator_girl.png",    False),
    ("16 boy.png",                   "gender_adolescent_boy.png",  False),
    ("16 girl.png",                  "gender_adolescent_girl.png", False),
    ("13 - 15 girl.jpg",             "gender_creator_alt_girl.png",False),  # spare / can promote to creator
    ("boy adult.png",                "gender_adult_boy.png",       False),
    ("girl adult.png",               "gender_adult_girl.png",      False),
]

for src_name, dst_name, do_remove_bg in JOBS:
    src = SRC / src_name
    dst = DST / dst_name
    if not src.exists():
        print(f"  MISSING: {src_name} — skipped")
        continue
    if do_remove_bg:
        remove_black_bg(src, dst)
    else:
        convert_copy(src, dst)

print("\nDone.")
