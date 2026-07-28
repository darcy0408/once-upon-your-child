import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/screens/parent_controls_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildSubject() {
    // ParentControlsScreen (and its children) read Riverpod providers via
    // Consumer, so a ProviderScope ancestor is required or the build throws
    // a StateError ("No ProviderScope found").
    return const ProviderScope(
      child: MaterialApp(home: ParentControlsScreen()),
    );
  }

  Future<void> expandBigFeelings(WidgetTester tester) async {
    // Scroll to the header and tap it.
    await tester.scrollUntilVisible(
      find.textContaining('My child could use some help'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.textContaining('My child could use some help'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders without crashing', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    expect(find.text('Parent Controls'), findsOneWidget);
  });

  testWidgets('Big Feelings header is visible', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('My child could use some help'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('My child could use some help'), findsOneWidget);
  });

  testWidgets('shows no-profile state when no child profile active',
      (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await expandBigFeelings(tester);
    // Without a profile, the no-profile message should appear.
    expect(find.text('No child profile active'), findsOneWidget);
  });

  testWidgets('math gate appears after expand when profile is set',
      (tester) async {
    // Set a profile ID so the no-profile state is skipped.
    SharedPreferences.setMockInitialValues({
      'active_profile_id': 'test-profile-123',
    });
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await expandBigFeelings(tester);
    expect(find.text('Parent verification'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
  });

  testWidgets('wrong math answer shows error', (tester) async {
    SharedPreferences.setMockInitialValues({
      'active_profile_id': 'test-profile-123',
    });
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await expandBigFeelings(tester);

    await tester.enterText(find.byType(TextField).first, '999');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('Not quite -- try again.'), findsOneWidget);
  });

  // MT-377 regression guard.
  //
  // SettingsScreen's only other entry points are inside the legacy
  // StoryScreen (main_story.dart:374 and :719), which is registered at
  // '/story-home' and never pushed. When this tile is missing, Settings is
  // unreachable in the shipped app — and with it the app-wide Text Size
  // slider and the only post-onboarding ToS / Privacy links. That is exactly
  // how the accessibility work in #484 shipped into a screen no user could
  // open, so this asserts the route rather than trusting it.
  testWidgets('offers a reachable route to Settings', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.textContaining('Text size'), findsOneWidget);

    // Present is not enough — it has to actually be tappable.
    final tile = tester.widget<ListTile>(
      find.ancestor(of: find.text('Settings'), matching: find.byType(ListTile)),
    );
    expect(tile.onTap, isNotNull);

    // The destination render is deliberately not asserted here: SettingsScreen
    // draws the partner logo via flutter_svg, which the widget-test harness
    // cannot decode, so pumping the pushed route always throws regardless of
    // whether navigation worked. The push itself is exercised in the browser
    // against a real web build instead.
  });
}
