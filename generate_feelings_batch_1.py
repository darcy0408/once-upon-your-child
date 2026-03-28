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
    GEMINI_API_KEY = os.getenv('GOOGLE_API_KEY')

if not GEMINI_API_KEY:
    logger.error("No API key found. Please set GEMINI_API_KEY in backend/.env")
    exit(1)

client = genai.Client(api_key=GEMINI_API_KEY)
# Using nano-banana-pro-preview as requested/used in other scripts
MODEL_NAME = 'nano-banana-pro-preview'

def generate_feeling_image(feeling_name, prompt, output_path):
    """Generate a feeling image using the Imagen API."""
    
    if output_path.exists():
        logger.info(f"Skipping {output_path.name} (Already exists)")
        return True

    while True:
        try:
            logger.info(f"Generating feeling: {feeling_name} -> {output_path}")
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
                logger.error(f"No image generated for: {feeling_name}")
                return False
                
        except Exception as e:
            error_msg = str(e)
            if '429' in error_msg or 'Too Many Requests' in error_msg:
                logger.warning("429 Too Many Requests. Waiting 60 seconds...")
                time.sleep(60)
                continue
            else:
                logger.error(f"Error generating {feeling_name}: {e}")
                return False

def main():
    target_dir = Path('assets/images/feelings/sprout')
    target_dir.mkdir(parents=True, exist_ok=True)
    
    style_base = "3D-rendered cute blob/bean character, solid black background (#000000), soft round squishy shape, simple cartoon face, stubby arms, subtle glow, 512x512 PNG."

    feelings = [
        ("bothered.png", f"greenish-yellow blob, annoyed, one eyebrow raised, arms crossed, zigzag lines. {style_base}"),
        ("bouncy.png", f"orange blob mid-bounce, huge grin, arms up, motion lines, sparkles. {style_base}"),
        ("gloomy.png", f"dark blue-gray blob, droopy eyes, rain cloud above, arms limp. {style_base}"),
        ("grossed_out.png", f"green blob, tongue out, squinted eyes, one arm pushing away, stink waves. {style_base}"),
    ]

    for filename, prompt in feelings:
        output_path = target_dir / filename
        generate_feeling_image(filename.replace('.png', ''), prompt, output_path)
        time.sleep(10) # Simple rate limit protection

if __name__ == "__main__":
    main()
