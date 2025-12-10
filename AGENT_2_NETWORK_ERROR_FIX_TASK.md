# 🔧 AGENT 2 TASK: Fix Network Error Handling

**Agent:** Grok or Codex
**Branch:** `fix/network-error-handling` (YOU WILL CREATE THIS)
**Time Estimate:** 30-45 minutes
**Priority:** MEDIUM - Improves UX before deployment

---

## 🎯 YOUR MISSION

Improve network error handling in the app to show user-friendly error messages instead of technical exceptions. This will make the app more professional and easier to troubleshoot.

---

## ⚠️ CRITICAL: BRANCH SETUP (DO THIS FIRST!)

**YOU WILL CREATE A NEW BRANCH!**

```bash
# 1. Navigate to project directory
cd C:\dev\story-weaver-app

# 2. Checkout main branch first
git checkout feature/gui-redesign

# 3. Pull latest changes
git pull origin feature/gui-redesign

# 4. Create NEW branch for this work
git checkout -b fix/network-error-handling

# 5. Verify you're on the new branch
git branch --show-current
```

**Expected output:** `fix/network-error-handling`

**If you see `feature/gui-redesign` or `main`, you did it wrong. Try again.**

---

## 📋 WHY THIS BRANCH SETUP?

**Agent 1** is testing on `feature/gui-redesign` and will commit test reports there.

**Agent 2** (you) is fixing code on `fix/network-error-handling`.

**This prevents conflicts!** You can both work simultaneously without stepping on each other's toes.

---

## 🔍 PROBLEM DESCRIPTION

### Current Behavior (Bad):
When users lose internet connection or the backend is unreachable, they see technical error messages like:

```
SocketException: Failed host lookup: 'story-weaver-app-production.up.railway.app'
ClientException: Connection failed
```

### Desired Behavior (Good):
Users should see friendly, helpful messages like:

```
❌ Cannot connect to server
Please check your internet connection and try again.
```

---

## 📝 TASK BREAKDOWN

### Task 1: Add Error Handling to POST Method (15 minutes)

**File:** `lib/services/api_service_manager.dart`

**Step 1: Find the POST method**

Search for this code (around lines 48-51):

```dart
} on SocketException catch (error) {
  debugPrint('Network error while calling $uri: $error');
  rethrow;
}
```

**Step 2: Add import at top of file**

Add this import with the other imports at the top:

```dart
import 'dart:io';
```

**Step 3: Replace the catch block**

Replace the existing `SocketException` catch block with this expanded error handling:

```dart
} on SocketException catch (error) {
  debugPrint('❌ Network error while calling $uri');
  debugPrint('   Error details: $error');
  debugPrint('   Backend URL: $_localBackendUrl');
  throw Exception(
    'Cannot connect to server. Please check your internet connection and try again.\n\nServer: $_localBackendUrl',
  );
} on HandshakeException catch (error) {
  debugPrint('❌ SSL/TLS error while calling $uri: $error');
  throw Exception(
    'Secure connection failed. This might be a certificate issue.\n\nDetails: $error',
  );
} on http.ClientException catch (error) {
  debugPrint('❌ HTTP Client error while calling $uri: $error');
  throw Exception(
    'Request failed: ${error.message}\n\nPlease try again.',
  );
}
```

**What this does:**
- Catches network connection failures (SocketException)
- Catches SSL certificate problems (HandshakeException)
- Catches HTTP client errors (ClientException)
- Shows user-friendly messages
- Logs technical details for debugging

---

### Task 2: Add Error Handling to GET Method (10 minutes)

**Same file:** `lib/services/api_service_manager.dart`

**Step 1: Find the GET method**

Search for this code (around lines 75-77):

```dart
} on SocketException catch (error) {
  debugPrint('Network error while calling $uri: $error');
  rethrow;
}
```

**Step 2: Replace with same error handling**

Replace with the SAME expanded error handling from Task 1:

```dart
} on SocketException catch (error) {
  debugPrint('❌ Network error while calling $uri');
  debugPrint('   Error details: $error');
  debugPrint('   Backend URL: $_localBackendUrl');
  throw Exception(
    'Cannot connect to server. Please check your internet connection and try again.\n\nServer: $_localBackendUrl',
  );
} on HandshakeException catch (error) {
  debugPrint('❌ SSL/TLS error while calling $uri: $error');
  throw Exception(
    'Secure connection failed. This might be a certificate issue.\n\nDetails: $error',
  );
} on http.ClientException catch (error) {
  debugPrint('❌ HTTP Client error while calling $uri: $error');
  throw Exception(
    'Request failed: ${error.message}\n\nPlease try again.',
  );
}
```

---

### Task 3: Test Your Changes (15 minutes)

**Test 1: Normal Operation (Backend Reachable)**

```bash
# 1. Launch the app
flutter run -d chrome

# 2. Try to generate a story
# Expected: Should work normally if backend is up
```

**Verify:**
- [ ] Story generation works normally
- [ ] No errors in console (or only expected debug prints)

**Test 2: Simulate Network Failure**

**Option A: Disconnect internet**
1. Disconnect your computer from WiFi/ethernet
2. Try to generate a story
3. You should see the user-friendly error message

**Option B: Change backend URL to invalid**
1. Temporarily edit `lib/config/flavor_config.dart`
2. Change backend URL to something fake like `https://fake-server-does-not-exist.com`
3. Try to generate a story
4. You should see: "Cannot connect to server. Please check your internet connection and try again."
5. **IMPORTANT:** Change the URL back after testing!

**Verify:**
- [ ] User sees friendly error message (not technical stack trace)
- [ ] Console shows emoji ❌ debug logs
- [ ] Console shows backend URL for debugging
- [ ] App doesn't crash
- [ ] User can try again

**Test 3: Check Console Logs**

When testing network errors, check the console shows:
```
❌ Network error while calling https://...
   Error details: [technical details]
   Backend URL: https://story-weaver-app-production.up.railway.app
```

**Verify:**
- [ ] Emoji ❌ appears in logs
- [ ] Technical details logged for debugging
- [ ] Backend URL logged
- [ ] User doesn't see technical details (only friendly message)

---

## 📊 TESTING SUMMARY TEMPLATE

After completing all tests, fill out this summary:

```
═══════════════════════════════════════════════════════════
NETWORK ERROR HANDLING FIX - TEST REPORT
Date: [Current Date/Time]
Agent: [Your Name - Grok/Codex]
Branch: fix/network-error-handling
═══════════════════════════════════════════════════════════

## CHANGES MADE
Files Modified:
- lib/services/api_service_manager.dart

Imports Added:
- dart:io (for HandshakeException)

Error Types Handled:
- [x] SocketException (network failures)
- [x] HandshakeException (SSL/TLS errors)
- [x] ClientException (HTTP client errors)

## TEST RESULTS

### Test 1: Normal Operation
Status: [ ] PASS [ ] FAIL
Notes:

### Test 2: Network Failure Simulation
Status: [ ] PASS [ ] FAIL
Error Message Shown to User:
Logs Shown in Console:

### Test 3: Console Logs
Status: [ ] PASS [ ] FAIL
Contains ❌ emoji: [ ] YES [ ] NO
Contains technical details: [ ] YES [ ] NO
Contains backend URL: [ ] YES [ ] NO

## ISSUES FOUND
Critical:
1.

Minor:
1.

## RECOMMENDATIONS
- [ ] Ready to merge to feature/gui-redesign
- [ ] Needs fixes first

═══════════════════════════════════════════════════════════
```

---

## 🔄 GIT SYNC (DO THIS AT THE END)

**After completing all testing:**

```bash
# 1. Check status
git status

# 2. Stage changes
git add lib/services/api_service_manager.dart

# 3. Commit
git commit -m "fix: Improve network error handling with user-friendly messages

Changes:
- Add HandshakeException handling for SSL errors
- Add ClientException handling for HTTP errors
- Replace technical error messages with user-friendly text
- Add detailed debug logging with ❌ emoji for easy scanning
- Log backend URL to help with troubleshooting

Testing:
- Verified normal operation works
- Tested network failure scenario
- Confirmed user sees friendly error message
- Verified console logs show technical details for debugging

File: lib/services/api_service_manager.dart"

# 4. Pull latest from feature/gui-redesign
git fetch origin feature/gui-redesign

# 5. Push to remote
git push origin fix/network-error-handling

# 6. Verify
git log -1 --oneline
```

---

## 🔀 NEXT STEP: CREATE PULL REQUEST (OPTIONAL)

**After pushing, you can create a PR to merge into feature/gui-redesign:**

```bash
gh pr create \
  --base feature/gui-redesign \
  --head fix/network-error-handling \
  --title "fix: Improve network error handling" \
  --body "Replaces technical error messages with user-friendly text.

## Changes
- Add HandshakeException, ClientException handling
- User-friendly error messages
- Detailed debug logging

## Testing
- [x] Normal operation works
- [x] Network failure shows friendly message
- [x] Console logs technical details

Ready to merge."
```

**OR** just leave it on the branch and the user can merge later.

---

## ❌ COMMON MISTAKES TO AVOID

1. **Wrong Branch** - Make sure you created `fix/network-error-handling`
2. **Forgot Import** - Must add `import 'dart:io';`
3. **Incomplete Changes** - Must update BOTH POST and GET methods
4. **Didn't Test** - Must test both normal operation AND network failure
5. **Broke Backend URL** - If you changed it for testing, CHANGE IT BACK!

---

## ✅ DEFINITION OF DONE

You're done when:
- [ ] `dart:io` import added
- [ ] POST method error handling updated
- [ ] GET method error handling updated
- [ ] Normal operation tested successfully
- [ ] Network failure tested successfully
- [ ] Console logs verified
- [ ] Test report completed
- [ ] Changes committed to fix/network-error-handling branch
- [ ] Changes pushed to remote
- [ ] Git sync completed successfully

---

**IMPORTANT:** This fix improves user experience without breaking existing functionality. Test thoroughly to ensure everything still works!

**Good luck! 🔧**
