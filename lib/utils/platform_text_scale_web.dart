// Web implementation of the platform text scale.
//
// CanvasKit paints text into a <canvas>, so the browser's font-size preference
// has no effect on anything Flutter draws. We therefore measure that preference
// out of the DOM ourselves and hand it back as a multiplier.
//
// The measurement uses a probe element with `font-size: medium`. The `medium`
// keyword is defined to resolve to the browser's *default* font size, which is
// exactly the value the user's browser/OS font-size setting moves — 16px when
// untouched. Reading `1rem` instead would be wrong, because author CSS on the
// root element would skew it (there is none today, but that is not a property
// worth depending on). The probe is appended, measured, and removed
// synchronously, so it never paints.

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:flutter/foundation.dart';

/// Browser default font size, in CSS pixels, when the user has changed nothing.
const double _kBaselineFontSizePx = 16.0;

/// Upper bound on the automatic scale.
///
/// main_story.dart clamps the *combined* factor to 2.0 as a layout backstop;
/// bounding the automatic contribution here too means a bizarre measurement
/// can never single-handedly consume the whole budget.
const double _kMaxPlatformScale = 2.0;

double? _cached;

/// Reads the browser's font-size preference as a text-scale multiplier.
///
/// Returns 1.0 when the preference is default, unreadable, or *smaller* than
/// default. The lower bound is deliberate: this app's own type already sits at
/// the small end, and the reason the setting is being honoured at all is
/// legibility, so automatically shrinking text further would work against the
/// only goal here. A user who genuinely wants smaller text can still get it
/// from the in-app Text Size slider, which multiplies on top of this.
///
/// The result is cached — this touches the DOM and is called from `build`.
double readPlatformTextScale() => _cached ??= _measure();

double _measure() {
  try {
    final body = html.document.body;
    if (body == null) return 1.0;

    final probe = html.DivElement()
      ..style.position = 'absolute'
      ..style.visibility = 'hidden'
      ..style.pointerEvents = 'none'
      ..style.fontSize = 'medium'
      ..text = 'M';
    body.append(probe);
    final computed = probe.getComputedStyle().fontSize;
    probe.remove();

    final px = double.tryParse(computed.replaceAll('px', '').trim());
    if (px == null || px <= 0) return 1.0;

    return (px / _kBaselineFontSizePx).clamp(1.0, _kMaxPlatformScale);
  } catch (_) {
    // Any DOM weirdness (detached document, hardened CSP, exotic browser)
    // falls back to "behave exactly as before".
    return 1.0;
  }
}

/// Clears the memoised measurement. Tests only.
@visibleForTesting
void resetPlatformTextScaleCache() => _cached = null;
