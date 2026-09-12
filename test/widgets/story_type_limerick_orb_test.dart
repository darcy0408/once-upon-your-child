// Limerick Mode orb on the story-type page: shown for the Explorer band only,
// and selecting it sets BOTH learningToReadMode (shared pipeline) and
// limerickMode (backend override), while picking Easy Reader clears the
// limerick flag again.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:story_weaver_app/models/wizard_data.dart';
import 'package:story_weaver_app/screens/wizard_steps/hero_creator_story_type_page.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';

Future<WizardData> _pumpPage(
  WidgetTester tester, {
  required AgeBandThemeData band,
  required int age,
}) async {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final data = WizardData()
    ..characterName = 'Max'
    ..characterAge = age
    ..characterGender = 'Boy';
  final controller = TextEditingController();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(extensions: <ThemeExtension<dynamic>>[band]),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: StatefulBuilder(
          builder: (context, setState) => HeroStoryTypePage(
            wizardData: data,
            wishController: controller,
            listeningFor: '',
            speechAvailable: false,
            onChanged: () => setState(() {}),
            onContinue: () {},
            onToggleListening: (_) {},
          ),
        ),
      ),
    ),
  );
  // The orbs float on a repeating animation, so never pumpAndSettle.
  await tester.pump(const Duration(milliseconds: 600));
  return data;
}

Future<void> _tapText(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Explorer sees Limerick Mode and it sets both flags',
      (tester) async {
    final data = await _pumpPage(tester, band: explorerTheme, age: 8);

    expect(find.text('Limerick Mode'), findsOneWidget);
    expect(find.text('Easy Reader'), findsOneWidget);

    await _tapText(tester, 'Limerick Mode');
    expect(data.limerickMode, isTrue);
    expect(data.learningToReadMode, isTrue);
    expect(data.rhymeTimeMode, isFalse);
    expect(data.interactiveMode, isFalse);

    // Easy Reader keeps the reading pipeline but drops the limerick override.
    await _tapText(tester, 'Easy Reader');
    expect(data.limerickMode, isFalse);
    expect(data.learningToReadMode, isTrue);

    // Any other mode clears both.
    await _tapText(tester, 'Story Quest');
    expect(data.limerickMode, isFalse);
    expect(data.learningToReadMode, isFalse);
  });

  testWidgets('a 6-year-old Explorer also gets the choice', (tester) async {
    await _pumpPage(tester, band: explorerTheme, age: 6);
    expect(find.text('Limerick Mode'), findsOneWidget);
  });

  testWidgets('Adventurer does not see Limerick Mode', (tester) async {
    await _pumpPage(tester, band: adventurerTheme, age: 10);
    expect(find.text('Limerick Mode'), findsNothing);
  });

  testWidgets('Sprout does not see Limerick Mode', (tester) async {
    await _pumpPage(tester, band: sproutTheme, age: 4);
    expect(find.text('Limerick Mode'), findsNothing);
  });
}
