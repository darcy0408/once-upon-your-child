import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/screens/parent_controls_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildSubject() {
    return const MaterialApp(home: ParentControlsScreen());
  }

  Future<void> expandBigFeelings(WidgetTester tester) async {
    // Scroll to the header and tap it.
    await tester.scrollUntilVisible(
      find.textContaining('My child could use some help'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.textContaining('My child could use some help'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders without crashing', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    expect(find.text('Parent Controls'), findsOneWidget);
  });

  testWidgets('Big Feelings header is visible', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('My child could use some help'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('My child could use some help'), findsOneWidget);
  });

  testWidgets('shows no-profile state when no child profile active',
      (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await expandBigFeelings(tester);
    // Without a profile, the no-profile message should appear.
    expect(find.text('No child profile active'), findsOneWidget);
  });

  testWidgets('math gate appears after expand when profile is set',
      (tester) async {
    // Set a profile ID so the no-profile state is skipped.
    SharedPreferences.setMockInitialValues({
      'active_child_profile_id': 'test-profile-123',
    });
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await expandBigFeelings(tester);
    expect(find.text('Parent verification'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
  });

  testWidgets('wrong math answer shows error', (tester) async {
    SharedPreferences.setMockInitialValues({
      'active_child_profile_id': 'test-profile-123',
    });
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await expandBigFeelings(tester);

    await tester.enterText(find.byType(TextField).first, '999');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('Not quite -- try again.'), findsOneWidget);
  });
}
