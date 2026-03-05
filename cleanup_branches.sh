#!/bin/bash
# Branch Cleanup Script
# Generated: December 24, 2025
# Run this to delete all outdated branches identified in BRANCH_STATUS_ANALYSIS.md

echo "🧹 Story Weaver Branch Cleanup"
echo "=============================="
echo ""
echo "This will delete 15 outdated branches from remote."
echo "Press Ctrl+C to cancel, or Enter to continue..."
read

echo ""
echo "Phase 1: Deleting outdated feature branches..."

git push origin --delete feature/wizard-story-creator && echo "✓ Deleted feature/wizard-story-creator" || echo "✗ Failed to delete feature/wizard-story-creator"
git push origin --delete feature/gui-redesign && echo "✓ Deleted feature/gui-redesign" || echo "✗ Failed to delete feature/gui-redesign"
git push origin --delete feature/offline-first && echo "✓ Deleted feature/offline-first" || echo "✗ Failed to delete feature/offline-first"
git push origin --delete feature/celery-integration && echo "✓ Deleted feature/celery-integration" || echo "✗ Failed to delete feature/celery-integration"
git push origin --delete feature/accessibility-fix && echo "✓ Deleted feature/accessibility-fix" || echo "✗ Failed to delete feature/accessibility-fix"
git push origin --delete feature/security-hardening && echo "✓ Deleted feature/security-hardening" || echo "✗ Failed to delete feature/security-hardening"
git push origin --delete feature/backend-modularization && echo "✓ Deleted feature/backend-modularization" || echo "✗ Failed to delete feature/backend-modularization"
git push origin --delete refactor/backend-modularization && echo "✓ Deleted refactor/backend-modularization" || echo "✗ Failed to delete refactor/backend-modularization"

echo ""
echo "Phase 2: Deleting outdated fix branches..."

git push origin --delete fix/network-error-handling && echo "✓ Deleted fix/network-error-handling" || echo "✗ Failed to delete fix/network-error-handling"
git push origin --delete fix-production-images && echo "✓ Deleted fix-production-images" || echo "✗ Failed to delete fix-production-images"
git push origin --delete fix/onboarding-ux-improvements && echo "✓ Deleted fix/onboarding-ux-improvements" || echo "✗ Failed to delete fix/onboarding-ux-improvements"
git push origin --delete grok2/ui-polish && echo "✓ Deleted grok2/ui-polish" || echo "✗ Failed to delete grok2/ui-polish"

echo ""
echo "Phase 3: Deleting outdated merge branches..."

git push origin --delete merge-phase1-independent && echo "✓ Deleted merge-phase1-independent" || echo "✗ Failed to delete merge-phase1-independent"
git push origin --delete merge-phase5-production-features && echo "✓ Deleted merge-phase5-production-features" || echo "✗ Failed to delete merge-phase5-production-features"

echo ""
echo "Phase 4: Deleting old dev branches..."

git push origin --delete codex-dev && echo "✓ Deleted codex-dev" || echo "✗ Failed to delete codex-dev"

echo ""
echo "✅ Branch cleanup complete!"
echo ""
echo "Next steps:"
echo "1. Review dependabot PRs at: https://github.com/darcy0408/story-weaver-app/pulls"
echo "2. Test and merge critical updates (werkzeug, stripe, redis)"
echo "3. Run 'git fetch --prune' to clean up local references"
echo ""
