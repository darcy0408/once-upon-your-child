#!/usr/bin/env python3
"""
Git Push Script for Railway Deployment Fix
"""
import subprocess
import sys

def run_command(cmd, description):
    """Run a command and return success status"""
    try:
        print(f"🔧 {description}...")
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            print(f"✅ {description} successful")
            if result.stdout.strip():
                print(f"   Output: {result.stdout.strip()}")
            return True
        else:
            print(f"❌ {description} failed")
            print(f"   Error: {result.stderr.strip()}")
            return False
    except subprocess.TimeoutExpired:
        print(f"⏱️ {description} timed out")
        return False
    except Exception as e:
        print(f"💥 {description} error: {e}")
        return False

def main():
    print("🚀 Pushing Railway Deployment Fix to Git")
    print("=" * 50)

    # Check git status
    if not run_command("git status --porcelain", "Checking git status"):
        return False

    # Add changes
    if not run_command("git add backend/requirements.txt backend/app.py", "Staging changes"):
        return False

    # Commit changes
    commit_msg = "Fix: Enable Railway deployment - uncomment psycopg2-binary and add anonymous user creation"
    if not run_command(f'git commit -m "{commit_msg}"', "Committing changes"):
        return False

    # Push changes
    if not run_command("git push origin main", "Pushing to main branch"):
        return False

    print("\n🎉 Successfully pushed Railway deployment fixes!")
    print("Railway should now redeploy automatically.")
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)