#!/bin/bash
# delete_emergency_branches.sh
# Emergency Branch Deletion Script
# Run this on or after January 24, 2026

echo ""
echo "======================================"
echo "Emergency Branch Deletion Script"
echo "======================================"
echo ""
echo "Scheduled Deletion Date: January 24, 2026"
echo "Today's Date: $(date +%Y-%m-%d)"
echo ""
echo "This will delete the following branches:"
echo "  - emergency-rollback"
echo "  - main-backup-pre-cleanup-2025-11-17"
echo ""
echo "⚠️  IMPORTANT: Review EMERGENCY_BRANCH_CLEANUP_REMINDER.md first!"
echo ""
echo "Have you verified that:"
echo "  ✓ Main branch is stable (30 days of testing)"
echo "  ✓ No critical issues in past month"
echo "  ✓ No emergency rollback needed"
echo "  ✓ Confident in current codebase state"
echo ""
echo "Press Ctrl+C to cancel, or Enter to continue..."
read

echo ""
echo "Phase 1: Deleting emergency-rollback..."
git push origin --delete emergency-rollback && \
  echo "✓ Deleted emergency-rollback from remote" || \
  echo "✗ Failed to delete emergency-rollback (may already be deleted)"

echo ""
echo "Phase 2: Deleting main-backup-pre-cleanup-2025-11-17..."
git push origin --delete main-backup-pre-cleanup-2025-11-17 && \
  echo "✓ Deleted main-backup-pre-cleanup-2025-11-17 from remote" || \
  echo "✗ Failed to delete main-backup (may already be deleted)"

echo ""
echo "Phase 3: Deleting local emergency-rollback if exists..."
git branch -d emergency-rollback 2>/dev/null && \
  echo "✓ Deleted local emergency-rollback branch" || \
  echo "ℹ No local emergency-rollback branch found"

echo ""
echo "Phase 4: Pruning references..."
git fetch --prune && \
  echo "✓ Pruned remote branch references" || \
  echo "✗ Failed to prune references"

echo ""
echo "======================================"
echo "Emergency branch cleanup complete!"
echo "======================================"
echo ""
echo "Final repository state:"
echo ""
git branch -a
echo ""
echo "Total branches: $(git branch -a | grep -v HEAD | wc -l)"
echo ""
echo "Next steps:"
echo "1. Update EMERGENCY_BRANCH_CLEANUP_REMINDER.md status to 'COMPLETED'"
echo "2. Update BRANCH_STATUS_ANALYSIS.md with final branch count"
echo "3. Celebrate clean repository! 🎉"
echo ""
