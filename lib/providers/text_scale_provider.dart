import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'text_scale_provider.g.dart';

/// Key used to persist the user's chosen app-wide text scale.
const kTextScaleKey = 'app_text_scale';

/// Default text scale (no adjustment).
const kDefaultTextScale = 1.0;

/// Smallest allowed text scale.
const kMinTextScale = 0.85;

/// Largest allowed text scale.
const kMaxTextScale = 1.6;

/// Riverpod notifier that manages the user's app-wide text size preference.
///
/// This is separate from the OS/browser font-size setting — Flutter web does
/// not read that — and separate from the per-band theme. It lets a parent
/// bump body text up for readability regardless of age band.
@riverpod
class TextScaleNotifier extends _$TextScaleNotifier {
  @override
  double build() {
    _loadFromPrefs();
    return kDefaultTextScale;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(kTextScaleKey);
    if (stored != null) {
      state = stored.clamp(kMinTextScale, kMaxTextScale);
    }
  }

  /// Sets and persists a new text scale, clamped to the allowed range.
  Future<void> setScale(double scale) async {
    final clamped = scale.clamp(kMinTextScale, kMaxTextScale);
    state = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(kTextScaleKey, clamped);
  }
}
