"""
Simple test to verify image generation fixes
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from openrouter_image_generator import OpenRouterImageGenerator

def test_openrouter():
    print("Testing OpenRouter image generation...")
    
    # Check API key
    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        print("ERROR: OPENROUTER_API_KEY not found in environment")
        return False
    
    print(f"API Key found: {api_key[:10]}...")
    
    # Initialize generator
    try:
        generator = OpenRouterImageGenerator(api_key=api_key)
        print("Generator initialized successfully")
    except Exception as e:
        print(f"ERROR initializing generator: {e}")
        return False
    
    # Test simple generation
    try:
        print("Attempting to generate a simple image...")
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
            print(f"Has image_url: {'image_url' in result[0]}")
            if 'image_url' in result[0]:
                url_preview = str(result[0]['image_url'])[:50]
                print(f"URL preview: {url_preview}...")
            return True
        else:
            print("FAILED: No images returned")
            return False
            
    except Exception as e:
        print(f"ERROR during generation: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_openrouter()
    if success:
        print("\n✓ Image generation is working!")
    else:
        print("\n✗ Image generation failed")