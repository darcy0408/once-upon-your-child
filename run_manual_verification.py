import requests
import json
import os
import time
from datetime import datetime

# Configuration
BASE_URL = "http://127.0.0.1:5000"
REPORTS_DIR = "reports/manual_verification"
AGE_BANDS = [4, 7, 9, 12, 16]
MODES = ["standard", "rhyme", "learning_to_read"]

def get_auth_token():
    try:
        resp = requests.post(f"{BASE_URL}/auth/anonymous")
        if resp.status_code == 200:
            return resp.json().get('access_token')
    except Exception as e:
        print(f"Error getting token: {e}")
    return None

def generate_story(age, mode, token):
    payload = {
        "character": "Alex",
        "age": age,
        "theme": "Adventure",
        "rhyme_time_mode": mode == "rhyme",
        "learning_to_read_mode": mode == "learning_to_read",
        "story_length": "standard"
    }
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    
    print(f"Generating {mode} story for age {age}...")
    start_time = time.time()
    try:
        resp = requests.post(f"{BASE_URL}/generate-story", json=payload, headers=headers, timeout=150)
        duration = time.time() - start_time
        if resp.status_code == 200:
            return resp.json(), duration
        else:
            print(f"Error: {resp.status_code} - {resp.text}")
            return None, duration
    except Exception as e:
        print(f"Request failed: {e}")
        return None, 0

def main():
    if not os.path.exists(REPORTS_DIR):
        os.makedirs(REPORTS_DIR)
        
    token = get_auth_token()
    results = []
    
    for age in AGE_BANDS:
        for mode in MODES:
            if mode == "learning_to_read" and age > 7:
                continue
                
            story_data, duration = generate_story(age, mode, token)
            
            if story_data:
                filename = f"story_age{age}_{mode}_{datetime.now().strftime('%H%M%S')}.json"
                filepath = os.path.join(REPORTS_DIR, filename)
                with open(filepath, 'w') as f:
                    json.dump(story_data, f, indent=2)
                
                story_info = story_data.get('story', {})
                title = story_info.get('title', 'Untitled')
                
                results.append({
                    "age": age,
                    "mode": mode,
                    "duration": duration,
                    "title": title,
                    "file": filepath
                })
                print(f"  Success: {title} ({duration:.1f}s)")
            else:
                print(f"  Failed for age {age}, mode {mode}")
                
    with open(os.path.join(REPORTS_DIR, "summary.json"), 'w') as f:
        json.dump(results, f, indent=2)
    
    print("\nVerification Complete.")
    print(f"Stories saved to: {REPORTS_DIR}")

if __name__ == "__main__":
    main()
