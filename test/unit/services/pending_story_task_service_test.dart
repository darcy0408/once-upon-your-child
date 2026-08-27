// MT-409: unit + rescue tests for the abandoned-story registry.
//
// The registry remembers every started generation task; what survives a
// terminal outcome is re-polled at next launch and anything that completed
// server-side is saved into the local library. These tests pin the registry
// bookkeeping (record / resolve / expiry / cap / corrupt blob) and every
// per-task outcome of the launch rescue.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/models/local/story_local.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/offline_story_service.dart';
import 'package:story_weaver_app/services/pending_story_task_service.dart';

/// In-memory stand-in for the Isar/localStorage-backed story library.
class _RecordingStore extends Fake implements OfflineStoryService {
  final List<StoryLocal> saved = [];

  @override
  Future<void> saveStory(StoryLocal story) async => saved.add(story);

  @override
  Future<List<StoryLocal>> getAllStories() async => List.of(saved);
}

PendingStoryTask _task(String id, {DateTime? createdAt}) => PendingStoryTask(
      taskId: id,
      characterName: 'Luna',
      age: 7,
      theme: 'Adventure',
      createdAt: createdAt ?? DateTime.now(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PendingStoryTaskService registry', () {
    test('record and pending round-trip', () async {
      final service = PendingStoryTaskService();
      await service.record(_task('task-1'));

      final tasks = await service.pending();
      expect(tasks, hasLength(1));
      expect(tasks.single.taskId, 'task-1');
      expect(tasks.single.characterName, 'Luna');
      expect(tasks.single.age, 7);
      expect(tasks.single.theme, 'Adventure');
    });

    test('record upserts by taskId', () async {
      final service = PendingStoryTaskService();
      await service.record(_task('task-1'));
      await service.record(_task('task-1'));

      expect(await service.pending(), hasLength(1));
    });

    test('resolve removes only the given id', () async {
      final service = PendingStoryTaskService();
      await service.record(_task('task-1'));
      await service.record(_task('task-2'));

      await service.resolve('task-1');

      final tasks = await service.pending();
      expect(tasks.map((t) => t.taskId), ['task-2']);
    });

    test('pending drops entries older than maxAge', () async {
      final service = PendingStoryTaskService();
      await service.record(_task('task-old',
          createdAt:
              DateTime.now().subtract(PendingStoryTaskService.maxAge * 2)));
      await service.record(_task('task-fresh'));

      final tasks = await service.pending();
      expect(tasks.map((t) => t.taskId), ['task-fresh']);
      // And the prune persisted — a second read stays clean.
      expect((await service.pending()).map((t) => t.taskId), ['task-fresh']);
    });

    test('record caps the list, dropping oldest first', () async {
      final service = PendingStoryTaskService();
      final base = DateTime.now()
          .subtract(const Duration(minutes: 30)); // all inside maxAge
      for (var i = 0; i < PendingStoryTaskService.maxTracked + 2; i++) {
        await service.record(
            _task('task-$i', createdAt: base.add(Duration(minutes: i))));
      }

      final tasks = await service.pending();
      expect(tasks, hasLength(PendingStoryTaskService.maxTracked));
      expect(tasks.map((t) => t.taskId), isNot(contains('task-0')));
      expect(tasks.map((t) => t.taskId), isNot(contains('task-1')));
    });

    test('a corrupt blob yields empty and does not throw', () async {
      SharedPreferences.setMockInitialValues(
          {'pending_story_tasks_v1': 'not json{{'});
      final service = PendingStoryTaskService();

      expect(await service.pending(), isEmpty);
      // And the registry still works afterwards.
      await service.record(_task('task-1'));
      expect(await service.pending(), hasLength(1));
    });
  });

  group('PendingStoryTaskService.recoverPending', () {
    final fakeJwt = '${base64Url.encode(utf8.encode('{"alg":"none"}'))}'
        '.${base64Url.encode(utf8.encode('{"sub":"user_test"}'))}'
        '.sig';

    /// Builds a MockClient that answers auth and serves [statusBody] (or
    /// [statusCode]) for every /task-status poll.
    MockClient statusClient(
      Map<String, dynamic>? statusBody, {
      int statusCode = 200,
      List<String>? polledIds,
    }) {
      return MockClient((request) async {
        final path = request.url.path;
        if (path.contains('auth')) {
          return http.Response(
              jsonEncode({'token': fakeJwt, 'user_id': 'user_test'}), 200);
        }
        if (path.contains('task-status')) {
          polledIds?.add(path.split('/').last);
          return http.Response(
              statusBody != null ? jsonEncode(statusBody) : 'error',
              statusCode);
        }
        return http.Response('not found', 404);
      });
    }

    Future<void> withAuthMock(
        MockClient client, Future<void> Function() body) async {
      await ApiServiceManager.resetAuthForTest();
      ApiServiceManager.setTestClient(client);
      try {
        await body();
      } finally {
        ApiServiceManager.setTestClient(null);
        await ApiServiceManager.resetAuthForTest();
      }
    }

    test('a completed task is saved to the library and cleared', () async {
      final service = PendingStoryTaskService();
      await service.record(_task('task-late'));
      final store = _RecordingStore();
      final polled = <String>[];
      final client = statusClient({
        'status': 'complete',
        'result': {
          'story': {
            'story_text': 'The story that finished after everyone left',
            'title': 'The Late Story',
            'wisdom_gem': 'Patience pays.',
            'pages': ['Page one.', 'Page two.'],
          }
        },
      }, polledIds: polled);

      await withAuthMock(client, () async {
        final rescued =
            await service.recoverPending(client: client, storage: store);
        expect(rescued, 1);
      });

      expect(polled, ['task-late']);
      expect(store.saved, hasLength(1));
      final story = store.saved.single;
      expect(story.storyText, 'The story that finished after everyone left');
      expect(story.title, 'The Late Story');
      expect(await service.pending(), isEmpty,
          reason: 'a rescued task must never be polled again');
    });

    test('a still-pending task is kept and nothing is saved', () async {
      final service = PendingStoryTaskService();
      await service.record(_task('task-slow'));
      final store = _RecordingStore();
      final client = statusClient({'status': 'pending'});

      await withAuthMock(client, () async {
        expect(await service.recoverPending(client: client, storage: store), 0);
      });

      expect(store.saved, isEmpty);
      expect((await service.pending()).map((t) => t.taskId), ['task-slow'],
          reason: 'still-running work is retried at the NEXT launch');
    });

    test('a 4xx clears the id without saving', () async {
      final service = PendingStoryTaskService();
      await service.record(_task('task-gone'));
      final store = _RecordingStore();
      final client = statusClient(null, statusCode: 404);

      await withAuthMock(client, () async {
        expect(await service.recoverPending(client: client, storage: store), 0);
      });

      expect(store.saved, isEmpty);
      expect(await service.pending(), isEmpty,
          reason: 'an unknown/refused id can never produce a story');
    });

    test('a failure status clears the id without saving', () async {
      final service = PendingStoryTaskService();
      await service.record(_task('task-failed'));
      final store = _RecordingStore();
      final client =
          statusClient({'status': 'failure', 'result': 'model exploded'});

      await withAuthMock(client, () async {
        expect(await service.recoverPending(client: client, storage: store), 0);
      });

      expect(store.saved, isEmpty);
      expect(await service.pending(), isEmpty);
    });

    test('an inner cancelled result clears the id without saving', () async {
      final service = PendingStoryTaskService();
      await service.record(_task('task-cancelled'));
      final store = _RecordingStore();
      final client = statusClient({
        'status': 'complete',
        'result': {'status': 'cancelled'},
      });

      await withAuthMock(client, () async {
        expect(await service.recoverPending(client: client, storage: store), 0);
      });

      expect(store.saved, isEmpty);
      expect(await service.pending(), isEmpty,
          reason: 'the user walked away from this task on purpose');
    });

    test('an exact-duplicate story is cleared without saving a second copy',
        () async {
      // The retry loop can leave TWO ids for one request (timeout → resume →
      // timeout → fresh POST) and both can finish with the same text — or the
      // in-session success already saved it. Either way: one copy only.
      final service = PendingStoryTaskService();
      await service.record(_task('task-dup'));
      final store = _RecordingStore();
      store.saved.add(StoryLocal.fromSavedStory(
        // Same text already in the library.
        _savedStoryWithText('Twice-finished tale'),
      ));
      final client = statusClient({
        'status': 'complete',
        'result': {
          'story': {'story_text': 'Twice-finished tale'}
        },
      });

      await withAuthMock(client, () async {
        expect(await service.recoverPending(client: client, storage: store), 0);
      });

      expect(store.saved, hasLength(1),
          reason: 'the library must not gain a duplicate');
      expect(await service.pending(), isEmpty);
    });

    test('a network error keeps the id for the next launch', () async {
      final service = PendingStoryTaskService();
      await service.record(_task('task-offline'));
      final store = _RecordingStore();
      final failingClient = MockClient((request) async {
        if (request.url.path.contains('auth')) {
          return http.Response(
              jsonEncode({'token': fakeJwt, 'user_id': 'user_test'}), 200);
        }
        throw const SocketExceptionFake();
      });

      await withAuthMock(failingClient, () async {
        expect(
            await service.recoverPending(client: failingClient, storage: store),
            0);
      });

      expect(store.saved, isEmpty);
      expect((await service.pending()).map((t) => t.taskId), ['task-offline']);
    });

    test('a 5xx keeps the id for the next launch', () async {
      final service = PendingStoryTaskService();
      await service.record(_task('task-hiccup'));
      final store = _RecordingStore();
      final client = statusClient(null, statusCode: 503);

      await withAuthMock(client, () async {
        expect(await service.recoverPending(client: client, storage: store), 0);
      });

      expect((await service.pending()).map((t) => t.taskId), ['task-hiccup']);
    });
  });
}

/// Minimal SavedStory for the duplicate-guard test's pre-seeded library.
SavedStory _savedStoryWithText(String text) => SavedStory(
      title: 'Existing copy',
      storyText: text,
      theme: 'Adventure',
      characters: const [],
      createdAt: DateTime.now(),
    );

/// A throwable that stands in for SocketException without importing dart:io
/// (keeps the file web-compatible if the suite ever runs there).
class SocketExceptionFake implements Exception {
  const SocketExceptionFake();
}
