// MT-409: rescue stories that finish after the client has given up waiting.
//
// MT-408 made a timed-out attempt resume its existing task instead of paying
// for a new generation — but each id is resumed at most once and the whole
// call gives up after `maxAttempts`. A generation that only lands after the
// entire retry budget (the production incident took ~5.8 minutes) was still
// abandoned, and once abandoned it was invisible: the library reads local
// storage, so a Story row sitting finished in the server database never
// appeared anywhere the user could see.
//
// This service closes that gap. Every started generation task is recorded
// here with just enough metadata to build a library entry; ids are removed
// again on every terminal outcome (success, cancel, structural failure). What
// remains after a crash or an exhausted retry budget is re-polled once on the
// next launch, and anything that completed server-side is saved into the
// local library — the story the user already paid for, delivered late instead
// of never.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/environment.dart';
import '../models.dart';
import '../models/local/story_local.dart';
import '../models/story_generation_result.dart';
import 'api_service_manager.dart';
import 'isar_service.dart';
import 'logger_service.dart';
import 'offline_story_service.dart';

/// One generation task the client walked away from before it resolved.
class PendingStoryTask {
  const PendingStoryTask({
    required this.taskId,
    required this.characterName,
    required this.age,
    required this.theme,
    this.isRhyming = false,
    this.isLearningToRead = false,
    required this.createdAt,
  });

  final String taskId;
  final String characterName;
  final int age;
  final String theme;
  final bool isRhyming;
  final bool isLearningToRead;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'characterName': characterName,
        'age': age,
        'theme': theme,
        'isRhyming': isRhyming,
        'isLearningToRead': isLearningToRead,
        'createdAt': createdAt.toIso8601String(),
      };

  static PendingStoryTask? fromJson(Map<String, dynamic> json) {
    final taskId = json['taskId'];
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (taskId is! String || taskId.isEmpty || createdAt == null) return null;
    return PendingStoryTask(
      taskId: taskId,
      characterName: json['characterName'] as String? ?? 'Hero',
      age: json['age'] as int? ?? 5,
      theme: json['theme'] as String? ?? 'Adventure',
      isRhyming: json['isRhyming'] as bool? ?? false,
      isLearningToRead: json['isLearningToRead'] as bool? ?? false,
      createdAt: createdAt,
    );
  }
}

class PendingStoryTaskService {
  static const String _prefsKey = 'pending_story_tasks_v1';

  /// Records older than this are dropped unpolled. The server keeps the
  /// finished Story row far longer, but a task that still reads `pending`
  /// after a day is never going to finish — and the task-owner record the
  /// backend uses to authorize `/task-status` expires on the same clock, so
  /// polling past it would be refused anyway.
  static const Duration maxAge = Duration(hours: 24);

  /// Hard cap on tracked ids. Oldest are dropped first. Generation is gated by
  /// quotas well below this, so hitting the cap means something is looping —
  /// bound the damage rather than growing an unbounded prefs blob.
  static const int maxTracked = 8;

  /// Remember a started task. Upserts by [PendingStoryTask.taskId], so the
  /// resume path re-reporting the same id is a no-op. Never throws: this is
  /// bookkeeping around a paid generation, and bookkeeping must not break it.
  Future<void> record(PendingStoryTask task) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasks = _load(prefs)
        ..removeWhere((t) => t.taskId == task.taskId)
        ..add(task);
      // Oldest first so the cap trims from the front.
      tasks.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      while (tasks.length > maxTracked) {
        tasks.removeAt(0);
      }
      await _save(prefs, tasks);
    } catch (e) {
      LoggerService.warning('PendingStoryTask: record failed', e);
    }
  }

  /// Forget a task that reached a terminal outcome. Never throws.
  Future<void> resolve(String taskId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasks = _load(prefs)..removeWhere((t) => t.taskId == taskId);
      await _save(prefs, tasks);
    } catch (e) {
      LoggerService.warning('PendingStoryTask: resolve failed', e);
    }
  }

  /// Unresolved tasks young enough to still be worth polling. Expired entries
  /// are pruned from storage as a side effect.
  Future<List<PendingStoryTask>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    final tasks = _load(prefs);
    final now = DateTime.now();
    final fresh =
        tasks.where((t) => now.difference(t.createdAt) < maxAge).toList();
    if (fresh.length != tasks.length) await _save(prefs, fresh);
    return fresh;
  }

  /// Launch-time rescue: poll each unresolved task once and save anything
  /// that completed server-side into the local library. Returns how many
  /// stories were rescued, so the caller can tell the user.
  ///
  /// Per-task outcomes:
  ///   * complete with a story → saved locally, id resolved;
  ///   * complete-but-cancelled, `failure`, or any 4xx (ownership lost,
  ///     unknown id) → resolved — the id can never produce a story;
  ///   * still `pending`/`processing`, network error, or 5xx → kept for the
  ///     next launch (expiry in [pending] bounds how long that can go on).
  Future<int> recoverPending({
    http.Client? client,
    OfflineStoryService? storage,
  }) async {
    final tasks = await pending();
    if (tasks.isEmpty) return 0;

    final httpClient = client ?? http.Client();
    // getInstance(), not .instance: at launch this can run before anything
    // else has opened Isar, and the bare getter throws until something has.
    final store =
        storage ?? OfflineStoryService(await IsarService.getInstance());
    var rescued = 0;
    try {
      // One request-timeout's worth of existing library text, for the
      // duplicate guard below. Loaded once, outside the loop.
      List<String>? existingTexts;

      for (final task in tasks) {
        try {
          final response = await httpClient
              .get(
                Uri.parse(
                    '${Environment.backendUrl}/task-status/${task.taskId}'),
                headers: await ApiServiceManager.authHeaders(),
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode >= 400 && response.statusCode < 500) {
            // Unknown id or ownership refused — nothing will ever come of it.
            await resolve(task.taskId);
            continue;
          }
          if (response.statusCode != 200) {
            continue; // server hiccup: retry later
          }

          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final status = data['status'] as String?;
          if (status == 'failure' || status == 'cancelled') {
            await resolve(task.taskId);
            continue;
          }
          if (status != 'complete') continue; // still pending: keep

          final result = data['result'];
          if (result is! Map<String, dynamic> ||
              result['status'] == 'cancelled') {
            await resolve(task.taskId);
            continue;
          }
          final parsed = StoryGenerationResult.fromBackend(result);
          if (parsed.storyText.trim().isEmpty) {
            await resolve(task.taskId);
            continue;
          }

          // Duplicate guard: a retry loop can leave two ids for the SAME
          // request (timeout → one resume → timeout → fresh POST), and both
          // can finish. The text of a given completed task never changes, so
          // an exact match against the library means this story is already
          // there — resolve without saving a second copy.
          existingTexts ??=
              (await store.getAllStories()).map((s) => s.storyText).toList();
          if (existingTexts.contains(parsed.storyText)) {
            await resolve(task.taskId);
            continue;
          }

          final saved = SavedStory(
            title: parsed.title ?? '${task.characterName}\'s Story',
            storyText: parsed.storyText,
            theme: task.theme,
            characters: [
              Character(
                id: 'recovered',
                name: task.characterName,
                age: task.age,
                role: 'Hero',
              ),
            ],
            createdAt: task.createdAt,
            isRhyming: task.isRhyming,
            isLearningToRead: task.isLearningToRead,
            wisdomGem: parsed.wisdomGem,
            pages: parsed.pages.isNotEmpty ? parsed.pages : null,
            adventureSteps:
                parsed.adventureSteps.isNotEmpty ? parsed.adventureSteps : null,
            totalWords: parsed.storyText.split(RegExp(r'\s+')).length,
            totalPages: parsed.pages.isNotEmpty ? parsed.pages.length : null,
          );
          await store.saveStory(StoryLocal.fromSavedStory(saved));
          existingTexts.add(parsed.storyText);
          await resolve(task.taskId);
          rescued++;
          LoggerService.info(
              'PendingStoryTask: rescued story for task ${task.taskId}');
        } catch (e) {
          // Network trouble or an unparsable body: keep the id and try again
          // next launch. The expiry in [pending] is the backstop.
          debugPrint('PendingStoryTask: poll for ${task.taskId} failed: $e');
        }
      }
    } finally {
      if (client == null) httpClient.close();
    }
    return rescued;
  }

  List<PendingStoryTask> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(PendingStoryTask.fromJson)
          .whereType<PendingStoryTask>()
          .toList();
    } catch (_) {
      // A corrupt blob poisons every future record/resolve — drop it.
      return [];
    }
  }

  Future<void> _save(
      SharedPreferences prefs, List<PendingStoryTask> tasks) async {
    await prefs.setString(
        _prefsKey, jsonEncode(tasks.map((t) => t.toJson()).toList()));
  }
}
