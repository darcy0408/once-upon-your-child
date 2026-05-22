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

  /// Full-screen background image.
  /// [variant] is one of: 'splash_bg', 'story_page_bg', 'feelings_bg'.
  static String backgroundPath(AgeBand band, {String variant = 'splash_bg'}) =>
      'assets/images/backgrounds/${_folder(band)}/$variant.jpg';

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

  /// Progress orb: pass [done]=true for the completed-step variant.
  static String orbPath(AgeBand band, {bool done = false}) {
    final state = done ? 'progress_done' : 'progress_active';
    return 'assets/images/orbs/${_folder(band)}/$state.webp';
  }

  /// UI element — buttons, character silhouettes, frames.
  /// e.g. 'continue_button.png', 'make_magic_normal.png', 'name_input_frame.png'
  static String uiPath(AgeBand band, String assetName) =>
      'assets/images/ui/${_folder(band)}/$assetName';
}
