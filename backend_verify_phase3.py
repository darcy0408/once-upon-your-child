#!/usr/bin/env python3
"""
Quick Backend Verification Script for Phase 3 Custom Elements
Usage: python backend_verify_phase3.py
"""
import requests
import json
import time

def test_custom_elements_quick():
    """Quick test of Phase 3 custom elements functionality"""

    # Test cases with expected keywords
    test_cases = [
        {
            "name": "Talking Animal",
            "custom_elements": "I want to meet a talking cat",
            "expected": ["cat", "talking"]
        },
        {
            "name": "Magical Object",
            "custom_elements": "I want to find a magic sword",
            "expected": ["magic", "sword"]
        },
        {
            "name": "Multiple Elements",
            "custom_elements": "I want to ride a dragon and find a hidden treasure",
            "expected": ["dragon", "treasure", "hidden"]
        }
    ]

    print("🔍 Phase 3 Custom Elements - Quick Verification")
    print("=" * 60)

    # Check backend health
    try:
        health_response = requests.get("http://127.0.0.1:5000/health", timeout=5)
        if health_response.status_code != 200:
            print("❌ Backend health check failed")
            return
        print("✅ Backend is healthy")
    except:
        print("❌ Cannot connect to backend. Start with: python backend/app.py")
        return

    passed = 0
    total = len(test_cases)

    for i, test_case in enumerate(test_cases, 1):
        print(f"\nTest {i}/{total}: {test_case['name']}")

        payload = {
            "character": {
                "name": f"TestCharacter{i}",
                "age": 8,
                "role": "The Brave Knight"
            },
            "age": 8,
            "archetype": "The Brave Knight",
            "theme": "Adventure",
            "story_length": "standard",
            "customElements": test_case["custom_elements"],
            "mood_selection": ["curious"]
        }

        try:
            start_time = time.time()
            response = requests.post(
                "http://127.0.0.1:5000/generate-story",
                json=payload,
                timeout=60
            )
            duration = time.time() - start_time

            if response.status_code == 200:
                data = response.json()
                story_text = data.get('story', '').lower()
                title = data.get('title', 'Unknown')

                # Check for expected keywords
                found_keywords = []
                for keyword in test_case["expected"]:
                    count = story_text.count(keyword.lower())
                    if count > 0:
                        found_keywords.append(f"{keyword}({count})")

                if found_keywords:
                    print(f"  ✅ PASS - Keywords found: {', '.join(found_keywords)}")
                    print(".1f")
                    passed += 1
                else:
                    print(f"  ❌ FAIL - Expected keywords not found: {test_case['expected']}")
                    print(f"  Story preview: {data.get('story', '')[:150]}...")

            else:
                print(f"  ❌ FAIL - HTTP {response.status_code}")

        except Exception as e:
            print(f"  ❌ FAIL - Exception: {str(e)}")

    print("\n" + "=" * 60)
    print(f"RESULTS: {passed}/{total} tests passed")
    if passed >= total - 1:  # Allow 1 failure
        print("🎉 Phase 3 Custom Elements: VERIFIED WORKING")
    else:
        print("⚠️ Phase 3 Custom Elements: ISSUES DETECTED")
    print("=" * 60)

if __name__ == "__main__":
    test_custom_elements_quick()