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
  ///
  /// Was `.jpg`, which resolved for exactly two files: the sprout
  /// `animal_whisperer` and `brave_hero`. Every other archetype in every band
  /// ships `.webp`, so the non-gendered path missed them all. Those two were
  /// converted to `.webp` so the whole tree is one format.
  static String archetypePath(AgeBand band, String archetypeId) =>
      'assets/images/archetypes/${_folder(band)}/$archetypeId.webp';

  /// Gender-selection card image for the wizard and the avatar builder.
  ///
  /// [gender] accepts any casing of 'boy'/'girl'; anything else reads as girl,
  /// matching the previous inline behaviour at every call site.
  ///
  /// This mapping used to be copy-pasted in four places (the avatar screen, two
  /// switches in the hero-creator step, and the responsive-overflow test) which
  /// had drifted to three different opinions about file extensions. The avatar
  /// screen asked for `gender_adventurer_*.webp` when only `.jpg` existed, so
  /// 9-to-12s got blank gender cards. The `.jpg` files are now converted and
  /// every band is `.webp`.
  static String genderPath(AgeBand band, String gender) {
    final g = gender.toLowerCase() == 'boy' ? 'boy' : 'girl';
    return 'assets/images/ui/gender/gender_${_folder(band)}_$g.webp';
  }

  /// Scenario/scene card illustration — e.g. 'enchanted_forest', 'orbital_station'.
  static String scenePath(AgeBand band, String sceneId) =>
      'assets/images/scenes/${_folder(band)}/$sceneId.webp';

  /// Companion creature image — pass the full filename including extension,
  /// e.g. 'pebble.png' or 'mochi.jpg'.
  static String companionPath(AgeBand band, String filename) =>
      'assets/images/companions/${_folder(band)}/$filename';

  /// Feeling face image. Core 8: angry, calm, confused, excited, happy, sad, scared, surprised.
  static String feelingPath(AgeBand band, String feelingName) =>
      'assets/images/feelings/${_folder(band)}/'
      '${normalizeFeelingId(feelingName)}.webp';

  /// Feeling ids in `feelings_wheel_data.dart` are hyphenated — 'hurt-mad',
  /// 'grossed-out', 'let-down' — while every shipped face file uses
  /// underscores. Interpolating the raw id missed the band artwork *and* the
  /// flat fallback library, so the picker silently dropped to a plain emoji and
  /// the commissioned faces for those feelings never appeared on any band.
  ///
  /// Callers building the flat `assets/feelings_faces/` path must normalize
  /// too — that library is underscore-named as well.
  static String normalizeFeelingId(String feelingName) =>
      feelingName.replaceAll('-', '_');
}
