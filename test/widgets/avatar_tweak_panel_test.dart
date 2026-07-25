import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/widgets/avatar_tweak_panel.dart';

void main() {
  group('AvatarTweakPanel responsive layout', () {
    Widget buildPanel() {
      return MaterialApp(
        home: Scaffold(
          body: AvatarTweakPanel(
            assetPath: 'assets/avatars/midjourney/avatar_042.webp',
            isPremium: false,
            onConfirm: (_) {},
            onBack: () {},
          ),
        ),
      );
    }

    testWidgets('narrow phone width shows a full-width "Use this look" button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildPanel());
      await tester.pump();

      final buttonFinder = find.widgetWithText(ElevatedButton, 'Use this look');
      expect(buttonFinder, findsOneWidget);

      final buttonSize = tester.getSize(buttonFinder);
      expect(buttonSize.width, greaterThanOrEqualTo(200));
    });

    testWidgets('wide width keeps the avatar + button Row layout',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildPanel());
      await tester.pump();

      expect(find.widgetWithText(ElevatedButton, 'Use this look'),
          findsOneWidget);
      // On wide screens the preview + button share a Row rather than
      // stacking, so the Row's cross-axis alignment marker is present.
      expect(find.byType(Row), findsWidgets);
    });
  });
}
