import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/providers/text_scale_provider.dart';
import 'package:story_weaver_app/utils/platform_text_scale.dart';

/// Mirrors the composition MaterialApp.builder does in
/// `lib/main_story.dart`: read the inherited text scaler, multiply by the
/// platform (browser) scale and the user's persisted preference, clamp the
/// total, and hand it back down via a MediaQuery override.
class _FixedTextScaleNotifier extends TextScaleNotifier {
  _FixedTextScaleNotifier(this._value);
  final double _value;

  @override
  double build() => _value;
}

/// Builds the same widget tree shape as main_story.dart so the composition
/// under test is the real one, not a paraphrase of it.
Widget _app({
  required double userScale,
  double? inheritedScaler,
}) {
  Widget app = ProviderScope(
    overrides: [
      textScaleNotifierProvider
          .overrideWith(() => _FixedTextScaleNotifier(userScale)),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final userTextScale = ref.watch(textScaleNotifierProvider);
        return MaterialApp(
          builder: (context, child) {
            final inheritedFactor = MediaQuery.textScalerOf(context).scale(1.0);
            final platformFactor = readPlatformTextScale();
            final combinedFactor =
                (inheritedFactor * platformFactor * userTextScale)
                    .clamp(0.0, 2.0);
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(combinedFactor)),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const Scaffold(body: Text('Hello')),
        );
      },
    ),
  );

  if (inheritedScaler != null) {
    app = MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(inheritedScaler)),
      child: app,
    );
  }
  return app;
}

double _effectiveScale(WidgetTester tester) =>
    MediaQuery.textScalerOf(tester.element(find.text('Hello'))).scale(10.0) /
    10.0;

void main() {
  test('platform scale is neutral off the web', () {
    // On native, Flutter already delivers the OS font-size setting through
    // MediaQuery. If this ever returned anything but 1.0, main_story.dart
    // would multiply the user's accessibility preference in twice and text
    // would balloon on exactly the devices that need it most.
    expect(readPlatformTextScale(), 1.0);
  });

  testWidgets('user text scale composes with the inherited scaler',
      (tester) async {
    await tester.pumpWidget(_app(userScale: 1.4));
    await tester.pumpAndSettle();

    // Harness default inherited scaler is 1.0 and the native platform factor
    // is 1.0, so the effective scale is the user's 1.4 preference alone.
    expect(_effectiveScale(tester), closeTo(1.4, 0.001));
  });

  testWidgets('an inherited OS scaler multiplies the user preference',
      (tester) async {
    await tester.pumpWidget(_app(userScale: 1.2, inheritedScaler: 1.5));
    await tester.pumpAndSettle();

    // 1.5 (OS) x 1.0 (platform) x 1.2 (user) = 1.8, under the 2.0 ceiling.
    expect(_effectiveScale(tester), closeTo(1.8, 0.001));
  });

  testWidgets('the combined factor is clamped so layouts cannot blow up',
      (tester) async {
    await tester.pumpWidget(
      _app(userScale: kMaxTextScale, inheritedScaler: 1.9),
    );
    await tester.pumpAndSettle();

    // 1.9 x 1.6 = 3.04 uncapped; the builder must hold it at 2.0.
    expect(_effectiveScale(tester), closeTo(2.0, 0.001));
  });
}
