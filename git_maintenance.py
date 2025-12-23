#!/usr/bin/env python3
"""
Git Maintenance Script
Check status, add files, commit, and push changes
"""
import subprocess
import sys
import os
from datetime import datetime

def run_git_command(cmd, description):
    """Run a git command and return the result"""
    try:
        print(f"🔧 {description}...")
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=os.getcwd())
        if result.returncode == 0:
            print(f"✅ {description} successful")
            return result.stdout.strip(), True
        else:
            print(f"❌ {description} failed")
            print(f"   Error: {result.stderr.strip()}")
            return result.stderr.strip(), False
    except Exception as e:
        print(f"💥 {description} error: {e}")
        return str(e), False

def main():
    print("🔧 Git Maintenance for Story Weaver App")
    print("=" * 50)

    # Check git status
    output, success = run_git_command("git status --porcelain", "Checking git status")
    if not success:
        return False

    if not output.strip():
        print("📋 No changes to commit")
        return True

    print(f"📝 Changes found:\n{output}")

    # Add all changes
    _, success = run_git_command("git add .", "Staging all changes")
    if not success:
        return False

    # Commit changes
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    commit_msg = f"[AGENT SYNC | {timestamp}] Automated Git Maintenance"
    _, success = run_git_command(f'git commit -m "{commit_msg}"', "Committing changes")
    if not success:
        return False

    # Pull changes
    _, success = run_git_command("git pull origin main --strategy-option=ours --no-edit", "Pulling latest changes from main")
    if not success:
        return False

    # Push changes
    _, success = run_git_command("git push origin main", "Pushing to main branch")
    if not success:
        return False

    print("\n🎉 Git maintenance completed successfully!")
    print(f"✅ Repository Synced. Timestamp: {timestamp}")
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
