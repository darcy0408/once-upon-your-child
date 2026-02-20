import requests
import json
import os
import time

# Configuration
BASE_URL = "http://127.0.0.1:5000"
REPORTS_DIR = "reports/duration_testing"
AGE_BANDS = [4, 7, 9, 12, 16]
LENGTHS = ["quick", "standard", "epic"]

def wait_for_backend():
    print("Waiting for backend to be ready...")
    for _ in range(30):
        try:
            resp = requests.get(f"{BASE_URL}/health", timeout=2)
            if resp.status_code == 200:
                print("Backend is ready!")
                return True
        except:
            pass
        time.sleep(2)
    return False

def get_auth_token():
    try:
        resp = requests.post(f"{BASE_URL}/auth/anonymous")
        if resp.status_code == 200:
            return resp.json().get('token')
    except Exception as e:
        print(f"Error getting token: {e}")
    return None

def generate_story(age, length, token):
    payload = {
        "character": "DurationTester",
        "age": age,
        "theme": "A Long Journey",
        "story_length": length
    }
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    
    print(f"Generating {length} story for age {age}...")
    start_time = time.time()
    try:
        resp = requests.post(f"{BASE_URL}/generate-story", json=payload, headers=headers, timeout=240)
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
        
    if not wait_for_backend():
        print("Backend failed to start. Exiting.")
        return

    token = get_auth_token()
    results = []
    
    total_expected = len(AGE_BANDS) * len(LENGTHS)
    current = 0
    
    for age in AGE_BANDS:
        for length in LENGTHS:
            current += 1
            print(f"[{current}/{total_expected}] Age: {age}, Length: {length}")
            story_data, duration = generate_story(age, length, token)
            
            status = "PASS" if story_data else "FAIL"
            word_count = 0
            if story_data:
                story_info = story_data.get('story', {})
                story_text = story_info.get('story_text', '')
                word_count = len(story_text.split())
                print(f"  Success: {word_count} words ({duration:.1f}s)")
            
            results.append({
                "age": age,
                "length": length,
                "status": status,
                "duration": duration,
                "word_count": word_count
            })
            # Add delay for stability
            time.sleep(2)
                
    with open(os.path.join(REPORTS_DIR, "summary.json"), 'w') as f:
        json.dump(results, f, indent=2)
    
    passed = sum(1 for r in results if r["status"] == "PASS")
    print(f"\nStory Duration Testing Complete: {passed}/{total_expected} Passed.")

if __name__ == "__main__":
    main()
