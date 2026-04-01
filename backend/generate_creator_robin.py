"""
Generate creator robin using Imagen 4.
Matches the illustrated style of the other band robins.

Usage:
    python backend/generate_creator_robin.py
"""

import os
import sys
import base64
from pathlib import Path
from dotenv import load_dotenv

# Load backend .env for GEMINI_API_KEY
load_dotenv(Path(__file__).parent / ".env")

API_KEY = os.environ.get("GEMINI_API_KEY")
if not API_KEY:
    print("ERROR: GEMINI_API_KEY not found in backend/.env")
    sys.exit(1)

OUTPUT_PATH = Path("assets/images/companions/creator/robin.png")

PROMPT = (
    "Illustrated digital art of an anthropomorphic European robin bird character. "
    "The robin has bright orange-red breast feathers, warm brown back feathers, and small expressive black eyes. "
    "It wears a delicate teal hamsa (hand of Fatima) beaded necklace. "
    "The robin stands confidently in a cozy art studio, holding a small paintbrush, "
    "with a tiny colour palette resting nearby. "
    "Splashes of vibrant paint — blues, golds, reds — surround the character with a creative, artistic energy. "
    "The illustration style is warm, painterly, and whimsical — similar to a high-quality animated film concept art. "
    "The character faces slightly toward the viewer with a curious, creative expression. "
    "Square 1024x1024 composition, transparent-friendly white background, "
    "clean edges suitable for background removal. "
    "No text, no watermarks."
)


def main():
    try:
        from google import genai
        from google.genai import types
    except ImportError:
        print("ERROR: google-genai not installed. Run: pip install google-genai")
        sys.exit(1)

    print("Connecting to Imagen 4...")
    client = genai.Client(api_key=API_KEY)

    print("Generating creator robin...")
    response = client.models.generate_images(
        model="imagen-4.0-generate-001",
        prompt=PROMPT,
        config=types.GenerateImagesConfig(
            number_of_images=1,
            aspect_ratio="1:1",
            output_mime_type="image/png",
        ),
    )

    if not response.generated_images:
        print("ERROR: No images returned from Imagen 4")
        sys.exit(1)

    image_data = response.generated_images[0].image.image_bytes
    print("Image generated (%d bytes). Removing background..." % len(image_data))

    try:
        from rembg import remove
        from PIL import Image
        import io

        result = remove(image_data)
        img = Image.open(io.BytesIO(result)).convert("RGBA")
        img = img.resize((1024, 1024), Image.LANCZOS)
        img.save(OUTPUT_PATH, "PNG")
        print("Saved %dx%d PNG to %s" % (img.size[0], img.size[1], OUTPUT_PATH))
    except ImportError:
        # rembg not available — save raw PNG
        print("WARNING: rembg not available. Saving without background removal.")
        OUTPUT_PATH.write_bytes(image_data)
        print("Saved raw PNG to %s" % OUTPUT_PATH)


if __name__ == "__main__":
    main()
