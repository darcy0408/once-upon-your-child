import 'package:shared_preferences/shared_preferences.dart';

class FeatureTourService {
  FeatureTourService._();

  static const _storyCountKey = 'feature_tour_story_count';
  static const _tourCompletedKey = 'feature_tour_completed';
  static const _tourDismissedKey = 'feature_tour_dismissed';

  static Future<int> incrementStoryCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_storyCountKey) ?? 0;
    final next = current + 1;
    await prefs.setInt(_storyCountKey, next);
    return next;
  }

  static Future<bool> shouldShowTour() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_tourCompletedKey) ?? false;
    final dismissed = prefs.getBool(_tourDismissedKey) ?? false;
    final storyCount = prefs.getInt(_storyCountKey) ?? 0;
    if (completed || dismissed) return false;
    return storyCount >= 1;
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourCompletedKey, true);
  }

  static Future<void> markDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourDismissedKey, true);
  }
}
