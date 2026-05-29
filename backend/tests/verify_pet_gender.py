import requests
import json
import os
import sys

# Configuration
BASE_URL = "http://127.0.0.1:5000"
API_KEY = os.environ.get("GEMINI_API_KEY")


def verify_pet_gender():
    print("Testing Pet Gender Verification...")

    # Test case: Female Dog tailored to fail if gender is ignored (defaulting to him/it)
    # We explicitly ask for a specific gender to be respected
    payload = {
        "user_id": "test_verifier_gender",
        "theme": "Backyard Adventure",
        "character": {
            "name": "Alex",
            "age": 7,
        },
        "character_details": {
            "pets": [
                {
                    "name": "Kassidy",
                    "species": "Dog",
                    "gender": "Girl",
                    "personality": "Sweet and fierce",
                }
            ]
        },
        "companion_name": "Kassidy",
    }

    try:
        response = requests.post(f"{BASE_URL}/generate-story", json=payload)
        response.raise_for_status()
        data = response.json()

        story_text = data.get("story_text") or data.get("story") or ""
        print("\n--- Generated Story Snippet ---")
        print(story_text[:500] + "...")

        lower_story = story_text.lower()

        # Check for presence of "she" or "her" in proximity to Kassidy
        # This is a bit rough, but a good first pass
        if "kassidy" in lower_story:
            print("\nSUCCESS: 'Kassidy' found in story text.")

            # Simple heuristic: Count pronouns
            she_count = lower_story.count(" she ") + lower_story.count(" her ")
            he_count = lower_story.count(" he ") + lower_story.count(" his ")

            print(f"Pronoun check: 'she/her': {she_count}, 'he/his': {he_count}")

            if she_count > 0:
                print("SUCCESS: Female pronouns found.")
            else:
                print("WARNING: No female pronouns found. Might be an issue.")

        else:
            print("\nWARNING: 'Kassidy' NOT found in story text.")

    except Exception as e:
        print(f"Error: {e}")
        if hasattr(e, "response") and e.response:
            print(f"Server Response: {e.response.text}")


if __name__ == "__main__":
    verify_pet_gender()
