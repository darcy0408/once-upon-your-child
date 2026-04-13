import requests
import json
import sys
import time
import traceback

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

BASE_URL = "http://localhost:5000"

def test_interactive_quality():
    print("🚀 Starting Interactive Story Quality Test (Real AI)")
    print("=" * 60)

    # 1. Create Story
    payload = {
        "user_id": "quality_tester",
        "theme": "Space Mystery",
        "tone": "exciting",
        "age": 10,
        "must_include": ["alien robot", "missing map"]
    }
    
    print(f"\n1️⃣ Generating Opening Segment for theme: '{payload['theme']}'...")
    start_time = time.time()
    
    try:
        r = requests.post(f"{BASE_URL}/generate-interactive-story", json=payload)
        duration = time.time() - start_time
        
        if r.status_code != 200:
            print(f"❌ Failed to generate story. Status: {r.status_code}")
            print(r.text)
            return

        data = r.json()
        story_id = data.get("story_id")
        # FIX: Use single braces for default dict
        segment = data.get("segment", {})
        choices = segment.get("choices", [])
        
        print(f"✅ Generated in {duration:.2f}s")
        print(f"   Story ID: {story_id}")
        print("\n📜 SEGMENT CONTENT:")
        print("-" * 20)
        print(segment.get("content", "NO CONTENT"))
        print("-" * 20)
        
        print("\n🤔 CHOICES GENERATED:")
        for idx, choice in enumerate(choices):
            print(f"   {idx + 1}. {choice.get('text', 'NO TEXT')}")
            
        print("\n✨ QUALITY CHECK:")
        if len(choices) < 2:
            print("❌ FAIL: Less than 2 choices provided.")
        else:
            print("✅ Pass: Adequate number of choices.")
            
        # Check if 'must_include' items are present
        content_lower = segment.get("content", "").lower()
        # FIX: Check safety
        if payload["must_include"]:
            missing_items = [item for item in payload["must_include"] if item.lower() not in content_lower]
            
            if not missing_items:
                 print("✅ Pass: All 'must_include' items present.")
            else:
                 print(f"⚠️ Warning: Missing items: {missing_items}")

    except Exception as e:
        traceback.print_exc()
        print(f"❌ Exception: {e}")

if __name__ == "__main__":
    test_interactive_quality()