import requests
import json
import sys
import time
import traceback

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

BASE_URL = "http://localhost:5000"

def generate_story_for_age(age, label):
    print(f"\n🚀 Generating for Age {age} ({label})...")
    payload = {
        "user_id": "quality_tester",
        "theme": "Space Mystery",
        "tone": "exciting" if age > 10 else "gentle",
        "age": age,
        "must_include": ["alien robot", "missing map"]
    }
    
    start_time = time.time()
    try:
        r = requests.post(f"{BASE_URL}/generate-interactive-story", json=payload)
        
        if r.status_code != 200:
            print(f"❌ Failed. Status: {r.status_code}")
            return

        data = r.json()
        segment = data.get("segment", {})
        content = segment.get("content", "")
        choices = segment.get("choices", [])
        
        print(f"✅ Generated in {time.time() - start_time:.2f}s")
        print("\n📜 SEGMENT CONTENT:")
        print("-" * 40)
        print(content)
        print("-" * 40)
        
        print("\n🤔 CHOICES:")
        for idx, choice in enumerate(choices):
            print(f"   {idx + 1}. {choice.get('text', 'NO TEXT')}")

    except Exception as e:
        traceback.print_exc()

if __name__ == "__main__":
    generate_story_for_age(3, "Toddler")
    generate_story_for_age(18, "Young Adult")
