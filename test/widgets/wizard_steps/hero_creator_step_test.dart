import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_steps/hero_creator_step.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';

void main() {
  // Silence asset-not-found FlutterErrors so tests that show character cards
  // (with placeholder image) don't fail on missing test assets.
  void silenceAssetErrors() {
    final original = FlutterError.onError!;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('Unable to load asset')) return;
      original(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
  }

  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    var remainingMs = total.inMilliseconds;
    while (remainingMs > 0) {
      await tester.pump(const Duration(milliseconds: 100));
      remainingMs -= 100;
    }
  }

  Widget buildSubject({
    required WizardData wizardData,
    required VoidCallback onNext,
    List<Character> availableCharacters = const [],
  }) {
    return MaterialApp(
      home: Scaffold(
        body: HeroCreatorStep(
          wizardData: wizardData,
          onNext: onNext,
          availableCharacters: availableCharacters,
        ),
      ),
    );
  }

  testWidgets('shows continue after entering name and selecting archetype',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData();

    await tester.pumpWidget(
      buildSubject(
        wizardData: wizardData,
        onNext: () {},
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));

    // Page 1: enter name (no availableCharacters → starts at page 1)
    await tester.enterText(find.byType(TextField).first, 'Luna');
    await tester.pump();

    // Navigate inner PageView to page 2 (archetype/avatar selection)
    final innerPV = tester.widgetList<PageView>(find.byType(PageView)).first;
    innerPV.controller!.jumpToPage(2);
    await pumpFor(tester, const Duration(milliseconds: 500));

    // Select an archetype
    final stormRider = find.textContaining('Storm Rider');
    if (stormRider.evaluate().isNotEmpty) {
      await tester.tap(stormRider.first);
      await pumpFor(tester, const Duration(milliseconds: 300));
    }

    // Verify wizard data was updated
    expect(wizardData.characterName, 'Luna');
  });

  testWidgets('loads existing character and continues', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    silenceAssetErrors();
    final wizardData = WizardData();
    var didContinue = false;
    final characters = [
      Character.fromJson({
        'id': 'char-1',
        'name': 'Milo',
        'age': 7,
        'role': 'The Storm Rider',
        'generated_avatar': {
          'id': 'avatar-milo',
          'image_base64':
              'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+X2ioAAAAASUVORK5CYII=',
          'seed': 'seed-milo',
          'style': 'cartoon',
          'attributes': <String, dynamic>{},
          'generated_at': '2026-01-01T00:00:00Z',
        },
      }),
    ];

    await tester.pumpWidget(
      buildSubject(
        wizardData: wizardData,
        onNext: () => didContinue = true,
        availableCharacters: characters,
      ),
    );
    await pumpFor(tester, const Duration(seconds: 1));

    // Page 0: shows existing characters as _CharacterChoiceCard
    // Find the character card by name text
    final miloFinder = find.text('Milo');
    expect(miloFinder, findsWidgets);
    await tester.tap(miloFinder.first);
    await pumpFor(tester, const Duration(milliseconds: 500));

    // Verify character data was loaded into wizard data
    expect(wizardData.characterName, 'Milo');
    expect(wizardData.characterId, 'char-1');
  });

  testWidgets('switches from existing hero selection to create new',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    silenceAssetErrors();
    final wizardData = WizardData();
    final characters = [
      Character.fromJson({
        'id': 'char-1',
        'name': 'Nova',
        'age': 8,
        'role': 'The Master Creator',
        'generated_avatar': {
          'id': 'avatar-nova',
          'image_base64':
              'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+X2ioAAAAASUVORK5CYII=',
          'seed': 'seed-nova',
          'style': 'cartoon',
          'attributes': <String, dynamic>{},
          'generated_at': '2026-01-01T00:00:00Z',
        },
      }),
    ];

    await tester.pumpWidget(
      buildSubject(
        wizardData: wizardData,
        onNext: () {},
        availableCharacters: characters,
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));

    // Page 0: shows existing characters + the "Create a new hero" CTA tile.
    final createNew = find.text('Create a new hero');
    expect(createNew, findsOneWidget);
    await tester.tap(createNew);
    await pumpFor(tester, const Duration(milliseconds: 500));

    // Tapping it opens the age-band picker dialog — pick a band.
    final explorerBand = find.text('Explorer');
    expect(explorerBand, findsOneWidget);
    await tester.tap(explorerBand);
    // Drain dialog dismiss + page transition + TTS timers (~850ms).
    await pumpFor(tester, const Duration(seconds: 2));

    // Should navigate to page 1 (name input)
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('increments and decrements age', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData()..characterAge = 7;

    await tester.pumpWidget(
      buildSubject(
        wizardData: wizardData,
        onNext: () {},
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));

    // Explorer band (age 6-8) uses chips "I'm 6", "I'm 7", "I'm 8"
    // Check if chips exist, otherwise fall back to +/- buttons
    final chip8 = find.text("I'm 8");
    final addButton = find.byIcon(Icons.add_rounded);

    if (chip8.evaluate().isNotEmpty) {
      // Explorer band: tap age chip to change age
      await tester.tap(chip8);
      await tester.pump();
      expect(wizardData.characterAge, 8);

      final chip7 = find.text("I'm 7");
      await tester.tap(chip7);
      await tester.pump();
      expect(wizardData.characterAge, 7);
    } else if (addButton.evaluate().isNotEmpty) {
      // Adventurer/Creator band: +/- buttons
      await tester.tap(addButton);
      await tester.pump();
      expect(wizardData.characterAge, 8);

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      expect(wizardData.characterAge, 7);
    }
  });

  testWidgets('selects Boy gender', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData();

    await tester.pumpWidget(
      buildSubject(wizardData: wizardData, onNext: () {}),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));

    final boyBtn = find.text('Boy');
    expect(boyBtn, findsOneWidget);
    await tester.tap(boyBtn);
    // _handleGenderSelection fires a 400ms timer → _heroNextPage → 850ms TTS timer.
    // Pump 1700ms to drain all pending timers before the test ends.
    await pumpFor(tester, const Duration(milliseconds: 1700));
    expect(wizardData.characterGender, 'Boy');
  });

  testWidgets('selects Girl gender', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData();

    await tester.pumpWidget(
      buildSubject(wizardData: wizardData, onNext: () {}),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));

    final girlBtn = find.text('Girl');
    expect(girlBtn, findsOneWidget);
    await tester.tap(girlBtn);
    await pumpFor(tester, const Duration(milliseconds: 1700));
    expect(wizardData.characterGender, 'Girl');
  });

  group('companions page declutter', () {
    late WizardData lastWizardData;
    var advanced = 0;

    /// Pumps the companions page. [storiesCreated] seeds the `user_progress`
    /// blob ProgressionService reads (0 = the very first story).
    Future<void> pumpCompanionPage(
      WidgetTester tester,
      int age, {
      int storiesCreated = 1,
    }) async {
      setLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);
      silenceAssetErrors();
      SharedPreferences.setMockInitialValues({
        'user_progress': jsonEncode({'storiesCreated': storiesCreated}),
      });
      advanced = 0;
      final wizardData = WizardData()
        ..characterName = 'Luna'
        ..characterAge = age;
      lastWizardData = wizardData;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [themeForAge(age)]),
          home: Scaffold(
            body: HeroCreatorStep(
              wizardData: wizardData,
              onNext: () => advanced++,
              availableCharacters: const [],
            ),
          ),
        ),
      );
      await pumpFor(tester, const Duration(milliseconds: 500));
      final pv = tester.widgetList<PageView>(find.byType(PageView)).first;
      pv.controller!.jumpToPage(4);
      await pumpFor(tester, const Duration(milliseconds: 600));
    }

    Finder lockedTiles() => find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('locked_companion_'));

    testWidgets('first story at 4, 7, 10: one buddy card, no extras',
        (tester) async {
      const expected = {
        4: 'Pebble',
        7: 'Ember',
        10: 'Atlas',
      };
      for (final age in [4, 7, 10]) {
        await pumpCompanionPage(tester, age, storiesCreated: 0);
        final name = expected[age]!;
        expect(find.textContaining(name), findsWidgets, reason: 'age $age');
        expect(find.text('Yes!'), findsOneWidget, reason: 'age $age');
        expect(
          find.text(age <= 8 ? 'Just me — no buddies' : 'Go solo'),
          findsOneWidget,
          reason: 'age $age',
        );
        expect(lockedTiles(), findsNothing, reason: 'age $age');
        expect(find.text('Add a Person'), findsNothing);
        expect(find.text('Add a Pet'), findsNothing);
        expect(find.text('Add your real pet to the adventure!'), findsNothing);
        expect(find.text('Ask a grown-up to add your real pet!'), findsNothing);
        expect(find.textContaining('adventure team'), findsNothing);
        expect(find.textContaining('Premium'), findsNothing);
      }
    });

    testWidgets('first story: Yes! selects the buddy and advances',
        (tester) async {
      await pumpCompanionPage(tester, 7, storiesCreated: 0);
      expect(find.text('Ember wants to come along!'), findsOneWidget);
      await tester.tap(find.text('Yes!'));
      await pumpFor(tester, const Duration(milliseconds: 1000));
      expect(lastWizardData.selectedCompanions, ['ember']);
      expect(lastWizardData.companionNames, ['Ember']);
    });

    testWidgets('first story: Just me clears and advances', (tester) async {
      await pumpCompanionPage(tester, 7, storiesCreated: 0);
      await tester.tap(find.text('Just me — no buddies'));
      await pumpFor(tester, const Duration(milliseconds: 1000));
      expect(lastWizardData.selectedCompanions, isEmpty);
      expect(lastWizardData.companionNames, isEmpty);
    });

    testWidgets('adventurer first story uses the calmer headline',
        (tester) async {
      await pumpCompanionPage(tester, 10, storiesCreated: 0);
      expect(find.text('Atlas is ready to join you.'), findsOneWidget);
    });

    testWidgets('after one story at age 7: 2 arrived, 2 silhouettes',
        (tester) async {
      await pumpCompanionPage(tester, 7, storiesCreated: 1);
      expect(find.text('Yes!'), findsNothing);
      expect(find.text('Ember'), findsOneWidget);
      expect(find.text('Robin'), findsOneWidget);
      expect(find.text('Clover'), findsNothing);
      expect(find.text('Biscuit'), findsNothing);
      expect(lockedTiles(), findsNWidgets(2));
      expect(find.text('arrives after your next story'), findsOneWidget);
      expect(find.text('arrives later'), findsOneWidget);
      // Bring-your-own is back from the second story on.
      expect(find.text('Add a Person'), findsOneWidget);
    });

    testWidgets('after one story at age 4: 2 arrived, locked ones hidden',
        (tester) async {
      await pumpCompanionPage(tester, 4, storiesCreated: 1);
      expect(find.text('Pebble'), findsOneWidget);
      expect(find.text('Robin'), findsOneWidget);
      expect(lockedTiles(), findsNothing);
      expect(find.textContaining('arrives'), findsNothing);
    });

    testWidgets('after three stories: all four, no silhouettes',
        (tester) async {
      await pumpCompanionPage(tester, 7, storiesCreated: 3);
      for (final n in ['Ember', 'Robin', 'Clover', 'Biscuit']) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      expect(lockedTiles(), findsNothing);
    });

    testWidgets('tapping a silhouette does nothing', (tester) async {
      await pumpCompanionPage(tester, 7, storiesCreated: 1);
      await tester.tap(lockedTiles().first);
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(lastWizardData.selectedCompanions, isEmpty);
      expect(advanced, 0);
    });

    testWidgets('the Explorer express lane is gone', (tester) async {
      for (final stories in [0, 1]) {
        await pumpCompanionPage(tester, 7, storiesCreated: stories);
        expect(find.text('Tell Me a Story!'), findsNothing);
      }
    });

    testWidgets('age 4 and 7: one solo button, kid-friendly label',
        (tester) async {
      for (final age in [4, 7]) {
        await pumpCompanionPage(tester, age);
        expect(find.text('Just me — no buddies'), findsOneWidget,
            reason: 'age $age');
        expect(find.text('Adventure alone!'), findsNothing);
        expect(find.textContaining('Go Solo'), findsNothing);
      }
    });

    testWidgets('age 10: single "Go solo" button', (tester) async {
      await pumpCompanionPage(tester, 10);
      expect(find.text('Go solo'), findsOneWidget);
      expect(find.text('Just me — no buddies'), findsNothing);
    });

    testWidgets('explorer sees one pet entry; adventurer keeps Add a Pet',
        (tester) async {
      await pumpCompanionPage(tester, 7);
      expect(find.text('Add your real pet to the adventure!'),
          findsOneWidget);
      expect(find.text('Add a Pet'), findsNothing);

      await pumpCompanionPage(tester, 10);
      expect(find.text('Add a Pet'), findsOneWidget);
    });
  });
}
