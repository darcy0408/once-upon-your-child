"""
Quick non-interactive avatar generation test
"""
import requests
import json
import base64
from datetime import datetime

BACKEND_URL = "http://127.0.0.1:5000"

print("\n" + "="*60)
print("QUICK AVATAR TEST")
print("="*60)

# Test avatar generation
payload = {
    "character_name": "Luna",
    "age": 8,
    "style": "pixar",
    "features": {
        "hair_style": "Long Curly",
        "hair_color": "Brown",
        "skin_tone": "Medium Tan",
        "outfit": "Explorer Jacket"
    }
}

print(f"\nGenerating Pixar avatar for Luna (age 8)...")
print("This may take 10-20 seconds...\n")

try:
    response = requests.post(
        f"{BACKEND_URL}/avatar/generate-avatar",
        json=payload,
        timeout=60
    )

    print(f"Status: {response.status_code}")

    if response.status_code == 200:
        result = response.json()
        if result['status'] == 'success':
            avatar = result['avatar']
            print("\n[SUCCESS] Avatar generated!")
            print(f"  ID: {avatar['id']}")
            print(f"  Seed: {avatar['seed']}")
            print(f"  Generation time: {avatar['generation_time_ms']}ms")

            # Save image
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"avatar_luna_{timestamp}.png"

            image_base64 = avatar['image_base64'].split('base64,')[1]
            image_data = base64.b64decode(image_base64)

            with open(filename, "wb") as f:
                f.write(image_data)

            print(f"\n  Saved to: {filename}")
            print(f"\n  Open this file to see your avatar!")
        else:
            print(f"\n[FAIL] {result.get('message')}")
    else:
        print(f"\n[FAIL] Request failed")
        print(f"Response: {response.text}")

except Exception as e:
    print(f"\n[ERROR] {e}")

print("\n" + "="*60)
