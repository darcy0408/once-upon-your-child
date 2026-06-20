// MT-269 regression guard: the mature-band Creative Brief "World & Setting"
// step must surface the bespoke editorial scene tiles (art / accent-gradient +
// thematic question) instead of the old bare ALL-CAPS ChoiceChips, so the
// commissioned `scenarios/<band>/` art and the authored thematic questions are
// actually reachable. Also pins the "My Own Idea" custom path.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_steps/hero_creator_step.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/widgets/hero_creator/scene_widgets.dart';

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

  testWidgets('Creator World step renders editorial scene tiles, not chips',
      (tester) async {
    silenceAssetErrors();
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(subject(creatorTheme, 13));
    await tester.pump(const Duration(milliseconds: 400));

    // Expand the (collapsed-by-default) World & Setting accordion section.
    // The section header renders the title upper-cased.
    await tester.tap(find.text('WORLD & SETTING'));
    await tester.pump(const Duration(milliseconds: 400));

    // Bespoke tiles now back the world picker.
    expect(find.byType(SceneImageButton), findsWidgets);
    // The custom-premise path is preserved as its own tile.
    expect(find.text('My Own Idea'), findsOneWidget);
  });
}
