#!/usr/bin/env python3
"""
Story Weaver App - Complete Setup and Testing Script
This script handles all setup and testing steps for the Story Weaver application.
"""

import os
import sys
import time
import subprocess
import socket
import requests
from pathlib import Path
from datetime import datetime

# Configuration
APP_DIR = Path("C:/dev/story-weaver-app")
BACKEND_DIR = APP_DIR / "backend"
VENV_PYTHON = BACKEND_DIR / ".venv" / "Scripts" / "python.exe"
BACKEND_PORT = 5000
WEB_PORT = 8080
FLASK_URL = f"http://localhost:{BACKEND_PORT}"
WEB_URL = f"http://localhost:{WEB_PORT}"

def log_step(step_num, title):
    """Print a formatted step header"""
    print(f"\n{'='*60}")
    print(f"STEP {step_num}: {title}")
    print(f"{'='*60}\n")

def check_port_available(port):
    """Check if a port is available"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    result = sock.connect_ex(('127.0.0.1', port))
    sock.close()
    return result != 0

def is_server_running(url, timeout=3):
    """Check if a server is running and responding"""
    try:
        response = requests.get(url, timeout=timeout)
        return response.status_code < 500
    except:
        return False

def run_command(cmd, cwd=None, shell=True, wait=True):
    """Run a system command"""
    try:
        if wait:
            process = subprocess.Popen(cmd, shell=shell, cwd=cwd, 
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            stdout, stderr = process.communicate()
            return process.returncode, stdout.decode(), stderr.decode()
        else:
            subprocess.Popen(cmd, shell=shell, cwd=cwd, 
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return 0, "", ""
    except Exception as e:
        return 1, "", str(e)

# ============================================================
# STEP 1: Check if Flask backend is running
# ============================================================
log_step(1, "Checking Flask Backend")

backend_running = is_server_running(f"{FLASK_URL}/health")

if backend_running:
    print("✅ Flask backend is already running!")
    try:
        response = requests.get(f"{FLASK_URL}/health", timeout=3)
        print(f"   Response: {response.text}")
    except:
        pass
else:
    print("❌ Flask backend is NOT running. Starting it...")
    
    # Start the backend process
    cmd = f'"{VENV_PYTHON}" "{BACKEND_DIR}/app.py"'
    proc = subprocess.Popen(cmd, shell=True, cwd=str(APP_DIR),
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"   Backend process started with PID: {proc.pid}")
    
    print("   Waiting 10 seconds for backend to initialize...")
    time.sleep(10)
    
    # Check health again
    if is_server_running(f"{FLASK_URL}/health"):
        print("✅ Flask backend is now running!")
        try:
            response = requests.get(f"{FLASK_URL}/health", timeout=3)
            print(f"   Response: {response.text}")
        except:
            pass
    else:
        print("❌ Flask backend health check still failed after starting")
        print("   (Check C:/dev/story-weaver-app/backend_startup.log for details)")

# ============================================================
# STEP 2: Check if Flutter web build exists
# ============================================================
log_step(2, "Checking Flutter Web Build")

flutter_index = APP_DIR / "build" / "web" / "index.html"
if flutter_index.exists():
    print(f"✅ Flutter web build found at: {flutter_index}")
else:
    print(f"❌ Flutter web build NOT found at: {flutter_index}")
    print("   Building Flutter web release...")
    
    returncode, stdout, stderr = run_command("flutter build web --release", cwd=str(APP_DIR))
    
    if returncode == 0:
        print("✅ Flutter build completed successfully!")
    else:
        print(f"❌ Flutter build failed with exit code: {returncode}")
        if stderr:
            print(f"   Error: {stderr}")

# ============================================================
# STEP 3: Start web server for Flutter app if needed
# ============================================================
log_step(3, "Starting Flutter Web Server")

port_available = check_port_available(WEB_PORT)

if port_available:
    print(f"Port {WEB_PORT} is available. Starting web server...")
    
    # Use Python's built-in http.server
    web_dir = str(APP_DIR / "build" / "web")
    cmd = f'"{VENV_PYTHON}" -m http.server {WEB_PORT} --directory "{web_dir}"'
    
    subprocess.Popen(cmd, shell=True, cwd=str(APP_DIR),
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"✅ Web server started on port {WEB_PORT}")
else:
    print(f"⚠️  Port {WEB_PORT} is already in use (server already running)")

# ============================================================
# STEP 4: Verify both servers
# ============================================================
log_step(4, "Verifying Both Servers")

print("Waiting 5 seconds for servers to stabilize...")
time.sleep(5)

print(f"\nChecking Flask backend ({FLASK_URL}/health)...")
if is_server_running(f"{FLASK_URL}/health"):
    print("✅ Flask backend is running")
    try:
        response = requests.get(f"{FLASK_URL}/health", timeout=3)
        print(f"   Status: {response.status_code}")
        print(f"   Response: {response.text[:100]}")
    except Exception as e:
        print(f"   Error reading response: {e}")
else:
    print("❌ Flask backend is not responding")

print(f"\nChecking Flutter web server ({WEB_URL})...")
if is_server_running(WEB_URL):
    print("✅ Flutter web server is running")
    try:
        response = requests.get(WEB_URL, timeout=3)
        print(f"   Status: {response.status_code}")
    except Exception as e:
        print(f"   Error: {e}")
else:
    print("❌ Flutter web server is not responding")

# ============================================================
# STEP 5: Run comprehensive quality check
# ============================================================
log_step(5, "Running Comprehensive Quality Check")

quality_check_script = APP_DIR / "run_comprehensive_quality_check.py"

if quality_check_script.exists():
    print("Starting quality check (this may take 5-10 minutes)...")
    print("=" * 60)
    
    # Set environment variable and run the script
    env = os.environ.copy()
    env['MOCK_TESTING_MODE'] = 'false'
    
    returncode, stdout, stderr = run_command(
        f'"{VENV_PYTHON}" "{quality_check_script}"',
        cwd=str(APP_DIR),
        wait=True
    )
    
    print(stdout)
    if stderr:
        print("STDERR:")
        print(stderr)
    
    print("=" * 60)
    if returncode == 0:
        print("✅ Quality check completed successfully!")
    else:
        print(f"❌ Quality check failed with exit code: {returncode}")
else:
    print(f"❌ Quality check script not found: {quality_check_script}")

# ============================================================
# STEP 6: Run cross-browser tests
# ============================================================
log_step(6, "Running Cross-Browser Tests")

cross_browser_script = APP_DIR / "test_cross_browser.py"

if cross_browser_script.exists():
    print("Starting cross-browser tests...")
    print("=" * 60)
    
    returncode, stdout, stderr = run_command(
        f'"{VENV_PYTHON}" "{cross_browser_script}"',
        cwd=str(APP_DIR),
        wait=True
    )
    
    print(stdout)
    if stderr:
        print("STDERR:")
        print(stderr)
    
    print("=" * 60)
    if returncode == 0:
        print("✅ Cross-browser tests completed successfully!")
    else:
        print(f"❌ Cross-browser tests failed with exit code: {returncode}")
else:
    print(f"❌ Cross-browser test script not found: {cross_browser_script}")

# ============================================================
# Final Summary
# ============================================================
log_step("FINAL", "All Steps Completed")

print("\n📋 Summary:")
print(f"  ✓ Flask Backend: {FLASK_URL}")
print(f"  ✓ Flutter Web Server: {WEB_URL}")
print(f"  ✓ Quality check and cross-browser tests executed")
print("\n" + "=" * 60)
print("Script execution completed!")
print("=" * 60)
