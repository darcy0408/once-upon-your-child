import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/age_band_theme.dart';

part 'age_band_provider.g.dart';

/// Key used to persist the user's age in SharedPreferences.
const _kUserAgeKey = 'user_age';

/// Key used to persist a parent's manual band override (optional).
const _kBandOverrideKey = 'age_band_override';

/// Key used to persist the palette flavor (from the hero's gender pick).
const _kPaletteFlavorKey = 'palette_flavor';

/// Riverpod notifier that manages the current age band.
///
/// On startup it reads the user's age (set at the age gate) from
/// SharedPreferences and resolves the appropriate [AgeBand].
/// Parents can override the band to move a child up or down.
@riverpod
class AgeBandNotifier extends _$AgeBandNotifier {
  @override
  AgeBandThemeData build() {
    // Start with explorer (the current look) as the default until prefs load.
    _loadFromPrefs();
    return explorerTheme;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Restore the palette flavor BEFORE resolving any theme so the first
    // resolved state already carries the boy/girl hues.
    final flavorName = prefs.getString(_kPaletteFlavorKey);
    if (flavorName != null) {
      currentPaletteFlavor = PaletteFlavor.values.firstWhere(
        (f) => f.name == flavorName,
        orElse: () => PaletteFlavor.neutral,
      );
    }

    // Check for a manual band override first.
    final overrideName = prefs.getString(_kBandOverrideKey);
    if (overrideName != null) {
      final band = AgeBand.values.where((b) => b.name == overrideName);
      if (band.isNotEmpty) {
        state = themeForBand(band.first);
        return;
      }
    }

    // Otherwise derive from persisted age.
    final age = prefs.getInt(_kUserAgeKey);
    if (age != null) {
      state = themeForAge(age);
    }
    // If no age is stored yet, keep explorer default.
  }

  /// Called when the user sets their age (e.g. at the age gate).
  Future<void> setAge(int age) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kUserAgeKey, age);
    // Clear any manual override when age is explicitly set.
    await prefs.remove(_kBandOverrideKey);
    state = themeForAge(age);
  }

  /// Allows a parent to override the visual band directly
  /// (e.g. a mature 7-year-old using the adventurer band).
  Future<void> overrideBand(AgeBand band) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBandOverrideKey, band.name);
    state = themeForBand(band);
  }

  /// Clears the manual override and reverts to age-derived band.
  Future<void> clearOverride() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBandOverrideKey);
    final age = prefs.getInt(_kUserAgeKey);
    state = age != null ? themeForAge(age) : explorerTheme;
  }

  /// Sets the palette flavor (from the hero's Boy/Girl pick) and re-resolves
  /// the current band's theme so the whole app re-colors immediately.
  ///
  /// The global [currentPaletteFlavor] is updated too, because many widgets
  /// resolve palettes via the static themeForBand/themeForAge helpers.
  Future<void> setFlavor(PaletteFlavor flavor) async {
    if (flavor == currentPaletteFlavor) return;
    currentPaletteFlavor = flavor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPaletteFlavorKey, flavor.name);
    state = themeForBand(state.band, flavor: flavor);
  }

  /// The current band enum for quick checks (e.g. `if (band == AgeBand.sprout)`).
  AgeBand get band => state.band;
}
