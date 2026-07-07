// lib/services/parent_recap_service.dart
//
// Weekly Parent Recap: aggregates the on-device activity feeds — the
// feelings journal, the local story library, and life-quest completions —
// into a week-scoped summary a parent can review in-app or hand to a
// clinician as a printed PDF (ClinicianHandoutPdfService). Also owns the two
// lightweight write paths that feed it: story-wizard feeling check-ins
// (magic_review_step.dart) and quest completions (life_quest_screen.dart).
//
// Privacy: everything here reads and writes SharedPreferences / the local
// story store only. The recap is computed fresh on every open and is never
// uploaded — no child data leaves the device.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/local/story_local.dart';

/// One saved feeling check-in. Same JSON shape as the Feelings Garden
/// journal entries (`_JournalEntry` in feelings_garden_screen.dart) and what
/// FeelingsAmbientService reads — all three share the
/// [ParentRecapService.journalKey] SharedPreferences list, so this shape
/// must not drift.
class FeelingCheckIn {
  final String coreName;
  final String coreEmoji;
  final String? secondaryName;
  final String? tertiaryName;
  final int intensity;
  final DateTime timestamp;

  const FeelingCheckIn({
    required this.coreName,
    required this.coreEmoji,
    this.secondaryName,
    this.tertiaryName,
    required this.intensity,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'coreName': coreName,
        'coreEmoji': coreEmoji,
        'secondaryName': secondaryName,
        'tertiaryName': tertiaryName,
        'intensity': intensity,
        'timestamp': timestamp.toIso8601String(),
      };

  factory FeelingCheckIn.fromJson(Map<String, dynamic> j) => FeelingCheckIn(
        coreName: j['coreName'] ?? '',
        coreEmoji: j['coreEmoji'] ?? '😐',
        secondaryName: j['secondaryName'],
        tertiaryName: j['tertiaryName'],
        intensity: (j['intensity'] as num?)?.toInt() ?? 3,
        timestamp: DateTime.tryParse(j['timestamp'] ?? '') ?? DateTime.now(),
      );
}

/// One completed Life Quest ending. Only id/title/time — growth-prompt
/// answers and choice paths are deliberately NOT persisted (free-text a
/// child typed stays ephemeral).
class QuestCompletion {
  final String questId;
  final String title;
  final DateTime timestamp;

  const QuestCompletion({
    required this.questId,
    required this.title,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'questId': questId,
        'title': title,
        'timestamp': timestamp.toIso8601String(),
      };

  factory QuestCompletion.fromJson(Map<String, dynamic> j) => QuestCompletion(
        questId: j['questId'] ?? '',
        title: j['title'] ?? '',
        timestamp: DateTime.tryParse(j['timestamp'] ?? '') ?? DateTime.now(),
      );
}

/// Per-feeling aggregate for the recap window, sorted most-frequent first.
class FeelingSummary {
  final String name;
  final String emoji;
  final int count;
  final double avgIntensity;

  const FeelingSummary({
    required this.name,
    required this.emoji,
    required this.count,
    required this.avgIntensity,
  });
}

/// Everything the recap screen and the clinician handout render.
class WeeklyRecapData {
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<FeelingCheckIn> checkIns;
  final List<FeelingSummary> topFeelings;
  final List<StoryLocal> stories;
  final List<QuestCompletion> questCompletions;

  const WeeklyRecapData({
    required this.weekStart,
    required this.weekEnd,
    required this.checkIns,
    required this.topFeelings,
    required this.stories,
    required this.questCompletions,
  });

  bool get isEmpty =>
      checkIns.isEmpty && stories.isEmpty && questCompletions.isEmpty;

  /// Distinct parent-selected Big Feelings focuses across the week's guided
  /// stories (StoryLocal.practiced is comma-joined), reading order preserved.
  List<String> get practicedFocuses {
    final seen = <String>{};
    for (final story in stories) {
      final practiced = story.practiced;
      if (practiced == null || practiced.trim().isEmpty) continue;
      for (final focus in practiced.split(',')) {
        final trimmed = focus.trim();
        if (trimmed.isNotEmpty) seen.add(trimmed);
      }
    }
    return seen.toList();
  }
}

class ParentRecapService {
  /// Shared with feelings_garden_screen.dart (writer) and
  /// FeelingsAmbientService (reader) — key and entry shape must stay in sync
  /// across all three.
  static const String journalKey = 'feelings_journal';
  static const String questCompletionsKey = 'quest_completions';

  static const int _journalCap = 60; // matches Feelings Garden
  static const int _questCap = 100;

  /// Reaching the same quest ending twice in quick succession (rewind →
  /// re-choose) counts once.
  static const Duration _questDedupeWindow = Duration(minutes: 30);

  static const Duration recapWindow = Duration(days: 7);

  /// Appends a feeling check-in to the shared journal. Best-effort and
  /// fire-and-forget safe: never throws, so callers on the story-generation
  /// path can't be blocked by a persistence failure.
  static Future<void> logFeelingCheckIn({
    required String coreName,
    required String coreEmoji,
    String? secondaryName,
    String? tertiaryName,
    int intensity = 3,
    DateTime? now,
  }) async {
    if (coreName.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(journalKey) ?? [];
      raw.add(jsonEncode(FeelingCheckIn(
        coreName: coreName.trim(),
        coreEmoji: coreEmoji.isNotEmpty ? coreEmoji : '😐',
        secondaryName: secondaryName,
        tertiaryName: tertiaryName,
        intensity: intensity.clamp(1, 5),
        timestamp: now ?? DateTime.now(),
      ).toJson()));
      final trimmed =
          raw.length > _journalCap ? raw.sublist(raw.length - _journalCap) : raw;
      await prefs.setStringList(journalKey, trimmed);
    } catch (_) {
      // Persist failure is non-fatal — the story flow must not notice.
    }
  }

  /// Appends a quest completion. Best-effort, never throws; consecutive
  /// completions of the same quest inside [_questDedupeWindow] collapse to
  /// one entry.
  static Future<void> logQuestCompletion({
    required String questId,
    required String title,
    DateTime? now,
  }) async {
    if (questId.trim().isEmpty) return;
    try {
      final effectiveNow = now ?? DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(questCompletionsKey) ?? [];
      if (raw.isNotEmpty) {
        final last = _decodeEntry(raw.last, QuestCompletion.fromJson);
        if (last != null &&
            last.questId == questId &&
            effectiveNow.difference(last.timestamp) < _questDedupeWindow) {
          return;
        }
      }
      raw.add(jsonEncode(QuestCompletion(
        questId: questId,
        title: title,
        timestamp: effectiveNow,
      ).toJson()));
      final trimmed =
          raw.length > _questCap ? raw.sublist(raw.length - _questCap) : raw;
      await prefs.setStringList(questCompletionsKey, trimmed);
    } catch (_) {
      // Persist failure is non-fatal — the quest flow must not notice.
    }
  }

  /// Builds the last-7-days recap from the shared journal, the quest
  /// completion log, and the caller-supplied local story list (the caller
  /// already has storyListProvider; this service stays store-agnostic).
  /// Malformed persisted entries are skipped, never thrown on.
  static Future<WeeklyRecapData> buildWeeklyRecap({
    required List<StoryLocal> allStories,
    DateTime? now,
  }) async {
    final weekEnd = now ?? DateTime.now();
    final weekStart = weekEnd.subtract(recapWindow);

    final prefs = await SharedPreferences.getInstance();

    final checkIns = (prefs.getStringList(journalKey) ?? [])
        .map((e) => _decodeEntry(e, FeelingCheckIn.fromJson))
        .whereType<FeelingCheckIn>()
        .where((c) =>
            c.coreName.isNotEmpty &&
            c.timestamp.isAfter(weekStart) &&
            !c.timestamp.isAfter(weekEnd))
        .toList();

    final questCompletions = (prefs.getStringList(questCompletionsKey) ?? [])
        .map((e) => _decodeEntry(e, QuestCompletion.fromJson))
        .whereType<QuestCompletion>()
        .where((q) =>
            q.timestamp.isAfter(weekStart) && !q.timestamp.isAfter(weekEnd))
        .toList();

    final stories = allStories
        .where((s) =>
            s.createdAt.isAfter(weekStart) && !s.createdAt.isAfter(weekEnd))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return WeeklyRecapData(
      weekStart: weekStart,
      weekEnd: weekEnd,
      checkIns: checkIns,
      topFeelings: _summarizeFeelings(checkIns),
      stories: stories,
      questCompletions: questCompletions.reversed.toList(),
    );
  }

  static List<FeelingSummary> _summarizeFeelings(
      List<FeelingCheckIn> checkIns) {
    final byName = <String, List<FeelingCheckIn>>{};
    for (final c in checkIns) {
      byName.putIfAbsent(c.coreName, () => []).add(c);
    }
    final summaries = byName.entries.map((e) {
      final total = e.value.fold<int>(0, (sum, c) => sum + c.intensity);
      return FeelingSummary(
        name: e.key,
        emoji: e.value.last.coreEmoji,
        count: e.value.length,
        avgIntensity: total / e.value.length,
      );
    }).toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : a.name.compareTo(b.name);
      });
    return summaries;
  }

  static T? _decodeEntry<T>(
      String raw, T Function(Map<String, dynamic>) fromJson) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return fromJson(decoded);
    } catch (_) {
      // Skip malformed entries rather than failing the whole recap.
    }
    return null;
  }
}
