import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/utils/early_reader_phrasing.dart';

void main() {
  group('phrasifyForEarlyReader', () {
    test('keeps a limerick line-for-line (Limerick Mode regression)', () {
      const limerick = 'Max walked into a land\n'
          'so bright, with colors in hand,\n'
          '   where sunflowers bloom and sway,\n'
          '   and petals dance every day,\n'
          'with a rainbow to stand.';

      final out = phrasifyForEarlyReader(limerick);

      // Before the fix only the final line survived, because the sentence
      // scanner needed a terminal . ! or ? on every line.
      expect(out.split('\n'), hasLength(5));
      expect(out, startsWith('Max walked into a land'));
      expect(out, endsWith('with a rainbow to stand.'));
      expect(out, isNot(contains('   ')));
    });

    test('keeps a clause that has no terminal punctuation', () {
      const text = 'Max ran. He saw a dog Then he went home.';
      final out = phrasifyForEarlyReader(text);
      expect(out, contains('He saw a dog'));
    });

    test('splits a long prose sentence at commas', () {
      const text =
          'The cat walked slowly through the tall wet grass, looking for a warm dry spot, and found one.';
      final out = phrasifyForEarlyReader(text);
      expect(out.split('\n').length, greaterThan(1));
    });

    test('short prose is untouched', () {
      expect(phrasifyForEarlyReader('Max ran fast.'), 'Max ran fast.');
      expect(phrasifyForEarlyReader('   '), '   ');
    });
  });
}
