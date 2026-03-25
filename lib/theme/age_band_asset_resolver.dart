// lib/theme/age_band_asset_resolver.dart
//
// Single source of truth for resolving paths inside age_band_assets/.
// All image consumers should call these methods rather than constructing
// paths manually, so the band-folder name mapping lives in one place.

import 'age_band_theme.dart';

class AgeBandAssetResolver {
  // Maps AgeBand enum → age_band_assets/ folder name.
  // Explorer maps to 'early_readers' — the asset generation used that name.
  static const Map<AgeBand, String> _bandFolder = {
    AgeBand.sprout:     'sprouts',
    AgeBand.explorer:   'early_readers',
    AgeBand.adventurer: 'adventurers',
    AgeBand.creator:    'creators',
    AgeBand.adolescent: 'adolescents',
    AgeBand.adult:      'adults',
  };

  static String _folder(AgeBand band) => _bandFolder[band]!;

  /// Archetype character image — e.g. 'brave_hero', 'storm_rider'.
  /// Returns a .jpg path in age_band_assets/{band}/archetypes/.
  static String archetypePath(AgeBand band, String archetypeId) =>
      'age_band_assets/${_folder(band)}/archetypes/$archetypeId.jpg';

  /// Full-screen background image.
  /// [variant] is one of: 'splash_bg', 'story_page_bg', 'feelings_bg'.
  static String backgroundPath(AgeBand band, {String variant = 'splash_bg'}) =>
      'age_band_assets/${_folder(band)}/backgrounds/$variant.jpg';

  /// Scenario/scene card illustration — e.g. 'enchanted_forest', 'orbital_station'.
  static String scenePath(AgeBand band, String sceneId) =>
      'age_band_assets/${_folder(band)}/scenes/$sceneId.jpg';

  /// Companion creature image — e.g. 'fluffy_dragon', 'ember_dragon'.
  static String companionPath(AgeBand band, String companionId) =>
      'age_band_assets/${_folder(band)}/companions/$companionId.png';

  /// Feeling face image. Core 8: angry, calm, confused, excited, happy, sad, scared, surprised.
  static String feelingPath(AgeBand band, String feelingName) =>
      'age_band_assets/${_folder(band)}/feelings/$feelingName.png';

  /// Progress orb: pass [done]=true for the completed-step variant.
  static String orbPath(AgeBand band, {bool done = false}) {
    final state = done ? 'progress_done' : 'progress_active';
    return 'age_band_assets/${_folder(band)}/orbs/$state.png';
  }

  /// UI element — buttons, character silhouettes, frames.
  /// e.g. 'continue_button.png', 'make_magic_normal.png', 'name_input_frame.png'
  static String uiPath(AgeBand band, String assetName) =>
      'age_band_assets/${_folder(band)}/ui/$assetName';
}
