import 'package:shared_preferences/shared_preferences.dart';

enum IllustrationPreference {
  /// No illustrations — text stories only, zero API cost.
  none,

  /// One illustration per story (cover scene only) — minimal cost.
  coverOnly,

  /// Multiple illustrations per story — richest experience, small cost.
  full,
}

extension IllustrationPreferenceX on IllustrationPreference {
  String get key => name; // 'none' | 'coverOnly' | 'full'

  String get label {
    switch (this) {
      case IllustrationPreference.none:
        return 'No illustrations';
      case IllustrationPreference.coverOnly:
        return 'Cover scene only';
      case IllustrationPreference.full:
        return 'Full illustrations';
    }
  }

  String get description {
    switch (this) {
      case IllustrationPreference.none:
        return 'Text stories only — completely free, no API cost ever.';
      case IllustrationPreference.coverOnly:
        return 'One beautiful scene per story — a tiny amount of your quota, typically free.';
      case IllustrationPreference.full:
        return 'Multiple scenes throughout the story — the richest experience, usually just pennies.';
    }
  }

  String get emoji {
    switch (this) {
      case IllustrationPreference.none:
        return '📖';
      case IllustrationPreference.coverOnly:
        return '🖼️';
      case IllustrationPreference.full:
        return '✨';
    }
  }

  /// How many illustrations to generate (used in magic_review_step).
  int get count {
    switch (this) {
      case IllustrationPreference.none:
        return 0;
      case IllustrationPreference.coverOnly:
        return 1;
      case IllustrationPreference.full:
        return 3;
    }
  }
}

class IllustrationPreferenceService {
  static const _key = 'illustration_preference';

  static Future<IllustrationPreference> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    return IllustrationPreference.values.firstWhere(
      (e) => e.key == stored,
      orElse: () => IllustrationPreference.full,
    );
  }

  static Future<void> save(IllustrationPreference value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.key);
  }
}
