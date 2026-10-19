import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/widgets/companion_arrival_card.dart';

void main() {
  for (final entry in {
    AgeBand.sprout: sproutTheme,
    AgeBand.explorer: explorerTheme,
    AgeBand.adult: adultTheme,
  }.entries) {
    testWidgets('arrival card fits 360x740 and dismisses (${entry.key})', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final companion = companionsForBand(entry.key)[1];
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(360, 740)),
            child: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CompanionArrivalCard(
                    companion: companion,
                    band: entry.value,
                    onDismiss: () => dismissed = true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('${companion.name} has arrived!'), findsOneWidget);
      expect(find.text(companion.tagline), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Dismiss'));
      expect(dismissed, isTrue);
    });
  }
}
