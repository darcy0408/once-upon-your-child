import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/providers/text_scale_provider.dart';

/// Mirrors the composition MaterialApp.builder does in
/// `lib/main_story.dart`: read the inherited text scaler, multiply by the
/// user's persisted preference, clamp the total, and hand it back down via
/// a MediaQuery override.
class _FixedTextScaleNotifier extends TextScaleNotifier {
  _FixedTextScaleNotifier(this._value);
  final double _value;

  @override
  double build() => _value;
}

void main() {
  testWidgets('user text scale composes with the inherited scaler',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          textScaleNotifierProvider
              .overrideWith(() => _FixedTextScaleNotifier(1.4)),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final userScale = ref.watch(textScaleNotifierProvider);
            return MaterialApp(
              builder: (context, child) {
                final inheritedFactor =
                    MediaQuery.textScalerOf(context).scale(1.0);
                final combinedFactor =
                    (inheritedFactor * userScale).clamp(0.0, 2.0);
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
      ),
    );

    await tester.pumpAndSettle();

    final textElement = tester.element(find.text('Hello'));
    final effectiveScaler = MediaQuery.textScalerOf(textElement);

    // With no other scaler in effect (test harness default is 1.0), the
    // effective scale factor should equal the user's 1.4 preference.
    expect(effectiveScaler.scale(10.0), closeTo(14.0, 0.001));
  });
}
