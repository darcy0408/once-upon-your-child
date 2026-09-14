import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/utils/choice_question.dart';

void main() {
  group('choiceQuestion', () {
    test('two choices become one question that ends with the open door', () {
      expect(
        choiceQuestion([
          'Follow the string of light between the boats.',
          'Climb the quay to inspect the stacked crates',
        ]),
        'Would you like to follow the string of light between the boats, '
        'or climb the quay to inspect the stacked crates, or something else?',
      );
    });

    test('three choices keep every option and still end on something else',
        () {
      expect(
        choiceQuestion(['Go left', 'Go right', 'Wait by the fire!']),
        'Would you like to go left, or go right, or wait by the fire, '
        'or something else?',
      );
    });

    test('leading capital and trailing punctuation are normalised', () {
      expect(
        choiceQuestion(['  Tend the stove...  ']),
        'Would you like to tend the stove, or something else?',
      );
    });

    test('no usable choices falls back to a plain question', () {
      expect(choiceQuestion([]), 'What would you like to do?');
      expect(choiceQuestion(['', '  ', '.']), 'What would you like to do?');
    });
  });
}
