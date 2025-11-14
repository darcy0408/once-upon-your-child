#!/bin/bash
# Simple script to merge completed branches

echo "🔄 Starting branch merge process..."

# List of branches to merge in order
BRANCHES=(
    "gemini/developer-documentation"
    "codex/story-result-polish" 
    "grok/production-maintenance"
    "grok/business-intelligence"
    "grok/security-hardening"
)

for branch in "${BRANCHES[@]}"; do
    echo "📋 Attempting to merge $branch..."
    
    if git merge "$branch" --no-ff -m "Merge $branch: Completed work" 2>/dev/null; then
        echo "✅ Successfully merged $branch"
    else
        echo "⚠️  Conflicts in $branch - skipping for now"
        git merge --abort 2>/dev/null || true
    fi
done

echo "🎯 Merge process complete. Check git status for any remaining conflicts."
