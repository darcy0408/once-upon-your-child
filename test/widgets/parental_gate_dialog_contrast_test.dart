import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/theme/app_theme.dart';
import 'package:story_weaver_app/widgets/parental_gate_dialog.dart';

/// MT-416: the "Parents only" math-check dialog rendered its explanation,
/// the "a × b =" label and the "Answer" label near-white on a light card on a
/// real phone. Rendered under all six band themes it did so in every one.
///
/// The dialog now owns an explicit colour pair (band card + band ink) and
/// nothing inherits. This test reads the colours the widgets actually carry
/// and computes the WCAG ratio, so the regression can't come back as an
/// inherited `null` colour that happens to resolve to white.

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

Color _flatten(Color fg, Color bg) {
  final a = fg.a;
  double mix(double f, double b) => f * a + b * (1 - a);
  return Color.from(
    alpha: 1,
    red: mix(fg.r, bg.r),
    green: mix(fg.g, bg.g),
    blue: mix(fg.b, bg.b),
  );
}

double _contrast(Color fg, Color bg) {
  final l1 = _luminance(_flatten(fg, bg));
  final l2 = _luminance(bg);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

const _bands = <String, AgeBandThemeData>{
  'sprout': sproutTheme,
  'explorer': explorerTheme,
  'adventurer': adventurerTheme,
  'creator': creatorTheme,
  'adolescent': adolescentTheme,
  'adult': adultTheme,
};

const _message = 'Quick check that a grown-up is holding the device. '
    'Solve this to unlock the consent form.';

Future<void> _openGate(WidgetTester tester, AgeBandThemeData band) async {
  // Wider than a phone on purpose: the test host has no bundled UI font and
  // draws box glyphs about twice as wide as the real ones, which overflows
  // the "a × b = [answer]" row at 360px (CLAUDE.md rule 2 warns about
  // exactly this). The dialog fits on a real 360px phone; this test is
  // about colour, so it sidesteps the phantom overflow.
  await tester.binding.setSurfaceSize(const Size(480, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(ageBand: band),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () => ParentalGateDialog.show(ctx, message: _message),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  // A wrong answer so the error line is part of what gets measured.
  await tester.enterText(find.byType(TextField), '1');
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

void main() {
  const aa = 4.5;

  for (final entry in _bands.entries) {
    testWidgets('math gate is readable on the ${entry.key} band',
        (tester) async {
      await _openGate(tester, entry.value);

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final card = dialog.backgroundColor;
      expect(card, isNotNull, reason: 'dialog must paint its own card colour');
      expect(card, entry.value.cardColor);

      // Every piece of copy carries an explicit colour that clears AA on
      // that card. A null colour would inherit — that was the bug.
      final copy = <String, Finder>{
        'explanation': find.text(_message),
        'multiplication label': find.textContaining('× '),
        'Cancel': find.widgetWithText(TextButton, 'Cancel'),
      };
      for (final item in copy.entries) {
        expect(item.value, findsOneWidget, reason: item.key);
      }

      for (final finder in [copy['explanation']!, copy['multiplication label']!]) {
        final text = tester.widget<Text>(finder);
        final color = text.style?.color;
        expect(color, isNotNull, reason: '${text.data} inherits its colour');
        expect(_contrast(color!, card!), greaterThanOrEqualTo(aa),
            reason: '${text.data} on ${entry.key} card');
      }

      final title = dialog.titleTextStyle?.color;
      expect(title, isNotNull, reason: 'title inherits its colour');
      expect(_contrast(title!, card!), greaterThanOrEqualTo(aa));

      final field = tester.widget<TextField>(find.byType(TextField));
      final typed = field.style?.color;
      final label = field.decoration?.labelStyle?.color;
      final fill = field.decoration?.fillColor;
      expect(typed, isNotNull, reason: 'typed answer inherits its colour');
      expect(label, isNotNull, reason: 'Answer label inherits its colour');
      expect(fill, isNotNull, reason: 'field fill inherits the band surface');
      final fieldBg = _flatten(fill!, card);
      expect(_contrast(typed!, fieldBg), greaterThanOrEqualTo(aa),
          reason: 'typed answer on ${entry.key} field');
      expect(_contrast(label!, fieldBg), greaterThanOrEqualTo(aa),
          reason: 'Answer label on ${entry.key} field');

      final errorInk = field.decoration?.errorStyle?.color;
      expect(field.decoration?.errorText, isNotNull, reason: 'wrong answer');
      expect(errorInk, isNotNull, reason: 'error line inherits its colour');
      expect(_contrast(errorInk!, card), greaterThanOrEqualTo(aa),
          reason: 'error line on ${entry.key} card');

      final cancel = tester.widget<TextButton>(copy['Cancel']!);
      final cancelInk = cancel.style?.foregroundColor?.resolve({});
      expect(cancelInk, isNotNull, reason: 'Cancel inherits its colour');
      expect(_contrast(cancelInk!, card), greaterThanOrEqualTo(aa),
          reason: 'Cancel on ${entry.key} card');
    });
  }

  testWidgets('the band ink/card pairs the dialog relies on all clear AA',
      (tester) async {
    // The dialog's contract is "onCard on cardColor"; pin that the six band
    // pairs honour it, since the dialog now has no other source of contrast.
    for (final entry in _bands.entries) {
      expect(_contrast(entry.value.onCard, entry.value.cardColor),
          greaterThanOrEqualTo(aa),
          reason: '${entry.key} onCard/cardColor');
    }
  });
}
