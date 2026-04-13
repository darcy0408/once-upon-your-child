import requests
import json
import os
import time

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

def generate_story(archetype, companion, custom_elements, token):
    payload = {
        "character": "FeatureTester",
        "character_details": {
            "role": archetype
        } if archetype else None,
        "age": 10,
        "theme": "The Grand Challenge",
        "companion": companion,
        "story_length": "standard",
        "custom_elements": custom_elements
    }
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    
    label = archetype if archetype else f"Custom: {custom_elements}"
    print(f"Generating story for {label}...")
    
    start_time = time.time()
    try:
        resp = requests.post(f"{BASE_URL}/generate-story", json=payload, headers=headers, timeout=180)
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
        
    if not wait_for_backend():
        print("Backend failed to start. Exiting.")
        return

    token = get_auth_token()
    results = []
    
    # 6 Archetype tests
    for i in range(len(ARCHETYPES)):
        archetype = ARCHETYPES[i]
        companion = COMPANIONS[i % len(COMPANIONS)]
        
        story_data, duration = generate_story(archetype, companion, None, token)
        status = "PASS" if story_data else "FAIL"
        results.append({
            "test": f"Archetype: {archetype}",
            "status": status,
            "duration": duration
        })
        if story_data:
            print(f"  Success ({duration:.1f}s)")
        
        # Add delay for stability
        time.sleep(2)
            
    # 1 Custom element test
    custom_elements = "A flying skateboard and a talking robot bird"
    story_data, duration = generate_story(None, "Star Dog", custom_elements, token)
    status = "PASS" if story_data else "FAIL"
    results.append({
        "test": f"Custom Element: {custom_elements}",
        "status": status,
        "duration": duration
    })
    if story_data:
        print(f"  Success ({duration:.1f}s)")
                
    with open(os.path.join(REPORTS_DIR, "summary.json"), 'w') as f:
        json.dump(results, f, indent=2)
    
    passed = sum(1 for r in results if r["status"] == "PASS")
    print(f"\nFeature Verification Complete: {passed}/7 Passed.")

if __name__ == "__main__":
    main()
