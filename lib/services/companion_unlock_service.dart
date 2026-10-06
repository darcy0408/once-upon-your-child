import 'progression_service.dart';
import '../theme/age_band_theme.dart';

/// Magic companions arrive one at a time, one per story CREATED.
///
/// Each age band has four built-in companions. The first is there from the
/// start; the second arrives after the first story, the third after the
/// second, the fourth after the third.
///
/// Unlocks are earned by stories played, never by payment.
///
/// What is NOT gated here: pets, saved friends and "bring your own"
/// companions are always available. Only the four built-in magic companions
/// of a band go through this service.
class CompanionUnlockService {
  CompanionUnlockService._();

  /// `thresholds[i]` is the number of stories a child must have created
  /// before the companion at index `i` (in band order) is available.
  /// Tune here; everything else derives from it.
  static const List<int> thresholds = [0, 1, 2, 3];

  /// Companion ids per band, in unlock order. These mirror the `id` fields of
  /// the constants in lib/widgets/hero_creator/companion_widgets.dart (kept
  /// as plain strings so this file stays free of Flutter widget imports; a
  /// test asserts the two stay in sync).
  static const Map<AgeBand, List<String>> companionIdsByBand = {
    AgeBand.sprout: [
      'sprout/pebble',
      'sprout/robin',
      'sprout/mochi',
      'sprout/sunny',
    ],
    AgeBand.explorer: ['ember', 'robin', 'clover', 'biscuit'],
    AgeBand.adventurer: ['atlas', 'kodiak', 'nyx', 'robin'],
    AgeBand.creator: ['cipher', 'rockin_robin', 'vesper', 'lore'],
    AgeBand.adolescent: ['zephyr', 'rockin_robin', 'shade', 'frost'],
    AgeBand.adult: ['tide', 'rockin_robin', 'onyx', 'cinder'],
  };

  /// Ids (in unlock order) available to [band] after [storiesCreated] stories.
  static List<String> unlockedCompanionIds(AgeBand band, int storiesCreated) {
    final ids = companionIdsByBand[band] ?? const <String>[];
    return [
      for (var i = 0; i < ids.length; i++)
        if (storiesCreated >= thresholds[i]) ids[i],
    ];
  }

  /// Whether [companionId] is available. Ids that are not one of the band's
  /// built-in companions (pets, friends, bring-your-own) are never gated, so
  /// this returns true for them.
  static bool isUnlocked(AgeBand band, String companionId, int storiesCreated) {
    final ids = companionIdsByBand[band] ?? const <String>[];
    final index = ids.indexOf(companionId);
    if (index < 0) return true;
    return storiesCreated >= thresholds[index];
  }

  /// The companion that became available when the count went from
  /// [previousCount] to [newCount], or null if none did.
  /// If several thresholds were crossed at once, returns the latest.
  static String? newlyUnlockedCompanionId(
    AgeBand band,
    int previousCount,
    int newCount,
  ) {
    final ids = companionIdsByBand[band] ?? const <String>[];
    String? result;
    for (var i = 0; i < ids.length; i++) {
      if (previousCount < thresholds[i] && newCount >= thresholds[i]) {
        result = ids[i];
      }
    }
    return result;
  }

  /// The live stories-created count: [ProgressionService]'s `storiesCreated`,
  /// the counter `_trackStoryCreation` actually increments.
  static Future<int> currentStoriesCreated({
    ProgressionService? progression,
  }) async {
    final progress = await (progression ?? ProgressionService())
        .getUserProgress();
    return progress.storiesCreated;
  }

  /// Convenience: ids available to [band] right now.
  static Future<List<String>> currentUnlockedCompanionIds(
    AgeBand band, {
    ProgressionService? progression,
  }) async {
    return unlockedCompanionIds(
      band,
      await currentStoriesCreated(progression: progression),
    );
  }
}
