import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/character_creation_screen_enhanced.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Character creation form validates required fields', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CharacterCreationScreenEnhanced()),
      ),
    );

    // Wait for the widget to be built
    await tester.pumpAndSettle();

    // Scroll to the create button at the bottom of the form
    final createButton = find.text('Create Character');
    await tester.scrollUntilVisible(
      createButton,
      500.0, // Scroll 500 pixels at a time
      scrollable: find.byType(Scrollable).first,
    );

    // Tap the create button without entering data
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    // Required validators should trigger
    expect(find.text('Required'), findsWidgets);
  });
}
