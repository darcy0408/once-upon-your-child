import os
import time
import json
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
    logger.error("No GEMINI_API_KEY found in environment or .env file.")
    exit(1)

client = genai.Client(api_key=GEMINI_API_KEY)
MODEL_NAME = 'models/imagen-4.0-generate-001'

def generate_image(prompt, output_path, force_generate=False):
    """Generate an image using the Imagen API with retry logic."""
    output_path = Path(output_path)
    
    if output_path.exists() and not force_generate:
        # Check if it's a "blank" file (less than 1KB)
        if output_path.stat().st_size > 1024:
            logger.info(f"Skipping {output_path} (Already exists and not blank)")
            return True
        else:
            logger.info(f"Overwriting {output_path} (File is blank/too small)")

    while True:
        try:
            logger.info(f"Generating image: {output_path}")
            # Detect format from extension
            ext = output_path.suffix.lower()
            mime_type = 'image/png' if ext == '.png' else 'image/jpeg'
            
            response = client.models.generate_images(
                model=MODEL_NAME,
                prompt=prompt,
                config=types.GenerateImagesConfig(
                    number_of_images=1,
                    output_mime_type=mime_type
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
                logger.error(f"No image generated for: {output_path}")
                return False
                
        except Exception as e:
            error_msg = str(e)
            if '429' in error_msg or 'Too Many Requests' in error_msg:
                logger.warning("429 Too Many Requests. Waiting 60 seconds...")
                time.sleep(60)
                continue
            elif '403' in error_msg and 'billing' in error_msg.lower():
                logger.error("Billing not enabled for this project. Cannot use Imagen API.")
                return "STOP"
            else:
                logger.error(f"Error generating {output_path}: {e}")
                time.sleep(10)
                return False

def main():
    try:
        with open("image_tasks.json", "r") as f:
            tasks = json.load(f)
    except FileNotFoundError:
        logger.error("image_tasks.json not found. Run extract_prompts.py first.")
        return

    total = len(tasks)
    success_count = 0
    
    for i, task in enumerate(tasks):
        path = task["output_path"]
        prompt = task["prompt"]
        
        logger.info(f"[{i+1}/{total}] Processing: {path}")
        result = generate_image(prompt, path, force_generate=True)
        
        if result == "STOP":
            logger.error("Encountered fatal billing error. Stopping.")
            break
        elif result:
            success_count += 1
            # Add a delay between successful requests to avoid rate limits
            time.sleep(15)
        else:
            logger.warning(f"Failed to generate: {path}")
            time.sleep(5)

    logger.info(f"Completed! Generated {success_count}/{total} images.")

if __name__ == "__main__":
    main()
