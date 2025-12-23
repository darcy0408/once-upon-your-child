#!/usr/bin/env python3
"""
Railway Production Deployment Test Script
Tests your live Railway deployment for custom elements functionality
"""
import requests
import json
import sys
import subprocess
import time
import threading

def check_railway_cli():
    """Check Railway CLI status and get service info"""
    print("\n🔧 Checking Railway CLI...")

    try:
        # Check if CLI is installed
        result = subprocess.run(["railway", "--version"], capture_output=True, text=True, timeout=5)
        if result.returncode != 0:
            print("   ⚠️  Railway CLI not installed or not in PATH")
            print("      Install with: npm install -g @railway/cli")
            return False

        print("   ✅ Railway CLI available")

        # Check authentication
        result = subprocess.run(["railway", "whoami"], capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print("   ✅ Railway CLI authenticated")
        else:
            print("   ⚠️  Railway CLI not authenticated")
            print("      Run: railway login")
            return False

        # Try to get services
        try:
            result = subprocess.run(["railway", "services"], capture_output=True, text=True, timeout=15)
            if result.returncode == 0:
                print("   📋 Railway Services found")
                # Don't print full output as it might be verbose
            else:
                print("   ⚠️  Could not list Railway services")
        except:
            print("   ⚠️  Could not check Railway services")

        return True

    except FileNotFoundError:
        print("   ❌ Railway CLI not found")
        print("      Install with: npm install -g @railway/cli")
        return False
    except subprocess.TimeoutExpired:
        print("   ⏱️  Railway CLI check timeout")
        return False
    except Exception as e:
        print(f"   ❌ Railway CLI error: {e}")
        return False

def test_railway_deployment():
    """Test Railway production deployment"""

    # Check Railway CLI first
    cli_available = check_railway_cli()

    # Get Railway URL from user
    if len(sys.argv) > 1:
        railway_url = sys.argv[1]
    else:
        railway_url = input("Enter your Railway backend URL (e.g., https://backend-production-xxxx.up.railway.app): ").strip()

    if not railway_url.startswith('http'):
        railway_url = f"https://{railway_url}"

    # Remove trailing slash
    railway_url = railway_url.rstrip('/')

    print(f"\n🧪 Testing Railway Production Deployment: {railway_url}")
    print("=" * 60)

    # Test 1: Health Check
    print("\n1️⃣ Testing Health Endpoint...")
    try:
        response = requests.get(f"{railway_url}/health", timeout=10)
        if response.status_code == 200:
            data = response.json()
            print("   ✅ PASS - Health check successful")
            print(f"   📊 Status: {data.get('status', 'unknown')}")
            print(f"   🤖 Model: {data.get('model', 'unknown')}")
        else:
            print(f"   ❌ FAIL - HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"   ❌ FAIL - {str(e)}")
        return False

    # Test 2: Custom Elements Story Generation
    print("\n2️⃣ Testing Custom Elements Story Generation...")
    payload = {
        "character": {
            "name": "Alex",
            "age": 8,
            "personality": "brave",
            "background": "adventurer"
        },
        "customElements": [
            {
                "type": "creature",
                "name": "dragon",
                "description": "a mighty fire-breathing dragon"
            },
            {
                "type": "location",
                "name": "castle",
                "description": "a towering stone castle on a hill"
            },
            {
                "type": "item",
                "name": "magic sword",
                "description": "a glowing sword with magical powers"
            }
        ],
        "theme": "fantasy",
        "length": "short"
    }

    try:
        response = requests.post(f"{railway_url}/generate-story",
                               json=payload, timeout=60)
        if response.status_code == 200:
            data = response.json()
            story = data.get("story", "").lower()

            # Check for custom elements
            dragon_found = "dragon" in story
            castle_found = "castle" in story
            sword_found = "sword" in story

            if dragon_found and castle_found and sword_found:
                print("   ✅ PASS - All custom elements found in story")
                print(f"   📖 Story length: {len(data.get('story', ''))} characters")
                print(f"   🏷️  Title: {data.get('title', 'No title')}")
            else:
                print("   ⚠️  PARTIAL - Some custom elements missing:")
                print(f"      Dragon: {'✅' if dragon_found else '❌'}")
                print(f"      Castle: {'✅' if castle_found else '❌'}")
                print(f"      Sword: {'✅' if sword_found else '❌'}")
                return False
        else:
            print(f"   ❌ FAIL - HTTP {response.status_code}: {response.text[:200]}")
            return False
    except Exception as e:
        print(f"   ❌ FAIL - {str(e)}")
        return False

    # Test 3: Performance Test
    print("\n3️⃣ Testing Performance (Concurrent Requests)...")
    import time
    import threading

    results = []
    errors = []

    def make_request(i):
        try:
            start = time.time()
            response = requests.post(f"{railway_url}/generate-story",
                                   json=payload, timeout=60)
            duration = time.time() - start
            if response.status_code == 200:
                results.append(duration)
            else:
                errors.append(f"Request {i}: HTTP {response.status_code}")
        except Exception as e:
            errors.append(f"Request {i}: {str(e)}")

    # Make 3 concurrent requests
    threads = []
    for i in range(3):
        t = threading.Thread(target=make_request, args=(i,))
        threads.append(t)
        t.start()

    # Wait for all threads
    for t in threads:
        t.join()

    if len(results) == 3 and len(errors) == 0:
        avg_time = sum(results) / len(results)
        max_time = max(results)
        print("   ✅ PASS - All concurrent requests successful")
        print(f"   ⏱️  Average response time: {avg_time:.1f}s")
        print(f"   🏃 Max response time: {max_time:.1f}s")
        if max_time < 30:
            print("   🚀 Excellent performance!")
        elif max_time < 60:
            print("   ⚡ Good performance")
        else:
            print("   🐌 Slower than expected, but functional")
    else:
        print(f"   ❌ FAIL - {len(errors)} errors out of 3 requests")
        for error in errors[:3]:  # Show first 3 errors
            print(f"      {error}")
        return False

    print("\n" + "=" * 60)
    print("🎉 RAILWAY PRODUCTION DEPLOYMENT: READY FOR LAUNCH!")
    print("=" * 60)
    print("✅ Health checks passing")
    print("✅ Custom elements working")
    print("✅ Concurrent requests handled")
    print("✅ Performance acceptable")
    print("\n🚀 Your Railway deployment is production-ready!")
    return True

if __name__ == "__main__":
    try:
        success = test_railway_deployment()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n⏹️  Test cancelled")
        sys.exit(1)
    except Exception as e:
        print(f"\n💥 Test failed: {e}")
        sys.exit(1)