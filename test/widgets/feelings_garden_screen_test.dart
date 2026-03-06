import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/screens/feelings_garden_screen.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    // Use timed pumps to avoid pumpAndSettle timeout on continuous animations.
    var remainingMs = total.inMilliseconds;
    while (remainingMs > 0) {
      await tester.pump(const Duration(milliseconds: 100));
      remainingMs -= 100;
    }
  }

  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 1024);
    tester.view.devicePixelRatio = 1.0;
  }

  Widget createTestWidget(int age) {
    return MaterialApp(
      theme: ThemeData(
        extensions: [explorerTheme],
      ),
      home: FeelingsGardenScreen(childAge: age),
    );
  }

  group('FeelingsGardenScreen Widget Tests', () {
    testWidgets('shows only How Big zone for age 5 and under', (tester) async {
      await tester.pumpWidget(createTestWidget(5));
      await pumpFor(tester, const Duration(milliseconds: 500));

      // Age ≤5 shows a single zone (no tabs)
      expect(find.byType(TabBar), findsNothing);
      // The Zone 1 heading for age ≤5 is 'How are you feeling?'
      expect(find.text('How are you feeling?'), findsOneWidget);
      // Tab-only content should be absent
      expect(find.text('Explorer'), findsNothing);
      expect(find.text('Journal'), findsNothing);
    });

    testWidgets('shows Tabs for age 6-7 (How Big & Explorer)', (tester) async {
      await tester.pumpWidget(createTestWidget(6));
      await pumpFor(tester, const Duration(milliseconds: 500));

      expect(find.text('How Big?'), findsOneWidget);
      expect(find.text('Explorer'), findsOneWidget);
      expect(find.text('Journal'), findsNothing);
    });

    testWidgets('shows all 3 Tabs for age 8+', (tester) async {
      await tester.pumpWidget(createTestWidget(8));
      await pumpFor(tester, const Duration(milliseconds: 500));

      expect(find.text('How Big?'), findsOneWidget);
      expect(find.text('Explorer'), findsOneWidget);
      expect(find.text('Journal'), findsOneWidget);
    });

    testWidgets('can select a core emotion and see intensity slider', (tester) async {
      setLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(createTestWidget(8));
      await pumpFor(tester, const Duration(milliseconds: 500));

      // Tap 'Happy' core emotion in the How Big zone
      await tester.tap(find.text('Happy'));
      await pumpFor(tester, const Duration(milliseconds: 300));

      expect(find.text('How big is this feeling?'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('can navigate to Explorer and select core feeling', (tester) async {
      setLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(createTestWidget(8));
      await pumpFor(tester, const Duration(milliseconds: 500));

      // Switch to Explorer tab
      await tester.tap(find.text('Explorer'));
      await pumpFor(tester, const Duration(milliseconds: 800));

      // Level 0 (_CoreGrid) has no heading; verify core emotions are visible
      expect(find.text('Happy'), findsWidgets);

      // Tap 'Happy' core emotion card
      await tester.ensureVisible(find.text('Happy').first);
      await tester.tap(find.text('Happy').first);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.pump(); // allow setState to rebuild

      // Level 1 (_SecondaryGrid) — secondary emotions under Happy are visible
      expect(find.text('Playful'), findsWidgets);
    });

    testWidgets('Saving to journal shows snackbar for age 8+', (tester) async {
      setLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(createTestWidget(8));
      await pumpFor(tester, const Duration(milliseconds: 500));

      // Select emotion to enable save bar
      await tester.tap(find.text('Happy'));
      await pumpFor(tester, const Duration(milliseconds: 300));

      // Tap 'Save' button in save bar
      await tester.tap(find.text('Save'));
      await pumpFor(tester, const Duration(milliseconds: 500));

      expect(find.text('Feeling saved to your journal 🌱'), findsOneWidget);
    });
  });
}
