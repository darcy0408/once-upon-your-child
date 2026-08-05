/// Regression test for MT-393 — Pick-a-Path branch choices were unreadable.
///
/// Every Pick-a-Path choice on the 8+/adult path renders through
/// [AppButton.primary]. The button set `overflow: TextOverflow.ellipsis` with
/// no `maxLines`, which collapses the label to a SINGLE line, so a child chose
/// between three sentences truncated to "Step into the library's doorway and
/// ask the arc…". These tests pin the wrapping behaviour at phone widths.
///
/// Run with:
///   flutter test test/widgets/app_button_label_wrap_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/widgets/app_button.dart';

/// A realistic Pick-a-Path choice — these come back from the story model as
/// full sentences, not verb phrases.
const _longChoice =
    "Step into the library's doorway and ask the archivist about the missing key";

/// Phone widths the app supports, smallest first.
const _phoneWidths = <double>[320, 360, 390, 430];

Future<void> _pumpButton(
  WidgetTester tester,
  double width, {
  required String label,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: AppButton.primary(label: label, onPressed: () {}),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('AppButton label wrapping', () {
    testWidgets('allows a long label more than one line', (tester) async {
      for (final width in _phoneWidths) {
        await _pumpButton(tester, width, label: _longChoice);

        final text = tester.widget<Text>(find.text(_longChoice));
        expect(
          text.maxLines,
          greaterThan(1),
          reason: 'a single-line label truncates the choice at ${width}px',
        );

        // The button's height is a MINIMUM (52), so a wrapped label must make
        // it grow. If the label were still collapsing to one line the button
        // would sit at exactly the minimum.
        final height = tester.getSize(find.byType(AppButton)).height;
        expect(
          height,
          greaterThan(52.0),
          reason: 'button did not grow to fit the wrapped label at ${width}px',
        );
      }
    });

    testWidgets('renders the full label text, not an ellipsised prefix',
        (tester) async {
      await _pumpButton(tester, 320, label: _longChoice);
      // The widget must carry the whole string — truncation is a paint-time
      // concern, so this guards against a future `substring` style "fix".
      expect(find.text(_longChoice), findsOneWidget);
    });

    testWidgets('leaves a short label on a single line at the min height',
        (tester) async {
      await _pumpButton(tester, 360, label: 'Continue');
      final height = tester.getSize(find.byType(AppButton)).height;
      expect(
        height,
        52.0,
        reason: 'short labels must keep the standard button height',
      );
    });

    testWidgets('does not overflow at any supported phone width',
        (tester) async {
      for (final width in _phoneWidths) {
        await _pumpButton(tester, width, label: _longChoice);
        expect(
          tester.takeException(),
          isNull,
          reason: 'AppButton overflowed at ${width}px',
        );
      }
    });
  });
}
