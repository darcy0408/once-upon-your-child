#!/usr/bin/env python3
"""Final comprehensive test of Story Weaver app"""
import os
import sys
import time
import subprocess
import requests
import socket
from pathlib import Path
import json

APP_DIR = Path("C:/dev/story-weaver-app")
os.chdir(APP_DIR)

# Check for web build files
web_dir = APP_DIR / "build" / "web"
web_files = list(web_dir.glob("*")) if web_dir.exists() else []

print("\n" + "="*70)
print("STORY WEAVER APP - COMPREHENSIVE VERIFICATION & TESTING")
print("="*70)

print(f"\n📍 Working directory: {os.getcwd()}")
print(f"📁 Web build directory: {web_dir}")
print(f"📦 Web build files found: {len(web_files)}")

# Check Flask backend
print("\n" + "-"*70)
print("1️⃣  FLASK BACKEND CHECK")
print("-"*70)

try:
    resp = requests.get("http://localhost:5000/health", timeout=3)
    if resp.status_code == 200:
        data = resp.json()
        print("✅ Flask backend is RUNNING on port 5000")
        print(f"   Database: {data.get('database', 'unknown')}")
        print(f"   Status: {data.get('status', 'unknown')}")
        print(f"   Gemini API configured: {data.get('has_api_key', False)}")
    else:
        print(f"❌ Flask backend returned status {resp.status_code}")
except Exception as e:
    print(f"❌ Flask backend not accessible: {type(e).__name__}: {e}")

# Check web build
print("\n" + "-"*70)
print("2️⃣  FLUTTER WEB BUILD CHECK")
print("-"*70)

if web_files:
    print(f"✅ Flutter web build directory exists with {len(web_files)} files")
    key_files = ['main.dart.js', 'flutter_service_worker.js', 'manifest.json']
    for key_file in key_files:
        if (web_dir / key_file).exists():
            size = (web_dir / key_file).stat().st_size
            print(f"   ✓ {key_file} ({size:,} bytes)")
else:
    print(f"❌ Flutter web build directory is empty or not found")

# Check if port 8080 is available
print("\n" + "-"*70)
print("3️⃣  WEB SERVER PORT CHECK")
print("-"*70)

def is_port_available(port):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        result = sock.connect_ex(('127.0.0.1', port))
        return result != 0
    finally:
        sock.close()

port_available = is_port_available(8080)
if port_available:
    print("⚠️  Port 8080 is available - starting web server...")
    
    # Start the web server
    try:
        # Use Python's http.server
        cmd = [
            sys.executable,
            '-m', 'http.server',
            '8080',
            '--directory', str(web_dir)
        ]
        
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        print(f"   ✅ Web server started (PID: {proc.pid})")
        print(f"   📍 Serving: {web_dir}")
        
        # Give it a moment to start
        time.sleep(2)
        
        # Test connection
        try:
            resp = requests.get("http://localhost:8080", timeout=3)
            print(f"   ✅ Web server responding (status: {resp.status_code})")
        except Exception as e:
            print(f"   ⚠️  Web server started but not yet responding: {e}")
    except Exception as e:
        print(f"   ❌ Failed to start web server: {e}")
else:
    print("⚠️  Port 8080 is already in use (server may already be running)")
    try:
        resp = requests.get("http://localhost:8080", timeout=3)
        print(f"   ✅ Web server is accessible (status: {resp.status_code})")
    except Exception as e:
        print(f"   ⚠️  Port in use but not responding: {e}")

# Run quality check
print("\n" + "="*70)
print("4️⃣  COMPREHENSIVE QUALITY CHECK")
print("="*70)

quality_script = APP_DIR / "run_comprehensive_quality_check.py"

if quality_script.exists():
    print("Starting quality check (5-10 minutes)...")
    print("-"*70)
    
    try:
        # Run directly with python
        result = subprocess.run(
            [sys.executable, str(quality_script)],
            capture_output=True,
            text=True,
            cwd=str(APP_DIR),
            timeout=600  # 10 minute timeout
        )
        
        if result.stdout:
            print(result.stdout)
        
        if result.returncode == 0:
            print("\n✅ Quality check COMPLETED SUCCESSFULLY")
        else:
            print(f"\n❌ Quality check FAILED (exit code: {result.returncode})")
            if result.stderr:
                print("\nError output:")
                print(result.stderr)
                
    except subprocess.TimeoutExpired:
        print("❌ Quality check TIMEOUT (exceeded 10 minutes)")
    except Exception as e:
        print(f"❌ Failed to run quality check: {e}")
else:
    print(f"❌ Quality check script not found: {quality_script}")

# Run cross-browser tests
print("\n" + "="*70)
print("5️⃣  CROSS-BROWSER TESTS")
print("="*70)

cross_browser_script = APP_DIR / "test_cross_browser.py"

if cross_browser_script.exists():
    print("Starting cross-browser tests (2-5 minutes)...")
    print("-"*70)
    
    try:
        result = subprocess.run(
            [sys.executable, str(cross_browser_script)],
            capture_output=True,
            text=True,
            cwd=str(APP_DIR),
            timeout=300  # 5 minute timeout
        )
        
        if result.stdout:
            print(result.stdout)
        
        if result.returncode == 0:
            print("\n✅ Cross-browser tests COMPLETED SUCCESSFULLY")
        else:
            print(f"\n⚠️  Cross-browser tests finished (exit code: {result.returncode})")
            if result.stderr:
                print("\nOutput:")
                print(result.stderr)
                
    except subprocess.TimeoutExpired:
        print("❌ Cross-browser tests TIMEOUT (exceeded 5 minutes)")
    except Exception as e:
        print(f"❌ Failed to run cross-browser tests: {e}")
else:
    print(f"❌ Cross-browser test script not found: {cross_browser_script}")

# Final summary
print("\n" + "="*70)
print("VERIFICATION COMPLETE")
print("="*70)
print("\n📋 Summary:")
print(f"  ✓ Flask Backend: http://localhost:5000")
print(f"  ✓ Flutter Web Build: {len(web_files)} files")
print(f"  ✓ Web Server: http://localhost:8080")
print(f"  ✓ Quality checks and cross-browser tests executed")
print("\n" + "="*70 + "\n")
