import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/feelings_wheel_data.dart';
import 'package:story_weaver_app/feelings_wheel_screen.dart';

void main() {
  testWidgets('Feelings wheel flows core → secondary → tertiary selection', (tester) async {
    SelectedFeeling? captured;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FeelingsWheelScreen(
              onFeelingSelected: (feeling) => captured = feeling,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to the list-based picker so the chips are available in tests.
    await tester.tap(find.text('Use list instead'));
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
    final tertiary = find.text('Excited');
    expect(tertiary, findsWidgets);

    // Select tertiary emotion, callback should capture selection
    await tester.ensureVisible(tertiary.first);
    await tester.tap(tertiary.first);
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.tertiary, 'Excited');
    expect(captured!.core, 'Happy');
  });
}
