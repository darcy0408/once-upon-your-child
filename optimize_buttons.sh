#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/mnt/c/dev/story-weaver-app/StoryWeaverImagestoShare/buttonsToOptimize/ButtonsToOptimize"

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
  # Skip already generated interaction-state assets.
  if [[ "$filename" =~ (_normal|_hover|_pressed|_clean)$ ]]; then
    continue
  fi

  normal="${filename}_normal.png"
  hover="${filename}_hover.png"
  pressed="${filename}_pressed.png"

  # Step A/B: Normal state keeps the original artwork/background intact.
  "${IM_CMD[@]}" convert "$file" \
    "$normal"

  # Step C: Hover state (brighter + more vivid)
  "${IM_CMD[@]}" convert "$normal" \
    -modulate 118,120,100 \
    -brightness-contrast 6x8 \
    "$hover"

  # Step D: Pressed state (slightly darker, smaller, and nudged down for tactile feel)
  canvas_width="$("${IM_CMD[@]}" identify -format "%w" "$normal")"
  canvas_height="$("${IM_CMD[@]}" identify -format "%h" "$normal")"
  "${IM_CMD[@]}" convert -size "${canvas_width}x${canvas_height}" xc:none \
    \( "$normal" -modulate 96,105,100 -resize 94% \) \
    -gravity center -geometry +0+4 -composite \
    "$pressed"

  echo "Processed: $file"
done

shopt -u nullglob
