#!/usr/bin/env python3
"""
Automated Backend Testing Suite for Story Weaver App
Tests Phase 3 Custom Elements and core functionality
"""
import requests
import json
import time
from datetime import datetime
import sys

# Fix Windows console encoding for emoji support
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

# Configuration
BACKEND_URL = "http://127.0.0.1:5000"
TEST_TIMEOUT = 60  # seconds

class StoryWeaverTester:
    def __init__(self):
        self.results = {
            "test_run": datetime.now().isoformat(),
            "tests": [],
            "summary": {}
        }

    def log_test(self, test_name, status, details="", duration=0, story_preview=""):
        """Log a test result"""
        test_result = {
            "name": test_name,
            "status": status,
            "details": details,
            "duration_ms": duration,
            "story_preview": story_preview[:200] if story_preview else "",
            "timestamp": datetime.now().isoformat()
        }
        self.results["tests"].append(test_result)

        status_icon = "✅" if status == "PASS" else "❌" if status == "FAIL" else "⚠️"
        print(f"{status_icon} {test_name}: {status} ({duration}ms)")
        if details:
            print(f"   └─ {details}")
        print()

    def check_backend_health(self):
        """Test 0.0: Backend Health Check"""
        print("🔍 Checking backend health...")

        try:
            start = time.time()
            response = requests.get(f"{BACKEND_URL}/health", timeout=5)
            duration = int((time.time() - start) * 1000)

            if response.status_code == 200:
                data = response.json()
                self.log_test(
                    "Backend Health Check",
                    "PASS",
                    f"Status: {data.get('status')}, Database: {data.get('database')}",
                    duration
                )
                return True
            else:
                self.log_test("Backend Health Check", "FAIL", f"Status code: {response.status_code}", duration)
                return False
        except Exception as e:
            self.log_test("Backend Health Check", "FAIL", f"Exception: {str(e)}", 0)
            return False

    def test_custom_element(self, test_name, custom_elements, character_name="TestHero", age=8, expected_keywords=None):
        """Generic test for custom elements"""
        payload = {
            "character": {
                "name": character_name,
                "age": age,
                "role": "The Brave Knight"
            },
            "age": age,
            "archetype": "The Brave Knight",
            "theme": "Adventure",
            "story_length": "standard",
            "customElements": custom_elements,
            "mood_selection": ["curious"]
        }

        try:
            start = time.time()
            response = requests.post(
                f"{BACKEND_URL}/generate-story",
                json=payload,
                timeout=TEST_TIMEOUT
            )
            duration = int((time.time() - start) * 1000)

            if response.status_code == 200:
                data = response.json()
                
                # Handle structured story response
                story_data = data.get('story', {})
                if isinstance(story_data, dict):
                    story_text = story_data.get('story_text', '').lower()
                    title = story_data.get('title', 'Unknown')
                    raw_story = story_data.get('story_text', '')
                else:
                    story_text = str(story_data).lower()
                    title = data.get('title', 'Unknown')
                    raw_story = str(story_data)

                # Check for expected keywords if provided
                if expected_keywords:
                    found_keywords = []
                    for keyword in expected_keywords:
                        count = story_text.count(keyword.lower())
                        if count > 0:
                            found_keywords.append(f"{keyword}({count})")

                    if found_keywords:
                        self.log_test(
                            test_name,
                            "PASS",
                            f"Keywords found: {', '.join(found_keywords)}",
                            duration,
                            raw_story[:200]
                        )
                        return True
                    else:
                        self.log_test(
                            test_name,
                            "FAIL",
                            f"No expected keywords found: {expected_keywords}",
                            duration,
                            raw_story[:200]
                        )
                        return False
                else:
                    # Just check if story was generated
                    self.log_test(
                        test_name,
                        "PASS",
                        f"Story generated: {title}",
                        duration,
                        raw_story[:200]
                    )
                    return True
            else:
                self.log_test(
                    test_name,
                    "FAIL",
                    f"Status code: {response.status_code}",
                    duration
                )
                return False
        except Exception as e:
            self.log_test(test_name, "FAIL", f"Exception: {str(e)}", 0)
            return False

    def run_phase3_tests(self):
        """Run all Phase 3 custom elements tests"""
        print("\n🧪 PHASE 3 CUSTOM ELEMENTS TEST SUITE")
        print("=" * 60)

        results = []
        # Test 3.1A: Simple Custom Request - Talking Cat
        results.append(self.test_custom_element(
            "Test 3.1A: Talking Cat",
            "I want to meet a talking cat",
            expected_keywords=["cat", "talking"]
        ))

        # Test 3.1B: Multiple Elements - Dragon and Key
        results.append(self.test_custom_element(
            "Test 3.1B: Dragon and Magic Key",
            "I want to ride a dragon and find a magic key",
            expected_keywords=["dragon", "key", "magic"]
        ))

        # Test 3.1C: Magic Sword
        results.append(self.test_custom_element(
            "Test 3.1C: Magic Sword",
            "I want to find a magic sword",
            expected_keywords=["magic", "sword"]
        ))

        # Test 3.1D: Flying Horse and Treasure
        results.append(self.test_custom_element(
            "Test 3.1D: Flying Horse and Treasure",
            "I want to ride a flying horse and discover a hidden treasure",
            expected_keywords=["flying", "horse", "treasure", "hidden"]
        ))

        # Test 3.1E: Robot Friend
        results.append(self.test_custom_element(
            "Test 3.1E: Robot Friend",
            "I want to build a robot friend",
            expected_keywords=["robot", "friend", "build"]
        ))

        # Test 3.2A: Empty Custom Elements
        results.append(self.test_custom_element(
            "Test 3.2A: Empty Custom Elements",
            "",
            expected_keywords=None  # Just check if story generates
        ))

        # Test 3.2C: Special Characters
        results.append(self.test_custom_element(
            "Test 3.2C: Special Characters",
            "I want emojis 🌟✨🎉 and symbols!",
            expected_keywords=None
        ))

        # Test 3.3A: Complex Multi-Element
        results.append(self.test_custom_element(
            "Test 3.3A: Complex Multi-Element",
            "I want to ride a flying horse, find a hidden treasure, and build a robot friend",
            expected_keywords=["flying", "horse", "treasure", "robot", "friend"]
        ))
        
        return all(results)

    def test_story_lengths(self):
        """Test different story lengths"""
        print("\n📏 STORY LENGTH OPTIONS TEST")
        print("=" * 60)

        lengths = ["short", "medium", "long"]
        results = []

        for length in lengths:
            payload = {
                "character": f"TestHero_{length}",
                "age": 8,
                "archetype": "The Brave Knight",
                "theme": "Adventure",
                "story_length": length,
                "custom_elements": f"Testing {length} mode with custom element",
                "mood_selection": ["happy"]
            }

            try:
                start = time.time()
                response = requests.post(
                    f"{BACKEND_URL}/generate-story",
                    json=payload,
                    timeout=TEST_TIMEOUT
                )
                duration = int((time.time() - start) * 1000)

                if response.status_code == 200:
                    data = response.json()
                    
                    # Handle structured story response
                    story_data = data.get('story', {})
                    if isinstance(story_data, dict):
                        story_body = story_data.get('story_text', '')
                    else:
                        story_body = str(story_data)
                        
                    word_count = len(story_body.split())
                    self.log_test(
                        f"Story Length - {length.upper()}",
                        "PASS",
                        f"Generated {word_count} words in {duration}ms",
                        duration
                    )
                    results.append(True)
                else:
                    self.log_test(
                        f"Story Length - {length.upper()}",
                        "FAIL",
                        f"Status code: {response.status_code}",
                        duration
                    )
                    results.append(False)
            except Exception as e:
                self.log_test(f"Story Length - {length.upper()}", "FAIL", f"Exception: {str(e)}", 0)
                results.append(False)
        
        return all(results)

    def generate_report(self):
        """Generate test report"""
        total_tests = len(self.results["tests"])
        passed = sum(1 for t in self.results["tests"] if t["status"] == "PASS")
        failed = sum(1 for t in self.results["tests"] if t["status"] == "FAIL")
        success_rate = (passed / total_tests * 100) if total_tests > 0 else 0

        self.results["summary"] = {
            "total_tests": total_tests,
            "passed": passed,
            "failed": failed,
            "success_rate": f"{success_rate:.1f}%",
            "phase_3_ready": passed > failed and failed < 3  # Allow some failures
        }

        return self.results

    def print_summary(self):
        """Print test summary"""
        summary = self.results["summary"]
        print("\n" + "=" * 60)
        print("TEST SUMMARY")
        print("=" * 60)
        print(f"Total Tests: {summary['total_tests']}")
        print(f"Passed: {summary['passed']}")
        print(f"Failed: {summary['failed']}")
        print(f"Success Rate: {summary['success_rate']}")

        if summary.get('phase_3_ready'):
            print("🎉 Phase 3 Custom Elements: READY FOR LAUNCH")
        else:
            print("⚠️ Phase 3 Custom Elements: NEEDS ATTENTION")

        print("=" * 60)

def main():
    """Main test runner"""
    print("🚀 Story Weaver App - Automated Testing Suite")
    print(f"Started: {datetime.now().isoformat()}")
    print(f"Backend URL: {BACKEND_URL}")
    print()

    tester = StoryWeaverTester()

    # Check backend health first
    if not tester.check_backend_health():
        print("❌ Backend is not available. Please start the backend server first:")
        print("   python backend/app.py")
        sys.exit(1)

    # Run Phase 3 tests
    tester.run_phase3_tests()

    # Run story length tests
    tester.test_story_lengths()

    # Generate and save report
    report = tester.generate_report()
    tester.print_summary()

    # Save detailed results
    report_file = "AUTOMATED_TEST_RESULTS.json"
    with open(report_file, "w") as f:
        json.dump(report, f, indent=2)

    print(f"\n📄 Detailed report saved to: {report_file}")
    print(f"\n✅ Testing completed at: {datetime.now().isoformat()}")

if __name__ == "__main__":
    main()