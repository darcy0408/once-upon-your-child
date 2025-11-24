"""
Quick test of Gemini image generation
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gemini_image_generator import GeminiImageGenerator

# Test with your API key
generator = GeminiImageGenerator()

print("Testing Gemini image generation...")
print(f"Using model: {generator.image_model._model_name}")

try:
    # Simple test
    result = generator.generate_story_illustration(
        scene_description="A happy 7-year-old girl with curly brown hair discovering a glowing magical crystal in a sunny forest",
        character_name="Isabella",
        style="colorful children's book illustration",
        num_images=1,
        age=7
    )

    if result:
        print(f"✅ SUCCESS! Generated {len(result)} image(s)")
        print(f"   Image ID: {result[0]['id']}")
        print(f"   Format: {result[0]['format']}")
        print(f"   Data length: {len(result[0]['image_data'])} bytes")
    else:
        print("❌ FAILED: No images returned")

except Exception as e:
    print(f"❌ ERROR: {e}")
    import traceback
    traceback.print_exc()
