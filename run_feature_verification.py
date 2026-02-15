import requests
import json
import os
import time
from datetime import datetime

# Configuration
BASE_URL = "http://127.0.0.1:5000"
REPORTS_DIR = "reports/feature_verification"

ARCHETYPES = [
    "The Bold Adventurer",
    "The Logic Luminary",
    "The Creative Catalyst",
    "The Heart Hero",
    "The Energy Engine",
    "The Quiet Observer"
]

COMPANIONS = [
    "Star Dog",
    "Shadow Cat",
    "Tiny Dragon",
    "Wise Owl",
    "Magic Unicorn",
    "Clever Fox"
]

def get_auth_token():
    try:
        resp = requests.post(f"{BASE_URL}/auth/anonymous")
        if resp.status_code == 200:
            return resp.json().get('access_token')
    except Exception as e:
        print(f"Error getting token: {e}")
    return None

def generate_story(archetype, companion, token):
    payload = {
        "character": "Alex",
        "character_details": {
            "role": archetype
        },
        "age": 8,
        "theme": "Adventure",
        "companion": companion,
        "story_length": "quick"
    }
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    
    print(f"Generating story for {archetype} with {companion}...")
    start_time = time.time()
    try:
        resp = requests.post(f"{BASE_URL}/generate-story", json=payload, headers=headers, timeout=150)
        duration = time.time() - start_time
        if resp.status_code == 200:
            return resp.json(), duration
        else:
            print(f"  Error: {resp.status_code}")
            return None, duration
    except Exception as e:
        print(f"  Request failed: {e}")
        return None, 0

def main():
    if not os.path.exists(REPORTS_DIR):
        os.makedirs(REPORTS_DIR)
        
    token = get_auth_token()
    results = []
    
    for i in range(len(ARCHETYPES)):
        archetype = ARCHETYPES[i]
        companion = COMPANIONS[i % len(COMPANIONS)]
        
        story_data, duration = generate_story(archetype, companion, token)
        
        if story_data:
            safe_arch = archetype.replace(' ', '_').replace("'", "")
            safe_comp = companion.replace(' ', '_')
            filename = f"story_{safe_arch}_{safe_comp}.json"
            filepath = os.path.join(REPORTS_DIR, filename)
            with open(filepath, 'w') as f:
                json.dump(story_data, f, indent=2)
            
            story_info = story_data.get('story', {})
            results.append({
                "archetype": archetype,
                "companion": companion,
                "duration": duration,
                "title": story_info.get('title'),
                "file": filepath
            })
            print(f"  Success: {story_info.get('title')} ({duration:.1f}s)")
        else:
            print(f"  Failed for {archetype}")
                
    with open(os.path.join(REPORTS_DIR, "summary.json"), 'w') as f:
        json.dump(results, f, indent=2)
    
    print("\nFeature Verification Complete.")
    print(f"Stories saved to: {REPORTS_DIR}")

if __name__ == "__main__":
    main()
