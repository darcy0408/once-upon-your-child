import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models/local/story_local.dart';
import 'package:story_weaver_app/services/clinician_handout_pdf_service.dart';
import 'package:story_weaver_app/services/parent_recap_service.dart';

/// Counts individual `/Type /Page` page objects in the raw PDF bytes
/// (excluding the `/Type /Pages` tree node) — same assertion technique as
/// story_pdf_service_test.dart.
int _countPdfPages(List<int> bytes) {
  final content = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r'/Type\s*/Page(?!s)').allMatches(content).length;
}

WeeklyRecapData _recap({
  List<FeelingCheckIn> checkIns = const [],
  List<FeelingSummary> topFeelings = const [],
  List<StoryLocal> stories = const [],
  List<QuestCompletion> questCompletions = const [],
}) {
  return WeeklyRecapData(
    weekStart: DateTime(2026, 6, 30),
    weekEnd: DateTime(2026, 7, 7),
    checkIns: checkIns,
    topFeelings: topFeelings,
    stories: stories,
    questCompletions: questCompletions,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const service = ClinicianHandoutPdfService();

  test('builds a document from a fully populated week', () async {
    final story = StoryLocal()
      ..storyId = 's1'
      ..title = 'The Brave Little Fox'
      ..storyText = 'unused'
      ..theme = 'Adventure'
      ..createdAt = DateTime(2026, 7, 3)
      ..practiced = 'sharing, big feelings';

    final bytes = await service.buildHandout(
      recap: _recap(
        checkIns: [
          FeelingCheckIn(
            coreName: 'Happy',
            coreEmoji: '😊',
            intensity: 4,
            timestamp: DateTime(2026, 7, 5),
          ),
        ],
        topFeelings: const [
          FeelingSummary(
              name: 'Happy', emoji: '😊', count: 3, avgIntensity: 3.7),
          FeelingSummary(name: 'Sad', emoji: '😢', count: 1, avgIntensity: 2),
        ],
        stories: [story],
        questCompletions: [
          QuestCompletion(
            questId: 'big_bear_hug',
            title: 'Big Bear Hug',
            timestamp: DateTime(2026, 7, 4),
          ),
        ],
      ),
      childLabel: 'Ruby',
    );

    expect(bytes, isNotEmpty);
    expect(_countPdfPages(bytes), greaterThanOrEqualTo(1));
  });

  test('still builds a valid document for an empty week', () async {
    final bytes = await service.buildHandout(recap: _recap());

    expect(bytes, isNotEmpty);
    expect(_countPdfPages(bytes), greaterThanOrEqualTo(1));
  });

  test('strips emoji and exotic glyphs instead of crashing', () async {
    final story = StoryLocal()
      ..storyId = 's2'
      ..title = '🦊 Foxy\'s "Big" Adventure — a tale…'
      ..storyText = 'unused'
      ..theme = '✨ Magic'
      ..createdAt = DateTime(2026, 7, 2);

    final bytes = await service.buildHandout(
      recap: _recap(
        topFeelings: const [
          FeelingSummary(
              name: '😠 Grr-Angry', emoji: '😠', count: 2, avgIntensity: 4.5),
        ],
        stories: [story],
        questCompletions: [
          QuestCompletion(
            questId: 'q',
            title: '👑 Princess Zoë\'s Quest',
            timestamp: DateTime(2026, 7, 6),
          ),
        ],
      ),
      childLabel: '👧 Zoë',
    );

    expect(bytes, isNotEmpty);
    expect(_countPdfPages(bytes), greaterThanOrEqualTo(1));
  });
}
