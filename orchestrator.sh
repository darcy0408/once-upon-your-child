#!/bin/bash
# Orchestrator Agent for Story Weaver Project
# Run this script to oversee project status, Git operations, and task generation

echo "=== Story Weaver Orchestrator ==="
echo "Checking project status..."

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

# Check status
echo "Git status:"
git status --porcelain

# Check stashes
echo "Stashes:"
git stash list

# Check remote branches
echo "Remote branches:"
git branch -r

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo "⚠️  Uncommitted changes detected. Please commit or stash before proceeding."
    exit 1
fi

# Check branch ownership
case $CURRENT_BRANCH in
    codex/*)
        ALLOWED="lib/ test/ pubspec.*"
        echo "✅ On Codex branch - allowed files: $ALLOWED"
        ;;
    gemini/*)
        ALLOWED="backend/*.py backend/tests/ docs/"
        echo "✅ On Gemini branch - allowed files: $ALLOWED"
        ;;
    grok/*)
        ALLOWED=".github/workflows/ scripts/ infra env-templates"
        echo "✅ On Grok branch - allowed files: $ALLOWED"
        ;;
    *)
        echo "⚠️  Not on an agent branch. Switch to codex/*, gemini/*, or grok/*"
        ;;
esac

# Generate tasks based on status
echo ""
echo "=== Generated Tasks ==="
echo "Codex (codex/offline-isar): Finalize Isar offline cache, run flutter test, commit if needed, push."
echo "Gemini (gemini/interactive-polish): Ensure backend tests pass, commit interactive polish, push."
echo "Grok (grok/env-management): Verify env files, commit, push."
echo ""
echo "Ensure agents work on their branches without interference."

# Update status file
echo "Updating November13.md with current status..."
git log --oneline -5 > temp_log.txt
echo "# Updated Status - $(date)" >> November13.md
cat temp_log.txt >> November13.md
rm temp_log.txt

echo "Orchestrator complete. Check November13.md for updates."</content>
<filePath>orchestrator.sh