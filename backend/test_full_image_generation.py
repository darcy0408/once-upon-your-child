"""
Test complete image generation setup
"""
import os
import sys
from dotenv import load_dotenv
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

load_dotenv()

from openrouter_image_generator import OpenRouterImageGenerator
from gemini_image_generator import GeminiImageGenerator

def test_complete_setup():
    print("=== Testing Complete Image Generation Setup ===\n")
    
    # Test OpenRouter (primary)
    print("1. Testing OpenRouter (Primary)...")
    openrouter_key = os.getenv("OPENROUTER_API_KEY")
    if openrouter_key:
        try:
            generator = OpenRouterImageGenerator(api_key=openrouter_key)
            result = generator.generate_story_illustration(
                scene_description="A happy child with a red balloon",
                character_name="Emma",
                num_images=1
            )
            
            if result and len(result) > 0:
                print("   ✓ OpenRouter: SUCCESS - Image generation working!")
                print(f"   ✓ Generated {len(result)} image(s)")
                return True, "openrouter"
            else:
                print("   ✗ OpenRouter: No images returned")
        except Exception as e:
            print(f"   ✗ OpenRouter: Error - {e}")
    else:
        print("   ✗ OpenRouter: No API key found")
    
    # Test Gemini (fallback)
    print("\n2. Testing Gemini (Fallback)...")
    gemini_key = os.getenv("GEMINI_API_KEY")
    if gemini_key:
        try:
            generator = GeminiImageGenerator(api_key=gemini_key)
            result = generator.generate_story_illustration(
                scene_description="A happy child with a red balloon",
                character_name="Emma",
                num_images=1
            )
            
            if result and len(result) > 0:
                print("   ✓ Gemini: SUCCESS - Image generation working!")
                print(f"   ✓ Generated {len(result)} image(s)")
                return True, "gemini"
            else:
                print("   ✗ Gemini: No images returned")
        except Exception as e:
            print(f"   ✗ Gemini: Error - {e}")
    else:
        print("   ✗ Gemini: No API key found")
    
    return False, None

def test_app_integration():
    print("\n3. Testing App Integration...")
    
    # Simulate app.py initialization logic
    openrouter_key = os.getenv("OPENROUTER_API_KEY")
    gemini_key = os.getenv("GEMINI_API_KEY")
    
    image_generator = None
    
    try:
        if openrouter_key:
            image_generator = OpenRouterImageGenerator(api_key=openrouter_key)
            print("   ✓ App would use OpenRouter (cost-optimized)")
        elif gemini_key:
            image_generator = GeminiImageGenerator(api_key=gemini_key)
            print("   ✓ App would use Gemini (fallback)")
        else:
            print("   ✗ App would have no image generator")
            
        if image_generator:
            # Test a quick generation
            result = image_generator.generate_story_illustration(
                scene_description="Test scene",
                character_name="Test",
                num_images=1
            )
            if result:
                print("   ✓ App integration test: SUCCESS")
                return True
            else:
                print("   ✗ App integration test: No images")
                return False
        else:
            return False
            
    except Exception as e:
        print(f"   ✗ App integration test: Error - {e}")
        return False

if __name__ == "__main__":
    print("Testing image generation for Story Weaver App...\n")
    
    # Test individual generators
    success, working_generator = test_complete_setup()
    
    # Test app integration
    app_success = test_app_integration()
    
    print(f"\n=== RESULTS ===")
    if success:
        print(f"✓ Image generation is working via {working_generator}")
    else:
        print("✗ No image generators are working")
        
    if app_success:
        print("✓ App integration is working")
    else:
        print("✗ App integration failed")
        
    print(f"\n=== RECOMMENDATIONS ===")
    if success and app_success:
        print("✓ Your image generation is fully functional!")
        print("✓ Users can generate illustrations and coloring pages")
    elif success:
        print("⚠ Image generation works but app integration needs fixing")
    else:
        print("✗ Image generation needs to be fixed")
        print("  - Check API keys in .env file")
        print("  - Verify API quotas/billing")
        print("  - Try again later if quota exceeded")