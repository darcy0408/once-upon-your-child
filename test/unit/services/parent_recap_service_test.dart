import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models/local/story_local.dart';
import 'package:story_weaver_app/services/parent_recap_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  String encodeGardenEntry({
    required String coreName,
    String coreEmoji = '😊',
    int intensity = 3,
    required DateTime timestamp,
  }) {
    return jsonEncode({
      'coreName': coreName,
      'coreEmoji': coreEmoji,
      'secondaryName': null,
      'tertiaryName': null,
      'intensity': intensity,
      'timestamp': timestamp.toIso8601String(),
    });
  }

  StoryLocal makeStory({
    required String title,
    required DateTime createdAt,
    String theme = 'Adventure',
    String? practiced,
  }) {
    return StoryLocal()
      ..storyId = title
      ..title = title
      ..storyText = 'text'
      ..theme = theme
      ..createdAt = createdAt
      ..practiced = practiced;
  }

  group('logFeelingCheckIn', () {
    test('appends an entry in the exact Feelings Garden journal shape',
        () async {
      final now = DateTime(2026, 7, 7, 12);
      await ParentRecapService.logFeelingCheckIn(
        coreName: 'Angry',
        coreEmoji: '😠',
        intensity: 4,
        now: now,
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(ParentRecapService.journalKey)!;
      expect(raw, hasLength(1));

      final decoded = jsonDecode(raw.single) as Map<String, dynamic>;
      // Key set must not drift from feelings_garden_screen._JournalEntry /
      // FeelingsAmbientService — all three share this list.
      expect(
        decoded.keys.toSet(),
        {
          'coreName',
          'coreEmoji',
          'secondaryName',
          'tertiaryName',
          'intensity',
          'timestamp',
        },
      );
      expect(decoded['coreName'], 'Angry');
      expect(decoded['coreEmoji'], '😠');
      expect(decoded['intensity'], 4);
      expect(DateTime.parse(decoded['timestamp'] as String), now);
    });

    test('no-ops on an empty core name', () async {
      await ParentRecapService.logFeelingCheckIn(
        coreName: '  ',
        coreEmoji: '😊',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(ParentRecapService.journalKey), isNull);
    });

    test('keeps the 60-entry cap, dropping the oldest first', () async {
      final base = DateTime(2026, 7, 1);
      SharedPreferences.setMockInitialValues({
        ParentRecapService.journalKey: [
          for (var i = 0; i < 60; i++)
            encodeGardenEntry(
              coreName: 'Feeling$i',
              timestamp: base.add(Duration(minutes: i)),
            ),
        ],
      });

      await ParentRecapService.logFeelingCheckIn(
        coreName: 'Newest',
        coreEmoji: '😊',
        now: base.add(const Duration(hours: 2)),
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(ParentRecapService.journalKey)!;
      expect(raw, hasLength(60));
      expect(jsonDecode(raw.first)['coreName'], 'Feeling1');
      expect(jsonDecode(raw.last)['coreName'], 'Newest');
    });
  });

  group('logQuestCompletion', () {
    test('collapses a repeated ending of the same quest within 30 minutes',
        () async {
      final t0 = DateTime(2026, 7, 7, 12);
      await ParentRecapService.logQuestCompletion(
          questId: 'big_bear_hug', title: 'Big Bear Hug', now: t0);
      await ParentRecapService.logQuestCompletion(
          questId: 'big_bear_hug',
          title: 'Big Bear Hug',
          now: t0.add(const Duration(minutes: 10)));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(ParentRecapService.questCompletionsKey),
          hasLength(1));
    });

    test('logs the same quest again once the dedupe window has passed',
        () async {
      final t0 = DateTime(2026, 7, 7, 12);
      await ParentRecapService.logQuestCompletion(
          questId: 'big_bear_hug', title: 'Big Bear Hug', now: t0);
      await ParentRecapService.logQuestCompletion(
          questId: 'big_bear_hug',
          title: 'Big Bear Hug',
          now: t0.add(const Duration(hours: 1)));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(ParentRecapService.questCompletionsKey),
          hasLength(2));
    });

    test('different quests back-to-back both log', () async {
      final t0 = DateTime(2026, 7, 7, 12);
      await ParentRecapService.logQuestCompletion(
          questId: 'big_bear_hug', title: 'Big Bear Hug', now: t0);
      await ParentRecapService.logQuestCompletion(
          questId: 'my_turn_your_turn',
          title: 'My Turn Your Turn',
          now: t0.add(const Duration(minutes: 5)));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(ParentRecapService.questCompletionsKey),
          hasLength(2));
    });
  });

  group('buildWeeklyRecap', () {
    test('windows all three feeds to the last 7 days', () async {
      final now = DateTime(2026, 7, 7, 12);
      SharedPreferences.setMockInitialValues({
        ParentRecapService.journalKey: [
          encodeGardenEntry(
              coreName: 'Old',
              timestamp: now.subtract(const Duration(days: 10))),
          encodeGardenEntry(
              coreName: 'Happy',
              timestamp: now.subtract(const Duration(days: 2))),
        ],
        ParentRecapService.questCompletionsKey: [
          jsonEncode({
            'questId': 'old_quest',
            'title': 'Old Quest',
            'timestamp':
                now.subtract(const Duration(days: 20)).toIso8601String(),
          }),
          jsonEncode({
            'questId': 'fresh_quest',
            'title': 'Fresh Quest',
            'timestamp':
                now.subtract(const Duration(days: 1)).toIso8601String(),
          }),
        ],
      });

      final recap = await ParentRecapService.buildWeeklyRecap(
        allStories: [
          makeStory(
              title: 'Old Story',
              createdAt: now.subtract(const Duration(days: 30))),
          makeStory(
              title: 'Fresh Story',
              createdAt: now.subtract(const Duration(days: 3))),
        ],
        now: now,
      );

      expect(recap.checkIns.map((c) => c.coreName), ['Happy']);
      expect(recap.questCompletions.map((q) => q.questId), ['fresh_quest']);
      expect(recap.stories.map((s) => s.title), ['Fresh Story']);
      expect(recap.isEmpty, isFalse);
    });

    test('aggregates feelings by count with average intensity', () async {
      final now = DateTime(2026, 7, 7, 12);
      SharedPreferences.setMockInitialValues({
        ParentRecapService.journalKey: [
          encodeGardenEntry(
              coreName: 'Sad',
              intensity: 2,
              timestamp: now.subtract(const Duration(days: 3))),
          encodeGardenEntry(
              coreName: 'Happy',
              intensity: 3,
              timestamp: now.subtract(const Duration(days: 2))),
          encodeGardenEntry(
              coreName: 'Happy',
              intensity: 5,
              timestamp: now.subtract(const Duration(days: 1))),
        ],
      });

      final recap = await ParentRecapService.buildWeeklyRecap(
        allStories: const [],
        now: now,
      );

      expect(recap.topFeelings, hasLength(2));
      expect(recap.topFeelings.first.name, 'Happy');
      expect(recap.topFeelings.first.count, 2);
      expect(recap.topFeelings.first.avgIntensity, 4.0);
      expect(recap.topFeelings.last.name, 'Sad');
    });

    test('skips malformed journal entries instead of throwing', () async {
      final now = DateTime(2026, 7, 7, 12);
      SharedPreferences.setMockInitialValues({
        ParentRecapService.journalKey: [
          'not json at all',
          '[1, 2, 3]',
          encodeGardenEntry(
              coreName: 'Calm',
              timestamp: now.subtract(const Duration(days: 1))),
        ],
      });

      final recap = await ParentRecapService.buildWeeklyRecap(
        allStories: const [],
        now: now,
      );

      expect(recap.checkIns.map((c) => c.coreName), ['Calm']);
    });

    test('collects distinct practiced focuses across guided stories',
        () async {
      final now = DateTime(2026, 7, 7, 12);
      final recap = await ParentRecapService.buildWeeklyRecap(
        allStories: [
          makeStory(
              title: 'A',
              createdAt: now.subtract(const Duration(days: 1)),
              practiced: 'sharing, big feelings'),
          makeStory(
              title: 'B',
              createdAt: now.subtract(const Duration(days: 2)),
              practiced: 'sharing'),
          makeStory(
              title: 'C', createdAt: now.subtract(const Duration(days: 3))),
        ],
        now: now,
      );

      expect(recap.practicedFocuses, ['sharing', 'big feelings']);
    });

    test('returns an empty recap when nothing happened this week', () async {
      final recap = await ParentRecapService.buildWeeklyRecap(
        allStories: const [],
        now: DateTime(2026, 7, 7, 12),
      );

      expect(recap.isEmpty, isTrue);
      expect(recap.topFeelings, isEmpty);
    });
  });
}
