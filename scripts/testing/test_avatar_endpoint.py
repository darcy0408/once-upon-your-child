import requests
import json

def test_generate_avatar():
    url = "http://127.0.0.1:5000/avatar/generate-avatar"
    payload = {
        "character_name": "Test Hero",
        "age": 8,
        "style": "pixar"
    }
    headers = {
        "Content-Type": "application/json"
    }

    print(f"Testing {url}...")
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=120)
        print(f"Status Code: {response.status_code}")
        try:
            data = response.json()
            if response.status_code == 200:
                print("✅ SUCCESS!")
                print(f"   Avatar ID: {data['avatar']['id']}")
                print(f"   Image data length: {len(data['avatar']['image_base64'])}")
            else:
                print(f"❌ FAILED: {data.get('message', 'No error message')}")
                print(f"   Error code: {data.get('error_code', 'No error code')}")
        except:
            print(f"   Response text: {response.text}")
    except Exception as e:
        print(f"❌ ERROR: {e}")

if __name__ == "__main__":
    test_generate_avatar()
