import 'dart:convert';

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
        return http.Response(jsonEncode({'story': 'Mock backend story'}), 200);
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

      expect(story, 'Mock backend story');
    });

    test('sends multi-character payload when additional characters present', () async {
      bool sawMultiCharacterEndpoint = false;
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('generate-multi-character-story')) {
          sawMultiCharacterEndpoint = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['main_character'], 'Kai');
          expect(body['characters'], contains('Maya'));
          return http.Response(jsonEncode({'story': 'Group adventure'}), 200);
        }
        return http.Response('{}', 500);
      });

      final story = await ApiServiceManager.generateStory(
        characterName: 'Kai',
        theme: 'Friendship',
        age: 9,
        additionalCharacters: const ['Maya'],
        currentFeeling: null,
        client: mockClient,
      );

      expect(story, 'Group adventure');
      expect(sawMultiCharacterEndpoint, isTrue);
    });

    test('retries failed backend calls before succeeding', () async {
      int attempts = 0;
      final mockClient = MockClient((request) async {
        attempts++;
        if (attempts < 3) {
          return http.Response('server busy', 500);
        }
        return http.Response(jsonEncode({'story': 'Retried story!'}), 200);
      });

      final story = await ApiServiceManager.generateStory(
        characterName: 'Retry Hero',
        theme: 'Adventure',
        age: 8,
        client: mockClient,
      );

      expect(story, 'Retried story!');
      expect(attempts, 3);
    });
  });
}
