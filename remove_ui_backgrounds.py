
import os
from pathlib import Path
try:
    from rembg import remove
    from PIL import Image
except ImportError:
    print("Error: 'rembg' or 'pillow' not found. Please run: pip install \"rembg[cpu]\" pillow")
    exit(1)

def process_transparency(target_dir_name):
    target_dir = Path(target_dir_name)
    if not target_dir.exists():
        print(f"Error: Directory {target_dir} not found.")
        return

    print(f"🚀 Processing images in {target_dir} for transparency (Recursive)...")
    
    # Process all PNG files recursively
    for img_path in target_dir.rglob('*.png'):
        print(f"  ✨ Removing background from: {img_path.relative_to(target_dir)}")
        try:
            with open(img_path, 'rb') as f:
                input_data = f.read()
            
            # Remove background using rembg
            output_data = remove(input_data)
            
            with open(img_path, 'wb') as f:
                f.write(output_data)
            print(f"  ✅ Success: {img_path.name}")
        except Exception as e:
            print(f"  ❌ Failed {img_path.name}: {e}")

if __name__ == "__main__":
    process_transparency('age_band_assets/creators')
