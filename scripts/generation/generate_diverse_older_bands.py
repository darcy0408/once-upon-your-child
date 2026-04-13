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
            logger.info(f"Generating: {output_path.name}")
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
    # Style Bases
    pixar_base = "Disney/Pixar-style 3D digital illustration. Cinematic lighting, soft shadows, high detail 3D render, subsurface scattering on skin, vibrant colors. Cute and friendly proportions."
    adventurer_style = "Cinematic Pixar 3D style, high-energy 'Cosmic Chronicle' aesthetic. Vibrant cosmic colors, glowing accents, cinematic lighting."
    creator_style = "Disney/Pixar-style 3D digital illustration, but with a more mature, clean, editorial feel. Cinematic lighting, nuanced textures, realistic skin shaders."

    assets = []

    # EARLY READERS (Ages 6-8)
    er_dir = Path("age_band_assets/early_readers/ui")
    assets.extend([
        (er_dir, "boy_character_black.png", f"{pixar_base} Adorable young Black boy character, age 7, curious eyes, natural curly hair, wearing an explorer vest and goggles. Joyful expression."),
        (er_dir, "boy_character_asian.png", f"{pixar_base} Adorable young East Asian boy character, age 7, messy black hair, wearing an explorer vest and goggles. Joyful expression."),
        (er_dir, "boy_character_hispanic.png", f"{pixar_base} Adorable young Hispanic boy character, age 7, wavy brown hair, wearing an explorer vest and goggles. Joyful expression."),
        (er_dir, "boy_character_south_asian.png", f"{pixar_base} Adorable young South Asian boy character, age 7, black hair, wearing an explorer vest and goggles. Joyful expression."),
        (er_dir, "girl_character_black.png", f"{pixar_base} Adorable young Black girl character, age 7, bright natural hair puffs with star clips, wearing an explorer vest and goggles. Energetic joyful expression."),
        (er_dir, "girl_character_asian.png", f"{pixar_base} Adorable young East Asian girl character, age 7, bright pigtails with star clips, wearing an explorer vest and goggles. Energetic joyful expression."),
        (er_dir, "girl_character_hispanic.png", f"{pixar_base} Adorable young Hispanic girl character, age 7, bright wavy pigtails with star clips, wearing an explorer vest and goggles. Energetic joyful expression."),
        (er_dir, "girl_character_south_asian.png", f"{pixar_base} Adorable young South Asian girl character, age 7, bright dark braided pigtails with star clips, wearing an explorer vest and goggles. Energetic joyful expression."),
    ])

    # ADVENTURERS (Ages 9-11)
    adv_dir = Path("age_band_assets/adventurers/ui")
    assets.extend([
        (adv_dir, "hero_black.png", f"{adventurer_style} Diverse Black adventurer character, age 10, androgynous appearance, brave expression, wearing cosmic gear with glowing elements. Focused and ready."),
        (adv_dir, "hero_asian.png", f"{adventurer_style} Diverse East Asian adventurer character, age 10, androgynous appearance, brave expression, wearing cosmic gear with glowing elements. Focused and ready."),
        (adv_dir, "hero_hispanic.png", f"{adventurer_style} Diverse Hispanic adventurer character, age 10, androgynous appearance, brave expression, wearing cosmic gear with glowing elements. Focused and ready."),
        (adv_dir, "hero_south_asian.png", f"{adventurer_style} Diverse South Asian adventurer character, age 10, androgynous appearance, brave expression, wearing cosmic gear with glowing elements. Focused and ready."),
        (adv_dir, "hero_white.png", f"{adventurer_style} Brave adventurer character, age 10, androgynous appearance, white skin, brave expression, wearing cosmic gear with glowing elements. Focused and ready."),
    ])

    # CREATORS (Ages 12+)
    cre_dir = Path("age_band_assets/creators/ui")
    assets.extend([
        (cre_dir, "creator_black.png", f"{creator_style} Diverse Black teenager character, age 14, expressive eyes, modern hoodie. Thoughtful expression."),
        (cre_dir, "creator_asian.png", f"{creator_style} Diverse East Asian teenager character, age 14, expressive eyes, modern hoodie. Thoughtful expression."),
        (cre_dir, "creator_hispanic.png", f"{creator_style} Diverse Hispanic teenager character, age 14, expressive eyes, modern hoodie. Thoughtful expression."),
        (cre_dir, "creator_south_asian.png", f"{creator_style} Diverse South Asian teenager character, age 14, expressive eyes, modern hoodie. Thoughtful expression."),
        (cre_dir, "creator_white.png", f"{creator_style} Creative teenager character, age 14, white skin, expressive eyes, modern hoodie. Thoughtful expression."),
    ])

    for output_dir, filename, prompt in assets:
        output_path = output_dir / filename
        generate_image(prompt, output_path)
        time.sleep(5) 
            
    logger.info("Batch complete for diverse characters across older bands!")

if __name__ == "__main__":
    main()
