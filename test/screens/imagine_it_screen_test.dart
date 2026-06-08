// Widget tests for ImagineItScreen — Explorer-band "Be a superhero!" entry
// (regression coverage for MT-110).
//
// Covers:
//   (a) The Explorer band renders the "Be a superhero!" button inside the
//       standard input panel.
//   (b) Tapping the button pushes [SuperheroEntryScreen].
//   (c) The button shows for Explorer AND Adventurer (backend prompt routing
//       has dedicated tiers T7_SUPERHERO_EXPLORER / T8_SUPERHERO_ADVENTURER).
//       Creator/Adolescent/Adult must NOT see it. The Sprout band uses a
//       different input path entirely (idea-tile, no gated button).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_steps/imagine_it_screen.dart';
import 'package:story_weaver_app/screens/wizard_steps/superhero_entry_screen.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';

WizardData _makeWizardData({int age = 7}) {
  return WizardData()
    ..characterName = 'Sam'
    ..characterAge = age
    ..characterId = 'char_sam';
}

/// Wraps [ImagineItScreen] in a MaterialApp whose theme carries the
/// AgeBandThemeData extension for [band]. ProviderScope is required because
/// tapping the superhero button pushes a ConsumerWidget.
Widget _bootstrap({
  required WizardData wizardData,
  required AgeBand band,
  required TextEditingController imagineCtl,
  required TextEditingController wishCtl,
}) {
  final bandTheme = themeForBand(band);
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData(extensions: [bandTheme]),
      home: ImagineItScreen(
        wizardData: wizardData,
        imagineItController: imagineCtl,
        wishController: wishCtl,
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 1.0;
  }

  testWidgets('Explorer band shows the "Be a superhero!" button',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final wd = _makeWizardData(age: 7);
    final imagineCtl = TextEditingController();
    final wishCtl = TextEditingController();
    addTearDown(imagineCtl.dispose);
    addTearDown(wishCtl.dispose);

    await tester.pumpWidget(_bootstrap(
      wizardData: wd,
      band: AgeBand.explorer,
      imagineCtl: imagineCtl,
      wishCtl: wishCtl,
    ));
    // Speech init is async; pumping a few frames lets the post-frame work
    // settle without depending on pumpAndSettle (which would hang on the
    // microphone availability future on some CI configurations).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Be a superhero!'), findsOneWidget);
    expect(find.text('🦸'), findsOneWidget);
  });

  testWidgets('tapping "Be a superhero!" pushes SuperheroEntryScreen',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final wd = _makeWizardData(age: 7);
    final imagineCtl = TextEditingController();
    final wishCtl = TextEditingController();
    addTearDown(imagineCtl.dispose);
    addTearDown(wishCtl.dispose);

    await tester.pumpWidget(_bootstrap(
      wizardData: wd,
      band: AgeBand.explorer,
      imagineCtl: imagineCtl,
      wishCtl: wishCtl,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SuperheroEntryScreen), findsNothing);

    // Scroll the button into view before tapping (the panel is tall enough
    // on some screen sizes that the button sits below the fold).
    await tester.ensureVisible(find.text('Be a superhero!'));
    await tester.pump();

    await tester.tap(find.text('Be a superhero!'));
    // Drive the navigation animation manually — pumpAndSettle would block
    // on the SuperheroEntryScreen's heroProfileProvider future.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SuperheroEntryScreen), findsOneWidget);
  });

  // ── Gating: button only renders for Explorer ─────────────────────────────

  Future<void> expectNoSuperheroButton(
    WidgetTester tester, {
    required AgeBand band,
  }) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    // Pick a reasonable age inside the band so any age-derived rendering
    // inside the screen stays consistent with the theme extension.
    final age = switch (band) {
      AgeBand.sprout => 4,
      AgeBand.explorer => 7,
      AgeBand.adventurer => 10,
      AgeBand.creator => 13,
      AgeBand.adolescent => 16,
      AgeBand.adult => 25,
    };

    final wd = _makeWizardData(age: age);
    final imagineCtl = TextEditingController();
    final wishCtl = TextEditingController();
    addTearDown(imagineCtl.dispose);
    addTearDown(wishCtl.dispose);

    await tester.pumpWidget(_bootstrap(
      wizardData: wd,
      band: band,
      imagineCtl: imagineCtl,
      wishCtl: wishCtl,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The gold-outlined gated button uses the exact label "Be a superhero!"
    // with a trailing exclamation point. The Sprout tile is "Be a superhero"
    // (no bang) — checking the exact gated label avoids cross-matching the
    // Sprout idea tile when this test ever happens to render that path.
    expect(
      find.text('Be a superhero!'),
      findsNothing,
      reason: 'Superhero button must not render outside Explorer band '
          '(band: $band)',
    );
  }

  testWidgets('Adventurer band shows the "Be a superhero!" button',
      (tester) async {
    // The Adventurer (9-12) superhero entry was added alongside Explorer
    // (backend tier T8_SUPERHERO_ADVENTURER). imagine_it_screen renders the
    // gated button for explorer OR adventurer, so it must be present here.
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final wd = _makeWizardData(age: 10);
    final imagineCtl = TextEditingController();
    final wishCtl = TextEditingController();
    addTearDown(imagineCtl.dispose);
    addTearDown(wishCtl.dispose);

    await tester.pumpWidget(_bootstrap(
      wizardData: wd,
      band: AgeBand.adventurer,
      imagineCtl: imagineCtl,
      wishCtl: wishCtl,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Be a superhero!'), findsOneWidget);
    expect(find.text('🦸'), findsOneWidget);
  });

  testWidgets('Creator band shows the "Be a superhero!" button',
      (tester) async {
    // The Creator (13-14) "Hero Saga" superhero entry was added alongside
    // Explorer/Adventurer (backend tier T9_SUPERHERO_CREATOR). imagine_it_screen
    // renders the gated button for explorer/adventurer/creator.
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final wd = _makeWizardData(age: 13);
    final imagineCtl = TextEditingController();
    final wishCtl = TextEditingController();
    addTearDown(imagineCtl.dispose);
    addTearDown(wishCtl.dispose);

    await tester.pumpWidget(_bootstrap(
      wizardData: wd,
      band: AgeBand.creator,
      imagineCtl: imagineCtl,
      wishCtl: wishCtl,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Be a superhero!'), findsOneWidget);
    expect(find.text('🦸'), findsOneWidget);
  });

  testWidgets('Adolescent band does NOT show the superhero button',
      (tester) async {
    await expectNoSuperheroButton(tester, band: AgeBand.adolescent);
  });

  testWidgets('Adult band does NOT show the superhero button',
      (tester) async {
    await expectNoSuperheroButton(tester, band: AgeBand.adult);
  });

  testWidgets('Sprout band does NOT show the gated superhero button '
      '(it has its own idea-tile path)', (tester) async {
    // Sprout renders _buildSproutInput() which never includes the gated
    // gold-outlined button; the superhero entry is exposed there as one of
    // the wrap-grid idea tiles with label "Be a superhero" (no exclamation
    // mark), so the gated button text must still be absent.
    await expectNoSuperheroButton(tester, band: AgeBand.sprout);
  });
}
