// Regression tests for the CharacterEditorScreen dropdown crashes (MT-383d).
//
// Both dropdowns took their value straight from the character being edited
// while offering a fixed list of items that predated the modern wizard and the
// adult age band. DropdownButton asserts that a non-null value matches exactly
// one item, so opening the editor on a wizard-made character (archetype role)
// or an 18+ character threw instead of rendering.
//
// These pin the invariant the widget depends on: whatever the character holds
// is always present in the item list exactly once.

import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/screens/character_editor_screen.dart';

void main() {
  group('roleOptionsFor', () {
    test('returns the legacy roles unchanged for a legacy role', () {
      expect(roleOptionsFor('Helper'), [
        'Adventurer',
        'Thinker',
        'Artist',
        'Helper',
        'Athlete',
        'Shy Friend',
      ]);
    });

    test('includes an archetype role so the dropdown can render it', () {
      final options = roleOptionsFor('Storm Rider');
      expect(options.first, 'Storm Rider');
      expect(options, contains('Adventurer'));
    });

    test('never duplicates the current value', () {
      for (final role in ['Helper', 'Storm Rider', 'Animal Whisperer', '']) {
        final options = roleOptionsFor(role);
        if (role.isNotEmpty) {
          expect(options.where((o) => o == role).length, 1,
              reason: 'ambiguous items assert in DropdownButton for "$role"');
        }
      }
    });

    test('falls back to the legacy list for an empty role', () {
      // The widget passes null as the value in this case, so the list only has
      // to be non-empty and free of a stray '' entry.
      expect(roleOptionsFor(''), isNot(contains('')));
      expect(roleOptionsFor(''), hasLength(6));
    });
  });

  group('ageOptionsFor', () {
    test('offers 3 through 17 for a child', () {
      final options = ageOptionsFor(9);
      expect(options.first, 3);
      expect(options.last, 17);
      expect(options, hasLength(15));
    });

    test('includes an adult age rather than dropping it', () {
      final options = ageOptionsFor(34);
      expect(options, contains(34));
      expect(options.where((o) => o == 34).length, 1);
    });

    test('keeps the list sorted when an out-of-range age is added', () {
      final options = ageOptionsFor(34);
      final sorted = [...options]..sort();
      expect(options, sorted);
    });

    test('every plausible character age resolves to exactly one item', () {
      for (final age in [3, 5, 12, 17, 18, 21, 40, 99]) {
        expect(ageOptionsFor(age).where((o) => o == age).length, 1,
            reason: 'age $age must appear exactly once');
      }
    });
  });
}
