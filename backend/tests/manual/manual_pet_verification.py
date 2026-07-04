import os

import requests

# Configuration
BASE_URL = "http://127.0.0.1:5000"
API_KEY = os.environ.get("GEMINI_API_KEY")


def test_custom_pet_story():
    print("Testing Custom Pet Story Generation...")

    payload = {
        "user_id": "test_verifier",
        "theme": "Magical Forest",
        "character": {
            "name": "Alex",
            "age": 7,
            "personality_traits": ["Brave", "Curious"],
        },
        "character_details": {
            "pets": [
                {
                    "name": "Sparky",
                    "species": "Dragon",
                    "personality": "Loves eating marshmallows and sneezing glitter",
                }
            ]
        },
        "companion_name": "Sparky",
    }

    try:
        response = requests.post(f"{BASE_URL}/generate-story", json=payload)
        response.raise_for_status()
        data = response.json()

        print(f"Status Code: {response.status_code}")
        print(f"Response: {data.keys()}")

        story_text = data.get("story_text") or data.get("story") or ""
        print("\n--- Generated Story Snippet ---")
        print(story_text[:500] + "...")

        if "Sparky" in story_text:
            print("\nSUCCESS: 'Sparky' found in story text.")
        else:
            print("\nWARNING: 'Sparky' NOT found in story text.")

        if "marshmallows" in story_text or "glitter" in story_text.lower():
            print("SUCCESS: Personality traits found in story.")
        else:
            print("WARNING: Personality traits NOT found.")

    except Exception as e:
        print(f"Error: {e}")
        if hasattr(e, "response") and e.response:
            print(f"Server Response: {e.response.text}")


if __name__ == "__main__":
    test_custom_pet_story()
