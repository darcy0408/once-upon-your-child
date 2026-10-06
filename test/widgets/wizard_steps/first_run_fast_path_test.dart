// First-story fast path (chunk 2): a NEW hero on a device with zero created
// stories skips the hero-type page (after the avatar) and the story-kind page
// (after the scene). From the second story both pages return. The optional
// extras on the 6-12 story-kind page are folded under "More options" on
// every run.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/models/generated_avatar.dart';
import 'package:story_weaver_app/screens/wizard_steps/hero_creator_step.dart';
import 'package:story_weaver_app/screens/wizard_steps/hero_creator_story_type_page.dart';
import 'package:story_weaver_app/services/avatar_generation_state.dart';
import 'package:story_weaver_app/services/progression_service.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/widgets/archetype_card.dart';
import 'package:story_weaver_app/widgets/hero_creator/hero_input_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  void silenceAssetErrors() {
    final original = FlutterError.onError!;
    FlutterError.onError = (details) {
      final msg = details.exception.toString();
      if (msg.contains('Unable to load asset')) return;
      original(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    var remainingMs = total.inMilliseconds;
    while (remainingMs > 0) {
      await tester.pump(const Duration(milliseconds: 100));
      remainingMs -= 100;
    }
  }

  void seedStories(int count) {
    SharedPreferences.setMockInitialValues({
      'user_progress': jsonEncode(
        UserProgress(storiesCreated: count).toJson(),
      ),
    });
  }

  GeneratedAvatar avatar() => GeneratedAvatar(
        id: 'a1',
        imageBase64: 'assets/images/none.png',
        seed: 's',
        style: 'cartoon',
        attributes: const {},
        generatedAt: DateTime(2026, 1, 1),
      );

  setUp(() => AvatarGenerationState().reset());
  tearDown(() => AvatarGenerationState().reset());

  group('HeroCreatorStep fast path', () {
    late WizardData wizardData;
    late int nextCalls;

    PageController innerController(WidgetTester tester) =>
        tester.widgetList<PageView>(find.byType(PageView)).first.controller!;

    // [subStep] 2 opens the inner PageView on the scene page (page 5) the way
    // the wizard does when the user taps "Place" in the progress bar.
    Future<void> pumpStep(WidgetTester tester, int age,
        {int? subStep}) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      silenceAssetErrors();
      wizardData = WizardData()
        ..characterName = 'Luna'
        ..characterAge = age;
      nextCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [themeForAge(age)]),
          home: Scaffold(
            body: HeroCreatorStep(
              wizardData: wizardData,
              onNext: () => nextCalls++,
              availableCharacters: const [],
              requestedSubStep: subStep,
            ),
          ),
        ),
      );
      await pumpFor(tester, const Duration(milliseconds: 600));
    }

    Future<void> finishAvatar(WidgetTester tester) async {
      // Same signal the background avatar generator uses; page 1 advances.
      AvatarGenerationState().completeGeneration(avatar());
      await pumpFor(tester, const Duration(milliseconds: 900));
    }

    testWidgets('first run at ages 4/7/10: avatar lands on companions with '
        'the default archetype stored', (tester) async {
      for (final age in [4, 7, 10]) {
        seedStories(0);
        AvatarGenerationState().reset();
        await pumpStep(tester, age);
        await finishAvatar(tester);

        final band = ageBandFromAge(age);
        expect(innerController(tester).page, 4, reason: 'age $age');
        expect(wizardData.selectedArchetypeId,
            CharacterArchetypes.forBand(band).first.name,
            reason: 'age $age');
        expect(wizardData.heroSuperpower,
            CharacterArchetypes.forBand(band).first.specialAbility,
            reason: 'age $age');
        expect(find.text('Choose your archetype'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
    });

    // Age 4 is left out: the Sprout archetype cards use WiggleWidget, whose
    // initState reads MediaQuery (a debug-mode assertion that predates this
    // change and fires whenever that page is built in a test).
    testWidgets('second story (storiesCreated = 1): avatar lands on the '
        'archetype page', (tester) async {
      for (final age in [7, 10]) {
        seedStories(1);
        AvatarGenerationState().reset();
        await pumpStep(tester, age);
        await finishAvatar(tester);

        expect(innerController(tester).page, 3, reason: 'age $age');
        expect(wizardData.selectedArchetypeId, isNull, reason: 'age $age');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('first run: scene continues straight to review with the '
        'default story type', (tester) async {
      for (final age in [4, 7, 10]) {
        seedStories(0);
        await pumpStep(tester, age, subStep: 2);
        // Non-default leftovers must be reset by the fast path.
        wizardData.rhymeTimeMode = true;
        wizardData.includeIllustrations = false;

        final arrow = find.byType(PressableArrowButton);
        await tester.ensureVisible(arrow);
        await tester.tap(arrow, warnIfMissed: false);
        await pumpFor(tester, const Duration(milliseconds: 600));

        expect(nextCalls, 1, reason: 'age $age');
        expect(wizardData.rhymeTimeMode, isFalse, reason: 'age $age');
        expect(wizardData.includeIllustrations, isTrue, reason: 'age $age');
        expect(wizardData.interactiveMode, isFalse, reason: 'age $age');
        expect(wizardData.storyLength, 'standard', reason: 'age $age');
        await pumpFor(tester, const Duration(seconds: 3)); // drain timers
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('second story: scene continues to the story-kind page',
        (tester) async {
      seedStories(1);
      await pumpStep(tester, 10, subStep: 2);

      final arrow = find.byType(PressableArrowButton);
      await tester.ensureVisible(arrow);
      await tester.tap(arrow, warnIfMissed: false);
      await pumpFor(tester, const Duration(milliseconds: 600));

      expect(nextCalls, 0);
      expect(innerController(tester).page, 6);
      await pumpFor(tester, const Duration(seconds: 3)); // drain timers
    });
  });

  group('HeroStoryTypePage "More options"', () {
    Future<WizardData> pumpPage(WidgetTester tester, int age) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final data = WizardData()
        ..characterName = 'Max'
        ..characterAge = age;
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [themeForAge(age)]),
          home: Scaffold(
            body: HeroStoryTypePage(
              wizardData: data,
              wishController: controller,
              listeningFor: '',
              speechAvailable: false,
              onChanged: () {},
              onContinue: () {},
              onToggleListening: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      return data;
    }

    Future<void> expand(WidgetTester tester) async {
      final row = find.text('More options');
      await tester.ensureVisible(row);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(row);
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('explorer: wishes start folded and expand on tap',
        (tester) async {
      await pumpPage(tester, 7);
      expect(find.text('More options'), findsOneWidget);
      expect(find.text('Fly in the sky'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      await expand(tester);
      expect(find.text('Fly in the sky', skipOffstage: false), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
    });

    testWidgets('adventurer: genre, personality and wish field start folded',
        (tester) async {
      await pumpPage(tester, 10);
      expect(find.text('More options'), findsOneWidget);
      expect(find.text('Add a genre twist (optional)'), findsNothing);
      expect(find.text('Add a personality twist (optional)'), findsNothing);
      expect(find.text('Anything special you want?'), findsNothing);

      await expand(tester);
      expect(find.text('Add a genre twist (optional)', skipOffstage: false),
          findsOneWidget);
      expect(
          find.text('Add a personality twist (optional)', skipOffstage: false),
          findsOneWidget);
      expect(find.text('Anything special you want?', skipOffstage: false),
          findsOneWidget);
    });

    testWidgets('sprout has no More options row', (tester) async {
      await pumpPage(tester, 4);
      expect(find.text('More options'), findsNothing);
    });
  });
}
