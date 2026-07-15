// lib/theme/age_band_asset_resolver.dart
//
// Single source of truth for resolving paths inside assets/images/.
// All image consumers should call these methods rather than constructing
// paths manually, so the band-folder name mapping lives in one place.

import 'age_band_theme.dart';

class AgeBandAssetResolver {
  // AgeBand.name matches the folder name exactly:
  // sprout, explorer, adventurer, creator, adolescent, adult.
  static String _folder(AgeBand band) => band.name;

  /// Archetype character image — e.g. 'brave_hero', 'storm_rider'.
  static String archetypePath(AgeBand band, String archetypeId) =>
      'assets/images/archetypes/${_folder(band)}/$archetypeId.jpg';

  /// Scenario/scene card illustration — e.g. 'enchanted_forest', 'orbital_station'.
  static String scenePath(AgeBand band, String sceneId) =>
      'assets/images/scenes/${_folder(band)}/$sceneId.jpg';

  /// Companion creature image — pass the full filename including extension,
  /// e.g. 'pebble.png' or 'mochi.jpg'.
  static String companionPath(AgeBand band, String filename) =>
      'assets/images/companions/${_folder(band)}/$filename';

  /// Feeling face image. Core 8: angry, calm, confused, excited, happy, sad, scared, surprised.
  static String feelingPath(AgeBand band, String feelingName) =>
      'assets/images/feelings/${_folder(band)}/$feelingName.webp';

}
