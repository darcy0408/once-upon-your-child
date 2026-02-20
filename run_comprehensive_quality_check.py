import requests
import json
import os
import time
from datetime import datetime

# Configuration
BASE_URL = "http://127.0.0.1:5000"
TIMESTAMP = datetime.now().strftime("%Y%m%d_%H%M%S")
RESULTS_DIR = f"quality_check_results/{TIMESTAMP}"
AGE_BANDS = [3.5, 6, 9, 12, 14, 16.5, 25] # Representing the 7 bands: 3-4, 5-7, 8-10, 11-13, 13-15, 15-18, Adult
AGE_LABELS = ["3-4", "5-7", "8-10", "11-13", "13-15", "15-18", "Adult"]
THEME = "The Brave Little Firefly"
CHARACTER_NAME = "Lumi"

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
        "character": CHARACTER_NAME,
        "age": age,
        "theme": THEME,
        "rhyme_time_mode": mode == "rhyme",
        "learning_to_read_mode": mode == "learning_to_read",
        "story_length": "short"
    }
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    
    endpoint = "/generate-story"
    if mode == "interactive":
        endpoint = "/generate-interactive-story"
        payload = {
            "user_id": "quality_tester",
            "theme": THEME,
            "tone": "adventurous",
            "age": age,
            "must_include": ["glowing wings", "dark forest"]
        }

    print(f"Generating {mode} story for age {age}...")
    start_time = time.time()
    try:
        resp = requests.post(f"{BASE_URL}{endpoint}", json=payload, headers=headers, timeout=180)
        duration = time.time() - start_time
        if resp.status_code == 200:
            return resp.json(), duration
        else:
            print(f"  Error: {resp.status_code} - {resp.text[:200]}")
            return None, duration
    except Exception as e:
        print(f"  Request failed: {e}")
        return None, 0

def main():
    if not os.path.exists(RESULTS_DIR):
        os.makedirs(RESULTS_DIR)
        
    token = get_auth_token()
    summary = []
    
    modes = ["standard", "rhyme", "learning_to_read", "interactive"]
    
    for age, label in zip(AGE_BANDS, AGE_LABELS):
        print(f"\n--- Testing Age Band: {label} ({age}) ---")
        for mode in modes:
            # Skip modes not applicable to age
            if mode == "learning_to_read" and age > 9:
                continue
                
            result_data, duration = generate_story(age, mode, token)
            
            if result_data:
                filename = f"age{label}_{mode}.json"
                filepath = os.path.join(RESULTS_DIR, filename)
                with open(filepath, 'w', encoding='utf-8') as f:
                    json.dump(result_data, f, indent=2, ensure_ascii=False)
                
                title = "Unknown"
                if mode == "interactive":
                    title = "Interactive Segment"
                else:
                    title = result_data.get('story', {}).get('title', 'Untitled')
                
                summary.append({
                    "age_label": label,
                    "age": age,
                    "mode": mode,
                    "duration": duration,
                    "title": title,
                    "file": filepath,
                    "status": "Success"
                })
                print(f"  Success: {title} ({duration:.1f}s)")
            else:
                summary.append({
                    "age_label": label,
                    "age": age,
                    "mode": mode,
                    "status": "Failed"
                })
                print(f"  FAILED for age {label}, mode {mode}")
                
    with open(os.path.join(RESULTS_DIR, "summary.json"), 'w', encoding='utf-8') as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)
    
    print("\nQuality Check Complete.")
    print(f"Results saved to: {RESULTS_DIR}")

if __name__ == "__main__":
    main()
