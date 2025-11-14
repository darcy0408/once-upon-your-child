import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const _keyHasCompleted = 'has_completed_onboarding';

  const OnboardingService();

  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasCompleted) ?? false;
  }

  Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasCompleted, true);
  }
}
