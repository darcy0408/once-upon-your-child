import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models/story_generation_result.dart';

void main() {
  group('StoryGenerationResult.practiced (MT-254)', () {
    test('parses the focus from the nested story object', () {
      final result = StoryGenerationResult.fromBackend({
        'story': {
          'story_text': 'Once upon a time…',
          'practiced': 'a limit is set',
        },
      });
      expect(result.practiced, 'a limit is set');
    });

    test('parses the focus from a top-level field', () {
      final result = StoryGenerationResult.fromBackend({
        'story_text': 'Once upon a time…',
        'practiced': 'a friendship bump happens',
      });
      expect(result.practiced, 'a friendship bump happens');
    });

    test('is null when the backend omits it (ordinary story)', () {
      final result = StoryGenerationResult.fromBackend({
        'story': {'story_text': 'Once upon a time…'},
      });
      expect(result.practiced, isNull);
    });

    test('treats blank/whitespace as null', () {
      final result = StoryGenerationResult.fromBackend({
        'story_text': 'Once upon a time…',
        'practiced': '   ',
      });
      expect(result.practiced, isNull);
    });
  });
}
