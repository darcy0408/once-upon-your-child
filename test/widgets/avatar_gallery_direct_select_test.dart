import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models/generated_avatar.dart';
import 'package:story_weaver_app/widgets/avatar_gallery_selector.dart';
import 'package:story_weaver_app/widgets/avatar_tweak_panel.dart';

void main() {
  testWidgets('tapping a face confirms it directly (no tweak panel)',
      (tester) async {
    final original = FlutterError.onError!;
    FlutterError.onError = (d) {
      if (d.exception.toString().contains('Unable to load asset')) return;
      original(d);
    };
    addTearDown(() => FlutterError.onError = original);
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    GeneratedAvatar? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AvatarGallerySelector(
          onAvatarSelected: (a) => picked = a,
          onCancel: () {},
        ),
      ),
    ));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final tile = find.bySemanticsLabel('Avatar option 1');
    expect(tile, findsOneWidget);
    await tester.tap(tile);
    await tester.pump();

    expect(picked, isNotNull);
    expect(find.byType(AvatarTweakPanel), findsNothing);
  });
}
