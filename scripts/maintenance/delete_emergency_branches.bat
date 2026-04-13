@echo off
REM delete_emergency_branches.bat
REM Emergency Branch Deletion Script (Windows)
REM Run this on or after January 24, 2026

echo.
echo ======================================
echo Emergency Branch Deletion Script
echo ======================================
echo.
echo Scheduled Deletion Date: January 24, 2026
echo.
echo This will delete the following branches:
echo   - emergency-rollback
echo   - main-backup-pre-cleanup-2025-11-17
echo.
echo WARNING: Review EMERGENCY_BRANCH_CLEANUP_REMINDER.md first!
echo.
echo Have you verified that:
echo   [x] Main branch is stable (30 days of testing)
echo   [x] No critical issues in past month
echo   [x] No emergency rollback needed
echo   [x] Confident in current codebase state
echo.
echo Press Ctrl+C to cancel, or any key to continue...
pause > nul

echo.
echo Phase 1: Deleting emergency-rollback...
git push origin --delete emergency-rollback && (
  echo [OK] Deleted emergency-rollback from remote
) || (
  echo [FAIL] Failed to delete emergency-rollback (may already be deleted)
)

echo.
echo Phase 2: Deleting main-backup-pre-cleanup-2025-11-17...
git push origin --delete main-backup-pre-cleanup-2025-11-17 && (
  echo [OK] Deleted main-backup-pre-cleanup-2025-11-17 from remote
) || (
  echo [FAIL] Failed to delete main-backup (may already be deleted)
)

echo.
echo Phase 3: Deleting local emergency-rollback if exists...
git branch -d emergency-rollback 2>nul && (
  echo [OK] Deleted local emergency-rollback branch
) || (
  echo [INFO] No local emergency-rollback branch found
)

echo.
echo Phase 4: Pruning references...
git fetch --prune && (
  echo [OK] Pruned remote branch references
) || (
  echo [FAIL] Failed to prune references
)

echo.
echo ======================================
echo Emergency branch cleanup complete!
echo ======================================
echo.
echo Final repository state:
echo.
git branch -a
echo.
git branch -a | find /c /v "" > temp_count.txt
set /p BRANCH_COUNT=<temp_count.txt
del temp_count.txt
echo Total branches: %BRANCH_COUNT%
echo.
echo Next steps:
echo 1. Update EMERGENCY_BRANCH_CLEANUP_REMINDER.md status to 'COMPLETED'
echo 2. Update BRANCH_STATUS_ANALYSIS.md with final branch count
echo 3. Celebrate clean repository!
echo.
pause
