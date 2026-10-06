import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/widgets/archetype_card.dart';

void main() {
  group('ArchetypeData.displayNameForStored', () {
    const stored = 'The Quiz Whiz'; // what the wizard always stores

    test('13-14 sees the mature name', () {
      expect(ArchetypeData.displayNameForStored(stored, 13), 'Logic Architect');
    });

    test('6-8 sees the explorer name', () {
      expect(
          ArchetypeData.displayNameForStored(stored, 7), 'The Brave Explorer');
    });

    test('9-12 keeps the stored name', () {
      expect(ArchetypeData.displayNameForStored(stored, 10), stored);
    });

    test('any of the archetype names resolves', () {
      expect(ArchetypeData.displayNameForStored('Logic Architect', 7),
          'The Brave Explorer');
    });

    test('unknown strings pass through unchanged', () {
      expect(ArchetypeData.displayNameForStored('storm_rider', 13),
          'storm_rider');
    });
  });
}
