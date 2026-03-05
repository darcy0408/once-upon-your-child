import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/subscription_models.dart';

void main() {
  group('UsageStats', () {
    test('daily reset is needed when date changes', () {
      final stats = UsageStats(
        storiesCreatedToday: 5,
        storiesCreatedThisMonth: 10,
        lastResetDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(stats.needsDailyReset(), isTrue);

      final reset = stats.resetDaily();
      expect(reset.storiesCreatedToday, 0);
      expect(reset.storiesCreatedThisMonth, stats.storiesCreatedThisMonth);
    });

    test('monthly reset clears both counters', () {
      final stats = UsageStats(
        storiesCreatedToday: 3,
        storiesCreatedThisMonth: 40,
        lastResetDate: DateTime.now().subtract(const Duration(days: 35)),
      );

      expect(stats.needsMonthlyReset(), isTrue);

      final reset = stats.resetMonthly();
      expect(reset.storiesCreatedToday, 0);
      expect(reset.storiesCreatedThisMonth, 0);
    });

    test('incrementStory bumps daily and monthly counts', () {
      final stats = UsageStats(storiesCreatedToday: 1, storiesCreatedThisMonth: 2);
      final incremented = stats.incrementStory();

      expect(incremented.storiesCreatedToday, 2);
      expect(incremented.storiesCreatedThisMonth, 3);
    });
  });
}
