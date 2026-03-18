"""
copy_age_band_assets.py
Copies age_band_assets/ into the Flutter assets/ directory.
Run from the project root: python copy_age_band_assets.py
Re-runnable: existing files are overwritten, nothing is deleted.
"""

import os
import shutil
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent
SRC_ROOT = PROJECT_ROOT / "age_band_assets"
DST_ROOT = PROJECT_ROOT / "assets" / "images"

# (source_subdir, destination_subdir)
# Source paths are relative to age_band_assets/
# Destination paths are relative to assets/images/
COPY_MAP = [
    # --- SPROUTS (note: uppercase 'UI' folder on disk) ---
    ("sprouts/UI",          "ui/sprout"),
    ("sprouts/archetypes",  "archetypes/sprout"),
    ("sprouts/companions",  "companions/sprout"),
    ("sprouts/feelings",    "feelings/sprout"),
    ("sprouts/orbs",        "orbs/sprout"),
    ("sprouts/backgrounds", "backgrounds/sprout"),

    # --- EARLY READERS → explorer ---
    ("early_readers/ui",          "ui/explorer"),
    ("early_readers/archetypes",  "archetypes/explorer"),
    ("early_readers/companions",  "companions/explorer"),
    ("early_readers/feelings",    "feelings/explorer"),
    ("early_readers/orbs",        "orbs/explorer"),
    ("early_readers/backgrounds", "backgrounds/explorer"),
    ("early_readers/scenes",      "scenes/explorer"),

    # --- ADVENTURERS ---
    ("adventurers/ui",          "ui/adventurer"),
    ("adventurers/archetypes",  "archetypes/adventurer"),
    ("adventurers/companions",  "companions/adventurer"),
    ("adventurers/feelings",    "feelings/adventurer"),
    ("adventurers/orbs",        "orbs/adventurer"),
    ("adventurers/backgrounds", "backgrounds/adventurer"),
    ("adventurers/scenes",      "scenes/adventurer"),

    # --- CREATORS ---
    ("creators/ui",          "ui/creator"),
    ("creators/archetypes",  "archetypes/creator"),
    ("creators/companions",  "companions/creator"),
    ("creators/feelings",    "feelings/creator"),
    ("creators/orbs",        "orbs/creator"),
    ("creators/backgrounds", "backgrounds/creator"),
    ("creators/scenes",      "scenes/creator"),

    # --- ADOLESCENTS (primary copy) ---
    ("adolescents/ui",          "ui/adolescent"),
    ("adolescents/archetypes",  "archetypes/adolescent"),
    ("adolescents/companions",  "companions/adolescent"),
    ("adolescents/feelings",    "feelings/adolescent"),
    ("adolescents/orbs",        "orbs/adolescent"),
    ("adolescents/backgrounds", "backgrounds/adolescent"),
    ("adolescents/scenes",      "scenes/adolescent"),

    # --- ADULTS ---
    ("adults/ui",          "ui/adult"),
    ("adults/archetypes",  "archetypes/adult"),
    ("adults/companions",  "companions/adult"),
    ("adults/feelings",    "feelings/adult"),
    ("adults/orbs",        "orbs/adult"),
    ("adults/backgrounds", "backgrounds/adult"),
    ("adults/scenes",      "scenes/adult"),
]

# These older_adolescents folders supplement the adolescent band
# (only files NOT already copied from adolescents/ are added)
SUPPLEMENT_MAP = [
    ("older_adolescents/ui",         "ui/adolescent"),
    ("older_adolescents/companions", "companions/adolescent"),
    ("older_adolescents/feelings",   "feelings/adolescent"),
]


def copy_dir(src: Path, dst: Path, overwrite: bool = True) -> int:
    """Copy all files from src into dst. Returns count of files copied."""
    if not src.exists():
        print(f"  ⚠  Source not found, skipping: {src}")
        return 0
    dst.mkdir(parents=True, exist_ok=True)
    count = 0
    for item in src.iterdir():
        if item.is_file():
            dest_file = dst / item.name
            if overwrite or not dest_file.exists():
                shutil.copy2(item, dest_file)
                count += 1
    return count


def main():
    totals = {}

    print("=== Standard copy ===")
    for src_rel, dst_rel in COPY_MAP:
        src = SRC_ROOT / src_rel
        dst = DST_ROOT / dst_rel
        n = copy_dir(src, dst, overwrite=True)
        totals[dst_rel] = totals.get(dst_rel, 0) + n
        print(f"  {src_rel:<45} -> {dst_rel:<30}  ({n} files)")

    print("\n=== Supplement copy (older_adolescents -> adolescent, missing files only) ===")
    for src_rel, dst_rel in SUPPLEMENT_MAP:
        src = SRC_ROOT / src_rel
        dst = DST_ROOT / dst_rel
        n = copy_dir(src, dst, overwrite=False)
        totals[dst_rel] = totals.get(dst_rel, 0) + n
        print(f"  {src_rel:<45} -> {dst_rel:<30}  (+{n} new files)")

    print("\n=== Summary ===")
    empty = []
    for dst_rel, count in sorted(totals.items()):
        dst = DST_ROOT / dst_rel
        actual = len(list(dst.glob("*"))) if dst.exists() else 0
        marker = "  [EMPTY]" if actual == 0 else ""
        print(f"  {dst_rel:<30}  copied={count}  total_now={actual}{marker}")
        if actual == 0:
            empty.append(dst_rel)

    if empty:
        print(f"\n[!] Empty destination dirs ({len(empty)}): {empty}")
        print("    These will be populated when source images are generated.")
    else:
        print("\n[OK] All destination directories have files.")


if __name__ == "__main__":
    main()
