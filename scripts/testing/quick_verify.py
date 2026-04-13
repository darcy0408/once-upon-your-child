#!/usr/bin/env python3
"""Quick verification of Story Weaver setup"""
import os
import sys
import time
import subprocess
import requests
from pathlib import Path

APP_DIR = Path("C:/dev/story-weaver-app")
os.chdir(APP_DIR)

print("\n" + "="*60)
print("STORY WEAVER - FINAL VERIFICATION & TESTING")
print("="*60)

# Check Flask backend
print("\n1️⃣  Checking Flask Backend...")
try:
    resp = requests.get("http://localhost:5000/health", timeout=3)
    if resp.status_code == 200:
        print("   ✅ Flask backend running on port 5000")
        print(f"   Response: {resp.text[:150]}")
    else:
        print(f"   ❌ Flask health check failed: {resp.status_code}")
except Exception as e:
    print(f"   ❌ Flask backend not accessible: {e}")

# Check Flutter web build
print("\n2️⃣  Checking Flutter Web Build...")
web_index = APP_DIR / "build" / "web" / "index.html"
if web_index.exists():
    print(f"   ✅ Flutter web build exists")
    # Count files in build/web
    web_dir = APP_DIR / "build" / "web"
    file_count = len(list(web_dir.glob("**/*")))
    print(f"   📦 Total files in build/web: {file_count}")
else:
    print(f"   ❌ Flutter web build NOT found")

# Check Flutter web server
print("\n3️⃣  Checking Flutter Web Server (port 8080)...")
try:
    resp = requests.get("http://localhost:8080", timeout=3)
    if resp.status_code == 200:
        print("   ✅ Flutter web server running on port 8080")
    else:
        print(f"   ⚠️  Web server responded with status {resp.status_code}")
except Exception as e:
    print(f"   ⚠️  Web server not accessible yet: {e}")

# Run quality check
print("\n4️⃣  Running Comprehensive Quality Check...")
print("   (This will take 5-10 minutes...)")
print("-" * 60)

quality_script = APP_DIR / "run_comprehensive_quality_check.py"
if quality_script.exists():
    result = subprocess.run([
        str(APP_DIR / "backend" / ".venv" / "Scripts" / "python.exe"),
        str(quality_script)
    ], capture_output=True, text=True, cwd=str(APP_DIR))
    
    # Print output
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print("ERRORS/WARNINGS:")
        print(result.stderr)
    
    if result.returncode == 0:
        print("\n✅ Quality check PASSED")
    else:
        print(f"\n❌ Quality check FAILED (exit code: {result.returncode})")
else:
    print(f"   ❌ Quality check script not found")

print("-" * 60)

# Run cross-browser tests
print("\n5️⃣  Running Cross-Browser Tests...")
print("   (This will take 2-5 minutes...)")
print("-" * 60)

cross_browser_script = APP_DIR / "test_cross_browser.py"
if cross_browser_script.exists():
    result = subprocess.run([
        str(APP_DIR / "backend" / ".venv" / "Scripts" / "python.exe"),
        str(cross_browser_script)
    ], capture_output=True, text=True, cwd=str(APP_DIR))
    
    # Print output
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print("ERRORS/WARNINGS:")
        print(result.stderr)
    
    if result.returncode == 0:
        print("\n✅ Cross-browser tests PASSED")
    else:
        print(f"\n❌ Cross-browser tests FAILED (exit code: {result.returncode})")
else:
    print(f"   ❌ Cross-browser test script not found")

print("-" * 60)

print("\n" + "="*60)
print("VERIFICATION COMPLETE")
print("="*60)
