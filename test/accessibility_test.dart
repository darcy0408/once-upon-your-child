import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/providers/highlight_color_provider.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/theme/app_theme.dart';
import 'package:story_weaver_app/widgets/app_button.dart';

/// WCAG 2.2 relative-luminance contrast ratio between two colors.
/// Uses [Color.computeLuminance], which implements the WCAG luminance formula.
double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  testWidgets('AppButton has semantic label via tooltip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton.primary(
            label: 'Click Me',
            semanticLabel: 'Submit form',
            onPressed: () {},
          ),
        ),
      ),
    );

    final tooltipFinder = find.byTooltip('Submit form');
    expect(tooltipFinder, findsOneWidget);
  });

  testWidgets('IconButton with tooltip has semantics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IconButton(
            tooltip: 'Delete story',
            icon: const Icon(Icons.delete),
            onPressed: () {},
          ),
        ),
      ),
    );

    final tooltipFinder = find.byTooltip('Delete story');
    expect(tooltipFinder, findsOneWidget);
  });

  // A11Y-001 — primary CTA contrast. The global ElevatedButton theme paints
  // `band.primary` as the background with white text. These tests are the
  // regression guard for the contrast fix.
  group('A11Y-001 — age band CTA contrast', () {
    test('non-Sprout bands meet AA normal-text contrast (4.5:1) on white', () {
      const bands = <AgeBandThemeData>[
        explorerTheme,
        adventurerTheme,
        creatorTheme,
        adolescentTheme,
        adultTheme,
      ];
      for (final band in bands) {
        final ratio = _contrastRatio(band.primary, Colors.white);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '${band.band.name} primary ${band.primary} vs white '
              'is ${ratio.toStringAsFixed(2)}:1 — needs >= 4.5:1',
        );
      }
    });

    test('Sprout primary meets at least AA large-text contrast (3:1)', () {
      // Sprout intentionally keeps the bright #E65100 and relies on the
      // large-text threshold; the next test guards that its CTA text really
      // stays large + bold so this 3:1 allowance remains valid.
      final ratio = _contrastRatio(sproutTheme.primary, Colors.white);
      expect(ratio, greaterThanOrEqualTo(3.0));
    });

    testWidgets('Sprout ElevatedButton text is WCAG large text (>=18pt bold)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(ageBand: sproutTheme),
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {},
              child: const Text('Make Magic!'),
            ),
          ),
        ),
      );

      final richText = tester.widget<RichText>(
        find.descendant(
          of: find.byType(ElevatedButton),
          matching: find.byType(RichText),
        ),
      );
      final style = richText.text.style!;

      expect(
        style.fontSize,
        greaterThanOrEqualTo(18.0),
        reason: 'Sprout CTA text must be >=18pt to qualify as WCAG large text',
      );
      expect(
        style.fontWeight!.value,
        greaterThanOrEqualTo(FontWeight.bold.value),
        reason: 'Sprout CTA text must be bold for the 3:1 large-text threshold',
      );
    });
  });

  // A11Y-LTR-03 — the Learning-to-read word-highlight color is configurable.
  group('A11Y-LTR-03 — configurable highlight color', () {
    test('defaults to gold and persists a new selection', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(highlightColorProvider), AppColors.gold);

      const skyBlue = Color(0xFF4FC3F7);
      await container.read(highlightColorProvider.notifier).setColor(skyBlue);
      expect(container.read(highlightColorProvider), skyBlue);
    });

    test('restores a saved color on next launch', () async {
      const mint = Color(0xFF81C784);
      SharedPreferences.setMockInitialValues({
        'reader_highlight_color': mint.toARGB32(),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // First read returns the default; _load() resolves asynchronously.
      container.read(highlightColorProvider);
      await pumpEventQueue();
      expect(container.read(highlightColorProvider), mint);
    });
  });
}
