import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/utils/input_sanitizer.dart';

void main() {
  group('InputSanitizer.detectCrisis (audit #5)', () {
    const crisisTexts = [
      'I want to kill myself',
      'i want to die',
      "I'm thinking about suicide",
      'feeling suicidal',
      'I want to hurt myself',
      'self-harm',
      'self harm',
      'I keep cutting myself',
      "I don't want to live anymore",
      'I wish I was dead',
      'there is no reason to live',
      'I just want to end it all',
      'I want to end my life',
      'I might take my own life',
      "I'd be better off dead",
      // Youth euphemisms (red-team 2026-07-17 MEDIUM-2) — mirror the server.
      'I want to unalive myself',
      'kms',
      'kys',
      'sewerslide',
      'I want to off myself',
      'I dont want to wake up tomorrow',
      'I should just delete myself',
    ];

    const nonCrisisTexts = [
      '',
      'the villain wants to kill the dragon',
      'the hero kills the monster and saves the day',
      'I want to fly to the moon',
      'the knight will die in the final battle',
      'I cut the rope to free the prince',
      "let's explore the haunted castle",
      'I want to build a treehouse with my friend',
      // Euphemism near-misses stay unflagged.
      'the hero jumped off my roof and flew',
      'I turned off my flashlight in the cave',
      '5 kms from the castle',
    ];

    for (final text in crisisTexts) {
      test('detects: "$text"', () {
        expect(InputSanitizer.detectCrisis(text), isTrue);
      });
    }

    for (final text in nonCrisisTexts) {
      test('ignores: "$text"', () {
        expect(InputSanitizer.detectCrisis(text), isFalse);
      });
    }

    test('is case-insensitive', () {
      expect(InputSanitizer.detectCrisis('I WANT TO KILL MYSELF'), isTrue);
    });
  });
}
