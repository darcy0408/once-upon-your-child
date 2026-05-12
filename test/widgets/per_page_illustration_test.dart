import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/services/per_page_illustration_prefetcher.dart';
import 'package:story_weaver_app/widgets/per_page_illustration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpWidget(
    WidgetTester tester, {
    required ValueNotifier<PageIllustrationState> notifier,
    VoidCallback? onTapUpgrade,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: PerPageIllustration(
                listenable: notifier,
                onTapUpgrade: onTapUpgrade,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('PerPageIllustration quota-exceeded rendering', () {
    testWidgets(
      'with onTapUpgrade provided, renders upsell card and tap fires callback',
      (tester) async {
        final notifier = ValueNotifier<PageIllustrationState>(
          const PageIllustrationState(
            status: PageIllustrationStatus.quotaExceeded,
          ),
        );
        addTearDown(notifier.dispose);

        var tapCount = 0;
        await pumpWidget(
          tester,
          notifier: notifier,
          onTapUpgrade: () => tapCount += 1,
        );

        // Upsell card surface elements present.
        expect(find.text('Out of free illustrations'), findsOneWidget);
        expect(
          find.text('Tap to upgrade and see this scene come alive.'),
          findsOneWidget,
        );
        expect(find.text('🎨'), findsOneWidget);

        // Tap → callback fires.
        await tester.tap(find.text('Out of free illustrations'));
        await tester.pump();
        expect(tapCount, 1);
      },
    );

    testWidgets(
      'with onTapUpgrade null, renders nothing (banner-only host)',
      (tester) async {
        final notifier = ValueNotifier<PageIllustrationState>(
          const PageIllustrationState(
            status: PageIllustrationStatus.quotaExceeded,
          ),
        );
        addTearDown(notifier.dispose);

        await pumpWidget(tester, notifier: notifier);

        expect(find.text('Out of free illustrations'), findsNothing);
        expect(find.text('🎨'), findsNothing);
      },
    );

    testWidgets(
      'transition from loading skeleton to quotaExceeded swaps the surface',
      (tester) async {
        final notifier = ValueNotifier<PageIllustrationState>(
          const PageIllustrationState(
            status: PageIllustrationStatus.loading,
          ),
        );
        addTearDown(notifier.dispose);

        await pumpWidget(
          tester,
          notifier: notifier,
          onTapUpgrade: () {},
        );

        // Skeleton path renders an auto_awesome icon, not the upsell text.
        expect(find.text('Out of free illustrations'), findsNothing);
        expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

        notifier.value = const PageIllustrationState(
          status: PageIllustrationStatus.quotaExceeded,
        );
        await tester.pump();

        expect(find.byIcon(Icons.auto_awesome), findsNothing);
        expect(find.text('Out of free illustrations'), findsOneWidget);
      },
    );

    testWidgets(
      'failed status renders nothing even when onTapUpgrade is provided',
      (tester) async {
        // Regression: only quotaExceeded should trip the upsell — generic
        // failures (HTTP error, missing image_data, circuit-breaker) must
        // stay silent so we don't blast the upsell on transient outages.
        final notifier = ValueNotifier<PageIllustrationState>(
          const PageIllustrationState(
            status: PageIllustrationStatus.failed,
            error: 'HTTP 500',
          ),
        );
        addTearDown(notifier.dispose);

        await pumpWidget(
          tester,
          notifier: notifier,
          onTapUpgrade: () => fail('failed status must not be tappable'),
        );

        expect(find.text('Out of free illustrations'), findsNothing);
      },
    );
  });
}
