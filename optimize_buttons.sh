#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/mnt/c/dev/story-weaver-app/StoryWeaverImagestoShare/buttonsToOptimize/ButtonsToOptimize"

# Prefer a local venv if present
if [[ -x "/mnt/c/dev/story-weaver-app/.venv/bin/rembg" ]]; then
  export PATH="/mnt/c/dev/story-weaver-app/.venv/bin:$PATH"
fi

# Prerequisite checks
if ! command -v rembg >/dev/null 2>&1; then
  echo "rembg is not installed. Install with: pip install \"rembg[cpu]\""
  exit 1
fi

if ! command -v magick >/dev/null 2>&1 && ! command -v convert >/dev/null 2>&1; then
  echo "ImageMagick is not installed. Install with: sudo apt install imagemagick"
  exit 1
fi

# Use ImageMagick v7 if available, otherwise fallback to v6
if command -v magick >/dev/null 2>&1; then
  IM_CMD=(magick)
else
  IM_CMD=()
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Target directory not found: $TARGET_DIR"
  exit 1
fi

cd "$TARGET_DIR"

shopt -s nullglob

for file in *.png *.jpg *.jpeg; do
  [[ -f "$file" ]] || continue

  filename="${file%.*}"
  clean="${filename}_clean.png"
  normal="${filename}_normal.png"
  hover="${filename}_hover.png"
  pressed="${filename}_pressed.png"

  # Step A: Remove background
  rembg i "$file" "$clean"

  # Step B: Normal state (200x200)
  "${IM_CMD[@]}" convert "$clean" -resize 200x200 "$normal"

  # Step C: Hover state (brightness 110%)
  "${IM_CMD[@]}" convert "$normal" -modulate 110,100,100 "$hover"

  # Step D: Pressed state (brightness 90%, 95% size, centered on 200x200)
  "${IM_CMD[@]}" convert "$normal" -modulate 90,100,100 -resize 95% \
    -gravity center -background none -extent 200x200 "$pressed"

  # Cleanup
  rm -f "$clean"

  echo "Processed: $file"
done

shopt -u nullglob
