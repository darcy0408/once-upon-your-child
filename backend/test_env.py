"""
Test environment variable loading
"""
import os
from dotenv import load_dotenv

print("Testing environment variable loading...")

# Load .env file
load_dotenv()

# Check both API keys
gemini_key = os.getenv("GEMINI_API_KEY")
openrouter_key = os.getenv("OPENROUTER_API_KEY")

print(f"GEMINI_API_KEY: {'Found' if gemini_key else 'Not found'}")
if gemini_key:
    print(f"  Length: {len(gemini_key)}")
    print(f"  Prefix: {gemini_key[:10]}...")

print(f"OPENROUTER_API_KEY: {'Found' if openrouter_key else 'Not found'}")
if openrouter_key:
    print(f"  Length: {len(openrouter_key)}")
    print(f"  Prefix: {openrouter_key[:10]}...")

# Test OpenRouter if key exists
if openrouter_key:
    print("\nTesting OpenRouter with loaded key...")
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    
    from openrouter_image_generator import OpenRouterImageGenerator
    
    try:
        generator = OpenRouterImageGenerator(api_key=openrouter_key)
        print("Generator initialized successfully")
        
        # Simple test
        result = generator.generate_story_illustration(
            scene_description="A red ball",
            character_name="Test",
            num_images=1
        )
        
        print(f"Result: {len(result) if result else 0} images generated")
        if result:
            print("SUCCESS: Image generation working!")
        else:
            print("No images returned")
            
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
else:
    print("\nSkipping OpenRouter test - no API key found")