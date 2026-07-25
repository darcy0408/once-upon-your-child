import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/screens/bedtime_wizard_screen.dart';

/// MT-361(e): the visual wizard now hands its answers to bedtime mode instead
/// of making the user re-say all of them. `bedtimeStepAfterSkipping` decides
/// where a skipped question lands, and it MUST mirror the `_advance(...)`
/// target of the corresponding spoken case in `_runStep` — if the two drift,
/// a seeded hand-off silently walks a different route than a voice run
/// (skipping a question that never gets asked, or stranding the user on a
/// step whose answer we already had).
///
/// Each expectation below is paired with the spoken case it mirrors.
void main() {
  group('bedtimeStepAfterSkipping — mirrors the spoken routing', () {
    test('heroName always goes to companion', () {
      // Spoken: case heroName -> _advance(BedtimeStep.companion)
      expect(
        bedtimeStepAfterSkipping(BedtimeStep.heroName,
            isSprout: false, continueSaga: false),
        BedtimeStep.companion,
      );
      expect(
        bedtimeStepAfterSkipping(BedtimeStep.heroName,
            isSprout: true, continueSaga: false),
        BedtimeStep.companion,
      );
    });

    test('companion skips listeners for Sprout only', () {
      // Spoken: case companion -> _isSprout ? setting : listeners
      expect(
        bedtimeStepAfterSkipping(BedtimeStep.companion,
            isSprout: true, continueSaga: false),
        BedtimeStep.setting,
      );
      expect(
        bedtimeStepAfterSkipping(BedtimeStep.companion,
            isSprout: false, continueSaga: false),
        BedtimeStep.listeners,
      );
    });

    test('setting goes straight to generating for Sprout', () {
      // Spoken: case setting -> _advance(_isSprout ? generating : feeling)
      expect(
        bedtimeStepAfterSkipping(BedtimeStep.setting,
            isSprout: true, continueSaga: false),
        BedtimeStep.generating,
      );
      expect(
        bedtimeStepAfterSkipping(BedtimeStep.setting,
            isSprout: false, continueSaga: false),
        BedtimeStep.feeling,
      );
    });

    test('feeling always goes to duration', () {
      // Spoken: case feeling -> _advance(BedtimeStep.duration)
      expect(
        bedtimeStepAfterSkipping(BedtimeStep.feeling,
            isSprout: false, continueSaga: false),
        BedtimeStep.duration,
      );
    });

    test('duration skips the confirm recap when continuing a saga', () {
      // Spoken: case duration -> _advance(_continueSaga ? generating : confirm)
      expect(
        bedtimeStepAfterSkipping(BedtimeStep.duration,
            isSprout: false, continueSaga: true),
        BedtimeStep.generating,
      );
      expect(
        bedtimeStepAfterSkipping(BedtimeStep.duration,
            isSprout: false, continueSaga: false),
        BedtimeStep.confirm,
      );
    });

    test('non-question steps are never skipped past', () {
      // greeting/confirm/generating/reading/done have no seeded answer, so the
      // function is identity for them — this is what stops _advance's skip
      // loop from spinning or walking past the story itself.
      for (final step in [
        BedtimeStep.greeting,
        BedtimeStep.age,
        BedtimeStep.sagaOffer,
        BedtimeStep.listeners,
        BedtimeStep.confirm,
        BedtimeStep.generating,
        BedtimeStep.reading,
        BedtimeStep.done,
      ]) {
        expect(
          bedtimeStepAfterSkipping(step,
              isSprout: false, continueSaga: false),
          step,
          reason: '$step must be identity so the skip loop terminates',
        );
      }
    });
  });

  group('a fully-seeded hand-off walks to the right landing step', () {
    /// Mirrors `_advance`'s skip loop for the case where every question is
    /// seeded, which is exactly what the MagicReview hand-off produces.
    BedtimeStep walkFrom(
      BedtimeStep start, {
      required bool isSprout,
      required bool continueSaga,
      required Set<BedtimeStep> answered,
    }) {
      var target = start;
      while (answered.contains(target)) {
        final after = bedtimeStepAfterSkipping(target,
            isSprout: isSprout, continueSaga: continueSaga);
        if (after == target) break;
        target = after;
      }
      return target;
    }

    const allSeeded = {
      BedtimeStep.heroName,
      BedtimeStep.companion,
      BedtimeStep.setting,
      BedtimeStep.feeling,
      BedtimeStep.duration,
    };

    test('non-Sprout is asked exactly one question: listeners', () {
      // "Are any brothers, sisters, or friends listening tonight?" has no
      // equivalent in the visual wizard, so there is nothing to seed it from
      // and it is deliberately still asked. A fully-seeded non-Sprout
      // hand-off therefore answers ONE question instead of five, rather than
      // going straight to the recap.
      expect(
        walkFrom(BedtimeStep.heroName,
            isSprout: false, continueSaga: false, answered: allSeeded),
        BedtimeStep.listeners,
      );
    });

    test('after listeners is answered the rest stays skipped', () {
      // Resuming the walk past listeners (the spoken case routes it to
      // setting) must still skip the remaining seeded questions and land on
      // the confirm recap.
      expect(
        walkFrom(BedtimeStep.setting,
            isSprout: false, continueSaga: false, answered: allSeeded),
        BedtimeStep.confirm,
      );
    });

    test('Sprout goes straight to generating', () {
      // Sprout skips listeners AND feeling/duration, so a seeded Sprout
      // hand-off should reach generating with no questions asked at all.
      expect(
        walkFrom(BedtimeStep.heroName,
            isSprout: true, continueSaga: false, answered: allSeeded),
        BedtimeStep.generating,
      );
    });

    test('saga continuation skips confirm', () {
      // Walk from setting (i.e. past the one unseedable listeners question)
      // so this exercises the continueSaga branch rather than halting early.
      expect(
        walkFrom(BedtimeStep.setting,
            isSprout: false, continueSaga: true, answered: allSeeded),
        BedtimeStep.generating,
      );
    });

    test('a partial hand-off stops at the first unseeded question', () {
      expect(
        walkFrom(BedtimeStep.heroName,
            isSprout: false,
            continueSaga: false,
            answered: const {BedtimeStep.heroName}),
        BedtimeStep.companion,
      );
    });
  });
}
