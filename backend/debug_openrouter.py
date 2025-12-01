import os
import sys
import logging
from dotenv import load_dotenv
from pathlib import Path

# Load environment variables
env_path = Path(__file__).parent / '.env'
load_dotenv(dotenv_path=env_path)

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import openrouter_image_generator
from openrouter_image_generator import OpenRouterImageGenerator

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

print(f"DEBUG: openrouter_image_generator file: {openrouter_image_generator.__file__}")

def test():
    api_key = os.getenv("OPENROUTER_API_KEY")
    print(f"DEBUG: API Key present: {bool(api_key)}")
    
    generator = OpenRouterImageGenerator(api_key=api_key)
    print("DEBUG: Generator initialized")
    
    try:
        # Use a very simple prompt
        illustrations = generator.generate_story_illustration(
            scene_description="A simple red ball",
            character_name="Ball",
            num_images=1
        )
        
        if illustrations:
            print(f"✅ Generated {len(illustrations)} images")
            img = illustrations[0]
            print("Image Keys:", list(img.keys()))
            print("Image ID:", img.get('id'))
            print("Image URL len:", len(img.get('image_url', '')))
        else:
            print("❌ No images generated")
            
    except Exception as e:
        logger.exception("Test failed")

if __name__ == "__main__":
    test()
