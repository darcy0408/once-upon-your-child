// Pins the disabled colours of AppButton.
//
// ElevatedButton.styleFrom does not derive disabled colours from the enabled
// ones. Omitting them makes Flutter fall back to the theme's onSurface at 12%
// background / 38% foreground, which measured 1.14:1 on the dark band
// scaffold — effectively invisible.
//
// That is not cosmetic here: Pick-a-Path renders every branch choice through
// AppButton.primary and disables them all while the next segment generates. A
// reader reported being unable to read the choices; the request behind that tap
// took 32 seconds, so they stayed unreadable for the entire wait.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/theme/app_theme.dart';
import 'package:story_weaver_app/widgets/app_button.dart';

/// WCAG relative luminance.
double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Composite [fg] (with its own alpha) over opaque [bg].
Color _over(Color fg, Color bg) {
  final a = fg.a;
  return Color.fromARGB(
    255,
    ((fg.r * a + bg.r * (1 - a)) * 255).round(),
    ((fg.g * a + bg.g * (1 - a)) * 255).round(),
    ((fg.b * a + bg.b * (1 - a)) * 255).round(),
  );
}

// The manifest background colour, representative of the dark band scaffold
// these buttons sit on.
const _scaffold = Color(0xFF2A1B4E);

ButtonStyle _styleOf(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;

Color? _resolve(MaterialStateProperty<Color?>? p, Set<MaterialState> states) =>
    p?.resolve(states);

void main() {
  testWidgets('disabled primary button stays legible on a dark scaffold',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: _scaffold,
          // onPressed: null is the disabled state Pick-a-Path puts every
          // choice into while the next segment generates.
          body: AppButton.primary(label: 'Cross the bridge', onPressed: null),
        ),
      ),
    );

    const disabled = {MaterialState.disabled};
    final style = _styleOf(tester);
    final bgColor = _resolve(style.backgroundColor, disabled);
    final fgColor = _resolve(style.foregroundColor, disabled);

    expect(bgColor, isNotNull,
        reason: 'no explicit disabledBackgroundColor — Flutter would fall back '
            'to onSurface@12%, measured 1.14:1 on this scaffold');
    expect(fgColor, isNotNull, reason: 'no explicit disabledForegroundColor');

    final bg = _over(bgColor!, _scaffold);
    final fg = _over(fgColor!, bg);
    final ratio = _contrast(fg, bg);

    expect(ratio, greaterThanOrEqualTo(4.5),
        reason: 'disabled choice text measured ${ratio.toStringAsFixed(2)}:1; '
            'WCAG AA body text needs 4.5:1');
  });

  testWidgets('enabled primary button contrast is unchanged', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: _scaffold,
          body: AppButton.primary(label: 'Cross the bridge', onPressed: () {}),
        ),
      ),
    );

    final style = _styleOf(tester);
    final bg = _resolve(style.backgroundColor, <MaterialState>{})!;
    final fg = _resolve(style.foregroundColor, <MaterialState>{})!;
    expect(bg, AppColors.primary);
    expect(_contrast(_over(fg, bg), bg), greaterThanOrEqualTo(4.5));
  });
}
