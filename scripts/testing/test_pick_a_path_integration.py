import requests
import json
import os
import time

# Configuration
BASE_URL = "http://127.0.0.1:5000"
REPORTS_DIR = "reports/pick_a_path_testing"

SCENARIOS = [
    {"age": 5, "theme": "Magic Forest", "length": "short"},
    {"age": 8, "theme": "Space Station", "length": "medium"},
    {"age": 12, "theme": "Ocean Depths", "length": "long"},
    {"age": 16, "theme": "Cyberpunk City", "length": "short"},
    {"age": 9, "theme": "Ancient Egypt", "length": "medium"}
]

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

def test_scenario(scenario, token):
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    
    # 1. Start Story
    print(f"Starting {scenario['length']} adventure for age {scenario['age']} (Theme: {scenario['theme']})...")
    payload = {
        "user_id": "test_user_pap",
        "character_id": "test_char_pap",
        "theme": scenario['theme'],
        "tone": "adventurous",
        "length": scenario['length'],
        "age": scenario['age']
    }
    
    start_time = time.time()
    try:
        resp = requests.post(f"{BASE_URL}/generate-interactive-story", json=payload, headers=headers, timeout=180)
        if resp.status_code != 200:
            print(f"  Error starting: {resp.status_code} - {resp.text}")
            return "FAIL", time.time() - start_time
        
        data = resp.json()
        story_id = data.get('story_id')
        segment = data.get('segment', {})
        choices = segment.get('choices', [])
        
        if not story_id or not choices:
            print(f"  Error: Missing story_id or choices")
            return "FAIL", time.time() - start_time
        
        # 2. Make one choice
        choice_id = choices[0].get('id')
        print(f"  Making choice: {choices[0].get('text')}...")
        
        cont_payload = {
            "story_id": story_id,
            "choice_id": choice_id
        }
        
        resp_cont = requests.post(f"{BASE_URL}/continue-interactive-story", json=cont_payload, headers=headers, timeout=180)
        duration = time.time() - start_time
        
        if resp_cont.status_code == 200:
            print(f"  Success! Story continued. ({duration:.1f}s)")
            return "PASS", duration
        else:
            print(f"  Error continuing: {resp_cont.status_code} - {resp_cont.text}")
            return "FAIL", duration
            
    except Exception as e:
        print(f"  Request failed: {e}")
        return "FAIL", 0

def main():
    if not os.path.exists(REPORTS_DIR):
        os.makedirs(REPORTS_DIR)
        
    if not wait_for_backend():
        print("Backend failed to start. Exiting.")
        return

    token = get_auth_token()
    results = []
    
    for i, scenario in enumerate(SCENARIOS):
        print(f"[{i+1}/{len(SCENARIOS)}] Scenario: {scenario['theme']}")
        status, duration = test_scenario(scenario, token)
        results.append({
            "scenario": scenario,
            "status": status,
            "duration": duration
        })
        time.sleep(2)
        
    with open(os.path.join(REPORTS_DIR, "summary.json"), 'w') as f:
        json.dump(results, f, indent=2)
        
    passed = sum(1 for r in results if r["status"] == "PASS")
    print(f"\nPick-A-Path Testing Complete: {passed}/{len(SCENARIOS)} Passed.")

if __name__ == "__main__":
    main()
