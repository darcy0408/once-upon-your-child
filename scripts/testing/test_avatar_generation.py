"""
Quick Avatar Generation Test

This script tests the avatar generation system end-to-end.
Run this to verify that avatar generation is working!
"""
import requests
import json
import base64
from datetime import datetime

# Backend URL
BACKEND_URL = "http://127.0.0.1:5000"

def save_avatar_image(base64_data, filename):
    """Save base64 image to file"""
    # Remove data URI prefix if present
    if "base64," in base64_data:
        base64_data = base64_data.split("base64,")[1]

    # Decode and save
    image_data = base64.b64decode(base64_data)
    with open(filename, "wb") as f:
        f.write(image_data)
    print(f"   Saved avatar to: {filename}")


def test_health():
    """Test 1: Health Check"""
    print("\n" + "="*60)
    print("TEST 1: Health Check")
    print("="*60)

    try:
        response = requests.get(f"{BACKEND_URL}/avatar/health")
        print(f"\nStatus: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")

        if response.status_code == 200:
            print("\n[OK] Avatar service is healthy!")
            return True
        else:
            print("\n[FAIL] Avatar service not healthy")
            return False
    except Exception as e:
        print(f"\n[ERROR] Could not connect to backend: {e}")
        print("\nMake sure the Flask backend is running!")
        print("Run: python backend/run.py")
        return False


def test_generate_avatar():
    """Test 2: Generate Avatar"""
    print("\n" + "="*60)
    print("TEST 2: Generate Avatar")
    print("="*60)

    # Test request
    payload = {
        "character_name": "Luna",
        "age": 8,
        "style": "pixar",
        "features": {
            "hair_style": "Long Curly",
            "hair_color": "Brown",
            "skin_tone": "Medium Tan",
            "outfit": "Explorer Jacket",
            "expression": "Happy"
        },
        "emotion_data": {
            "core": "Happy",
            "secondary": "Joyful",
            "eye_type": "Happy",
            "mouth_type": "Smile"
        }
    }

    print(f"\nGenerating avatar for: {payload['character_name']}")
    print(f"Age: {payload['age']}, Style: {payload['style']}")
    print("\nSending request... (this may take 5-10 seconds)")

    try:
        response = requests.post(
            f"{BACKEND_URL}/avatar/generate-avatar",
            json=payload,
            timeout=30
        )

        print(f"\nStatus: {response.status_code}")

        if response.status_code == 200:
            result = response.json()

            if result['status'] == 'success':
                avatar = result['avatar']
                print("\n[SUCCESS] Avatar generated!")
                print(f"   Avatar ID: {avatar['id']}")
                print(f"   Seed: {avatar['seed']}")
                print(f"   Style: {avatar['style']}")
                print(f"   Generation time: {avatar['generation_time_ms']}ms")

                # Save the image
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"avatar_luna_{timestamp}.png"
                save_avatar_image(avatar['image_base64'], filename)

                print(f"\n   Open {filename} to see your avatar!")
                return True
            else:
                print(f"\n[FAIL] Generation failed: {result.get('message')}")
                return False
        else:
            print(f"\n[FAIL] Request failed")
            print(f"Response: {response.text}")
            return False

    except requests.exceptions.Timeout:
        print("\n[ERROR] Request timed out (Gemini may be slow)")
        print("Try again - sometimes the first request takes longer")
        return False
    except Exception as e:
        print(f"\n[ERROR] {e}")
        return False


def test_different_styles():
    """Test 3: Generate Multiple Styles"""
    print("\n" + "="*60)
    print("TEST 3: Generate Multiple Styles")
    print("="*60)

    styles = ["pixar", "watercolor", "cartoon", "clay"]

    print("\nGenerating 4 avatars with different styles...")
    print("(This will take about 30-40 seconds)\n")

    for style in styles:
        print(f"\nGenerating {style.upper()} style avatar...")

        payload = {
            "character_name": "Alex",
            "age": 10,
            "style": style,
            "features": {
                "hair_style": "Short Spiky",
                "hair_color": "Black",
                "skin_tone": "Light",
                "outfit": "Superhero Cape"
            }
        }

        try:
            response = requests.post(
                f"{BACKEND_URL}/avatar/generate-avatar",
                json=payload,
                timeout=30
            )

            if response.status_code == 200:
                result = response.json()
                if result['status'] == 'success':
                    avatar = result['avatar']
                    filename = f"avatar_alex_{style}.png"
                    save_avatar_image(avatar['image_base64'], filename)
                    print(f"   [OK] {style.capitalize()} avatar saved!")
                else:
                    print(f"   [FAIL] {result.get('message')}")
            else:
                print(f"   [FAIL] Status {response.status_code}")

        except Exception as e:
            print(f"   [ERROR] {e}")

    print("\n[COMPLETE] Check your current directory for avatar images!")


def test_fallback_avatars():
    """Test 4: Get Fallback Avatars"""
    print("\n" + "="*60)
    print("TEST 4: Fallback Avatars")
    print("="*60)

    try:
        response = requests.get(f"{BACKEND_URL}/avatar/fallback-avatars")

        if response.status_code == 200:
            result = response.json()
            fallbacks = result['fallback_avatars']

            print(f"\n[OK] Found {len(fallbacks)} fallback avatars:")
            for fb in fallbacks:
                print(f"   - {fb['id']}: {fb['style']} ({fb['preview_url']})")

            return True
        else:
            print(f"\n[FAIL] Status {response.status_code}")
            return False

    except Exception as e:
        print(f"\n[ERROR] {e}")
        return False


def main():
    """Run all tests"""
    print("\n" + "="*60)
    print("MAGICAL AVATAR SYSTEM - LIVE TESTING")
    print("="*60)

    # Test 1: Health check
    if not test_health():
        print("\n" + "="*60)
        print("BACKEND NOT RUNNING")
        print("="*60)
        print("\nTo start the backend, run:")
        print("   python backend/run.py")
        print("\nOr:")
        print("   cd backend && python run.py")
        return

    # Test 2: Generate single avatar
    print("\n\nPress Enter to generate a test avatar, or Ctrl+C to skip...")
    try:
        input()
        test_generate_avatar()
    except KeyboardInterrupt:
        print("\n[SKIPPED]")

    # Test 3: Multiple styles
    print("\n\nPress Enter to test all 4 styles (takes ~40 seconds), or Ctrl+C to skip...")
    try:
        input()
        test_different_styles()
    except KeyboardInterrupt:
        print("\n[SKIPPED]")

    # Test 4: Fallback avatars
    test_fallback_avatars()

    print("\n" + "="*60)
    print("TESTING COMPLETE!")
    print("="*60)
    print("\nCheck your current directory for generated avatar images!")
    print("\nNext steps:")
    print("1. Review the generated avatars")
    print("2. Adjust prompts in avatar_prompt_service.py if needed")
    print("3. Start building the Flutter frontend!")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n[CANCELLED] Testing stopped by user")
    except Exception as e:
        print(f"\n[ERROR] Unexpected error: {e}")
        import traceback
        traceback.print_exc()
