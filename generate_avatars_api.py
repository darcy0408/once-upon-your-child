
import os
import time
import logging
from pathlib import Path
from google import genai
from google.genai import types
from dotenv import load_dotenv

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Load environment variables
dotenv_path = Path('backend/.env')
if dotenv_path.exists():
    load_dotenv(dotenv_path=dotenv_path)
else:
    load_dotenv()

GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
if not GEMINI_API_KEY:
    # Try alternate location if not in backend/.env
    GEMINI_API_KEY = os.getenv('GOOGLE_API_KEY')

client = genai.Client(api_key=GEMINI_API_KEY)
# Using nano-banana-pro-preview as requested
MODEL_NAME = 'nano-banana-pro-preview'

def generate_avatar(prompt, output_path):
    """Generate an avatar using Imagen API."""
    
    if output_path.exists():
        logger.info(f"Skipping {output_path.name} (Already exists)")
        return True

    while True:
        try:
            logger.info(f"Generating Avatar: {output_path.name}")
            response = client.models.generate_images(
                model=MODEL_NAME,
                prompt=prompt,
                config=types.GenerateImagesConfig(
                    number_of_images=1,
                    output_mime_type='image/png'
                )
            )
            
            if response.generated_images:
                image_bytes = response.generated_images[0].image.image_bytes
                output_path.parent.mkdir(parents=True, exist_ok=True)
                with open(output_path, 'wb') as f:
                    f.write(image_bytes)
                logger.info(f"Successfully saved to: {output_path}")
                return True
            else:
                logger.error(f"No image generated for: {output_path.name}")
                return False
                
        except Exception as e:
            error_msg = str(e)
            if '429' in error_msg or 'Too Many Requests' in error_msg:
                logger.warning("429 Too Many Requests. Waiting 60 seconds...")
                time.sleep(60)
                continue
            else:
                logger.error(f"Error generating {output_path.name}: {e}")
                return False

def main():
    raw_dir = Path('avatars/raw')
    raw_dir.mkdir(parents=True, exist_ok=True)
    
    fill_color = "#6C7A89" # slate-blue
    base_style = f"Flat vector silhouette, {fill_color} solid fill color, solid black #000000 background, no face, no skin color, no racial features, no gradients, minimal detail, centered on square canvas, clean flat vector art style, NO eyes NO mouth NO nose NO skin tones"

    avatars = [
        ("sprout_boy.png", f"Flat vector silhouette of a tiny toddler boy, very small and round body proportions, short messy hair, chunky simple shapes, {fill_color} solid fill color, solid black background, no face, no skin color, no racial features, no gradients, minimal detail, cute and friendly, centered on square canvas, clean flat vector art style, NO eyes NO mouth NO nose NO skin tones"),
        ("sprout_girl.png", f"Flat vector silhouette of a tiny toddler girl, very small and round body proportions, short pigtails or small ponytail, chunky simple shapes, {fill_color} solid fill color, solid black background, no face, no skin color, no racial features, no gradients, minimal detail, cute and friendly, centered on square canvas, clean flat vector art style, NO eyes NO mouth NO nose NO skin tones"),
        ("explorer_boy.png", f"Flat vector silhouette of an energetic young boy age 6-9, small backpack, slightly taller and leaner than a toddler, short spiky hair, {fill_color} solid fill color, solid black background, no face, no skin color, no racial features, no gradients, simple cartoon proportions, dynamic pose, centered, NO eyes NO mouth NO nose"),
        ("explorer_girl.png", f"Flat vector silhouette of an energetic young girl age 6-9, small backpack, slightly taller and leaner than a toddler, shoulder-length bob hair, {fill_color} solid fill color, solid black background, no face, no skin color, no racial features, no gradients, simple cartoon proportions, dynamic pose, centered, NO eyes NO mouth NO nose"),
        ("adventurer_boy.png", f"Flat vector silhouette of a pre-teen boy age 10-12, wearing a baseball cap, leaner proportions, short textured hair, {fill_color} solid fill color, solid black background, no face, no skin color, no racial features, no gradients, simple flat style, centered, NO eyes NO mouth NO nose"),
        ("adventurer_girl.png", f"Flat vector silhouette of a pre-teen girl age 10-12, wearing a headband, leaner proportions, high ponytail, {fill_color} solid fill color, solid black background, no face, no skin color, no racial features, no gradients, simple flat style, centered, NO eyes NO mouth NO nose"),
        ("creator_boy.png", f"Flat vector silhouette of a creative young teen boy, messy artistic hair, holding a sketchbook, {fill_color} solid fill color, solid black background, no face, no skin color, no racial features, no gradients, clean vector, centered, NO eyes NO mouth NO nose"),
        ("creator_girl.png", f"Flat vector silhouette of a creative young teen girl, space buns hair style, holding a palette, {fill_color} solid fill color, solid black background, no face, no skin color, no racial features, no gradients, clean vector, centered, NO eyes NO mouth NO nose"),
        ("adolescent_boy.png", f"Flat vector silhouette of a late teen boy age 16-18, taller and more angular, short styled hair, {fill_color} solid fill color, solid black background, no face, no skin color, no racial features, no gradients, mature silhouette, centered, NO eyes NO mouth NO nose"),
        ("adolescent_girl.png", f"Flat vector silhouette of a late teen girl age 16-18, taller and more angular, long flowing hair, {fill_color} solid fill color, solid black background, no face, no skin color, no racial features, no gradients, mature silhouette, centered, NO eyes NO mouth NO nose"),
        ("adult_man.png", f"Flat vector silhouette of an adult man, broad shoulders, tall proportions, short neat hair, {fill_color} solid fill color, solid black background, no face, no skin color, no racial features, no gradients, authoritative but kind posture, centered, NO eyes NO mouth NO nose"),
        ("adult_woman.png", f"Flat vector silhouette of an adult woman, graceful tall proportions, elegant bun hair style, {fill_color} solid fill color, solid black background, no face, no skin color, no racial features, no gradients, compassionate posture, centered, NO eyes NO mouth NO nose"),
    ]

    for filename, prompt in avatars:
        output_path = raw_dir / filename
        generate_avatar(prompt, output_path)
        time.sleep(5) # Rate limit protection

if __name__ == "__main__":
    main()
