import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models.dart';
import 'dart:convert';

void main() {
  group('Character Model Tests', () {
    test('Robustly parses personality sliders from strings', () {
      final json = {
        'id': '123',
        'name': 'TestHero',
        'age': 8,
        'role': 'Hero',
        'personality_sliders': {
          'bravery': '85',  // String input
          'kindness': 90,   // Int input
          'curiosity': 'invalid' // Invalid input
        }
      };

      final character = Character.fromJson(json);

      expect(character.personalitySliders, isNotNull);
      expect(character.personalitySliders!['bravery'], 85);
      expect(character.personalitySliders!['kindness'], 90);
      expect(character.personalitySliders!.containsKey('curiosity'), isFalse);
    });

    test('Robustly parses pets list', () {
      final json = {
        'id': '123',
        'name': 'TestHero',
        'age': 8,
        'role': 'Hero',
        'pets': [
          {'name': 'Sparky', 'species': 'Dragon'}, // Valid
          null, // Invalid null
          'invalid_string', // Invalid type
          {'name': 'Fluffy'} // Valid partial
        ]
      };

      final character = Character.fromJson(json);

      expect(character.pets, isNotNull);
      expect(character.pets!.length, 2);
      expect(character.pets![0]['name'], 'Sparky');
      expect(character.pets![1]['name'], 'Fluffy');
    });

    test('Parses generated avatar correctly', () {
      final json = {
        'id': '123',
        'name': 'TestHero',
        'age': 8,
        'role': 'Hero',
        'generated_avatar': {
          'id': 'avatar_1',
          'image_base64': 'data:image/png;base64,abcdef',
          'seed': '12345',
          'style': 'cartoon',
          'attributes': {'hair': 'blue'},
          'generated_at': DateTime.now().toIso8601String()
        }
      };

      final character = Character.fromJson(json);

      expect(character.generatedAvatar, isNotNull);
      expect(character.generatedAvatar!.imageBase64, 'data:image/png;base64,abcdef');
      expect(character.generatedAvatar!.style, 'cartoon');
      expect(character.generatedAvatar!.seed, '12345');
    });

    test('Parses generated avatar when stored as JSON string', () {
      final avatarJson = {
        'id': 'avatar_2',
        'image_base64': 'data:image/png;base64,xyz',
        'seed': 'seed_2',
        'style': 'watercolor',
        'attributes': {'hair': 'green'},
        'generated_at': DateTime.now().toIso8601String(),
      };

      final json = {
        'id': '123',
        'name': 'TestHero',
        'age': 8,
        'role': 'Hero',
        // Older rows may persist avatar_data/generated_avatar as a serialized JSON string.
        'avatar_data': jsonEncode(avatarJson),
      };

      final character = Character.fromJson(json);

      expect(character.generatedAvatar, isNotNull);
      expect(character.generatedAvatar!.id, 'avatar_2');
      expect(character.generatedAvatar!.style, 'watercolor');
      expect(character.generatedAvatar!.seed, 'seed_2');
      expect(character.generatedAvatar!.imageBase64, 'data:image/png;base64,xyz');
    });
  });

  group('InteractiveStoryData Model Tests', () {
    test('Parses complete interactive story structure', () {
      final json = {
        'id': 'story_1',
        'title': 'Adventure 1',
        'theme': 'Magic',
        'age': 10,
        'current_segment_number': 2,
        'inventory': [
          {'id': 'item_1', 'name': 'Key', 'acquired_at_segment': 1}
        ],
        'state': {
          'current_location': 'Castle',
          'current_goal': 'Find the dragon',
          'key_clues': ['Clue 1']
        }
      };

      final story = InteractiveStoryData.fromJson(json);

      expect(story.id, 'story_1');
      expect(story.age, 10);
      expect(story.inventory.length, 1);
      expect(story.inventory.first.name, 'Key');
      expect(story.state.currentLocation, 'Castle');
      expect(story.state.keyClues, contains('Clue 1'));
      expect(story.segments, isEmpty);
    });

    test('Parses segments in path order (MT-382a)', () {
      // Server orders by segment_number already, but the parse must not
      // depend on it — deliver them shuffled.
      final json = {
        'id': 'story_1',
        'title': 'Adventure 1',
        'theme': 'Magic',
        'segments': [
          {
            'id': 'seg_2',
            'segment_number': 2,
            'content': 'Second part.',
            'choices': [],
          },
          {
            'id': 'seg_1',
            'segment_number': 1,
            'content': 'First part.',
            'choices': [],
          },
        ],
      };

      final story = InteractiveStoryData.fromJson(json);

      expect(story.segments.length, 2);
      expect(
        story.segments.map((s) => s.content).toList(),
        ['First part.', 'Second part.'],
      );
    });
  });
}
