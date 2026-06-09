import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/widgets/image_mode_orb.dart';

/// MT-051: the spotlight "✨ Try this!" pill nudges Explorer kids toward the
/// high-value modes. It must only appear when spotlighted AND not selected, so
/// it never fights the active checkmark in the shared top-right badge slot.
void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 180, height: 180, child: child),
        ),
      );

  group('ImageModeOrb spotlight badge', () {
    testWidgets('shows "✨ Try this!" when spotlight && not active',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        ImageModeOrb(
          modeType: 'rhyme',
          label: 'Rhyme Time',
          isActive: false,
          spotlight: true,
          onTap: () {},
        ),
      ));
      await tester.pump();

      expect(find.text('✨ Try this!'), findsOneWidget);
    });

    testWidgets('hides spotlight pill when the orb is active',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        ImageModeOrb(
          modeType: 'rhyme',
          label: 'Rhyme Time',
          isActive: true,
          spotlight: true,
          onTap: () {},
        ),
      ));
      await tester.pump();

      // Suppressed in favor of the active checkmark.
      expect(find.text('✨ Try this!'), findsNothing);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('no pill when spotlight is false (default)',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        ImageModeOrb(
          modeType: 'pickpath',
          label: 'Pick a Path',
          isActive: false,
          onTap: () {},
        ),
      ));
      await tester.pump();

      expect(find.text('✨ Try this!'), findsNothing);
    });
  });
}
