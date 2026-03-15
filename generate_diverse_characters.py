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
client = genai.Client(api_key=GEMINI_API_KEY)
MODEL_NAME = 'models/imagen-4.0-generate-001'

def generate_image(prompt, output_path, format='PNG', force_black_bg=True):
    """Generate an image using the Imagen API with retry logic and optional black background."""
    
    if output_path.exists():
        logger.info(f"Skipping {output_path.name} (Already exists)")
        return True

    if force_black_bg:
        prompt = f"{prompt} -- THE CHARACTER/ELEMENT MUST BE ISOLATED ON A PURE SOLID BLACK BACKGROUND. NO SCENERY. NO FLOOR. NO SHADOWS. NO GRADIENTS IN THE BACKGROUND. PURE BLACK #000000 ONLY."

    while True:
        try:
            logger.info(f"Generating Pixar-style: {output_path.name}")
            response = client.models.generate_images(
                model=MODEL_NAME,
                prompt=prompt,
                config=types.GenerateImagesConfig(
                    number_of_images=1,
                    output_mime_type='image/png' if format == 'PNG' else 'image/jpeg'
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
                time.sleep(10)
                return False

def main():
    age_band = "sprouts"
    base_dir = Path("age_band_assets") / age_band
    
    # PIXAR STYLE BASE
    style_base = "Disney/Pixar-style 3D digital illustration. Cinematic lighting, soft shadows, high detail 3D render, subsurface scattering on skin, vibrant colors. Cute and friendly proportions."

    assets = [
        # DIVERSE BOY CHARACTERS
        ("UI", "boy_character_black.png", f"{style_base} Adorable young Black boy character, big curious eyes, natural curly hair, star-print t-shirt, denim overalls. Joyful expression.", "PNG", True),
        ("UI", "boy_character_asian.png", f"{style_base} Adorable young East Asian boy character, big curious eyes, messy black hair, star-print t-shirt, denim overalls. Joyful expression.", "PNG", True),
        ("UI", "boy_character_hispanic.png", f"{style_base} Adorable young Hispanic boy character, big curious eyes, wavy brown hair, star-print t-shirt, denim overalls. Joyful expression.", "PNG", True),
        ("UI", "boy_character_south_asian.png", f"{style_base} Adorable young South Asian boy character, big curious eyes, black hair, star-print t-shirt, denim overalls. Joyful expression.", "PNG", True),
        
        # DIVERSE GIRL CHARACTERS
        ("UI", "girl_character_black.png", f"{style_base} Adorable young Black girl character, bright natural hair puffs with star clips, rainbow-stripe dress. Energetic joyful expression.", "PNG", True),
        ("UI", "girl_character_asian.png", f"{style_base} Adorable young East Asian girl character, bright pigtails with star clips, rainbow-stripe dress. Energetic joyful expression.", "PNG", True),
        ("UI", "girl_character_hispanic.png", f"{style_base} Adorable young Hispanic girl character, bright wavy pigtails with star clips, rainbow-stripe dress. Energetic joyful expression.", "PNG", True),
        ("UI", "girl_character_south_asian.png", f"{style_base} Adorable young South Asian girl character, bright dark braided pigtails with star clips, rainbow-stripe dress. Energetic joyful expression.", "PNG", True),
    ]

    summary = []
    for subfolder, filename, prompt, fmt, black_bg in assets:
        output_path = base_dir / subfolder / filename
        if generate_image(prompt, output_path, format=fmt, force_black_bg=black_bg):
            summary.append(str(output_path))
            time.sleep(5) 
            
    logger.info("Disney/Pixar style batch complete for diverse characters!")

if __name__ == "__main__":
    main()
