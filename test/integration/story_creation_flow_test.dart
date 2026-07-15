import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ApiServiceManager.generateStory', () {
    test('returns story text from backend client', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('generate-story'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['character'], 'Luna');
        expect(body['subscription_tier'], 'free');
        expect(body['user_id'], startsWith('user_'));
        return http.Response(
            jsonEncode({
              'story': {'story_text': 'Mock backend story'}
            }),
            200);
      });

      final story = await ApiServiceManager.generateStory(
        characterName: 'Luna',
        theme: 'Adventure',
        age: 7,
        companion: 'None',
        characterDetails: const {},
        currentFeeling: null,
        client: mockClient,
      );

      expect(story.storyText, 'Mock backend story');
    });

    test('includes additional characters in payload when present', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('generate-story'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final extras = body['additional_characters'] as List<dynamic>?;
        expect(extras, isNotNull);
        expect(extras, contains('Maya'));
        expect(body['subscription_tier'], 'free');
        return http.Response(
            jsonEncode({
              'story': {'story_text': 'Group adventure'}
            }),
            200);
      });

      final story = await ApiServiceManager.generateStory(
        characterName: 'Kai',
        theme: 'Friendship',
        age: 9,
        additionalCharacters: const ['Maya'],
        currentFeeling: null,
        client: mockClient,
      );

      expect(story.storyText, 'Group adventure');
    });

    test('forwards big feelings hidden context fields in payload', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('generate-story'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['feelingTrigger'], 'Someone said no');
        expect(body['bodySignal'], 'Hot face');
        expect(body['copingTool'], 'Take a dragon breath');
        expect(body['repairGoal'], 'Help fix it');
        expect(body['parentHiddenContext'], 'trouble hearing no');
        return http.Response(
            jsonEncode({
              'story': {'story_text': 'Big feelings story'}
            }),
            200);
      });

      final story = await ApiServiceManager.generateStory(
        characterName: 'Milo',
        theme: 'Big Feelings',
        age: 5,
        currentFeeling: const {
          'emotion_name': 'Mad',
          'physical_signs': 'Hot face',
        },
        feelingTrigger: 'Someone said no',
        bodySignal: 'Hot face',
        copingTool: 'Take a dragon breath',
        repairGoal: 'Help fix it',
        parentHiddenContext: 'trouble hearing no',
        client: mockClient,
      );

      expect(story.storyText, 'Big feelings story');
    });

    test('retries failed backend calls before succeeding', () async {
      int attempts = 0;
      final mockClient = MockClient((request) async {
        attempts++;
        if (attempts < 3) {
          return http.Response('server busy', 500);
        }
        return http.Response(
            jsonEncode({
              'story': {'story_text': 'Retried story!'}
            }),
            200);
      });

      final story = await ApiServiceManager.generateStory(
        characterName: 'Retry Hero',
        theme: 'Adventure',
        age: 8,
        client: mockClient,
        retryInitialDelay: const Duration(milliseconds: 20),
      );

      expect(story.storyText, 'Retried story!');
      expect(attempts, 3);
    });

    test('verifies exponential backoff timing', () async {
      int attempts = 0;
      final stopwatch = Stopwatch()..start();
      final mockClient = MockClient((request) async {
        attempts++;
        if (attempts < 3) {
          return http.Response('server busy', 500);
        }
        return http.Response(
            jsonEncode({
              'story': {'story_text': 'Timing story'}
            }),
            200);
      });

      final story = await ApiServiceManager.generateStory(
        characterName: 'Timing Tester',
        theme: 'Patience',
        age: 6,
        client: mockClient,
        maxAttempts: 3,
        retryInitialDelay: const Duration(milliseconds: 20),
      );

      stopwatch.stop();

      expect(story.storyText, 'Timing story');
      expect(attempts, 3);
      expect(
        stopwatch.elapsed,
        greaterThanOrEqualTo(const Duration(milliseconds: 60)),
      );
    });

    test('throws HttpException after retries exhausted', () async {
      final mockClient = MockClient(
        (request) async => http.Response('server busy', 503),
      );

      await expectLater(
        ApiServiceManager.generateStory(
          characterName: 'Retry Hero',
          theme: 'Adventure',
          age: 8,
          client: mockClient,
          retryInitialDelay: const Duration(milliseconds: 10),
          maxAttempts: 2,
        ),
        throwsA(
          allOf(
            isA<HttpException>(),
            predicate((error) => error.toString().contains('503')),
          ),
        ),
      );
    });

    test('throws TimeoutException when backend stalls', () async {
      final mockClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return http.Response(
            jsonEncode({
              'story': {'story_text': 'Too late'}
            }),
            200);
      });

      await expectLater(
        ApiServiceManager.generateStory(
          characterName: 'Slow Hero',
          theme: 'Adventure',
          age: 8,
          client: mockClient,
          requestTimeout: const Duration(milliseconds: 20),
        ),
        throwsA(
          allOf(
            isA<TimeoutException>(),
            predicate((error) => error.toString().contains('too long')),
          ),
        ),
      );
    });

    test('async 202 path polls /task-status WITH auth headers', () async {
      // Regression: /task-status is auth-gated server-side, but the poll GET
      // was sent without headers → perpetual 401 → the async story path never
      // completed on prod (2026-07-15 walkthrough). Pin that every status poll
      // carries an Authorization header and that a complete envelope parses.
      var statusPolls = 0;
      // Well-formed unexpired JWT (no exp claim) so _isTokenExpired passes.
      final fakeJwt = '${base64Url.encode(utf8.encode('{"alg":"none"}'))}'
          '.${base64Url.encode(utf8.encode('{"sub":"user_test"}'))}'
          '.sig';
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('auth')) {
          return http.Response(
              jsonEncode({
                'token': fakeJwt,
                'user_id': 'user_test',
              }),
              200);
        }
        if (path.contains('generate-story')) {
          return http.Response(jsonEncode({'task_id': 'task-123'}), 202);
        }
        if (path.contains('task-status')) {
          statusPolls++;
          final auth = request.headers['Authorization'] ??
              request.headers['authorization'];
          expect(auth, isNotNull,
              reason: '/task-status poll must send the JWT — an unauthenticated '
                  'poll 401s forever and the async story path never completes');
          expect(auth, isNotEmpty);
          return http.Response(
              jsonEncode({
                'status': 'complete',
                'result': {
                  'story': {'story_text': 'Async story done'}
                },
              }),
              200);
        }
        return http.Response('not found', 404);
      });

      // _ensureAuthenticated fetches the anonymous token through _testClient
      // (not the per-call client), so route BOTH through the same mock and
      // start from a clean auth slate.
      await ApiServiceManager.resetAuthForTest();
      ApiServiceManager.setTestClient(mockClient);
      addTearDown(() async {
        ApiServiceManager.setTestClient(null);
        await ApiServiceManager.resetAuthForTest();
      });

      final story = await ApiServiceManager.generateStory(
        characterName: 'Async Hero',
        theme: 'Adventure',
        age: 30,
        currentFeeling: null,
        client: mockClient,
        requestTimeout: const Duration(seconds: 10),
      );

      expect(statusPolls, greaterThan(0));
      expect(story.storyText, 'Async story done');
    });
  });
}
