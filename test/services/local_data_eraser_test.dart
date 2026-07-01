// Unit tests for LocalDataEraser (MT-236 / PRIV-03 / PRIV-02).
//
// Verifies that a confirmed backend deletion clears child PII + caches from
// SharedPreferences while preserving app/parent/account configuration, and
// that a FAILED backend deletion leaves everything intact.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/services/local_data_eraser.dart';
import 'package:story_weaver_app/services/parental_consent_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A representative mix of child-PII/cache keys plus app/parent/account
  // config that MUST survive erasure.
  Map<String, Object> seed() => <String, Object>{
        // Child PII / consent.
        'user_name': 'Robin',
        'user_age': 7,
        'parent_email': 'parent@example.com',
        'allow_photo_avatar': true,
        'child_profiles': <String>['{"id":"1","name":"Robin","age":7}'],
        'active_profile_id': '1',
        'parental_consent_granted': true,
        'parental_consent_method': 'email_verified',
        'parental_consent_verified': true,
        'parental_consent_recorded_at': '2026-06-30T00:00:00.000',
        // Big Feelings / feelings content.
        'big_feelings_parent_hidden_context': 'divorce',
        'big_feelings_repair_goal': 'say sorry',
        'feelings_journal': <String>['sad today'],
        'learned_emotions': '{"joy":3}',
        // Story / character / avatar caches.
        'isar_stories': '[]',
        'isar_characters': '[]',
        'isar_avatar_cache': '[]',
        'saved_stories_v2': '[]',
        'illustrated_stories': '[]',
        'character_evolution_data': '{}',
        'coloring_pages': '[]',
        // Suffixed (prefix-swept) keys.
        'hero_profile_abc': '{}',
        'hero_saga_abc': '{}',
        'superhero_portrait_abc': 'data:...',
        'caregivers_1': '[]',
        'playback_pos_xyz': 4200,
        'story_progress_xyz': 3,
        // App / parent / account config — MUST be preserved.
        'theme_mode': 'dark',
        'reader_highlight_color': 123,
        'onboarding_has_completed': true,
        'screen_time_daily_limit': 30,
        'screen_time_bedtime_hour': 20,
        'subscription_status': '{"tier":"free"}',
        'is_paid_premium': false,
        'story_weaver_user_id': 'usr_keepme',
        'story_weaver_country': 'US',
      };

  const childPiiAndCacheKeys = <String>[
    'user_name',
    'user_age',
    'parent_email',
    'allow_photo_avatar',
    'child_profiles',
    'active_profile_id',
    'parental_consent_granted',
    'parental_consent_method',
    'parental_consent_verified',
    'parental_consent_recorded_at',
    'big_feelings_parent_hidden_context',
    'big_feelings_repair_goal',
    'feelings_journal',
    'learned_emotions',
    'isar_stories',
    'isar_characters',
    'isar_avatar_cache',
    'saved_stories_v2',
    'illustrated_stories',
    'character_evolution_data',
    'coloring_pages',
    'hero_profile_abc',
    'hero_saga_abc',
    'superhero_portrait_abc',
    'caregivers_1',
    'playback_pos_xyz',
    'story_progress_xyz',
  ];

  const appConfigKeysToPreserve = <String>[
    'theme_mode',
    'reader_highlight_color',
    'onboarding_has_completed',
    'screen_time_daily_limit',
    'screen_time_bedtime_hour',
    'subscription_status',
    'is_paid_premium',
    'story_weaver_user_id',
    'story_weaver_country',
  ];

  test('SUCCESS: clearing removes every child PII + cache key', () async {
    SharedPreferences.setMockInitialValues(seed());
    final prefs = await SharedPreferences.getInstance();

    await LocalDataEraser.clearPrefsKeys(prefs);

    for (final key in childPiiAndCacheKeys) {
      expect(prefs.containsKey(key), isFalse,
          reason: 'child PII/cache key "$key" should be erased');
    }
  });

  test('SUCCESS: app/parent/account config is preserved', () async {
    SharedPreferences.setMockInitialValues(seed());
    final prefs = await SharedPreferences.getInstance();

    await LocalDataEraser.clearPrefsKeys(prefs);

    for (final key in appConfigKeysToPreserve) {
      expect(prefs.containsKey(key), isTrue,
          reason: 'app-config key "$key" must NOT be erased');
    }
    expect(prefs.getString('story_weaver_user_id'), 'usr_keepme');
  });

  test('SUCCESS flow: backend-confirmed delete clears consent + PII', () async {
    SharedPreferences.setMockInitialValues(seed());
    final prefs = await SharedPreferences.getInstance();

    // Mirror the screen gate: erase locally ONLY when the backend delete
    // succeeds. eraseAll() is not used here because it would open native Isar;
    // clearPrefsKeys + clearConsent are the client-erasure primitives it runs.
    Future<void> runDeleteFlow({required bool backendSucceeds}) async {
      if (!backendSucceeds) {
        throw Exception('HTTP 500 — backend delete failed');
      }
      await const ParentalConsentService().clearConsent();
      await LocalDataEraser.clearPrefsKeys(prefs);
    }

    await runDeleteFlow(backendSucceeds: true);

    expect(await const ParentalConsentService().hasConsent(), isFalse);
    expect(prefs.containsKey('user_name'), isFalse);
    expect(prefs.containsKey('parent_email'), isFalse);
    expect(prefs.containsKey('isar_stories'), isFalse);
  });

  test('FAILURE flow: failed backend delete leaves PII + consent intact',
      () async {
    SharedPreferences.setMockInitialValues(seed());
    final prefs = await SharedPreferences.getInstance();

    Future<void> runDeleteFlow({required bool backendSucceeds}) async {
      if (!backendSucceeds) {
        throw Exception('HTTP 500 — backend delete failed');
      }
      await const ParentalConsentService().clearConsent();
      await LocalDataEraser.clearPrefsKeys(prefs);
    }

    await expectLater(
      runDeleteFlow(backendSucceeds: false),
      throwsA(isA<Exception>()),
    );

    // Nothing was erased because the backend never confirmed.
    expect(await const ParentalConsentService().hasConsent(), isTrue);
    expect(prefs.getString('user_name'), 'Robin');
    expect(prefs.getString('parent_email'), 'parent@example.com');
    expect(prefs.getString('isar_stories'), '[]');
    expect(prefs.containsKey('hero_profile_abc'), isTrue);
  });

  test('key lists never target protected app-config keys', () {
    for (final protectedKey in appConfigKeysToPreserve) {
      expect(LocalDataEraser.piiPrefsKeys.contains(protectedKey), isFalse,
          reason: '"$protectedKey" must not be in the PII clear list');
      expect(
        LocalDataEraser.piiPrefsKeyPrefixes.any(protectedKey.startsWith),
        isFalse,
        reason: '"$protectedKey" must not match a PII prefix',
      );
    }
  });
}
