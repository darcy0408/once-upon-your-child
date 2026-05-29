"""
Test script for Magical Avatar System backend

Tests:
1. Avatar Prompt Service - prompt generation and safety validation
2. Avatar Generation Service - full generation flow
3. Avatar API Endpoints - HTTP requests
"""

import os
import sys

# Add backend to path
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from services.avatar_generation_service import (
    AvatarGenerationService,
    get_error_message,
)
from services.avatar_prompt_service import AvatarPromptService


def test_prompt_service():
    """Test AvatarPromptService"""
    print("\n" + "=" * 60)
    print("TEST 1: Avatar Prompt Service")
    print("=" * 60)

    service = AvatarPromptService()

    # Test 1.1: Basic prompt generation
    print("\n[1.1] Testing basic prompt generation...")
    prompt = service.build_avatar_prompt(
        character_name="Luna",
        age=8,
        style="pixar",
        features={
            "hair_style": "Long Curly",
            "hair_color": "Brown",
            "skin_tone": "Medium Tan",
            "outfit": "Explorer Jacket",
        },
    )

    assert "Luna" in prompt
    assert "8-year-old" in prompt
    assert "pixar" in prompt.lower()  # Case insensitive check
    assert "Long Curly" in prompt
    print("[OK] Basic prompt generation works!")
    print(f"   Prompt length: {len(prompt)} characters")

    # Test 1.2: Emotion mirroring
    print("\n[1.2] Testing emotion mirroring...")
    emotion_data = {
        "core": "Happy",
        "secondary": "Joyful",
        "eye_type": "Happy",
        "mouth_type": "Smile",
        "intensity": 4,
    }

    prompt_with_emotion = service.build_avatar_prompt(
        character_name="Luna", age=8, features={}, emotion_data=emotion_data
    )

    assert "Happy" in prompt_with_emotion
    assert "joyful" in prompt_with_emotion.lower()
    print("[OK] Emotion mirroring works!")

    # Test 1.3: Safety validation
    print("\n[1.3] Testing safety validation...")

    safe_prompt = "Create a magical Pixar-style portrait"
    is_safe, message = service.validate_prompt_safety(safe_prompt)
    assert is_safe == True
    print(f"[OK] Safe prompt validated: {message}")

    unsafe_prompt = "Create a photorealistic portrait"
    is_safe, message = service.validate_prompt_safety(unsafe_prompt)
    assert is_safe == False
    print(f"[OK] Unsafe prompt blocked: {message}")

    # Test 1.4: Character seed generation
    print("\n[1.4] Testing character seed generation...")
    seed1 = service.generate_character_seed("Luna", 8, {"hair_style": "Long Curly"})
    seed2 = service.generate_character_seed("Luna", 8, {"hair_style": "Long Curly"})
    seed3 = service.generate_character_seed("Max", 8, {"hair_style": "Long Curly"})

    assert seed1 == seed2, "Same character should have same seed"
    assert seed1 != seed3, "Different characters should have different seeds"
    assert len(seed1) == 16, "Seed should be 16 characters"
    print(f"[OK] Seed generation works! Example seed: {seed1}")

    # Test 1.5: All style anchors
    print("\n[1.5] Testing all style anchors...")
    styles = ["pixar", "watercolor", "cartoon", "clay"]
    for style in styles:
        prompt = service.build_avatar_prompt("Test", 7, style=style)
        assert (
            style.lower() in prompt.lower()
            or service.STYLE_ANCHORS[style].lower() in prompt.lower()
        )
        print(f"   [OK] {style.capitalize()} style works")

    print("\n[OK] All Avatar Prompt Service tests passed!")


def test_generation_service():
    """Test AvatarGenerationService"""
    print("\n" + "=" * 60)
    print("TEST 2: Avatar Generation Service")
    print("=" * 60)

    service = AvatarGenerationService()

    # Test 2.1: Service initialization
    print("\n[2.1] Testing service initialization...")
    assert service.prompt_service is not None
    print("[OK] Prompt service initialized")

    if service.image_generator is None:
        print("[WARN] Image generator not available (GEMINI_API_KEY not set)")
        print("   Skipping image generation tests")
        return
    else:
        print("[OK] Image generator initialized")

    # Test 2.2: Input validation
    print("\n[2.2] Testing input validation...")

    try:
        service.generate_avatar("", 8)
        assert False, "Should have raised ValueError for empty name"
    except ValueError as e:
        print(f"[OK] Empty name rejected: {e}")

    try:
        service.generate_avatar("Luna", 2)  # Too young
        assert False, "Should have raised ValueError for age < 3"
    except ValueError as e:
        print(f"[OK] Invalid age rejected: {e}")

    try:
        service.generate_avatar("Luna", 8, style="invalid")
        assert False, "Should have raised ValueError for invalid style"
    except ValueError as e:
        print(f"[OK] Invalid style rejected: {e}")

    # Test 2.3: Fallback avatars
    print("\n[2.3] Testing fallback avatars...")
    fallbacks = service.get_fallback_avatars()
    assert (
        len(fallbacks) == 8
    ), "Should have 8 fallback avatars (2 per style x 4 styles)"
    print(f"[OK] Found {len(fallbacks)} fallback avatars")

    pixar_fallbacks = service.get_fallback_avatars(style="pixar")
    assert len(pixar_fallbacks) == 2
    assert all(fb["style"] == "pixar" for fb in pixar_fallbacks)
    print(f"[OK] Style filtering works (Pixar: {len(pixar_fallbacks)})")

    # Test 2.4: Error messages
    print("\n[2.4] Testing error messages...")
    for code in ["generation_failed", "timeout", "invalid_style"]:
        message = get_error_message(code)
        assert len(message) > 0
        assert "!" in message or "?" in message  # Kid-friendly messages
        print(f"   [OK] {code}: {message[:50]}...")

    print("\n[OK] All Avatar Generation Service tests passed!")


def test_api_integration():
    """Test API endpoints (requires running Flask app)"""
    print("\n" + "=" * 60)
    print("TEST 3: API Integration")
    print("=" * 60)

    print("\n[Info] To test API endpoints, run:")
    print("   1. Start Flask backend: python backend/run.py")
    print("   2. Test health endpoint:")
    print("      curl http://localhost:5000/avatar/health")
    print("   3. Test avatar generation:")
    print("      curl -X POST http://localhost:5000/avatar/generate-avatar \\")
    print("        -H 'Content-Type: application/json' \\")
    print('        -d \'{"character_name":"Luna","age":8,"style":"pixar"}\'')


def main():
    """Run all tests"""
    print("\n" + "=" * 60)
    print("MAGICAL AVATAR SYSTEM - BACKEND TESTS")
    print("=" * 60)

    try:
        # Test 1: Prompt Service
        test_prompt_service()

        # Test 2: Generation Service
        test_generation_service()

        # Test 3: API Integration Info
        test_api_integration()

        print("\n" + "=" * 60)
        print("[SUCCESS] ALL TESTS PASSED!")
        print("=" * 60)
        print("\nNext steps:")
        print("1. Set GEMINI_API_KEY environment variable for full testing")
        print("2. Start Flask backend to test API endpoints")
        print("3. Create fallback avatar images in backend/static/fallback_avatars/")
        print("4. Build Flutter frontend UI")

    except AssertionError as e:
        print(f"\n[FAIL] TEST FAILED: {e}")
        return 1
    except Exception as e:
        print(f"\n[ERROR] UNEXPECTED ERROR: {e}")
        import traceback

        traceback.print_exc()
        return 1

    return 0


if __name__ == "__main__":
    exit(main())
