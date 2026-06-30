import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/utils/paywall_gate.dart';

/// Pumps a button that invokes [showPaywallGated]; [onPaywallShown] fires only
/// if the gate actually lets the paywall through. A null [band] simulates a
/// screen with no AgeBandThemeData extension.
Widget _harness(AgeBand? band, VoidCallback onPaywallShown) {
  final ext = band == null ? null : themeForBand(band);
  return MaterialApp(
    theme: ThemeData(extensions: ext == null ? const <ThemeExtension>[] : [ext]),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showPaywallGated<void>(
              context: context,
              showActualPaywall: () async => onPaywallShown(),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
}

int _productFromPrompt(WidgetTester tester) {
  final prompt = tester.widget<Text>(find.textContaining('×')).data!;
  final m = RegExp(r'(\d+)\s*×\s*(\d+)').firstMatch(prompt)!;
  return int.parse(m.group(1)!) * int.parse(m.group(2)!);
}

void main() {
  testWidgets('adult band opens the paywall without a gate', (tester) async {
    var shown = false;
    await tester.pumpWidget(_harness(AgeBand.adult, () => shown = true));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(shown, isTrue);
    expect(find.textContaining('×'), findsNothing); // no gate shown
  });

  for (final band in const [
    AgeBand.sprout,
    AgeBand.explorer,
    AgeBand.adventurer,
    AgeBand.creator,
    AgeBand.adolescent,
  ]) {
    testWidgets('minor band $band is gated before the paywall', (tester) async {
      var shown = false;
      await tester.pumpWidget(_harness(band, () => shown = true));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      // Gate is up; paywall has NOT been reached.
      expect(find.textContaining('×'), findsOneWidget);
      expect(shown, isFalse);
    });
  }

  testWidgets('null band (no theme extension) is gated, not bypassed',
      (tester) async {
    var shown = false;
    await tester.pumpWidget(_harness(null, () => shown = true));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.textContaining('×'), findsOneWidget);
    expect(shown, isFalse);
  });

  testWidgets('wrong answer keeps the gate closed; correct product unlocks',
      (tester) async {
    var shown = false;
    await tester.pumpWidget(_harness(AgeBand.adventurer, () => shown = true));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    final product = _productFromPrompt(tester);

    // Wrong answer: still gated.
    await tester.enterText(find.byType(TextField), '${product + 1}');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(shown, isFalse);

    // Correct answer: paywall reached.
    await tester.enterText(find.byType(TextField), '$product');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(shown, isTrue);
  });
}
