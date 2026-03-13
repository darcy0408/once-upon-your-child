import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/screens/parent_controls_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSubject() {
    return const MaterialApp(home: ParentControlsScreen());
  }

  Future<void> revealBigFeelingsSection(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Big Feelings'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('loads persisted hidden big feelings context', (tester) async {
    SharedPreferences.setMockInitialValues({
      'big_feelings_parent_hidden_context': 'bedtime worry',
    });

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await revealBigFeelingsSection(tester);

    final bedtimeChip = tester.widget<ChoiceChip>(
      find.byKey(
        const ValueKey('parent_big_feelings_context_bedtime worry'),
      ),
    );

    expect(bedtimeChip.selected, isTrue);
  });

  testWidgets('persists selected hidden big feelings context', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await revealBigFeelingsSection(tester);

    await tester.tap(
      find.byKey(
        const ValueKey('parent_big_feelings_context_sibling conflict'),
      ),
    );
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('big_feelings_parent_hidden_context'),
      'sibling conflict',
    );
  });
}
