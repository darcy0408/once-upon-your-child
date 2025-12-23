#!/usr/bin/env python3
"""
Comprehensive Test Runner for Story Weaver App
Executes all automated tests and generates detailed results
"""
import json
import time
from datetime import datetime
from automated_test_suite import StoryWeaverTester

def run_comprehensive_tests():
    """Run all automated tests and collect results"""

    print("🚀 Starting Comprehensive Test Suite...")
    print("=" * 50)

    tester = StoryWeaverTester()
    results = {
        "test_run": datetime.now().isoformat(),
        "summary": {},
        "tests": []
    }

    # Test 1: Backend Health Check
    print("\n1️⃣ Testing Backend Health...")
    start_time = time.time()
    try:
        health_result = tester.check_backend_health()
        duration = int((time.time() - start_time) * 1000)

        test_result = {
            "name": "Backend Health Check",
            "status": "PASS" if health_result else "FAIL",
            "duration_ms": duration,
            "details": "Backend responding correctly" if health_result else "Backend not responding"
        }
        results["tests"].append(test_result)
        print(f"   ✅ {test_result['status']} ({duration}ms)")

    except Exception as e:
        duration = int((time.time() - start_time) * 1000)
        test_result = {
            "name": "Backend Health Check",
            "status": "FAIL",
            "duration_ms": duration,
            "details": f"Exception: {str(e)}"
        }
        results["tests"].append(test_result)
        print(f"   ❌ FAIL ({duration}ms) - {str(e)}")

    # Test 2: Custom Elements - Single Element
    print("\n2️⃣ Testing Custom Elements (Single)...")
    start_time = time.time()
    try:
        custom_result = tester.test_custom_element("Custom Elements - Single Element", "dragon")
        duration = int((time.time() - start_time) * 1000)

        test_result = {
            "name": "Custom Elements - Single Element",
            "status": "PASS" if custom_result else "FAIL",
            "duration_ms": duration,
            "details": "Single custom element integrated successfully" if custom_result else "Single element integration failed"
        }
        results["tests"].append(test_result)
        print(f"   ✅ {test_result['status']} ({duration}ms)")

    except Exception as e:
        duration = int((time.time() - start_time) * 1000)
        test_result = {
            "name": "Custom Elements - Single Element",
            "status": "FAIL",
            "duration_ms": duration,
            "details": f"Exception: {str(e)}"
        }
        results["tests"].append(test_result)
        print(f"   ❌ FAIL ({duration}ms) - {str(e)}")

    # Test 3: Custom Elements - Multiple Elements
    print("\n3️⃣ Testing Custom Elements (Multiple)...")
    start_time = time.time()
    try:
        multi_result = tester.test_custom_element("Custom Elements - Multiple Elements", "wizard, castle, magic sword")
        duration = int((time.time() - start_time) * 1000)

        test_result = {
            "name": "Custom Elements - Multiple Elements",
            "status": "PASS" if multi_result else "FAIL",
            "duration_ms": duration,
            "details": "Multiple custom elements integrated successfully" if multi_result else "Multiple elements integration failed"
        }
        results["tests"].append(test_result)
        print(f"   ✅ {test_result['status']} ({duration}ms)")

    except Exception as e:
        duration = int((time.time() - start_time) * 1000)
        test_result = {
            "name": "Custom Elements - Multiple Elements",
            "status": "FAIL",
            "duration_ms": duration,
            "details": f"Exception: {str(e)}"
        }
        results["tests"].append(test_result)
        print(f"   ❌ FAIL ({duration}ms) - {str(e)}")

    # Test 4: Story Length Options
    print("\n4️⃣ Testing Story Length Options...")
    start_time = time.time()
    try:
        length_result = tester.test_story_lengths()
        duration = int((time.time() - start_time) * 1000)

        test_result = {
            "name": "Story Length Options",
            "status": "PASS" if length_result else "FAIL",
            "duration_ms": duration,
            "details": "All story lengths generated correctly" if length_result else "Story length options failed"
        }
        results["tests"].append(test_result)
        print(f"   ✅ {test_result['status']} ({duration}ms)")

    except Exception as e:
        duration = int((time.time() - start_time) * 1000)
        test_result = {
            "name": "Story Length Options",
            "status": "FAIL",
            "duration_ms": duration,
            "details": f"Exception: {str(e)}"
        }
        results["tests"].append(test_result)
        print(f"   ❌ FAIL ({duration}ms) - {str(e)}")

    # Test 5: Phase 3 Complete Test Suite
    print("\n5️⃣ Testing Phase 3 Complete Suite...")
    start_time = time.time()
    try:
        phase3_result = tester.run_phase3_tests()
        duration = int((time.time() - start_time) * 1000)

        test_result = {
            "name": "Phase 3 Complete Test Suite",
            "status": "PASS" if phase3_result else "FAIL",
            "duration_ms": duration,
            "details": "All Phase 3 tests passed" if phase3_result else "Some Phase 3 tests failed"
        }
        results["tests"].append(test_result)
        print(f"   ✅ {test_result['status']} ({duration}ms)")

    except Exception as e:
        duration = int((time.time() - start_time) * 1000)
        test_result = {
            "name": "Phase 3 Complete Test Suite",
            "status": "FAIL",
            "duration_ms": duration,
            "details": f"Exception: {str(e)}"
        }
        results["tests"].append(test_result)
        print(f"   ❌ FAIL ({duration}ms) - {str(e)}")

    # Calculate summary
    total_tests = len(results["tests"])
    passed_tests = sum(1 for t in results["tests"] if t["status"] == "PASS")
    failed_tests = total_tests - passed_tests
    success_rate = f"{(passed_tests/total_tests*100):.1f}%" if total_tests > 0 else "0%"

    # Phase 3 readiness assessment
    custom_tests = [t for t in results["tests"] if "Custom Elements" in t["name"]]
    custom_passed = sum(1 for t in custom_tests if t["status"] == "PASS")
    phase_3_ready = custom_passed >= len(custom_tests) - 1 and passed_tests >= total_tests - 2

    results["summary"] = {
        "total_tests": total_tests,
        "passed": passed_tests,
        "failed": failed_tests,
        "success_rate": success_rate,
        "phase_3_ready": phase_3_ready
    }

    print("\n" + "=" * 50)
    print("🎯 TEST SUMMARY")
    print("=" * 50)
    print(f"Total Tests: {total_tests}")
    print(f"Passed: {passed_tests}")
    print(f"Failed: {failed_tests}")
    print(f"Success Rate: {success_rate}")
    print(f"Phase 3 Ready: {'✅ YES' if phase_3_ready else '❌ NO'}")

    return results

def save_results(results, filename="AUTOMATED_TEST_RESULTS.json"):
    """Save test results to JSON file"""
    with open(filename, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print(f"\n💾 Results saved to: {filename}")

def main():
    """Main test runner"""
    try:
        # Run all tests
        results = run_comprehensive_tests()

        # Save results
        save_results(results)

        # Generate report
        print("\n📊 Generating test report...")
        import generate_test_report
        generate_test_report.main()

        print("\n🎉 Test run complete!")
        print("   📄 Check PHASE3_TEST_REPORT.md for detailed results")

    except Exception as e:
        print(f"\n❌ Test runner failed: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()