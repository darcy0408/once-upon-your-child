import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/screens/big_feelings_flow_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSubject({String? initialParentHiddenContext}) {
    return MaterialApp(
      home: BigFeelingsFlowScreen(
        initialParentHiddenContext: initialParentHiddenContext,
      ),
    );
  }

  testWidgets('loads persisted real-life struggle into hidden parent UI',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'big_feelings_parent_hidden_context': 'bedtime worry',
    });

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Parent context'));
    await tester.pumpAndSettle();

    final chip = tester.widget<ChoiceChip>(
      find.byKey(
        const ValueKey('big_feelings_parent_context_bedtime worry'),
      ),
    );

    expect(chip.selected, isTrue);
  });

  testWidgets('persists selected real-life struggle chip', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Parent context'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('big_feelings_parent_context_friendship hurt'),
      ),
    );
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('big_feelings_parent_hidden_context'),
      'friendship hurt',
    );
  });
}
