import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'isar_service.dart';
import 'parental_consent_service.dart';

/// Erases all local child PII + cached content from the device after a
/// CONFIRMED successful backend deletion (COPPA / GDPR right to erasure —
/// PRIV-03 / PRIV-02, part of MT-236).
///
/// The backend `DELETE /api/user/<id>/data` anonymizes the server record; this
/// helper removes the client half that used to be left behind: child name/age,
/// parent email, consent record, "Big Feelings" notes, saved stories,
/// characters, avatars and every derived cache.
///
/// IMPORTANT: only invoke this once the backend deletion has been confirmed.
/// It deliberately does NOT touch app/parent/account configuration (theme,
/// locale, onboarding, screen-time limits, subscription state, account id).
class LocalDataEraser {
  const LocalDataEraser();

  /// Exact-match child-PII + cache SharedPreferences keys removed on erasure.
  ///
  /// Grouped by origin so a reviewer can confirm completeness. Anything NOT in
  /// this list (theme_mode, reader_highlight_color, onboarding_*, screen_time_*,
  /// subscription_status, story_weaver_user_id/_country, feature unlocks, etc.)
  /// is intentionally preserved as app/parent/account configuration.
  static const List<String> piiPrefsKeys = <String>[
    // Parental consent record (also cleared via clearConsent()).
    'parental_consent_granted',
    'parental_consent_method',
    'parental_consent_verified',
    'parental_consent_recorded_at',
    // Child identity / profile.
    'user_age',
    'user_name',
    'parent_email',
    'allow_photo_avatar',
    'child_profiles',
    'active_profile_id',
    // "Big Feelings" + feelings-corner content (child/parent authored).
    'big_feelings_parent_hidden_context',
    'big_feelings_repair_goal',
    'feelings_check_ins',
    'feelings_journal',
    'emotion_check_ins',
    'learned_emotions',
    'emotion_story_moments',
    // Saved stories + story caches.
    'isar_stories', // web story cache (native lives in Isar)
    'saved_stories_v2',
    'offline_story_cache',
    'illustrated_stories',
    'enhanced_illustrated_stories',
    // Saved characters / heroes / avatars.
    'isar_characters',
    'isar_chronicles',
    'isar_chapter_memories',
    'isar_avatar_cache',
    'character_evolution_data',
    'last_hero_id',
    'last_hero_at',
    // Coloring pages (child-created art).
    'coloring_pages',
    'user_colorings',
    // Child progress / drafts / feedback.
    'achievement_state_v1',
    'achievement_last_sync',
    'user_progress',
    'story_feedback_entries',
    'wizard_draft',
  ];

  /// Prefixes for per-character / per-story keys swept on erasure. These are
  /// written with a suffixed id (e.g. `hero_profile_<characterId>`), so an
  /// exact-match list cannot enumerate them.
  static const List<String> piiPrefsKeyPrefixes = <String>[
    'hero_profile_',
    'hero_saga_',
    'superhero_portrait_',
    'caregivers_',
    'playback_pos_',
    'story_progress_',
  ];

  /// Removes every child-PII + cache key from [prefs]. Pure over the injected
  /// instance so it is unit-testable without platform channels or Isar.
  @visibleForTesting
  static Future<void> clearPrefsKeys(SharedPreferences prefs) async {
    for (final key in piiPrefsKeys) {
      await prefs.remove(key);
    }
    // Sweep suffixed keys by prefix. Snapshot the key set first so removing
    // while iterating is safe.
    for (final key in prefs.getKeys().toList()) {
      if (piiPrefsKeyPrefixes.any(key.startsWith)) {
        await prefs.remove(key);
      }
    }
  }

  /// Full local erasure: consent record, all child-PII SharedPreferences keys,
  /// and the Isar caches (stories / characters / chronicles / avatars).
  ///
  /// Safe on web — the Isar caches are SharedPreferences-backed and already
  /// removed by [clearPrefsKeys], so the extra clear is a cheap no-op. The Isar
  /// clear is best-effort and never blocks the prefs/consent erasure.
  Future<void> eraseAll() async {
    // 1. Consent-clear method (per task): removes the consent record.
    await const ParentalConsentService().clearConsent();

    // 2. Child-PII + cache SharedPreferences keys (covers ALL web data).
    final prefs = await SharedPreferences.getInstance();
    await clearPrefsKeys(prefs);

    // 3. Native Isar caches. On web this reduces to removing the isar_* keys
    //    already gone above. Best-effort so a storage hiccup never leaves the
    //    prefs half-erased.
    try {
      await IsarService.clearAllCaches();
    } catch (_) {
      // Non-fatal: the SharedPreferences erasure above is the source of truth
      // for web, and native re-clears on next launch if this ever failed.
    }
  }
}
