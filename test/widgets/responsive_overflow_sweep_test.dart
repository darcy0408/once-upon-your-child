// DIAGNOSTIC HARNESS — responsive overflow sweep.
//
// Pumps the app's pumpable widgets across phone widths (320/360/390/430) and
// all six age bands, and records every RenderFlex / RenderBox overflow that
// Flutter reports during layout+paint.
//
// How the detection works: in debug builds an overflowing render box reports a
// FlutterError ("A RenderFlex overflowed by N pixels on the right."). Inside a
// widget test that error is routed through `FlutterError.onError`, so we can
// install our own collector, pump, and read the messages back — no screenshots
// and no golden files required.
//
// This file asserts nothing about specific widgets on purpose: it is a REPORT.
// It fails only if a subject cannot be pumped at all. The table is printed by
// `tearDownAll` at the end of the run.
//
// TWO THINGS TO KNOW BEFORE TRUSTING A ROW:
//
//  1. `flutter test` renders every glyph with a square fallback font (advance
//     == fontSize), which is roughly twice the width of the real UI fonts.
//     Overflows caused purely by text width are therefore often artefacts.
//     Every case is pumped twice — normal and with text shrunk to
//     `_kShrunkTextScale` — and the report splits GEOMETRY-DRIVEN (still
//     overflows with tiny text; trust it) from TEXT-METRIC-DRIVEN (confirm in
//     the real app first).
//
//  2. An overflow is reported once per render object, at PAINT time. For a
//     long full-screen subject, whether a given box paints in the frames we
//     pump is not perfectly stable run to run, so a full-screen subject can
//     under-report. Anything worth pinning should also get its own small
//     component-level case (see `GenderRow[brief 130/28]`).
//
// Run:  flutter test test/widgets/responsive_overflow_sweep_test.dart
//
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_steps/hero_creator_creative_brief.dart';
import 'package:story_weaver_app/screens/wizard_steps/hero_creator_step.dart';
import 'package:story_weaver_app/screens/wizard_steps/magic_review_step.dart';
import 'package:story_weaver_app/services/child_profile_service.dart';
import 'package:story_weaver_app/theme/age_band_asset_resolver.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/widgets/adventurer_character_sheet.dart';
import 'package:story_weaver_app/widgets/app_bottom_navigation.dart';
import 'package:story_weaver_app/widgets/child_profile_switcher.dart';
import 'package:story_weaver_app/widgets/crisis_resources_panel.dart';
import 'package:story_weaver_app/widgets/error_message.dart';
import 'package:story_weaver_app/widgets/feelings_badge_grid.dart';
import 'package:story_weaver_app/widgets/hero_creator/hero_input_widgets.dart';
import 'package:story_weaver_app/widgets/make_magic_button.dart';
import 'package:story_weaver_app/widgets/mission_ready_button.dart';
import 'package:story_weaver_app/widgets/moon_phase_progress.dart';
import 'package:story_weaver_app/widgets/story_generation_progress.dart';
import 'package:story_weaver_app/widgets/storybook_progress_indicator.dart';

// ---------------------------------------------------------------------------
// Sweep matrix
// ---------------------------------------------------------------------------

const List<double> kWidths = <double>[320, 360, 390, 430];

Size _surfaceFor(double width) =>
    Size(width, width == 320 ? 568 : 740); // iPhone SE vs modern phone

const List<AgeBandThemeData> kBands = <AgeBandThemeData>[
  sproutTheme,
  explorerTheme,
  adventurerTheme,
  creatorTheme,
  adolescentTheme,
  adultTheme,
];

const List<AgeBandThemeData> kMatureBands = <AgeBandThemeData>[
  creatorTheme,
  adolescentTheme,
  adultTheme,
];

int _ageFor(AgeBand band) {
  switch (band) {
    case AgeBand.sprout:
      return 4;
    case AgeBand.explorer:
      return 7;
    case AgeBand.adventurer:
      return 10;
    case AgeBand.creator:
      return 13;
    case AgeBand.adolescent:
      return 16;
    case AgeBand.adult:
      return 25;
  }
}

// ---------------------------------------------------------------------------
// Result collection
// ---------------------------------------------------------------------------

/// Text scale used for the discriminator pass. Real proportional UI fonts are
/// roughly half the advance width of the square fallback glyphs `flutter test`
/// substitutes, so this approximates "what this would look like with the real
/// font" without needing the font itself.
const double _kShrunkTextScale = 0.45;

class _Finding {
  _Finding({
    required this.subject,
    required this.band,
    required this.width,
    required this.pixels,
    required this.side,
    required this.renderObject,
    required this.culprit,
    required this.geometryDriven,
  });

  final String subject;
  final String band;
  final double width;
  final double pixels;
  final String side;
  final String renderObject;

  /// `file.dart:line:col` of the widget Flutter blamed, when it can be
  /// recovered from the error's `DebugCreator` information.
  final String culprit;

  /// True when the same box still overflows with text shrunk to
  /// [_kShrunkTextScale] — i.e. fixed sizes, not text metrics, are the cause.
  /// False means the finding is probably an artefact of the wide test font and
  /// needs confirming against the real app before anyone "fixes" it.
  final bool geometryDriven;
}

final List<_Finding> _overflows = <_Finding>[];
final List<String> _otherErrors = <String>[];
final List<String> _pumpFailures = <String>[];
final Set<String> _subjectsSwept = <String>{};

final RegExp _overflowRe =
    RegExp(r'A (\w+) overflowed by ([\d.]+) pixels on the (\w+)');

/// Errors that are artefacts of the test environment, not layout problems.
bool _isBenign(String message) {
  return message.contains('Unable to load asset') ||
      message.contains('ink_sparkle.frag') ||
      message.contains('MissingPluginException') ||
      message.contains('Could not load font') ||
      message.contains('google_fonts was unable to load font');
}

/// Pulls `lib/…/file.dart:line:col` out of the "relevant error-causing widget"
/// block that `DebugCreator` attaches to rendering-library errors.
const bool kResolveCulprits =
    bool.fromEnvironment('SWEEP_CULPRITS', defaultValue: true);

String _culpritOf(FlutterErrorDetails details) {
  if (!kResolveCulprits) return '';
  late final String dump;
  try {
    dump = details.toString();
  } catch (_) {
    return '';
  }
  final marker = dump.indexOf('The relevant error-causing widget was');
  if (marker < 0) return '';
  final lines = dump
      .substring(marker)
      .split('\n')
      .skip(1)
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .take(3)
      .toList();
  final locRe = RegExp(r'([\w/]+\.dart):(\d+):\d+');
  for (final line in lines) {
    final loc = locRe.firstMatch(line);
    if (loc != null) {
      final path = loc.group(1)!;
      final short = path.split('/').last;
      final widget = lines.first.split(' ').first;
      return '$widget @ $short:${loc.group(2)}';
    }
  }
  return lines.isEmpty ? '' : lines.first.split(' ').first;
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  var remaining = total.inMilliseconds;
  while (remaining > 0) {
    await tester.pump(const Duration(milliseconds: 100));
    remaining -= 100;
  }
}

/// One (summary, culprit) pair harvested from a single pumped frame set.
typedef _Captured = (String summary, String culprit);

/// Pumps [builder] once at ([band], [width], [textScale]) and returns
/// everything Flutter complained about while it was on screen.
Future<List<_Captured>> _pumpVariant(
  WidgetTester tester, {
  required String subject,
  required AgeBandThemeData band,
  required double width,
  required Widget Function(AgeBandThemeData band) builder,
  required bool fullScreen,
  required bool withProviderScope,
  required Duration settle,
  required double textScale,
  required bool recordFailures,
}) async {
  // Collect the raw details only. Rendering an error to a string DURING the
  // paint pass that produced it perturbs the pass and silently swallows the
  // overflow reports that would have followed it, so culprit resolution is
  // deferred until after the frame settles (while the tree is still mounted).
  final rawDetails = <FlutterErrorDetails>[];
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = rawDetails.add;

  final size = _surfaceFor(width);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  await tester.binding.setSurfaceSize(size);

  Widget child;
  try {
    child = builder(band);
  } catch (e) {
    FlutterError.onError = previous;
    if (recordFailures) {
      _pumpFailures
          .add('$subject / ${band.band.name} / $width: build() threw $e');
    }
    return const <_Captured>[];
  }

  // Component-level subjects are measured at the given WIDTH with unbounded
  // height — that is how they sit inside the app's scrolling pages, and it
  // isolates width-driven overflow from "this screen is taller than 740px".
  // Full-screen subjects manage their own scrolling and get the real surface.
  if (!fullScreen) {
    child = Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(child: child),
    );
  }

  Widget app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(extensions: <ThemeExtension<dynamic>>[band]),
    builder: (context, inner) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: inner!,
    ),
    home: Scaffold(backgroundColor: Colors.black, body: child),
  );
  if (withProviderScope) {
    app = ProviderScope(child: app);
  }

  try {
    await tester.pumpWidget(app);
    await _pumpFor(tester, settle);
  } catch (e) {
    if (recordFailures) {
      _pumpFailures.add('$subject / ${band.band.name} / $width: pump threw $e');
    }
  }

  // Resolve culprits while the element tree is still mounted.
  final captured = <(String, String)>[]; // (summary, culprit)
  for (final details in List<FlutterErrorDetails>.of(rawDetails)) {
    final summary = details.exceptionAsString();
    captured.add((summary, _isBenign(summary) ? '' : _culpritOf(details)));
  }

  // Tear the tree down inside the case so tickers/timers belonging to this
  // subject are disposed before the next size is applied.
  try {
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFor(tester, const Duration(milliseconds: 300));
  } catch (_) {
    // Teardown noise is not interesting for a layout sweep.
  }

  FlutterError.onError = previous;
  final pending = tester.takeException();
  if (pending != null) {
    captured.add((pending.toString(), ''));
  }
  return captured;
}

/// Identity of an overflowing box, independent of how many pixels it spilled —
/// used to match the same box across the normal and shrunk-text passes.
String _boxKey(RegExpMatch m, String culprit) =>
    '${m.group(1)}|${m.group(3)}|$culprit';

/// Pumps one (subject, band, width) twice — once with normal text metrics and
/// once with text shrunk to [_kShrunkTextScale] — and files the findings.
///
/// Why twice: `flutter test` renders every glyph with the fallback test font,
/// whose characters are square (advance == fontSize). Real UI fonts are far
/// narrower, so a Row that only overflows because of text width is very likely
/// a TEST ARTEFACT. A box that still overflows with text shrunk to 45% is
/// geometry-driven (fixed widths/heights) and is a real layout bug.
Future<void> _pumpOne(
  WidgetTester tester, {
  required String subject,
  required AgeBandThemeData band,
  required double width,
  required Widget Function(AgeBandThemeData band) builder,
  required bool fullScreen,
  required bool withProviderScope,
  required Duration settle,
}) async {
  final normal = await _pumpVariant(
    tester,
    subject: subject,
    band: band,
    width: width,
    builder: builder,
    fullScreen: fullScreen,
    withProviderScope: withProviderScope,
    settle: settle,
    textScale: 1.0,
    recordFailures: true,
  );
  final shrunk = await _pumpVariant(
    tester,
    subject: subject,
    band: band,
    width: width,
    builder: builder,
    fullScreen: fullScreen,
    withProviderScope: withProviderScope,
    settle: settle,
    textScale: _kShrunkTextScale,
    recordFailures: false,
  );

  final shrunkKeys = <String>{};
  for (final (message, culprit) in shrunk) {
    if (_isBenign(message)) continue;
    final m = _overflowRe.firstMatch(message);
    if (m != null) shrunkKeys.add(_boxKey(m, culprit));
  }

  final seen = <String>{};
  for (final (message, culprit) in normal) {
    if (_isBenign(message)) continue;
    final match = _overflowRe.firstMatch(message);
    if (match != null) {
      final key =
          '${match.group(1)}|${match.group(2)}|${match.group(3)}|$culprit';
      if (!seen.add(key)) continue; // same box re-reported across frames
      _overflows.add(_Finding(
        subject: subject,
        band: band.band.name,
        width: width,
        pixels: double.parse(match.group(2)!),
        side: match.group(3)!,
        renderObject: match.group(1)!,
        culprit: culprit,
        geometryDriven: shrunkKeys.contains(_boxKey(match, culprit)),
      ));
    } else {
      final firstLine = message.split('\n').first;
      _otherErrors.add('$subject / ${band.band.name} / $width: $firstLine');
    }
  }
}

/// Sweeps one subject across every band x width in the matrix.
Future<void> sweep(
  WidgetTester tester,
  String subject,
  Widget Function(AgeBandThemeData band) builder, {
  bool fullScreen = false,
  bool withProviderScope = false,
  Duration settle = const Duration(milliseconds: 400),
  List<AgeBandThemeData> bands = kBands,
}) async {
  _subjectsSwept.add(subject);
  for (final band in bands) {
    for (final width in kWidths) {
      await _pumpOne(
        tester,
        subject: subject,
        band: band,
        width: width,
        builder: builder,
        fullScreen: fullScreen,
        withProviderScope: withProviderScope,
        settle: settle,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

String _genderAsset(AgeBand band, {required bool boy}) {
  // Delegates to the shared resolver rather than keeping a fourth copy of this
  // mapping — the copies had drifted apart on file extensions, which is what
  // blanked the 9-to-12 gender cards in the first place.
  return AgeBandAssetResolver.genderPath(band, boy ? 'boy' : 'girl');
}

WizardData _filledWizardData(AgeBand band) {
  return WizardData()
    ..characterName = 'Alexandria'
    ..characterAge = _ageFor(band)
    ..characterGender = 'Girl'
    ..selectedArchetypeId = 'The Storm Rider'
    ..selectedScenario = 'dragon_egg'
    ..selectedCompanions = <String>['Robin', 'Sparkle the Dragon']
    ..customElements = 'A rainbow castle and a puzzle box.';
}

void main() {
  // ==========================================================================
  // CONTROL CASE — validates that the harness actually SEES an overflow.
  //
  // Two GenderImageButtons at the authored width of 140 plus a band-scaled
  // 32px gap plus the selection border drawn OUTSIDE the fixed child. This is
  // the layout the hero-creator step used before it was made responsive.
  // ==========================================================================
  testWidgets('CONTROL: gender row with hard-coded width:140', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await sweep(
      tester,
      'GenderRow[hard-coded 140]',
      (band) => Padding(
        padding: EdgeInsets.symmetric(horizontal: band.space(24)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GenderImageButton(
              gender: 'Boy',
              assetPath: _genderAsset(band.band, boy: true),
              isSelected: true,
              width: 140,
              height: 180,
              onTap: () {},
            ),
            SizedBox(width: band.space(32)),
            GenderImageButton(
              gender: 'Girl',
              assetPath: _genderAsset(band.band, boy: false),
              isSelected: false,
              width: 140,
              height: 180,
              onTap: () {},
            ),
          ],
        ),
      ),
      settle: const Duration(milliseconds: 300),
    );

    // The whole point of the control: if this stops overflowing, the harness
    // has gone blind and every "clean" result below is meaningless.
    expect(
      _overflows.where((f) => f.subject == 'GenderRow[hard-coded 140]'),
      isNotEmpty,
      reason: 'harness failed to detect a known overflow',
    );
  });

  // ==========================================================================
  // The same row, sized the way hero_creator_step.dart now sizes it.
  // ==========================================================================
  testWidgets('gender row with responsive LayoutBuilder sizing',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await sweep(
      tester,
      'GenderRow[responsive]',
      (band) => Padding(
        padding: EdgeInsets.symmetric(horizontal: band.space(24)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gap = band.space(32);
            const borderAllowance = 2 * 2 * kGenderSelectedBorder;
            final available = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : kGenderCardMaxWidth * 2 + gap + borderAllowance;
            final cardWidth = ((available - gap - borderAllowance) / 2)
                .clamp(88.0, kGenderCardMaxWidth);
            final cardHeight = cardWidth * (180 / 140);
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GenderImageButton(
                  gender: 'Boy',
                  assetPath: _genderAsset(band.band, boy: true),
                  isSelected: true,
                  width: cardWidth,
                  height: cardHeight,
                  onTap: () {},
                ),
                SizedBox(width: gap),
                GenderImageButton(
                  gender: 'Girl',
                  assetPath: _genderAsset(band.band, boy: false),
                  isSelected: false,
                  width: cardWidth,
                  height: cardHeight,
                  onTap: () {},
                ),
              ],
            );
          },
        ),
      ),
      settle: const Duration(milliseconds: 300),
    );
  });

  // ==========================================================================
  // The mature-band Creative Brief gender picker, before and after it was made
  // responsive. Pumped standalone (rather than relying on the full-screen
  // CreativeBriefWidget case) because an overflow is only reported for a box
  // that actually paints, and the brief is long enough that a full-screen pump
  // does not report it reliably frame to frame.
  //
  // "pre-fix" = the old hard-coded 130x170 cards + 28px gap. Kept as a second
  // control: it must overflow, or the sweep is not measuring anything.
  // "responsive" mirrors hero_creator_creative_brief.dart:290-330 as it stands
  // now, inside that screen's own 24px horizontal padding.
  // ==========================================================================
  Widget briefGenderRow(AgeBandThemeData band, {required bool responsive}) {
    Widget card(bool boy, double w, double h) => GenderImageButton(
          gender: boy ? 'Boy' : 'Girl',
          assetPath: _genderAsset(band.band, boy: boy),
          isSelected: !boy,
          width: w,
          height: h,
          onTap: () {},
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: responsive
          ? LayoutBuilder(
              builder: (context, constraints) {
                const gap = 28.0;
                const maxCard = 130.0;
                const borderAllowance = 2 * 2 * kGenderSelectedBorder;
                final available = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : maxCard * 2 + gap + borderAllowance;
                final cardWidth = ((available - gap - borderAllowance) / 2)
                    .clamp(84.0, maxCard);
                final cardHeight = cardWidth * (170 / 130);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    card(true, cardWidth, cardHeight),
                    const SizedBox(width: gap),
                    card(false, cardWidth, cardHeight),
                  ],
                );
              },
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                card(true, 130, 170),
                const SizedBox(width: 28),
                card(false, 130, 170),
              ],
            ),
    );
  }

  testWidgets('Creative Brief gender row, pre-fix hard-coded 130/28',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await sweep(
      tester,
      'GenderRow[brief pre-fix]',
      (band) => briefGenderRow(band, responsive: false),
      bands: kMatureBands,
      settle: const Duration(milliseconds: 300),
    );
  });

  testWidgets('Creative Brief gender row, current responsive sizing',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await sweep(
      tester,
      'GenderRow[brief responsive]',
      (band) => briefGenderRow(band, responsive: true),
      bands: kMatureBands,
      settle: const Duration(milliseconds: 300),
    );
  });

  // ==========================================================================
  // Full-screen subjects
  // ==========================================================================

  testWidgets('HeroCreatorStep (whole wizard step 1)', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await sweep(
      tester,
      'HeroCreatorStep',
      (band) => HeroCreatorStep(
        wizardData: WizardData()..characterAge = _ageFor(band.band),
        onNext: () {},
        availableCharacters: const <Character>[],
      ),
      fullScreen: true,
      withProviderScope: true,
      settle: const Duration(milliseconds: 2000),
    );
  });

  testWidgets('MagicReviewStep (whole review step)', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await sweep(
      tester,
      'MagicReviewStep',
      (band) => MagicReviewStep(
        wizardData: _filledWizardData(band.band),
        onGoToSubStep: (_) {},
      ),
      fullScreen: true,
      settle: const Duration(milliseconds: 1200),
    );
  });

  testWidgets('CreativeBriefWidget (mature-band brief form)', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await sweep(
      tester,
      'CreativeBriefWidget',
      (band) => CreativeBriefWidget(
        wizardData: _filledWizardData(band.band),
        availableCharacters: const <Character>[],
        briefScrollController: ScrollController(),
        briefCharacterKey: GlobalKey(),
        briefCompanionsKey: GlobalKey(),
        briefWorldKey: GlobalKey(),
        briefConfigKey: GlobalKey(),
        briefCharacterController: ExpansibleController(),
        briefCompanionsController: ExpansibleController(),
        briefWorldController: ExpansibleController(),
        briefConfigController: ExpansibleController(),
        nameController: TextEditingController(text: 'Alexandria'),
        characterDesireController: TextEditingController(),
        imagineItController: TextEditingController(),
        wishController: TextEditingController(),
        selectedArchetypeId: 'The Storm Rider',
        onChanged: () {},
        onContinue: () {},
        onLoadCharacter: (_) {},
        onSelectArchetype: (_) {},
        companionShowcase: const SizedBox.shrink(),
        companionGrid: const SizedBox.shrink(),
      ),
      fullScreen: true,
      bands: kMatureBands,
      settle: const Duration(milliseconds: 800),
    );
  });

  testWidgets('FeelingsBadgeGrid (2-col emotion grid)', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await sweep(
      tester,
      'FeelingsBadgeGrid',
      (band) => FeelingsBadgeGrid(onSelected: (_) {}, band: band.band),
      fullScreen: true,
      settle: const Duration(milliseconds: 300),
    );
  });

  // ==========================================================================
  // Component-level subjects (measured at width, unbounded height)
  // ==========================================================================

  testWidgets('AdventurerCharacterSheet', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await sweep(
      tester,
      'AdventurerCharacterSheet',
      (band) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AdventurerCharacterSheet(
          wizardData: _filledWizardData(band.band),
          band: band,
          heroAvatar: const ColoredBox(color: Colors.blueGrey),
          onTapName: () {},
          onTapParty: () {},
        ),
      ),
      settle: const Duration(milliseconds: 300),
    );
  });

  testWidgets('AppBottomNavigationBar', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await sweep(
      tester,
      'AppBottomNavigationBar',
      (band) => AppBottomNavigationBar(
        currentIndex: 0,
        onTap: (_) {},
        childAge: _ageFor(band.band),
      ),
      settle: const Duration(milliseconds: 300),
    );
  });

  testWidgets('MoonPhaseProgress (4-step wizard tracker)', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // NOTE: wizard_story_screen.dart wraps this in FittedBox(scaleDown), which
    // hands it unbounded width — so overflow here is latent, not user-visible
    // at that call site. It matters for any future un-fitted call site.
    await sweep(
      tester,
      'MoonPhaseProgress',
      (band) => MoonPhaseProgress(
        currentStep: 1,
        totalSteps: 4,
        stepLabels: <String>[
          'My Character',
          'My Companions',
          'My Setting',
          band.launchStoryLabel,
        ],
        stepIcons: band.band == AgeBand.sprout
            ? const <String>['*', 'D', 'R', '+']
            : null,
        onStepTap: (_) {},
      ),
      settle: const Duration(milliseconds: 300),
    );
  });

  testWidgets('StorybookProgressIndicator', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await sweep(
      tester,
      'StorybookProgressIndicator[5 pages]',
      (band) => const StorybookProgressIndicator(
        currentPage: 3,
        totalPages: 5,
        stageLabel: 'The Great Discovery!',
      ),
      settle: const Duration(milliseconds: 200),
    );
  });

  testWidgets('CrisisResourcesPanel', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await sweep(
      tester,
      'CrisisResourcesPanel',
      (band) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: CrisisResourcesPanel(),
      ),
      settle: const Duration(milliseconds: 200),
    );
  });

  testWidgets('StoryGenerationProgress', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await sweep(
      tester,
      'StoryGenerationProgress',
      (band) => const StoryGenerationProgress(
        currentPhase: 1,
        totalPhases: 3,
        funFact: 'Did you know? Storytellers have been weaving tales for '
            'over 40,000 years.',
      ),
      settle: const Duration(milliseconds: 300),
    );
  });

  testWidgets('ErrorMessage', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await sweep(
      tester,
      'ErrorMessage',
      (band) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ErrorMessage(
          title: "We couldn't reach the story engine",
          message: 'Check your connection and try again in a moment.',
          onRetry: () {},
        ),
      ),
      settle: const Duration(milliseconds: 200),
    );
  });

  testWidgets('MakeMagicButton', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await sweep(
      tester,
      'MakeMagicButton',
      (band) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: MakeMagicButton(
          label: band.launchStoryLabel,
          onTap: () {},
          ageBand: band.band,
        ),
      ),
      settle: const Duration(milliseconds: 300),
    );
  });

  testWidgets('MissionReadyButton', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await sweep(
      tester,
      'MissionReadyButton',
      (band) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: MissionReadyButton(onTap: () {}),
      ),
      settle: const Duration(milliseconds: 300),
    );
  });

  testWidgets('PressableArrowButton', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await sweep(
      tester,
      'PressableArrowButton',
      (band) => PressableArrowButton(
        enabled: true,
        onTap: () {},
        hint: band.wizardNextHint,
      ),
      settle: const Duration(milliseconds: 200),
    );
  });

  testWidgets('ChildProfileSwitcher', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final profiles = <ChildProfile>[
      ChildProfile(id: 'a', name: 'Alexandria', age: 7),
      ChildProfile(id: 'b', name: 'Bartholomew', age: 10),
      ChildProfile(id: 'c', name: 'Cassiopeia', age: 13),
    ];

    await sweep(
      tester,
      'ChildProfileSwitcher',
      (band) => ChildProfileSwitcher(
        profiles: profiles,
        activeProfileId: 'a',
        onProfileSelected: (_) {},
        onAddProfile: () {},
      ),
      settle: const Duration(milliseconds: 200),
    );
  });

  // ==========================================================================
  // Report
  // ==========================================================================
  tearDownAll(() {
    final buffer = StringBuffer()
      ..writeln('')
      ..writeln('=' * 78)
      ..writeln('RESPONSIVE OVERFLOW SWEEP');
    buffer.writeln(
      'widths=${kWidths.map((w) => w.toInt()).join("/")}  '
      'bands=${kBands.map((b) => b.band.name).join("/")}',
    );
    buffer
      ..writeln('subjects swept: ${_subjectsSwept.length}')
      ..writeln('=' * 78);

    if (_overflows.isEmpty) {
      buffer.writeln('NO OVERFLOWS DETECTED.');
    } else {
      int bySubject(_Finding a, _Finding b) {
        final s = a.subject.compareTo(b.subject);
        if (s != 0) return s;
        final c = a.culprit.compareTo(b.culprit);
        if (c != 0) return c;
        final w = a.width.compareTo(b.width);
        if (w != 0) return w;
        return a.band.compareTo(b.band);
      }

      void writeSection(String title, List<_Finding> rows) {
        buffer
          ..writeln('')
          ..writeln(title)
          ..writeln(
            '${'SUBJECT'.padRight(28)}${'BAND'.padRight(11)}'
            '${'W'.padRight(5)}${'PX'.padRight(8)}${'SIDE'.padRight(7)}'
            'BLAMED WIDGET',
          )
          ..writeln('-' * 78);
        for (final f in rows..sort(bySubject)) {
          buffer.writeln(
            '${f.subject.padRight(28)}${f.band.padRight(11)}'
            '${f.width.toInt().toString().padRight(5)}'
            '${f.pixels.toString().padRight(8)}'
            '${f.side.padRight(7)}'
            '${f.culprit.isEmpty ? "(${f.renderObject})" : f.culprit}',
          );
        }
      }

      writeSection(
        'GEOMETRY-DRIVEN (fixed sizes -- real bugs, reproduce in the app):',
        _overflows.where((f) => f.geometryDriven).toList(),
      );
      writeSection(
        'TEXT-METRIC-DRIVEN (vanish at ${_kShrunkTextScale}x text -- confirm '
        'visually before fixing;\nflutter test substitutes a square fallback '
        'font that is far wider than the real UI font):',
        _overflows.where((f) => !f.geometryDriven).toList(),
      );
      buffer
        ..writeln('-' * 78)
        ..writeln('total overflow findings: ${_overflows.length} '
            '(${_overflows.where((f) => f.geometryDriven).length} geometry, '
            '${_overflows.where((f) => !f.geometryDriven).length} text-metric)');

      final clean = _subjectsSwept
          .where((s) => !_overflows.any((f) => f.subject == s))
          .toList()
        ..sort();
      buffer.writeln('clean subjects (no overflow at any band x width):');
      for (final s in clean) {
        buffer.writeln('  - $s');
      }
    }

    if (_pumpFailures.isNotEmpty) {
      buffer
        ..writeln('-' * 78)
        ..writeln('PUMP FAILURES (${_pumpFailures.length}):');
      for (final f in _pumpFailures) {
        buffer.writeln('  ! $f');
      }
    }

    if (_otherErrors.isNotEmpty) {
      final unique = _otherErrors.toSet().toList()..sort();
      buffer
        ..writeln('-' * 78)
        ..writeln('NON-OVERFLOW ERRORS (${unique.length} unique):');
      for (final e in unique.take(40)) {
        buffer.writeln('  ? $e');
      }
    }

    buffer.writeln('=' * 78);
    print(buffer.toString());
  });
}
