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

# Collect all available API keys
keys = [
    os.getenv('GEMINI_API_KEY'),
    os.getenv('GOOGLE_API_KEY_2'),
    os.getenv('GOOGLE_API_KEY_3'),
    os.getenv('GOOGLE_API_KEY_4')
]
keys = [k for k in keys if k]

if not keys:
    logger.error("No Gemini/Google API keys found in environment or .env file.")
    exit(1)

clients = [genai.Client(api_key=k) for k in keys]
MODEL_NAME = 'models/imagen-4.0-generate-001'

def generate_image(prompt, output_path, force_generate=True):
    """Generate an image using the Imagen API with retry and key rotation logic."""
    output_path = Path(output_path)
    
    if output_path.exists() and not force_generate:
        if output_path.stat().st_size > 1024:
            logger.info(f"Skipping {output_path} (Already exists and not blank)")
            return True

    key_index = 0
    attempts = 0
    max_attempts = len(clients) * 2 # Try each key twice before long wait

    while True:
        client = clients[key_index]
        try:
            logger.info(f"Generating image (Key {key_index + 1}/{len(clients)}): {output_path}")
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
                attempts += 1
                if attempts < max_attempts:
                    logger.warning(f"Key {key_index + 1} rate limited. Rotating to next key...")
                    key_index = (key_index + 1) % len(clients)
                    time.sleep(2) # Short pause before trying next key
                    continue
                else:
                    logger.warning("All keys rate limited. Waiting 60 seconds...")
                    attempts = 0 # Reset attempts after long wait
                    time.sleep(60)
                    continue
            elif '403' in error_msg and 'billing' in error_msg.lower():
                logger.error(f"Billing not enabled for Key {key_index + 1}. Removing from rotation.")
                clients.pop(key_index)
                if not clients:
                    logger.error("No valid keys remaining.")
                    return "STOP"
                key_index = key_index % len(clients)
                continue
            else:
                logger.error(f"Error generating {output_path} with Key {key_index + 1}: {e}")
                time.sleep(10)
                return False

import sys

def main():
    task_file = "priority_image_tasks.json"
    if len(sys.argv) > 1:
        task_file = sys.argv[1]
        
    try:
        with open(task_file, "r", encoding='utf-8') as f:
            tasks = json.load(f)
    except FileNotFoundError:
        logger.error(f"{task_file} not found.")
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
            time.sleep(15) # Delay to avoid rate limits
        else:
            logger.warning(f"Failed to generate: {path}")
            time.sleep(5)

    logger.info(f"Completed! Generated {success_count}/{total} priority images.")

if __name__ == "__main__":
    main()
