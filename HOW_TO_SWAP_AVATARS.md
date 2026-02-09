# How to Swap Avatar Images

## Current Setup

**Production (what app uses):**
- Location: `assets/avatars/midjourney/`
- Format: WebP, 512x512
- Count: 94 images
- Files: 1.webp, 1.1.webp, 2.webp, 2.2.webp, etc.

**Source Library:**
- Location: `avatarImages/originals/`
- Format: PNG (high-res)
- Count: 319 images
  - 94 numbered files (currently in production)
  - 225 kaboom files (extras for swapping/siblings)

---

## How to Swap an Avatar

### Option 1: Replace Existing Avatar

**Example:** Replace "4.webp" with one of the kaboom images

1. **Pick your replacement** from `avatarImages/originals/kaboom_*.png`

2. **Convert to WebP** (512x512, quality 85):
   ```bash
   # Using ImageMagick
   magick convert "avatarImages/originals/kaboom_31639_107_Girl_PigtailsDeep_Skin.png" \
     -resize 512x512 -quality 85 \
     "assets/avatars/midjourney/4.webp"

   # Or using Python with Pillow
   from PIL import Image
   img = Image.open("avatarImages/originals/kaboom_....png")
   img = img.resize((512, 512), Image.LANCZOS)
   img.save("assets/avatars/midjourney/4.webp", "WEBP", quality=85)
   ```

3. **Test** - Restart app and check avatar gallery

### Option 2: Add New Avatar (expand beyond 94)

1. **Pick a kaboom image** you want to add

2. **Convert and name it** with next available number:
   ```bash
   # Convert to 72.webp (since 72 doesn't exist)
   magick convert "avatarImages/originals/kaboom_....png" \
     -resize 512x512 -quality 85 \
     "assets/avatars/midjourney/72.webp"
   ```

3. **Update metadata.json**:
   ```json
   "72.webp": {
     "id": "72",
     "filename": "72.webp",
     "age": null,
     "ageGroup": null,
     "skinTone": "deep",
     "hairColor": "black",
     "hairStyle": "afro-puffs",
     "gender": "feminine",
     "tags": ["natural-hair", "dark-skin"]
   }
   ```

4. **Update total** in metadata.json header

---

## Batch Conversion Script

Create `convert_avatar.py`:

```python
from PIL import Image
import sys
import os

def convert_to_webp(source_path, dest_path, size=(512, 512), quality=85):
    """Convert PNG to WebP for avatar use"""
    img = Image.open(source_path)

    # Convert RGBA to RGB if needed
    if img.mode == 'RGBA':
        background = Image.new('RGB', img.size, (255, 255, 255))
        background.paste(img, mask=img.split()[3])
        img = background

    # Resize
    img = img.resize(size, Image.LANCZOS)

    # Save as WebP
    img.save(dest_path, 'WEBP', quality=quality)
    print(f"✓ Converted {os.path.basename(source_path)} → {os.path.basename(dest_path)}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python convert_avatar.py <source.png> <output_number>")
        print("Example: python convert_avatar.py kaboom_....png 72")
        sys.exit(1)

    source = sys.argv[1]
    number = sys.argv[2]
    dest = f"assets/avatars/midjourney/{number}.webp"

    convert_to_webp(source, dest)
```

Usage:
```bash
python convert_avatar.py "avatarImages/originals/kaboom_....png" 72
```

---

## Which Kaboom Files Do You Have?

Your 225 extra images organized by type (from filenames):

| Type | Count | Examples |
|------|-------|----------|
| Ages 4-5 | ~30 | kaboom_*_4_year_old_*.png |
| Ages 6-7 | ~70 | kaboom_*_6_year_old_*.png, kaboom_*_7_year_old_*.png |
| Ages 8-10 | ~95 | kaboom_*_9_year_old_*.png, kaboom_*_10_year_old_*.png |
| Deep Skin | ~6 | kaboom_*_Deep_Skin_*.png |
| Braids | ~7 | kaboom_*_Braid_*.png |
| Curly Hair | ~3 | kaboom_*_Curly_*.png |

List all kaboom files:
```bash
ls avatarImages/originals/kaboom_*.png
```

---

## Tips

1. **Keep backups** - Don't delete original PNGs
2. **Test in app** - Always check the avatar picker after swapping
3. **Consistency** - Keep all avatars at 512x512 WebP
4. **Metadata optional** - App works without metadata tags, but they help with filtering

---

## Viewing Production vs Extras

**See what's in production:**
```bash
ls assets/avatars/midjourney/*.webp
```

**See what kaboom extras you have:**
```bash
ls avatarImages/originals/kaboom_*.png | head -20
```

**Find specific features:**
```bash
# Dark skin girls
ls avatarImages/originals/kaboom_*Girl*Deep_Skin*.png

# Boys with braids
ls avatarImages/originals/kaboom_*Boy*Braid*.png
```
