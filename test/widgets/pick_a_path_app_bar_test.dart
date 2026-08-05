/// Regression test for MT-393 F12 — the Pick-a-Path story title read "The …".
///
/// The app bar carried the [StorybookProgressIndicator] in its `actions` slot.
/// With six page icons that indicator is ~215px wide, so on a 360px bar the
/// title was left roughly 57px between the back button and the indicator and
/// ellipsised after three characters. The fix moves the indicator to its own
/// row below the title and lets the title take two lines.
///
/// These tests assert on the WIDTH the title is given rather than on how many
/// characters fit, because `flutter test` substitutes a fallback font about
/// twice as wide as the real UI fonts — character counts here would not
/// reflect the device.
///
/// Run with:
///   flutter test test/widgets/pick_a_path_app_bar_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/widgets/pick_a_path_app_bar.dart';
import 'package:story_weaver_app/widgets/storybook_progress_indicator.dart';

/// A realistic generated story title — the model returns full noun phrases.
const _longTitle = 'The Case of the Missing Marbles and the Midnight Garden';

/// Phone widths the app supports, smallest first.
const _phoneWidths = <double>[320, 360, 390, 430];

/// One age per band, so the sprout branch (larger type, taller bar) is covered.
const _bandAges = <String, int>{
  'sprout': 4,
  'explorer': 7,
  'adventurer': 10,
  'creator': 13,
  'adolescent': 16,
  'adult': 25,
};

Future<void> _pumpBar(
  WidgetTester tester,
  double width, {
  required int age,
  String title = _longTitle,
  bool withProgress = true,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final band = themeForAge(age);
  final bar = PickAPathAppBar(
    title: title,
    band: band,
    isSprout: age <= 5,
    progress: withProgress
        ? const StorybookProgressIndicator(
            currentPage: 2,
            totalPages: 6,
            stageLabel: 'Play Time!',
          )
        : null,
  );

  // initialRoute pushes ['/', '/reader'], so the route can pop and the AppBar
  // renders its back button — without it the title would get a falsely
  // generous slot and the width assertions below would be too easy to pass.
  await tester.pumpWidget(
    MaterialApp(
      initialRoute: '/reader',
      routes: {
        '/': (_) => const Scaffold(body: SizedBox.shrink()),
        '/reader': (_) => Scaffold(appBar: bar),
      },
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PickAPathAppBar title', () {
    testWidgets('gives the title most of the bar width at every phone width',
        (tester) async {
      for (final width in _phoneWidths) {
        await _pumpBar(tester, width, age: 10);

        final titleWidth = tester.getSize(find.text(_longTitle)).width;
        // The old layout left ~57px of 360 (16%). Anything above half the
        // screen means the indicator is no longer competing for the row.
        expect(
          titleWidth,
          greaterThan(width * 0.5),
          reason: 'title got only ${titleWidth}px of ${width}px — the progress '
              'indicator is crowding the title row again',
        );
      }
    });

    testWidgets('allows the title two lines', (tester) async {
      await _pumpBar(tester, 360, age: 10);
      final text = tester.widget<Text>(find.text(_longTitle));
      expect(text.maxLines, 2);
      // AppBar's DefaultTextStyle sets softWrap:false; the Text must override
      // it or maxLines alone changes nothing.
      expect(text.softWrap, isTrue);
    });

    testWidgets('renders the whole title string, not a truncated prefix',
        (tester) async {
      await _pumpBar(tester, 320, age: 10);
      expect(find.text(_longTitle), findsOneWidget);
    });
  });

  group('PickAPathAppBar progress row', () {
    testWidgets('sits below the toolbar, not beside the title',
        (tester) async {
      for (final width in _phoneWidths) {
        await _pumpBar(tester, width, age: 10);

        final titleBottom = tester.getRect(find.text(_longTitle)).bottom;
        final progressTop =
            tester.getRect(find.byType(StorybookProgressIndicator)).top;
        expect(
          progressTop,
          greaterThanOrEqualTo(titleBottom),
          reason: 'progress indicator overlaps the title row at ${width}px',
        );
      }
    });

    testWidgets('is omitted while loading, and the bar shrinks to match',
        (tester) async {
      await _pumpBar(tester, 360, age: 10, withProgress: false);
      expect(find.byType(StorybookProgressIndicator), findsNothing);

      final barHeight = tester.getSize(find.byType(PickAPathAppBar)).height;
      expect(barHeight, 68.0);
    });
  });

  group('PickAPathAppBar across bands', () {
    testWidgets('does not overflow for any band at any phone width',
        (tester) async {
      for (final entry in _bandAges.entries) {
        for (final width in _phoneWidths) {
          await _pumpBar(tester, width, age: entry.value);
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} overflowed at ${width}px',
          );
        }
      }
    });

    testWidgets('gives sprout a taller bar for its larger title',
        (tester) async {
      await _pumpBar(tester, 360, age: 4, withProgress: false);
      expect(tester.getSize(find.byType(PickAPathAppBar)).height, 76.0);
    });
  });
}
