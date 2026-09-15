import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/screens/bedtime_wizard_screen.dart';

/// MT-433: "Change it" on the recipe read-back used to restart at the
/// companion question and walk every question again — five narrated
/// questions to change one answer. The read-back now asks which one thing to
/// change, re-asks that question, and comes straight back.
void main() {
  group('bedtimeStepToChange — which question the answer points at', () {
    test('the chip labels map to their questions', () {
      expect(bedtimeStepToChange('Buddy'), BedtimeStep.companion);
      expect(bedtimeStepToChange('Companion'), BedtimeStep.companion);
      expect(bedtimeStepToChange('Place'), BedtimeStep.setting);
      expect(bedtimeStepToChange('Kind of story'), BedtimeStep.feeling);
      expect(bedtimeStepToChange('Vibe'), BedtimeStep.feeling);
      expect(bedtimeStepToChange('Length'), BedtimeStep.duration);
      expect(bedtimeStepToChange("Who's listening"), BedtimeStep.listeners);
      expect(bedtimeStepToChange('Listeners'), BedtimeStep.listeners);
    });

    test('spoken answers map by keyword', () {
      expect(bedtimeStepToChange('the dragon, I want the owl'),
          BedtimeStep.companion);
      expect(bedtimeStepToChange('where it happens'), BedtimeStep.setting);
      expect(bedtimeStepToChange('make it a funny one'), BedtimeStep.feeling);
      expect(bedtimeStepToChange('make it shorter'), BedtimeStep.duration);
      expect(bedtimeStepToChange('twenty minutes'), BedtimeStep.duration);
      expect(bedtimeStepToChange('my brother is listening too'),
          BedtimeStep.listeners);
    });

    test('friendship is the story kind, friend is the companion', () {
      expect(bedtimeStepToChange('a friendship story'), BedtimeStep.feeling);
      expect(bedtimeStepToChange('a different friend'), BedtimeStep.companion);
    });

    test("who's listening beats who's coming", () {
      expect(bedtimeStepToChange("who's listening"), BedtimeStep.listeners);
      expect(
          bedtimeStepToChange("who's coming with me"), BedtimeStep.companion);
    });

    test('silence or nonsense gives null so the caller can fall back', () {
      expect(bedtimeStepToChange(''), isNull);
      expect(bedtimeStepToChange('   '), isNull);
      expect(bedtimeStepToChange('banana'), isNull);
    });
  });

  group('bedtimeStepAfterSingleChange — back to the read-back', () {
    test('every question returns to confirm instead of walking on', () {
      for (final next in [
        BedtimeStep.listeners,
        BedtimeStep.setting,
        BedtimeStep.feeling,
        BedtimeStep.duration,
        BedtimeStep.confirm,
      ]) {
        expect(bedtimeStepAfterSingleChange(next), BedtimeStep.confirm,
            reason: 'after a single change, $next must return to confirm');
      }
    });

    test('generating is left alone', () {
      expect(bedtimeStepAfterSingleChange(BedtimeStep.generating),
          BedtimeStep.generating);
    });
  });
}
