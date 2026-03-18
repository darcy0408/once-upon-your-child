# Updated Agent Prompts
**Updated:** 2026-02-12, 8:30 PM
**Reason:** Account for test_fixtures.dart being broken

---

## 🔄 UPDATED: Tasks 2, 3, 6 (Any Test Creation Task)

### Important Update for All Test Tasks

**CRITICAL:** Do NOT use `test/helpers/test_fixtures.dart` - it's broken (32 compilation errors)

**Solution:** Follow Codex's example from Task 1:
1. Inline minimal fixtures inside your test file
2. Create helper functions for common test data
3. Example from Codex's subscription_service_test.dart:

```dart
// Inline fixture functions
Map<String, dynamic> _freeStatusFixture() {
  return <String, dynamic>{
    'tier': 'free',
    'status': 'active',
    'story_limit': 3,
    'stories_used': 2,
  };
}

Map<String, dynamic> _premiumStatusFixture() {
  return <String, dynamic>{
    'tier': 'premium',
    'status': 'active',
    'story_limit': -1,
    'stories_used': 42,
  };
}

// Inline fake service
class _FakeStripeService extends StripeService {
  _FakeStripeService({required List<Object> results})
      : _results = Queue<Object>.from(results),
        super();

  final Queue<Object> _results;

  @override
  Future<Map<String, dynamic>> getSubscriptionStatus(String userId) async {
    if (_results.isEmpty) {
      throw Exception('No fake response configured');
    }
    final next = _results.removeFirst();
    if (next is Exception) throw next;
    return Map<String, dynamic>.from(next as Map);
  }
}
```

---

## 📋 UPDATED: Task 2 Prompt (Stripe Service Tests)

```
TASK ASSIGNMENT: Create Stripe Service Tests

You are [Agent Name]. Your task is Task 2 from AGENT_TASK_DELEGATION_PLAN.md.

IMPORTANT UPDATE:
⚠️ Do NOT use test/helpers/test_fixtures.dart (it's broken with 32 errors)
✅ Instead, inline minimal fixtures like Codex did in Task 1

REFERENCE CODEX'S APPROACH:
- File: test/unit/services/subscription_service_test.dart
- Pattern: Inline fixture functions (_freeStatusFixture, etc.)
- Pattern: Inline fake services (_FakeStripeService)
- This approach works perfectly!

YOUR TASK:
Create unit tests for Stripe payment service integration.

FILE TO CREATE:
- `test/unit/services/stripe_service_test.dart`

REQUIRED TESTS (10 total):

Group 1: Checkout Session Creation (3 tests)
1. test_successful_session_creation
2. test_session_with_user_id
3. test_session_with_metadata

Group 2: Payment Success Handling (3 tests)
4. test_successful_payment_webhook
5. test_subscription_activation
6. test_user_tier_upgrade

Group 3: Error Handling (4 tests)
7. test_api_key_missing
8. test_network_errors
9. test_invalid_session_id
10. test_webhook_signature_validation_failure

INLINE FIXTURES TO CREATE:
```dart
// Example fixtures you'll need
Map<String, dynamic> _successfulCheckoutFixture() {
  return {
    'id': 'cs_test_123',
    'url': 'https://checkout.stripe.com/test',
    'status': 'open',
  };
}

Map<String, dynamic> _paymentSuccessWebhookFixture() {
  return {
    'type': 'checkout.session.completed',
    'data': {
      'object': {
        'id': 'cs_test_123',
        'customer': 'cus_test_456',
        'subscription': 'sub_test_789',
      }
    }
  };
}

// Create more as needed...
```

SUCCESS CRITERIA:
- All 10 tests passing
- No dependency on test_fixtures.dart
- All fixtures inlined
- Mock Stripe API calls (no real API requests)

Follow the pattern from Codex's Task 1!
```

---

## 📋 UPDATED: Task 3 Prompt (Isar Service Tests)

```
TASK ASSIGNMENT: Create Isar Database Service Tests

You are [Agent Name]. Your task is Task 3 from AGENT_TASK_DELEGATION_PLAN.md.

IMPORTANT UPDATE:
⚠️ Do NOT use test/helpers/test_fixtures.dart (it's broken)
✅ Inline minimal fixtures like Codex did in Task 1

YOUR TASK:
Create unit tests for Isar local database operations.

FILE TO CREATE:
- `test/unit/services/isar_service_test.dart`

REQUIRED TESTS (10 total):

Group 1: Database Initialization (2 tests)
1. test_database_creation
2. test_schema_migration

Group 2: Character Storage (4 tests)
3. test_save_character
4. test_update_character
5. test_delete_character
6. test_get_character_by_id

Group 3: Story Persistence (3 tests)
7. test_save_story
8. test_get_all_stories
9. test_delete_story

Group 4: Error Handling (1 test)
10. test_database_errors

INLINE FIXTURES TO CREATE:
```dart
// Example fixtures
Map<String, dynamic> _testCharacterData() {
  return {
    'id': 'char_test_1',
    'name': 'Luna',
    'age': 7,
    'createdAt': DateTime.now().toIso8601String(),
  };
}

Map<String, dynamic> _testStoryData() {
  return {
    'id': 'story_test_1',
    'title': 'Test Story',
    'content': 'Once upon a time...',
    'createdAt': DateTime.now().toIso8601String(),
  };
}
```

USE MOCKS:
- Import: `import '../helpers/mocks.dart';`
- Use: `MockIsar` (this file should work - it doesn't depend on test_fixtures.dart)

SUCCESS CRITERIA:
- All 10 tests passing
- No dependency on test_fixtures.dart
- Mock database (no real DB created)
- Test cleanup after each test
```

---

## 📋 NEW: Task 13 Prompt (Fix test_fixtures.dart)

```
TASK ASSIGNMENT: Fix test_fixtures.dart

This task was created after Codex discovered test_fixtures.dart is broken.

YOUR TASK:
Fix all 32 compilation errors in test/helpers/test_fixtures.dart

CURRENT ERRORS:
```bash
dart analyze test/helpers/test_fixtures.dart
32 issues found:
- URI doesn't exist: 'package:story_weaver_app/models/character.dart'
- URI doesn't exist: 'package:story_weaver_app/models/story.dart'
- URI doesn't exist: 'package:story_weaver_app/models/interactive_story_data.dart'
- Undefined class 'Character' (multiple)
- Undefined class 'Story' (multiple)
- Undefined class 'InteractiveStoryData' (multiple)
- Missing required arguments for GeneratedAvatar constructor
- Wrong parameter names for GeneratedAvatar
```

STEPS TO FIX:

1. Find Correct Model Locations
```bash
# Search for actual model files
find lib -name "*.dart" | grep -i character
find lib -name "*.dart" | grep -i story
find lib -name "*.dart" | grep -i interactive

# Or use grep
grep -r "class Character" lib/
grep -r "class.*Story" lib/
grep -r "class InteractiveStoryData" lib/
```

2. Update Imports in test_fixtures.dart
- Replace broken import paths with actual paths
- Example: If Character is in lib/models.dart, use:
  `import 'package:story_weaver_app/models.dart';`

3. Fix GeneratedAvatar Constructor
```bash
# Find correct constructor
grep -A 20 "class GeneratedAvatar" lib/

# Update test_fixtures.dart lines 57, 66 with correct parameters
```

4. Fix All Model Constructors
- Check required parameters for each model
- Update all fixture functions to match

5. Verify Fix
```bash
dart analyze test/helpers/test_fixtures.dart
# Should show: 0 issues found
```

SUCCESS CRITERIA:
- ✅ 0 compilation errors
- ✅ All imports resolve
- ✅ All fixtures compile
- ✅ Run: `dart analyze test/helpers/test_fixtures.dart` → clean

PRIORITY:
HIGH - This unblocks other agents from using shared fixtures
```

---

## 🎯 PRIORITY RECOMMENDATION

**For next available agent:**

**Option 1 (HIGH IMPACT):** Task 13 - Fix test_fixtures.dart
- Time: 1-2 hours
- Impact: Unblocks Tasks 2, 3, 6 and all future test tasks
- Future agents can use shared fixtures instead of inlining

**Option 2 (CONTINUE PATTERN):** Task 2 or 3 - Using Inline Fixtures
- Time: 2-3 hours each
- Impact: More tests completed
- Pattern: Follow Codex's successful approach

**Codex proved the inline fixture pattern works perfectly, so either option is viable!**

---

**Last Updated:** 2026-02-12, 8:30 PM
**Maintained By:** Claude Sonnet 4.5
