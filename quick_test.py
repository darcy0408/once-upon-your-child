#!/usr/bin/env python3
"""
Quick Test Runner for Story Weaver App
Fast verification of critical functionality
"""
import requests
import time
import json

def quick_health_check():
    """Quick backend health check"""
    try:
        response = requests.get("http://localhost:5000/health", timeout=5)
        return response.status_code == 200
    except:
        return False

def quick_custom_elements_test():
    """Quick test of custom elements functionality"""
    try:
        payload = {
            "character": {
                "name": "Alex",
                "age": 8
            },
            "customElements": "dragon, castle",
            "story_length": "short"
        }
        response = requests.post("http://localhost:5000/generate-story",
                               json=payload, timeout=30)
        if response.status_code == 200:
            data = response.json()
            story = data.get("story", "").lower()
            return "dragon" in story and "castle" in story
        return False
    except:
        return False

def run_quick_tests():
    """Run quick verification tests"""
    print("⚡ Running Quick Tests...")
    print("-" * 30)

    # Test 1: Backend Health
    print("1. Backend Health Check...")
    health_ok = quick_health_check()
    print(f"   {'✅ PASS' if health_ok else '❌ FAIL'}")

    # Test 2: Custom Elements
    print("2. Custom Elements Integration...")
    custom_ok = quick_custom_elements_test()
    print(f"   {'✅ PASS' if custom_ok else '❌ FAIL'}")

    # Summary
    all_pass = health_ok and custom_ok
    print("-" * 30)
    print(f"Overall: {'✅ ALL PASS' if all_pass else '❌ ISSUES DETECTED'}")

    return all_pass

def main():
    """Main quick test function"""
    try:
        success = run_quick_tests()
        exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n⏹️  Test interrupted")
        exit(1)
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        exit(1)

if __name__ == "__main__":
    main()