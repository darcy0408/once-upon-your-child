# BRIEF — SubscriptionService dedup refactor (MT-104)

**Status:** Planned (audit complete, not yet executed)
**Estimated effort:** 4.0–5.25 hours
**Plan author:** Plan agent run on 2026-05-14

---

## Goal

Delete `lib/subscription_service.dart` (~268 lines, local-only, fakes Stripe upgrades) and consolidate its useful methods onto `lib/services/subscription_service.dart` (~38 lines, backend-backed via `SubscriptionSyncService`).

## ⚠️ Pre-existing bug surfaced by the audit

The "Force Premium / Reset to Free" dev buttons in `lib/settings_screen.dart` (lines 681, 705) have been **silently broken** since they were added. They call `wrong-class.upgradeToPremium()`, which writes a fake sub to the `user_subscription` SharedPref key — but `is_paid_premium` and `subscription_status` (the keys actually read by `ApiServiceManager.hasPremiumAccess` / `ProgressionService.hasPaidPremium`) are NEVER updated. **Anyone who used the dev button thinking they tested Premium was testing nothing.** Step 8 of this plan must either delete the buttons or rewrite them to hit Stripe test mode.

## 1. Audit findings

### Wrong-class consumers — `import 'subscription_service.dart'` (no `services/`)
Production:
- `lib/character_management_screen_v2.dart:10` → `canCreateCharacter`, `getMaxCharacters`
- `lib/interactive_story_screen.dart:12` → `recordStoryCreation`
- `lib/main_story.dart:38` → `getSubscription`, `getRemainingStoriesToday`
- `lib/paywall_dialog.dart:4` → `getSubscription` (reads `.limits.maxStoriesPerDay/PerMonth`)
- `lib/pick_a_path_adventure_screen.dart:12` → `recordStoryCreation`
- `lib/quick_story_screen.dart:10` → `canCreateStory`, `getSubscription`, `recordStoryCreation`
- `lib/settings_screen.dart:17` → `upgradeToPremium`, `downgradeToFree` (broken dev shortcut)

Tests:
- `test/integration/paywall_test.dart:6` → `canCreateStory`, `recordStoryCreation` + raw SharedPref seeding (`user_subscription`, `usage_stats`)

### Right-class consumers — `import 'services/subscription_service.dart'`
- `lib/main.dart:14` — `initialize()`
- `lib/providers/subscription_provider.dart:2` — `getSubscriptionStatus()`
- `lib/widgets/subscription_status_banner.dart:4` — `statusStream`, `currentStatus`
- `test/widgets/subscription_ui_test.dart:4` — extends class for mock
- `test/widgets/subscription_sync_widget_test.dart:4` — extends class for mock

### Method-by-method disposition (wrong class)

| Method | Disposition | Why |
|---|---|---|
| `statusStream`, `currentStatus` (getters) | duplicate (already on canonical) | — |
| `getSubscription()` | **move to canonical** | 4 consumers; reimplement from `_syncService.currentStatus` |
| `setSubscription()` | **delete** | no external callers |
| `upgradeToPremium()` | **delete + rewrite call site** | only `settings_screen` dev button — see Step 8 |
| `downgradeToFree()` | **delete + rewrite call site** | only `settings_screen` dev button |
| `getUsageStats()` / `_saveUsageStats()` | **move to canonical (private)** | local SharedPref pattern, no consumers outside class |
| `recordStoryCreation()` | **move to canonical** | 3 consumers |
| `canCreateStory()` | **move to canonical** | `quick_story_screen` + tests |
| `getRemainingStoriesToday()` | **move to canonical** | `main_story` |
| `getRemainingStoriesThisMonth()` | **delete** | zero consumers |
| `hasFeature()` | **delete** | zero consumers |
| `isThemeAvailable()` / `isCompanionAvailable()` | **delete** | zero consumers |
| `canCreateCharacter()` / `getMaxCharacters()` | **move to canonical** | `character_management_screen_v2` |
| `resetUsageStats()` | **delete** | zero external consumers |
| `activateIsabelaTester()` | **delete** | fully dead — zero callers |
| `_handleRemoteStatus()` + ctor stream sub | **delete** | double-cache; sync service already persists `subscription_status` |
| `extension SubscriptionStatusMapper.toUserSubscription()` | **move to canonical file** | required by `getSubscription()` |

## 2. Canonical API after dedup

```dart
class SubscriptionService {
  SubscriptionService({SubscriptionSyncService? syncService});

  Stream<SubscriptionStatus> get statusStream;
  SubscriptionStatus? get currentStatus;
  Future<void> initialize([String? userId]);
  Future<void> refresh([String? userId]);
  Future<Map<String, dynamic>> getSubscriptionStatus([String? userId]);
  void dispose();

  // Moved from wrong class
  Future<UserSubscription> getSubscription();
  Future<bool> canCreateStory();
  Future<int> getRemainingStoriesToday();
  Future<void> recordStoryCreation();
  Future<bool> canCreateCharacter(int currentCharacterCount);
  Future<int> getMaxCharacters();

  Future<UsageStats> _getUsageStats();
  Future<void> _saveUsageStats(UsageStats stats);
}

extension SubscriptionStatusMapper on SubscriptionStatus {
  UserSubscription toUserSubscription();
}
```

Notes:
- `getSubscription()` derives entirely from `_syncService.currentStatus`. Returns `UserSubscription()` (free defaults) if sync hasn't completed. No SharedPref fallback.
- Usage stats stay private. `_kUsageStatsKey = 'usage_stats'` retained as the only client-side counter source.
- `getSubscriptionStatus()` (raw map) stays unchanged — thin StripeService passthrough.

## 3. Migration sequence

Each step leaves the tree compiling. Run `flutter analyze` between steps.

1. **Add moved methods + extension to canonical file** (`lib/services/subscription_service.dart`). Wrong class still exists; both classes have these methods now; consumers import only one each, so no collision.
2. **Migrate `lib/character_management_screen_v2.dart`** — import swap only, signatures match.
3. **Migrate `lib/interactive_story_screen.dart`** — import swap only.
4. **Migrate `lib/pick_a_path_adventure_screen.dart`** — import swap only.
5. **Migrate `lib/quick_story_screen.dart`** — import swap; 3 method calls match.
6. **Migrate `lib/main_story.dart`** — import swap; 2 method calls match.
7. **Migrate `lib/paywall_dialog.dart`** — import swap; 1 method.
8. **Rewrite `lib/settings_screen.dart` dev buttons** (only behavior-changing step):
   - **Option A (preferred):** delete both buttons. They never worked correctly.
   - **Option B:** route "Force Premium" through `PremiumUpgradeScreen` (same as production paywall), "Reset to Free" through Stripe portal/cancel. No more local-pref writes.
   - Either way: remove import of wrong class.
9. **Update tests:**
   - `test/integration/paywall_test.dart` — rewrite to inject a fake `SubscriptionSyncService` (constructor already supports it) and seed only `usage_stats`. Or delete if redundant with widget tests.
   - `test/widgets/subscription_ui_test.dart` and `subscription_sync_widget_test.dart` — verify mocks still compile. Should be fine; only override `statusStream`/`dispose`.
10. **Delete `lib/subscription_service.dart`** — final step. Verify `flutter analyze` clean, `flutter test` passes, `grep "import 'subscription_service.dart'"` returns zero.

## 4. Risks / gotchas

- **Behavior change at `settings_screen.dart:681,705`** — see top-of-doc warning. Deleting fixes the silent-bug risk; "rewriting" requires actually wiring Stripe checkout from the dev button.
- **Test `test/integration/paywall_test.dart` will break** — depends on the wrong-class SharedPref bypass. Step 9 rewrites it.
- **Orphaned SharedPref key `user_subscription`** — existing installs have stale data after upgrade. Harmless (no readers post-refactor). Optional one-time cleanup in `main.dart` startup: `prefs.remove('user_subscription')`.
- **Singleton change** — wrong class was `factory _instance` singleton; canonical class is not. Most consumers do `final _service = SubscriptionService()` per-screen (now per-screen instances). `SubscriptionSyncService` IS still a singleton internally, so streams remain shared. No real behavior change.
- **First-frame race** — old `getSubscription()` had a SharedPref fallback. New version returns `UserSubscription()` (free) when sync hasn't completed. `main.dart` calls `initialize()` at startup → sync hydrates from its `subscription_status` cache before any UI reads. Verify `quick_story_screen` / `main_story` startup ordering — both are post-login screens, so should be fine.

## 5. Critical files

- `lib/subscription_service.dart` (TO DELETE)
- `lib/services/subscription_service.dart` (TO EXTEND)
- `lib/settings_screen.dart` (dev-button rewrite/removal)
- `test/integration/paywall_test.dart` (rewrite or delete)
- `lib/services/subscription_sync_service.dart` (read-only, understand cache contract)

## 6. Effort estimate

| Section | Hours |
|---|---|
| Skim audit (this doc) | 0.25 |
| Add methods to canonical (Step 1) | 0.5 |
| Import swaps in 6 production files (Steps 2–7) | 0.75 |
| settings_screen dev-button rewrite/removal (Step 8) | 0.5–1.0 |
| Test fixes (Step 9) | 1.0–1.5 |
| Delete + final verification (Step 10) | 0.25 |
| Manual smoke (settings, paywall, character limit, story limit) | 0.75 |
| **Total** | **4.0–5.25 hours** |
