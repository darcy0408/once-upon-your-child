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
  });
}
