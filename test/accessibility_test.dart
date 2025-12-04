import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/widgets/app_button.dart';

void main() {
  testWidgets('AppButton has semantic label via tooltip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton.primary(
            label: 'Click Me',
            semanticLabel: 'Submit form',
            onPressed: () {},
          ),
        ),
      ),
    );

    final tooltipFinder = find.byTooltip('Submit form');
    expect(tooltipFinder, findsOneWidget);
  });

  testWidgets('IconButton with tooltip has semantics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IconButton(
            tooltip: 'Delete story',
            icon: const Icon(Icons.delete),
            onPressed: () {},
          ),
        ),
      ),
    );

    final tooltipFinder = find.byTooltip('Delete story');
    expect(tooltipFinder, findsOneWidget);
  });
}
