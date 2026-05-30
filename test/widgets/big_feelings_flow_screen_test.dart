import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/screens/big_feelings_flow_screen.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    var remainingMs = total.inMilliseconds;
    while (remainingMs > 0) {
      await tester.pump(const Duration(milliseconds: 100));
      remainingMs -= 100;
    }
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders without crashing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BigFeelingsFlowScreen()),
    );
    await pumpFor(tester, const Duration(seconds: 1));

    expect(find.byType(BigFeelingsFlowScreen), findsOneWidget);
  });

  // MT-162 / content-safety audit F-19: a grieving 6-12-year-old had no
  // matching feeling word because `Grief` was gated to Adolescent+ (15+).
  // The remediation adds a gentler "Missing Someone" option for Explorer
  // (6-8) and Adventurer (9-11). The next group of tests pins that gating.
  //
  // We assert against the data accessor (`debugFeelingLabelsForBand`) rather
  // than rendering the widget — Creator/Adolescent/Adult use the Google Font
  // `SourceSansPro` which the test environment can't fetch and which throws
  // mid-build, making widget-level assertions on those bands flaky.
  group('MT-162: "Missing Someone" age-gating', () {
    test('appears in the Adventurer band (age-9-aligned)', () {
      final labels = BigFeelingsFlowScreen.debugFeelingLabelsForBand(
        AgeBand.adventurer,
      );
      expect(labels, contains('Missing Someone'));
      // Grief is the 15+ mature word — must NOT leak down to a 9-year-old.
      expect(labels, isNot(contains('Grief')));
    });

    test('appears in the Explorer band (age-7-aligned)', () {
      final labels = BigFeelingsFlowScreen.debugFeelingLabelsForBand(
        AgeBand.explorer,
      );
      expect(labels, contains('Missing Someone'));
      expect(labels, isNot(contains('Grief')));
    });

    test('does NOT appear in the Sprout band (age-4-aligned)', () {
      final labels = BigFeelingsFlowScreen.debugFeelingLabelsForBand(
        AgeBand.sprout,
      );
      expect(labels, isNot(contains('Missing Someone')));
      expect(labels, isNot(contains('Grief')));
    });

    test(
        'coexists with literal "Grief" in the Adolescent band (age-17-aligned)',
        () {
      final labels = BigFeelingsFlowScreen.debugFeelingLabelsForBand(
        AgeBand.adolescent,
      );
      // Both options are present from 15+ on purpose: "Missing Someone" maps
      // to absence/longing, "Grief" to deeper loss. Different intensities,
      // both valuable; the user picks the word that fits the moment.
      expect(labels, contains('Grief'));
      expect(labels, contains('Missing Someone'));
    });

    test(
        'appears in the Creator band (age-13-aligned); Grief is still gated to 15+',
        () {
      final labels = BigFeelingsFlowScreen.debugFeelingLabelsForBand(
        AgeBand.creator,
      );
      // Creator (13-14) doesn't yet receive `Grief` (that's Adolescent+), so
      // the softer option carries through normal inheritance from Adventurer
      // to close the F-19 gap at this band too.
      expect(labels, contains('Missing Someone'));
      expect(labels, isNot(contains('Grief')));
    });
  });
}
