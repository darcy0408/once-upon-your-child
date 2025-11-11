import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/services/story_complexity_service.dart';

void main() {
  group('StoryComplexityService.getAgeGuidelines', () {
    test('returns early-childhood rules for ages 3-5', () {
      final rules = StoryComplexityService.getAgeGuidelines(4);
      expect(rules['length_guideline'], '100-150 words');
      expect(rules['vocabulary_level'], contains('simple'));
      expect(rules['word_count_max'], 150);
    });

    test('returns teen rules for ages 13-15', () {
      final rules = StoryComplexityService.getAgeGuidelines(14);
      expect(rules['length_guideline'], '400-600 words');
      expect(rules['concepts'], contains('complex themes'));
      expect(rules['special_instructions'], contains('identity'));
      expect(rules['word_count_min'], greaterThan(300));
    });

    test('returns adult rules for ages 16+', () {
      final rules = StoryComplexityService.getAgeGuidelines(18);
      expect(rules['length_guideline'], '600-800 words');
      expect(rules['vocabulary_level'], contains('mature'));
    });
  });

  group('StoryComplexityService.buildAgeInstructions', () {
    test('includes critical guidance strings', () {
      final instructions = StoryComplexityService.buildAgeInstructions(7);
      expect(instructions, contains('LENGTH:'));
      expect(instructions, contains('VOCABULARY:'));
      expect(instructions, contains('SPECIAL NOTES:'));
    });
  });
}
