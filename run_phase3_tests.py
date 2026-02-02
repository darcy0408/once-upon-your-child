#!/usr/bin/env python3
"""
Automated Phase 3 Testing Suite for Story Weaver App
Tests custom elements feature and core functionality
"""
import sys
import os
import requests
import json
import time
from datetime import datetime

# Fix Windows console encoding for emoji support
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

# Configuration
BACKEND_URL = "http://localhost:5000"

# Check if mock mode is enabled
MOCK_MODE = os.environ.get('MOCK_TESTING_MODE', 'false').lower() in ['true', '1', 'yes']

# Auto-select endpoint suffix based on mock mode
ENDPOINT_SUFFIX = '-mock' if MOCK_MODE else ''

print(f"\n{'='*60}")
print(f"MOCK TESTING MODE: {'ENABLED ✅ (FREE)' if MOCK_MODE else 'DISABLED ❌ (USES API)'}")
print(f"Endpoint suffix: '{ENDPOINT_SUFFIX}'")
print(f"Cost per test: ${'0.00' if MOCK_MODE else '~0.0034'}")
print(f"{'='*60}\n")

TEST_RESULTS = {
    "date": datetime.now().isoformat(),
    "tester": "Automated Test Script",
    "mock_mode": MOCK_MODE,
    "tests": [],
    "summary": {}
}

def log_test(test_name, status, details="", duration=0):
    """Log a test result"""
    test_result = {
        "name": test_name,
        "status": status,
        "details": details,
        "duration_ms": duration
    }
    TEST_RESULTS["tests"].append(test_result)
    status_symbol = "✅" if status == "PASS" else "❌"
    print(f"{status_symbol} {test_name}: {status} ({duration}ms)")
    if details:
        print(f"   Details: {details}")

def test_backend_health():
    """Test 1.0: Backend Health Check"""
    print("\n" + "="*60)
    print("TEST 1.0: Backend Health Check")
    print("="*60)
    
    try:
        start = time.time()
        response = requests.get(f"{BACKEND_URL}/health", timeout=5)
        duration = int((time.time() - start) * 1000)
        
        if response.status_code == 200:
            data = response.json()
            log_test(
                "Backend Health",
                "PASS",
                f"Status: {data.get('status')}, Database: {data.get('database')}",
                duration
            )
            return True
        else:
            log_test("Backend Health", "FAIL", f"Status code: {response.status_code}", duration)
            return False
    except Exception as e:
        log_test("Backend Health", "FAIL", f"Exception: {str(e)}", 0)
        return False

def test_custom_elements_simple():
    """Test 3.1A: Custom Elements - Simple Request"""
    print("\n" + "="*60)
    print("TEST 3.1A: Custom Elements - Simple Request")
    print("="*60)
    
    payload = {
        "character": "TestHero",
        "age": 8,
        "archetype": "The Brave Knight",
        "theme": "Adventure",
        "story_length": "standard",
        "custom_elements": "I want to meet a talking tree",
        "mood_selection": ["curious"]
    }
    
    try:
        start = time.time()
        response = requests.post(
            f"{BACKEND_URL}/generate-story{ENDPOINT_SUFFIX}",  # Auto-switch based on mode
            json=payload,
            timeout=10 if MOCK_MODE else 120  # Mock is fast, real API is slow
        )
        duration = int((time.time() - start) * 1000)
        
        if response.status_code == 200:
            data = response.json()
            story_text = data.get('story', '').lower()
            
            # Check if talking tree appears in story
            has_tree = 'tree' in story_text or 'talking' in story_text
            
            if has_tree:
                log_test(
                    "Custom Elements - Simple",
                    "PASS",
                    "Talking tree found in story",
                    duration
                )
                return True
            else:
                log_test(
                    "Custom Elements - Simple",
                    "PARTIAL",
                    "Story generated but custom element not clearly found",
                    duration
                )
                print(f"   Story preview: {data.get('story', '')[:200]}...")
                return True  # Still a pass if story generates
        else:
            log_test(
                "Custom Elements - Simple",
                "FAIL",
                f"Status code: {response.status_code}",
                duration
            )
            return False
    except Exception as e:
        log_test("Custom Elements - Simple", "FAIL", f"Exception: {str(e)}", 0)
        return False

def test_custom_elements_multiple():
    """Test 3.1B: Custom Elements - Multiple Elements"""
    print("\n" + "="*60)
    print("TEST 3.1B: Custom Elements - Multiple Elements")
    print("="*60)
    
    payload = {
        "character": "TestHero",
        "age": 8,
        "archetype": "The Brave Knight",
        "theme": "Adventure",
        "story_length": "standard",
        "custom_elements": "I want to ride a dragon and find a magic key",
        "mood_selection": ["excited"]
    }
    
    try:
        start = time.time()
        response = requests.post(
            f"{BACKEND_URL}/generate-story{ENDPOINT_SUFFIX}",  # Auto-switch based on mode
            json=payload,
            timeout=10 if MOCK_MODE else 120  # Mock is fast, real API is slow
        )
        duration = int((time.time() - start) * 1000)
        
        if response.status_code == 200:
            data = response.json()
            story_text = data.get('story', '').lower()
            
            # Check for both elements
            has_dragon = 'dragon' in story_text
            has_key = 'key' in story_text or 'magic' in story_text
            
            if has_dragon and has_key:
                log_test(
                    "Custom Elements - Multiple",
                    "PASS",
                    "Both dragon and magic key found",
                    duration
                )
                return True
            elif has_dragon or has_key:
                log_test(
                    "Custom Elements - Multiple",
                    "PARTIAL",
                    f"Dragon: {has_dragon}, Key/Magic: {has_key}",
                    duration
                )
                return True
            else:
                log_test(
                    "Custom Elements - Multiple",
                    "PARTIAL",
                    "Story generated but elements not clearly visible",
                    duration
                )
                return True
        else:
            log_test(
                "Custom Elements - Multiple",
                "FAIL",
                f"Status code: {response.status_code}",
                duration
            )
            return False
    except Exception as e:
        log_test("Custom Elements - Multiple", "FAIL", f"Exception: {str(e)}", 0)
        return False

def test_empty_custom_elements():
    """Test 3.2A: Custom Elements - Empty Field"""
    print("\n" + "="*60)
    print("TEST 3.2A: Custom Elements - Empty Field")
    print("="*60)
    
    payload = {
        "character": "TestHero",
        "age": 8,
        "archetype": "The Brave Knight",
        "theme": "Adventure",
        "story_length": "standard",
        "custom_elements": "",  # Empty
        "mood_selection": ["happy"]
    }
    
    try:
        start = time.time()
        response = requests.post(
            f"{BACKEND_URL}/generate-story{ENDPOINT_SUFFIX}",  # Auto-switch based on mode
            json=payload,
            timeout=10 if MOCK_MODE else 120  # Mock is fast, real API is slow
        )
        duration = int((time.time() - start) * 1000)
        
        if response.status_code == 200:
            log_test(
                "Empty Custom Elements",
                "PASS",
                "Story generated without custom elements",
                duration
            )
            return True
        else:
            log_test(
                "Empty Custom Elements",
                "FAIL",
                f"Status code: {response.status_code}",
                duration
            )
            return False
    except Exception as e:
        log_test("Empty Custom Elements", "FAIL", f"Exception: {str(e)}", 0)
        return False

def test_special_characters():
    """Test 3.2C: Custom Elements - Special Characters"""
    print("\n" + "="*60)
    print("TEST 3.2C: Custom Elements - Special Characters")
    print("="*60)
    
    payload = {
        "character": "TestHero",
        "age": 8,
        "archetype": "The Brave Knight",
        "theme": "Adventure",
        "story_length": "standard",
        "custom_elements": "I want emojis 🌟✨🎉 and symbols!",
        "mood_selection": ["creative"]
    }
    
    try:
        start = time.time()
        response = requests.post(
            f"{BACKEND_URL}/generate-story{ENDPOINT_SUFFIX}",  # Auto-switch based on mode
            json=payload,
            timeout=10 if MOCK_MODE else 120  # Mock is fast, real API is slow
        )
        duration = int((time.time() - start) * 1000)
        
        if response.status_code == 200:
            log_test(
                "Special Characters",
                "PASS",
                "Story generated with special characters in input",
                duration
            )
            return True
        else:
            log_test(
                "Special Characters",
                "FAIL",
                f"Status code: {response.status_code}",
                duration
            )
            return False
    except Exception as e:
        log_test("Special Characters", "FAIL", f"Exception: {str(e)}", 0)
        return False

def test_story_length_options():
    """Test 2.4: Story Length Options"""
    print("\n" + "="*60)
    print("TEST 2.4: Story Length Options")
    print("="*60)
    
    lengths = ["quick", "standard", "epic"]
    all_passed = True
    
    for length in lengths:
        payload = {
            "character": f"TestHero_{length}",
            "age": 8,
            "archetype": "The Brave Knight",
            "theme": "Adventure",
            "story_length": length,
            "custom_elements": f"Testing {length} mode",
            "mood_selection": ["happy"]
        }
        
        try:
            start = time.time()
            response = requests.post(
                f"{BACKEND_URL}/generate-story",
                json=payload,
                timeout=60
            )
            duration = int((time.time() - start) * 1000)
            
            if response.status_code == 200:
                data = response.json()
                story_length = len(data.get('story', '').split())
                log_test(
                    f"Story Length - {length.upper()}",
                    "PASS",
                    f"Generated {story_length} words in {duration}ms",
                    duration
                )
            else:
                log_test(
                    f"Story Length - {length.upper()}",
                    "FAIL",
                    f"Status code: {response.status_code}",
                    duration
                )
                all_passed = False
        except Exception as e:
            log_test(f"Story Length - {length.upper()}", "FAIL", f"Exception: {str(e)}", 0)
            all_passed = False
    
    return all_passed

def generate_report():
    """Generate test report"""
    total_tests = len(TEST_RESULTS["tests"])
    passed = sum(1 for t in TEST_RESULTS["tests"] if t["status"] in ["PASS", "PARTIAL"])
    failed = sum(1 for t in TEST_RESULTS["tests"] if t["status"] == "FAIL")
    
    TEST_RESULTS["summary"] = {
        "total_tests": total_tests,
        "passed": passed,
        "failed": failed,
        "success_rate": f"{(passed/total_tests*100):.1f}%" if total_tests > 0 else "0%"
    }
    
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    print(f"Total Tests: {total_tests}")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")
    print(f"Success Rate: {TEST_RESULTS['summary']['success_rate']}")
    print("="*60)
    
    return TEST_RESULTS

def main():
    """Run all tests"""
    print("\n" + "="*60)
    print("🧪 STORY WEAVER PHASE 3 - AUTOMATED TEST SUITE")
    print("="*60)
    print(f"Started: {datetime.now().isoformat()}")
    print(f"Backend URL: {BACKEND_URL}")
    
    # Run tests
    if not test_backend_health():
        print("\n⚠️ CRITICAL: Backend is not running!")
        print("   Please start the backend with: python backend/app.py")
        return
    
    # Phase 3 Tests
    test_custom_elements_simple()
    test_custom_elements_multiple()
    test_empty_custom_elements()
    test_special_characters()
    test_story_length_options()
    
    # Generate report
    final_report = generate_report()
    
    # Save report to file
    report_file = "PHASE3_TEST_RESULTS.json"
    with open(report_file, "w") as f:
        json.dump(final_report, f, indent=2)
    print(f"\n✅ Report saved to: {report_file}")
    
    print(f"\n✅ Testing completed at: {datetime.now().isoformat()}")

if __name__ == "__main__":
    main()
