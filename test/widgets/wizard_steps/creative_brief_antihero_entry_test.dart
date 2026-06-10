// Regression guard: the antihero / Hero Saga entry must be REACHABLE from the
// mature-band Creative Brief. Phases 1-2 wired the backend tier + picker but
// the only start-entry lived in younger-band screens, so a new mature user had
// no way to launch it. These tests pin the entry CTA's presence per band.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_steps/hero_creator_step.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';

void main() {
  void silenceAssetErrors() {
    final original = FlutterError.onError!;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('Unable to load asset')) return;
      original(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
  }

  Widget subject(AgeBandThemeData band, int age) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(extensions: [band]),
        home: Scaffold(
          body: HeroCreatorStep(
            wizardData: WizardData()..characterAge = age,
            onNext: () {},
            availableCharacters: const [],
          ),
        ),
      ),
    );
  }

  testWidgets('Adolescent Creative Brief shows the "Live a double life" entry',
      (tester) async {
    silenceAssetErrors();
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(subject(adolescentTheme, 16));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Live a double life'), findsOneWidget);
  });

  testWidgets('Creator Creative Brief shows the "Start a Hero Saga" entry',
      (tester) async {
    silenceAssetErrors();
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(subject(creatorTheme, 13));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Start a Hero Saga'), findsOneWidget);
  });

  testWidgets('Adult Creative Brief has no antihero entry (no backend tier)',
      (tester) async {
    silenceAssetErrors();
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(subject(adultTheme, 25));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Live a double life'), findsNothing);
    expect(find.text('Start a Hero Saga'), findsNothing);
  });
}
