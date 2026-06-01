// Cross-session persistence for a child's generated superhero portrait.
//
// Keyed by the same characterId used for [HeroProfileLocal], so the
// welcome-back screen can show the portrait the kid generated last time.
// Stored in SharedPreferences (works on web + mobile, no Isar codegen) — the
// portrait is a ~1-2MB data URI, one per character. Best-effort: every call
// swallows errors so persistence never blocks the flow.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SuperheroPortraitStore {
  static String _key(String characterId) => 'superhero_portrait_$characterId';

  /// Persist the portrait [dataUri] for [characterId].
  static Future<void> save(String characterId, String dataUri) async {
    if (characterId.isEmpty || dataUri.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(characterId), dataUri);
    } catch (e) {
      debugPrint('SuperheroPortraitStore.save failed: $e');
    }
  }

  /// Load the saved portrait data URI for [characterId], or null if none.
  static Future<String?> load(String characterId) async {
    if (characterId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key(characterId));
    } catch (e) {
      debugPrint('SuperheroPortraitStore.load failed: $e');
      return null;
    }
  }
}
