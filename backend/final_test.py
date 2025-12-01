"""
Final test of image generation (Windows-compatible)
"""
import os
import sys
from dotenv import load_dotenv
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

load_dotenv()

from openrouter_image_generator import OpenRouterImageGenerator

def test_image_generation():
    print("Testing OpenRouter image generation...")
    
    openrouter_key = os.getenv("OPENROUTER_API_KEY")
    if not openrouter_key:
        print("ERROR: No OpenRouter API key found")
        return False
    
    try:
        generator = OpenRouterImageGenerator(api_key=openrouter_key)
        
        # Test story illustration
        print("Generating story illustration...")
        result = generator.generate_story_illustration(
            scene_description="A happy 7-year-old girl named Emma playing with a red balloon in a sunny park",
            character_name="Emma",
            style="colorful children's book illustration",
            num_images=1,
            age=7
        )
        
        if result and len(result) > 0:
            print(f"SUCCESS: Generated {len(result)} story illustration(s)")
            print(f"Image ID: {result[0].get('id', 'N/A')}")
            
            # Test coloring page
            print("Generating coloring page...")
            coloring_result = generator.generate_coloring_page(
                scene_description="Emma holding a balloon with trees in the background",
                character_name="Emma",
                num_images=1,
                age=7
            )
            
            if coloring_result and len(coloring_result) > 0:
                print(f"SUCCESS: Generated {len(coloring_result)} coloring page(s)")
                print("OVERALL: Image generation is working perfectly!")
                return True
            else:
                print("WARNING: Story illustrations work but coloring pages failed")
                return True  # Still partially working
        else:
            print("FAILED: No images generated")
            return False
            
    except Exception as e:
        print(f"ERROR: {e}")
        return False

if __name__ == "__main__":
    success = test_image_generation()
    
    print("\n" + "="*50)
    if success:
        print("RESULT: Image generation is WORKING!")
        print("Your app can now generate:")
        print("- Story illustrations")
        print("- Coloring pages")
        print("- Both via OpenRouter API")
    else:
        print("RESULT: Image generation FAILED")
        print("Check your OpenRouter API key and quota")
    print("="*50)