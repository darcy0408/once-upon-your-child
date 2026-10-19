import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/services/companion_unlock_service.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/widgets/companion_arrival_card.dart';

void main() {
  test('service ids match the companion constants, in order', () {
    for (final band in AgeBand.values) {
      expect(
        CompanionUnlockService.companionIdsByBand[band],
        companionsForBand(band).map((c) => c.id).toList(),
        reason: '$band',
      );
    }
  });

  group('unlockedCompanionIds', () {
    for (final band in AgeBand.values) {
      test('$band unlocks one per story created', () {
        final ids = CompanionUnlockService.companionIdsByBand[band]!;
        expect(
          CompanionUnlockService.unlockedCompanionIds(band, 0),
          ids.sublist(0, 1),
        );
        expect(
          CompanionUnlockService.unlockedCompanionIds(band, 1),
          ids.sublist(0, 2),
        );
        expect(
          CompanionUnlockService.unlockedCompanionIds(band, 2),
          ids.sublist(0, 3),
        );
        expect(CompanionUnlockService.unlockedCompanionIds(band, 3), ids);
        expect(CompanionUnlockService.unlockedCompanionIds(band, 50), ids);
      });
    }
  });

  group('newlyUnlockedCompanionId', () {
    for (final band in AgeBand.values) {
      test('$band returns the arriving companion at each crossing', () {
        final ids = CompanionUnlockService.companionIdsByBand[band]!;
        expect(
          CompanionUnlockService.newlyUnlockedCompanionId(band, 0, 1),
          ids[1],
        );
        expect(
          CompanionUnlockService.newlyUnlockedCompanionId(band, 1, 2),
          ids[2],
        );
        expect(
          CompanionUnlockService.newlyUnlockedCompanionId(band, 2, 3),
          ids[3],
        );
      });

      test('$band has no false positives', () {
        expect(
          CompanionUnlockService.newlyUnlockedCompanionId(band, 3, 4),
          isNull,
        );
        expect(
          CompanionUnlockService.newlyUnlockedCompanionId(band, 9, 10),
          isNull,
        );
        expect(
          CompanionUnlockService.newlyUnlockedCompanionId(band, 1, 1),
          isNull,
        );
        expect(
          CompanionUnlockService.newlyUnlockedCompanionId(band, 0, 0),
          isNull,
        );
        // Going backwards never "unlocks".
        expect(
          CompanionUnlockService.newlyUnlockedCompanionId(band, 3, 2),
          isNull,
        );
      });
    }
  });

  test('isUnlocked gates built-ins but never pets/friends/own companions', () {
    const band = AgeBand.explorer;
    expect(CompanionUnlockService.isUnlocked(band, 'ember', 0), isTrue);
    expect(CompanionUnlockService.isUnlocked(band, 'robin', 0), isFalse);
    expect(CompanionUnlockService.isUnlocked(band, 'robin', 1), isTrue);
    expect(CompanionUnlockService.isUnlocked(band, 'biscuit', 2), isFalse);
    expect(CompanionUnlockService.isUnlocked(band, 'biscuit', 3), isTrue);
    expect(CompanionUnlockService.isUnlocked(band, 'my_dog_rex', 0), isTrue);
  });
}
