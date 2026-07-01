import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models/antihero_crux_result.dart';
import 'package:story_weaver_app/models/api_error.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AntiheroCruxResult.fromBackend', () {
    test('parses the part-1 awaiting_choice envelope', () {
      final result = AntiheroCruxResult.fromBackend({
        'status': 'awaiting_choice',
        'continuation_token': 'tok-123',
        'story': {
          'title': 'The Tell',
          'pages': ['Beat 1', 'Beat 2', 'Beat 3', 'Beat 4'],
          'crux': 'Hand over the drive, or burn the cover you built.',
          'choices': [
            {'id': 'a', 'text': 'Give it up'},
            {'id': 'b', 'text': 'Keep hiding'},
          ],
        },
      });

      expect(result.isValid, isTrue);
      expect(result.continuationToken, 'tok-123');
      expect(result.title, 'The Tell');
      expect(result.pages, hasLength(4));
      expect(result.crux, contains('burn the cover'));
      expect(result.choices.map((c) => c.id), ['a', 'b']);
      expect(result.choices.first.text, 'Give it up');
    });

    test('drops malformed choices and reports invalid when < 2 remain', () {
      final result = AntiheroCruxResult.fromBackend({
        'continuation_token': 'tok',
        'story': {
          'pages': ['Beat 1'],
          'crux': 'x',
          'choices': [
            {'id': 'a', 'text': 'only one valid'},
            {'id': '', 'text': 'missing id'},
          ],
        },
      });

      expect(result.choices, hasLength(1));
      expect(result.isValid, isFalse);
    });
  });

  group('ApiServiceManager.generateAntiheroCrux', () {
    test('posts the antihero body and returns the parsed crux', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('generate-antihero-crux'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['theme'], 'superhero');
        expect(body['hero_mode'], 'antihero');
        expect(body['character'], 'Rowan');
        expect(body['hero_secret'], 'That I\'m not okay');
        return http.Response(
          jsonEncode({
            'status': 'awaiting_choice',
            'continuation_token': 'tok-abc',
            'story': {
              'title': 'Borrowed Time',
              'pages': ['b1', 'b2', 'b3', 'b4'],
              'crux': 'the line',
              'choices': [
                {'id': 'a', 'text': 'A'},
                {'id': 'b', 'text': 'B'},
              ],
            },
          }),
          200,
        );
      });

      final crux = await ApiServiceManager.generateAntiheroCrux(
        characterName: 'Rowan',
        age: 16,
        subscriptionTier: 'free',
        heroSecret: "That I'm not okay",
        client: mockClient,
      );

      expect(crux.continuationToken, 'tok-abc');
      expect(crux.choices, hasLength(2));
    });

    test('maps a QUOTA_EXCEEDED 429 to an ApiError', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Daily story limit reached', 'code': 'QUOTA_EXCEEDED'}),
          429,
        );
      });

      expect(
        () => ApiServiceManager.generateAntiheroCrux(
          characterName: 'Rowan',
          age: 16,
          client: mockClient,
        ),
        throwsA(isA<ApiError>()),
      );
    });
  });

  group('ApiServiceManager.generateAntiheroResolution', () {
    test('posts the token + choice and parses the complete story', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('generate-antihero-resolution'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['continuation_token'], 'tok-abc');
        expect(body['choice_id'], 'b');
        return http.Response(
          jsonEncode({
            'status': 'complete',
            'story': {
              'id': 's1',
              'title': 'Borrowed Time',
              'story_text': 'full story',
              'pages': ['b1', 'b2', 'b3', 'b4', 'b5', 'b6', 'b7'],
              'superhero_meta': {
                'band': 'adolescent',
                'saga_state': {'defining_choice': 'kept hiding'},
              },
            },
          }),
          200,
        );
      });

      final story = await ApiServiceManager.generateAntiheroResolution(
        continuationToken: 'tok-abc',
        choiceId: 'b',
        client: mockClient,
      );

      expect(story.pages, hasLength(7));
      expect(story.superheroMeta?['saga_state']['defining_choice'], 'kept hiding');
    });

    test('maps a 410 expired token to an ApiError', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'expired', 'code': 'TOKEN_EXPIRED'}),
          410,
        );
      });

      expect(
        () => ApiServiceManager.generateAntiheroResolution(
          continuationToken: 'stale',
          choiceId: 'a',
          client: mockClient,
        ),
        throwsA(isA<ApiError>()),
      );
    });

    test('throws when a 200 carries no story body', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'status': 'complete'}), 200);
      });

      expect(
        () => ApiServiceManager.generateAntiheroResolution(
          continuationToken: 'tok',
          choiceId: 'a',
          client: mockClient,
        ),
        throwsA(isA<HttpException>()),
      );
    });
  });
}
