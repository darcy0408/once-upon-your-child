import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/theme/app_theme.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(int v) {
    final s = v / 255.0;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel((c.r * 255).round()) +
      0.7152 * channel((c.g * 255).round()) +
      0.0722 * channel((c.b * 255).round());
}

/// Composites a possibly-translucent foreground over an opaque background,
/// which is what actually reaches the eye — a 38%-alpha white is not white.
Color _flatten(Color fg, Color bg) {
  final a = fg.a;
  int mix(double f, double b) => ((f * 255 * a) + (b * 255 * (1 - a))).round();
  return Color.fromARGB(255, mix(fg.r, bg.r), mix(fg.g, bg.g), mix(fg.b, bg.b));
}

double _contrast(Color fg, Color bg) {
  final l1 = _luminance(_flatten(fg, bg));
  final l2 = _luminance(bg);
  final hi = math.max(l1, l2);
  final lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // WCAG AA for body text. Hint text counts: a user has to read it to know
  // what the field wants.
  const aaBodyText = 4.5;

  group('hint text on the dark background', () {
    test('AppColors.hintOnDark clears WCAG AA on both gradient ends', () {
      expect(_contrast(AppColors.hintOnDark, AppColors.gradientStart),
          greaterThanOrEqualTo(aaBodyText));
      expect(_contrast(AppColors.hintOnDark, AppColors.gradientEnd),
          greaterThanOrEqualTo(aaBodyText));
    });

    test('the opacities it replaced genuinely failed', () {
      // Guards against someone "simplifying" hintOnDark back to one of these.
      // These are the measurements that motivated the constant, asserted so
      // the rationale cannot quietly rot.
      for (final failing in <Color>[
        Colors.white24,
        Colors.white30,
        Colors.white38,
      ]) {
        expect(
          _contrast(failing, AppColors.gradientStart),
          lessThan(aaBodyText),
          reason: '$failing was expected to fail AA on the dark background',
        );
      }
    });

    test('it still reads as secondary, not as primary body text', () {
      // The point is legibility, not flattening the hierarchy — hint text
      // must stay visibly dimmer than the white input text sitting next to it.
      expect(_contrast(AppColors.hintOnDark, AppColors.gradientStart),
          lessThan(_contrast(Colors.white, AppColors.gradientStart)));
    });
  });
}
