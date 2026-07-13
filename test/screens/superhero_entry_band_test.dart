import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/screens/wizard_steps/superhero_entry_screen.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';

void main() {
  // Adult (18+) has no dedicated superhero screen set; it rides the Creator
  // (13-14) visuals, roster, and welcome-back copy — mirroring the backend,
  // which routes 18+ to the Creator "Hero Saga" prompt tier. Every other
  // band maps to itself (Sprout included: it has superhero screens, just no
  // saga).
  group('SuperheroEntryScreen.visualBand', () {
    test('adult aliases to creator', () {
      expect(
        SuperheroEntryScreen.visualBand(AgeBand.adult),
        AgeBand.creator,
      );
    });

    test('every non-adult band maps to itself', () {
      for (final band in AgeBand.values) {
        if (band == AgeBand.adult) continue;
        expect(SuperheroEntryScreen.visualBand(band), band);
      }
    });

    test('the aliased adult band participates in the saga read path', () {
      // The welcome-back recap gate reads visualBand(...).usesHeroSaga; the
      // magic-review write gate reads the RAW band's usesHeroSaga. Both must
      // be true for adults or the read/write sides would drift (MT-286).
      expect(
        SuperheroEntryScreen.visualBand(AgeBand.adult).usesHeroSaga,
        isTrue,
      );
      expect(AgeBand.adult.usesHeroSaga, isTrue);
    });
  });
}
