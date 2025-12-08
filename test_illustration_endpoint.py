#!/usr/bin/env python3
"""
Test the /generate-illustrations endpoint directly
"""
import requests
import json

url = "http://127.0.0.1:5000/generate-illustrations"

payload = {
    "scene_description": "A brave little girl named Emma discovering a glowing magic crystal in an enchanted forest",
    "character_name": "Emma",
    "age": 7,
    "style": "simple, colorful children's book illustration for early readers",
    "num_images": 1,
}

print(f"🌐 Testing {url}")
print(f"📦 Payload: {json.dumps(payload, indent=2)}")

try:
    print("\n⏳ Sending request...")
    response = requests.post(url, json=payload, timeout=60)
    
    print(f"\n📊 Status: {response.status_code}")
    print(f"📋 Response preview:")
    
    data = response.json()
    
    if response.status_code == 200:
        illustrations = data.get('illustrations', [])
        count = data.get('count', 0)
        
        print(f"  ✅ Success! Generated {count} illustration(s)")
        
        if illustrations:
            for i, img in enumerate(illustrations):
                img_data_len = len(img.get('image_data', ''))
                print(f"  📸 Illustration {i+1}:")
                print(f"     - ID: {img.get('id')}")
                print(f"     - Image data size: {img_data_len} chars (base64)")
                print(f"     - Format: {img.get('format')}")
        else:
            print("  ⚠️  No illustrations in response")
    else:
        print(f"  ❌ Error: {data}")
        
except requests.exceptions.Timeout:
    print("❌ Request timed out after 60 seconds")
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
