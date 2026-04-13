
import os
import json
import time
from pathlib import Path
from google import genai
from google.genai import types
from dotenv import load_dotenv
import logging

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
# Using standard Imagen 4 model
MODEL_NAME = 'models/imagen-4.0-generate-001'

def generate_transparent_image(prompt, output_path):
    """Attempt to generate an image with an actual transparent background."""
    # Modified prompt to be more aggressive about transparency
    enhanced_prompt = f"{prompt} -- THE ELEMENT MUST BE ISOLATED ON A PURE TRANSPARENT BACKGROUND. ABSOLUTELY NO WHITE OR BLACK BACKGROUND. NO BACKGROUND FILL. NO SHADOWS."
    
    try:
        logger.info(f"Regenerating: {output_path.name}")
        response = client.models.generate_images(
            model=MODEL_NAME,
            prompt=enhanced_prompt,
            config=types.GenerateImagesConfig(
                number_of_images=1,
                include_rai_reason=True,
                # We request PNG which supports alpha, though the model might still fill it
                output_mime_type='image/png'
            )
        )
        
        if response.generated_images:
            image_bytes = response.generated_images[0].image.image_bytes
            with open(output_path, 'wb') as f:
                f.write(image_bytes)
            logger.info(f"Saved to: {output_path}")
            return True
        else:
            logger.error(f"No image generated for {output_path.name}")
            return False
            
    except Exception as e:
        logger.error(f"Error: {e}")
        return False

def main():
    # Only regenerating UI assets for now as they need transparency
    ui_prompts = {
        "make_magic_button_normal": "Children's book digital illustration style. A wide rounded-rectangle button with a warm gradient from deep coral pink to golden yellow to soft lavender. Thick bubbly glowing golden border. Large friendly rounded letters spell 'MAKE MAGIC' in white. Tiny sparkle stars and small heart shapes. Toy-like and inviting. Transparent background.",
        "make_magic_button_pressed": "Children's book digital illustration style. Same as normal but gradient is 20% darker, border thinner, sparkles compressed inward, subtle inner shadow. Transparent background.",
        "continue_button_normal": "Children's book digital illustration style. Wide rounded-rectangle in warm golden yellow to soft coral. 'CONTINUE' in large white rounded letters with orange outline. Star-shape arrow points right. Thick bubbly border. Transparent background.",
        "name_input_frame": "Children's book digital illustration. Wide banner frame, chunky bubbly golden rectangle, rounded ends, star shapes at corners, soft cloud-pink inner fill. 3D quality. No text. Transparent background.",
        "progress_orb_idle": "Children's book digital illustration. Small chunky star in grey-lavender, gentle glow. Round and friendly. Transparent background. 80x80 pixels.",
        "progress_orb_active": "Children's book digital illustration. Small chunky star in bright golden-yellow, radiating warm light. Transparent background. 80x80 pixels.",
        "progress_orb_done": "Children's book digital illustration. Small chunky star in warm green with a tiny sparkle checkmark. Transparent background. 80x80 pixels."
    }
    
    output_dir = Path('sprouts/UI')
    output_dir.mkdir(parents=True, exist_ok=True)
    
    for filename, prompt in ui_prompts.items():
        output_path = output_dir / f"{filename}.png"
        generate_transparent_image(prompt, output_path)
        time.sleep(5) # Delay to respect rate limits

if __name__ == "__main__":
    main()
