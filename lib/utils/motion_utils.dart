import 'package:flutter/material.dart';
import '../theme/age_band_theme.dart';

/// Checks whether animations should be reduced based on system accessibility
/// settings AND the current age band's sparkle/particle preferences.
class MotionPrefs {
  /// Returns true if the system requests reduced motion.
  static bool reduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Returns the effective sparkle intensity (0.0-1.0).
  /// Returns 0.0 if system requests reduced motion.
  static double sparkleIntensity(BuildContext context) {
    if (reduceMotion(context)) return 0.0;
    final band = Theme.of(context).extension<AgeBandThemeData>();
    return band?.sparkleIntensity ?? 1.0;
  }

  /// Returns true if particles should be shown.
  static bool showParticles(BuildContext context) {
    if (reduceMotion(context)) return false;
    final band = Theme.of(context).extension<AgeBandThemeData>();
    return band?.showParticles ?? true;
  }

  /// Returns a scaled animation duration.
  /// If reduced motion, returns Duration.zero (instant transitions).
  static Duration scaledDuration(BuildContext context, Duration base) {
    if (reduceMotion(context)) return Duration.zero;
    return base;
  }
}
