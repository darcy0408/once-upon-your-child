import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/utils/distress_detector.dart';

void main() {
  group('containsDistressSignal — true positives (ideation / self-harm)', () {
    const distressing = <String>[
      'I want to die',
      'i wanna die',
      'sometimes i wish i was dead',
      'I wish I were dead',
      'i wish i was never born',
      'i wish i wasnt born',
      'everyone is better off without me',
      'they would be better off dead i think',
      'theres no reason to live anymore',
      'i have nothing to live for',
      'i dont want to live',
      'i dont want to be alive',
      "i don't want to be here anymore",
      'i dont want to wake up tomorrow',
      'i do not want to be here',
      'i want to end my life',
      'i just want to end it all',
      'i want to take my own life',
      'im going to kill myself',
      'i keep thinking about killing myself',
      'i want to kill my self',
      'i might commit suicide',
      'i feel suicidal',
      'i want to hurt myself',
      'im hurting myself',
      'i want to harm myself',
      'i keep cutting myself',
      'i cut myself last night',
      'thoughts of self harm',
    ];

    for (final text in distressing) {
      test('flags: "$text"', () {
        expect(containsDistressSignal(text), isTrue);
      });
    }
  });

  group('containsDistressSignal — false positives (story / game violence)', () {
    const benign = <String>[
      'kill the dragon',
      'I want to defeat the villain',
      'the monster died',
      'the bad guy died at the end',
      'we have to kill the evil wizard',
      'my hero killed the giant spider',
      'a story about death and rebirth of a phoenix',
      'the dragon is dead now',
      'Suicide Squad team up adventure', // popular franchise, not distress
      'I hate myself for losing the game', // venting, not actionable
      'im dying to see the unicorn', // idiom
      'ride a magic carpet and trick a witch',
      'a candy house in the clouds',
      'kill me, this homework is so boring', // hyperbole
      'going to the moon with my dog',
    ];

    for (final text in benign) {
      test('ignores: "$text"', () {
        expect(containsDistressSignal(text), isFalse);
      });
    }
  });

  group('containsDistressSignal — normalisation', () {
    test('is case-insensitive', () {
      expect(containsDistressSignal('I WANT TO DIE'), isTrue);
    });

    test('collapses extra whitespace', () {
      expect(containsDistressSignal('i want   to    kill   myself'), isTrue);
    });

    test('matches across apostrophes and punctuation', () {
      expect(containsDistressSignal("I don't want to be here..."), isTrue);
    });

    test('matches phrase embedded mid-sentence', () {
      expect(
        containsDistressSignal('honestly i just want to disappear and die'),
        isTrue,
      );
    });
  });

  group('containsDistressSignal — empty / whitespace', () {
    test('empty string is false', () {
      expect(containsDistressSignal(''), isFalse);
    });

    test('whitespace-only is false', () {
      expect(containsDistressSignal('   \n\t  '), isFalse);
    });
  });
}
