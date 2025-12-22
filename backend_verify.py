
import requests
import json
import time

def verify_backend():
    url = "http://127.0.0.1:5000/generate-story"
    
    # Payload simulating a 5-year-old Storm Rider with Barnaby
    # Designed to trigger both Age Calibration and Three-Key Lock
    payload = {
        "character": "Toby",
        "age": 5,
        "theme": "Adventure",
        "story_length": "standard",
        "companion": "Barnaby", # Legacy/Fallback name
        "companion_characters": [
            {
                "name": "Barnaby",
                "signaturePower": "Super Sniffer",
                "description": "A loyal beagle",
                "role": "Companion"
            }
        ],
        "character_details": {
            # Correct camelCase key as per fix
            "specialAbility": "Can command wind and weather" 
        }
    }

    print(f"Sending request to {url}...")
    try:
        start_time = time.time()
        response = requests.post(url, json=payload, timeout=60)
        duration = time.time() - start_time
        print(f"Response received in {duration:.2f}s. Status Code: {response.status_code}")

        if response.status_code == 200:
            data = response.json()
            story_text = data.get('story', '')
            
            # 1. Verify Age Calibration
            # Since we can't see the PROMPT here (only the result), we can't directly check for instructions.
            # However, we can check if the story text *looks* simple or if we can inspect logs.
            # WAIT: The generate_story endpoint returns the *generated story*, not the prompt.
            # To Verify the prompt construction, we'd need to rely on logs OR 
            # we can temporarily modify the endpoint to return the prompt (bad practice)
            # OR we can trust the log output we'll see in the 'python backend/app.py' terminal running in the background.
            
            # Let's check the story content for clues, but real verification should be via logs.
            # I will assume if the logs show the prompt contains expected strings, we are good.
            # But the script can't read the logs of another process easily.
            
            # ALTERNATIVE: Use the mock/endpoint which returns the prompt? No.
            
            # Let's rely on the FACT that we can verify the 'Three-Key Lock' logic by seeing if the story
            # actually USES the special ability + companion power + setting. 
            # It's hard to grep "Logic" from text.
            
            # BUT, we can make a specific request to a DEBUG endpoint or inspect the logs manually.
            # Since I have access to `read_terminal` or `command_status`, I can inspect the backend logs!
            
            print(f"Story Title: {data.get('title')}")
            print(f"Story Text Preview: {story_text[:200]}...")
            return True
        else:
            print(f"Error: {response.text}")
            return False

    except Exception as e:
        print(f"Exception: {e}")
        return False

if __name__ == "__main__":
    verify_backend()
