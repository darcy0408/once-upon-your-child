"""
Test Gemini image generation with correct model
"""
import os
import sys
from dotenv import load_dotenv
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

load_dotenv()

from gemini_image_generator import GeminiImageGenerator

def test_gemini_image():
    print("Testing Gemini image generation...")
    
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("No Gemini API key found")
        return False
    
    try:
        generator = GeminiImageGenerator(api_key=api_key)
        print(f"Using model: {generator.image_model._model_name}")
        
        # Test simple generation
        result = generator.generate_story_illustration(
            scene_description="A happy child reading a book",
            character_name="Alex",
            style="simple children's book illustration",
            num_images=1,
            age=7
        )
        
        if result and len(result) > 0:
            print(f"SUCCESS! Generated {len(result)} image(s)")
            print(f"Image ID: {result[0].get('id', 'N/A')}")
            print(f"Has image_data: {'image_data' in result[0]}")
            if 'image_data' in result[0]:
                data_preview = str(result[0]['image_data'])[:50]
                print(f"Data preview: {data_preview}...")
            return True
        else:
            print("No images returned")
            return False
            
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_gemini_image()
    if success:
        print("\nGemini image generation is working!")
    else:
        print("\nGemini image generation failed")