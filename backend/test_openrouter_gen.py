"""
Test script for OpenRouter image generation
Run this to verify the fix for OpenRouter integration.
"""
import os
import sys
import logging
from dotenv import load_dotenv
from pathlib import Path

# Load environment variables from backend/.env file explicitly
env_path = Path(__file__).parent / '.env'
load_dotenv(dotenv_path=env_path)

# Add current directory to path so we can import backend modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from openrouter_image_generator import OpenRouterImageGenerator

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def test_openrouter_generation():
    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        logger.error(f"OPENROUTER_API_KEY not set. Checked {env_path.absolute()}")
        return

    logger.info(f"Testing with API Key: {api_key[:5]}...{api_key[-5:]}")
    
    generator = OpenRouterImageGenerator(api_key=api_key)

    print("\n" + "="*50)
    print("TEST 1: Story Illustration")
    print("="*50)
    
    try:
        illustrations = generator.generate_story_illustration(
            scene_description="A cute robot helping a cat stuck in a tree",
            character_name="Robo",
            style="cartoon",
            num_images=1
        )
        
        if illustrations:
            print(f"SUCCESS! Generated {len(illustrations)} illustration(s)")
            img = illustrations[0]
            print("   Image Details:")
            for k, v in img.items():
                if k == 'image_url':
                    print(f"   - {k}: {str(v)[:50]}... (len={len(str(v))})")
                else:
                    print(f"   - {k}: {v}")
        else:
            print("FAILED: No illustrations returned")
            
    except Exception as e:
        logger.exception("Test 1 failed with exception")

    print("\n" + "="*50)
    print("TEST 2: Coloring Page")
    print("="*50)

    try:
        pages = generator.generate_coloring_page(
            scene_description="A robot holding a flower",
            character_name="Robo",
            num_images=1
        )

        if pages:
            print(f"SUCCESS! Generated {len(pages)} coloring page(s)")
            img = pages[0]
            # Create a safe copy for printing
            safe_img = img.copy()
            if 'image_url' in safe_img and len(safe_img['image_url']) > 100:
                safe_img['image_url'] = safe_img['image_url'][:50] + "..." + safe_img['image_url'][-20:]
                
            print(f"   Image Object Keys: {list(img.keys())}")
            print(f"   ID: {img.get('id')}")
            url = img.get('image_url', '')
            print(f"   URL/Data length: {len(url)}")
        else:
            print("FAILED: No coloring pages returned")

    except Exception as e:
        logger.exception("Test 2 failed with exception")

if __name__ == "__main__":
    test_openrouter_generation()
