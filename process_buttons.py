import os
from PIL import Image, ImageEnhance
from pathlib import Path

def process_button(input_path):
    # Open an image file
    with Image.open(input_path) as img:
        # Scale the image slightly bigger (e.g., 5% bigger)
        width, height = img.size
        new_size = (int(width * 1.05), int(height * 1.05))
        img_resized = img.resize(new_size, Image.Resampling.LANCZOS)
        
        # Increase brightness slightly (e.g., 15% brighter)
        enhancer = ImageEnhance.Brightness(img_resized)
        img_brightened = enhancer.enhance(1.15)
        
        # Save the new image
        name = input_path.stem
        output_name = f"{name}_clicked{input_path.suffix}"
        output_path = input_path.parent / output_name
        
        img_brightened.save(output_path)
        print(f"Processed {input_path.name} -> {output_name}")

if __name__ == "__main__":
    dirs = [
        Path(r"age_band_assets\early_readers\ui"),
        Path(r"age_band_assets\adventurers\ui"),
        Path(r"age_band_assets\creators\ui"),
    ]
    
    buttons = ["continue_button.png", "make_magic_normal.png"]
    
    for d in dirs:
        if not d.exists():
            print(f"Directory not found: {d}")
            continue
        for btn in buttons:
            btn_path = d / btn
            if btn_path.exists():
                process_button(btn_path)
            else:
                print(f"File not found: {btn_path}")
