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

    // MT-176: the geometric wheel image was removed (asset never shipped);
    // the list picker is now the sole UI, so no toggle interaction is needed.

    // Tap a core emotion
    final happy = find.text('Happy');
    expect(happy, findsWidgets);
    await tester.ensureVisible(happy.first);
    await tester.tap(happy.first);
    await tester.pumpAndSettle();

    // Secondary level should appear
    final secondary = find.text('Playful');
    expect(secondary, findsWidgets);

    // Tap a secondary emotion
    await tester.ensureVisible(secondary.first);
    await tester.tap(secondary.first);
    await tester.pumpAndSettle();

    // Tertiary options should appear
    final tertiaryStage = find.ancestor(
      of: find.text('3. Exact feelings'),
      matching: find.byType(Container),
    );
    final tertiary = find.descendant(
      of: tertiaryStage.first,
      matching: find.widgetWithText(ChoiceChip, 'Cheeky'),
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
    expect(captured!.tertiary, 'Cheeky');
    expect(captured!.core, 'Happy');
    
    // Verify "Feeling selected!" text appears
    expect(find.text('Feeling selected!'), findsOneWidget);
  });
}
