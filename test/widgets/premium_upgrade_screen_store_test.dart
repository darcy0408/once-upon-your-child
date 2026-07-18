// Guards App Store review sim 2026-07-17 Finding 2 (Guideline 3.1.2 /
// 2.3.1): the store builds have no annual product — every IAP purchase
// charges monthly — so the paywall must not offer or price "Yearly".
//
// `flutter test` runs on the Dart VM, where `dart.library.io` is available,
// so the conditional import in payment_channel.dart resolves to the STORE
// variant (`isStoreBillingPlatform == true`) — exactly the configuration
// under review here. The web variant (toggle visible, yearly default) is
// compile-time unreachable in this harness and is covered by the Stripe
// paywall flow instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/premium_upgrade_screen.dart';
import 'package:story_weaver_app/services/payment/payment_channel.dart';

void main() {
  testWidgets(
      'store paywall hides the Yearly toggle and prices monthly (3.1.2)',
      (tester) async {
    expect(isStoreBillingPlatform, isTrue,
        reason: 'flutter test compiles the io channel; if this flips, the '
            'assertions below are exercising the wrong platform variant');

    await tester.pumpWidget(const MaterialApp(home: PremiumUpgradeScreen()));
    await tester.pump();

    // No billing-period toggle at all on store builds.
    expect(find.text('Yearly (Save 50%)'), findsNothing);
    expect(find.text('Monthly'), findsNothing);

    // Premium card shows the real monthly charge, not the annual per-month
    // teaser (59.99 / 12 = $5.00) or the yearly-savings badge.
    expect(find.text('\$9.99'), findsOneWidget);
    expect(find.text('\$5.00'), findsNothing);
    expect(find.textContaining('Save \$'), findsNothing);
  });
}
