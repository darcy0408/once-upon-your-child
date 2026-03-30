import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const _keyHasCompleted = 'has_completed_onboarding';

  // UX-polish hint keys
  static const _keySwipeHint = 'has_seen_swipe_hint';
  static const _keyArchetypeDeal = 'has_seen_archetype_deal';
  static const _keyCountdownCount = 'countdown_shown_count';
  static const _prefixScenario = 'has_seen_scenario_';

  const OnboardingService();

  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasCompleted) ?? false;
  }

  Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasCompleted, true);
  }

  // ── Swipe hint (scenario carousel) ───────────────────────────────────────

  Future<bool> hasSeenSwipeHint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySwipeHint) ?? false;
  }

  Future<void> markSwipeHintSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySwipeHint, true);
  }

  // ── Per-scenario "New!" badge tracking ───────────────────────────────────

  Future<bool> hasVisitedScenario(String scenarioId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefixScenario$scenarioId') ?? false;
  }

  Future<void> markScenarioVisited(String scenarioId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefixScenario$scenarioId', true);
  }

  // ── Archetype card-deal animation ────────────────────────────────────────

  Future<bool> hasSeenArchetypeDeal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyArchetypeDeal) ?? false;
  }

  Future<void> markArchetypeDealSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyArchetypeDeal, true);
  }

  // ── 3-2-1 countdown (shown first 3 times only) ───────────────────────────

  Future<int> getCountdownCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCountdownCount) ?? 0;
  }

  Future<void> incrementCountdownCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyCountdownCount) ?? 0;
    await prefs.setInt(_keyCountdownCount, current + 1);
  }
}
