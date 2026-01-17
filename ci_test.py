#!/usr/bin/env python3
"""
CI/CD Test Script for Story Weaver App
Designed for automated deployment verification
"""
import subprocess
import sys
import time
import os
from pathlib import Path

def run_command(cmd, description, timeout=60):
    """Run a command with timeout and return success status"""
    print(f"🔧 {description}...")
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True,
                              text=True, timeout=timeout)
        if result.returncode == 0:
            print(f"   ✅ SUCCESS")
            return True, result.stdout
        else:
            print(f"   ❌ FAILED (exit code: {result.returncode})")
            if result.stderr:
                print(f"   Error: {result.stderr}")
            return False, result.stderr
    except subprocess.TimeoutExpired:
        print(f"   ⏰ TIMEOUT ({timeout}s)")
        return False, "Timeout"
    except Exception as e:
        print(f"   💥 ERROR: {str(e)}")
        return False, str(e)

def start_backend():
    """Start the backend server"""
    print("🚀 Starting backend server...")

    # Check if backend is already running
    try:
        import requests
        response = requests.get("http://localhost:5000/health", timeout=2)
        if response.status_code == 200:
            print("   ✅ Backend already running")
            return True
    except:
        pass

    # Start backend in background
    try:
        if os.name == 'nt':  # Windows
            cmd = "start /B python backend/app.py"
        else:  # Unix-like
            cmd = "python backend/app.py &"

        process = subprocess.Popen(cmd, shell=True,
                                 stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL)
        time.sleep(3)  # Wait for startup

        # Verify it's running
        import requests
        response = requests.get("http://localhost:5000/health", timeout=5)
        if response.status_code == 200:
            print("   ✅ Backend started successfully")
            return True
        else:
            print("   ❌ Backend failed to start properly")
            return False
    except Exception as e:
        print(f"   💥 Failed to start backend: {e}")
        return False

def run_backend_tests():
    """Run backend-specific tests"""
    print("\n🧪 Running Backend Tests...")

    # Run quick test
    success, output = run_command("python quick_test.py", "Quick functionality test", 30)
    if not success:
        return False

    # Run comprehensive tests
    success, output = run_command("python run_all_tests.py", "Comprehensive test suite", 300)
    if not success:
        return False

    return True

def run_frontend_tests():
    """Run frontend tests if available"""
    print("\n📱 Running Frontend Tests...")

    # Check if Flutter tests exist
    if Path("test").exists():
        success, output = run_command("flutter test", "Flutter unit tests", 120)
        return success
    else:
        print("   ⏭️  No frontend tests found, skipping")
        return True

def generate_reports():
    """Generate test reports"""
    print("\n📊 Generating Reports...")

    success, output = run_command("python generate_test_report.py", "Generate test report", 30)
    return success

def cleanup():
    """Clean up test artifacts"""
    print("\n🧹 Cleaning up...")

    # Kill any background processes
    try:
        if os.name == 'nt':  # Windows
            subprocess.run("taskkill /F /IM python.exe", shell=True,
                         capture_output=True)
        else:  # Unix-like
            subprocess.run("pkill -f 'python backend/app.py'", shell=True,
                         capture_output=True)
    except:
        pass

    print("   ✅ Cleanup complete")

def main():
    """Main CI/CD test function"""
    print("🚀 Story Weaver App - CI/CD Test Suite")
    print("=" * 50)

    success = True
    start_time = time.time()

    try:
        # Step 1: Start backend
        if not start_backend():
            success = False

        # Step 2: Run backend tests
        if success and not run_backend_tests():
            success = False

        # Step 3: Run frontend tests
        if success and not run_frontend_tests():
            success = False

        # Step 4: Generate reports
        if not generate_reports():
            print("   ⚠️  Report generation failed, but continuing")

    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
        success = False

    finally:
        # Always cleanup
        cleanup()

    # Final summary
    duration = time.time() - start_time
    print("\n" + "=" * 50)
    print("🎯 CI/CD TEST RESULTS")
    print("=" * 50)
    print(f"Status: {'✅ SUCCESS' if success else '❌ FAILURE'}")

    if success:
        print("\n🎉 All tests passed! Ready for deployment.")
    else:
        print("\n⚠️  Tests failed. Check logs above for details.")

    # Exit with appropriate code
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()