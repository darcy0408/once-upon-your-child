import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/feelings_wheel_data.dart';
import 'package:story_weaver_app/feelings_wheel_screen.dart';

void main() {
  testWidgets('Feelings wheel flows core → secondary → tertiary selection', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SelectedFeeling? captured;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FeelingsWheelScreen(
              currentFeeling: captured,
              onFeelingSelected: (feeling) => captured = feeling,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to the list-based picker so the chips are available in tests.
    final listToggle = find.text('Use list instead');
    await tester.ensureVisible(listToggle);
    await tester.tap(listToggle);
    await tester.pumpAndSettle();

    // Tap a core emotion
    final happy = find.text('Happy');
    expect(happy, findsWidgets);
    await tester.ensureVisible(happy.first);
    await tester.tap(happy.first);
    await tester.pumpAndSettle();

    // Secondary level should appear
    final joyful = find.text('Joyful');
    expect(joyful, findsWidgets);

    // Tap a secondary emotion
    await tester.ensureVisible(joyful.first);
    await tester.tap(joyful.first);
    await tester.pumpAndSettle();

    // Tertiary options should appear
    final tertiaryStage = find.ancestor(
      of: find.text('3. Exact feelings'),
      matching: find.byType(Container),
    );
    final tertiary = find.descendant(
      of: tertiaryStage.first,
      matching: find.widgetWithText(ChoiceChip, 'Excited'),
    );
    expect(tertiary, findsOneWidget);

    // Select tertiary emotion from the exact-feelings section
    await tester.ensureVisible(tertiary);
    await tester.tap(tertiary);
    
    // Update widget with new captured feeling to show summary
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FeelingsWheelScreen(
              currentFeeling: captured,
              onFeelingSelected: (feeling) => captured = feeling,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.tertiary, 'Excited');
    expect(captured!.core, 'Happy');
    
    // Verify "Feeling selected!" text appears
    expect(find.text('Feeling selected!'), findsOneWidget);
  });
}
