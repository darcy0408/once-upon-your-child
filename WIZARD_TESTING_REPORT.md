WIZARD TESTING REPORT  
Date: 2025-12-09  
Agent: Codex  
Branch: feature/gui-redesign  
Commit: (not reached - app failed to run)

## OVERALL STATUS
[ ] PASS  
[ ] PARTIAL  
[x] FAIL - Blocking runtime errors prevented wizard testing

## TEST RESULTS

### Step 1 - Step 4 & Navigation & Story Generation
Tests Passed: 0/67 (blocked before wizard)
Issues Found:
1. App fails at launch in Chrome due to `FirebaseException` type mismatch on web (`type 'FirebaseException' is not a subtype of type 'JavaScriptObject'`) coming from `grace_period_analytics.dart` -> `firebase_analytics` on web.
2. Subscription sync throws SQL error against local DB: `no such column: user.stories_created_count` when calling `/users/.../feature-unlocks`, causing unhandled exception spam in console.
3. Console flooded with avatar URL debug prints and repeated rebuild errors; UI does not stabilize to reach wizard.
4. Missing fonts warning: “Could not find a set of Noto fonts...” on startup.

### Console Errors
Clean Console: [ ] YES  [x] NO  
Errors Found:
- `FirebaseException` as above (stack trace in console on launch).  
- SQLite column missing: `user.stories_created_count` (stack trace in console).  
- Missing font assets warning (Noto fonts).

## CRITICAL ISSUES (Must fix before deploy)
1. Fix Firebase Analytics web integration crash (`FirebaseException` type mismatch) so app can render.
2. Fix subscription sync endpoint/DB schema mismatch (`user.stories_created_count` column missing) to stop fatal errors on startup.
3. Address missing font assets warning or suppress debug spam; ensure startup console is clean.

## MINOR ISSUES
1. Avatar debug URL logs clutter console; consider gating behind debug flag.

## OBSERVATIONS
- Performance: Not testable (app crashing on launch).
- Animations: Not testable.
- Visual Polish: Not testable.
- User Experience: Not testable.

## RECOMMENDATIONS
- [ ] Ready to deploy as-is  
- [x] Fix critical issues first  
- [ ] Needs more work  

Notes: Wizard flow could not be exercised; no checklist items verified. Re-run full 67-item test after startup blockers are resolved.
