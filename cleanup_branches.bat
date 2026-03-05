@echo off
REM Branch Cleanup Script (Windows)
REM Generated: December 24, 2025
REM Run this to delete all outdated branches identified in BRANCH_STATUS_ANALYSIS.md

echo.
echo ============================
echo Story Weaver Branch Cleanup
echo ============================
echo.
echo This will delete 15 outdated branches from remote.
echo Press Ctrl+C to cancel, or any key to continue...
pause > nul

echo.
echo Phase 1: Deleting outdated feature branches...
echo.

git push origin --delete feature/wizard-story-creator && echo [OK] Deleted feature/wizard-story-creator || echo [FAIL] Failed to delete feature/wizard-story-creator
git push origin --delete feature/gui-redesign && echo [OK] Deleted feature/gui-redesign || echo [FAIL] Failed to delete feature/gui-redesign
git push origin --delete feature/offline-first && echo [OK] Deleted feature/offline-first || echo [FAIL] Failed to delete feature/offline-first
git push origin --delete feature/celery-integration && echo [OK] Deleted feature/celery-integration || echo [FAIL] Failed to delete feature/celery-integration
git push origin --delete feature/accessibility-fix && echo [OK] Deleted feature/accessibility-fix || echo [FAIL] Failed to delete feature/accessibility-fix
git push origin --delete feature/security-hardening && echo [OK] Deleted feature/security-hardening || echo [FAIL] Failed to delete feature/security-hardening
git push origin --delete feature/backend-modularization && echo [OK] Deleted feature/backend-modularization || echo [FAIL] Failed to delete feature/backend-modularization
git push origin --delete refactor/backend-modularization && echo [OK] Deleted refactor/backend-modularization || echo [FAIL] Failed to delete refactor/backend-modularization

echo.
echo Phase 2: Deleting outdated fix branches...
echo.

git push origin --delete fix/network-error-handling && echo [OK] Deleted fix/network-error-handling || echo [FAIL] Failed to delete fix/network-error-handling
git push origin --delete fix-production-images && echo [OK] Deleted fix-production-images || echo [FAIL] Failed to delete fix-production-images
git push origin --delete fix/onboarding-ux-improvements && echo [OK] Deleted fix/onboarding-ux-improvements || echo [FAIL] Failed to delete fix/onboarding-ux-improvements
git push origin --delete grok2/ui-polish && echo [OK] Deleted grok2/ui-polish || echo [FAIL] Failed to delete grok2/ui-polish

echo.
echo Phase 3: Deleting outdated merge branches...
echo.

git push origin --delete merge-phase1-independent && echo [OK] Deleted merge-phase1-independent || echo [FAIL] Failed to delete merge-phase1-independent
git push origin --delete merge-phase5-production-features && echo [OK] Deleted merge-phase5-production-features || echo [FAIL] Failed to delete merge-phase5-production-features

echo.
echo Phase 4: Deleting old dev branches...
echo.

git push origin --delete codex-dev && echo [OK] Deleted codex-dev || echo [FAIL] Failed to delete codex-dev

echo.
echo ============================
echo Branch cleanup complete!
echo ============================
echo.
echo Next steps:
echo 1. Review dependabot PRs at: https://github.com/darcy0408/story-weaver-app/pulls
echo 2. Test and merge critical updates (werkzeug, stripe, redis)
echo 3. Run 'git fetch --prune' to clean up local references
echo.
pause
