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

    // Tap a core emotion
    await tester.ensureVisible(find.text('Happy'));
    await tester.tap(find.text('Happy'));
    await tester.pumpAndSettle();

    // Secondary level should appear
    expect(find.text('Joyful'), findsWidgets);

    // Tap a secondary emotion
    await tester.ensureVisible(find.text('Joyful').first);
    await tester.tap(find.text('Joyful').first);
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
