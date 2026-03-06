import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const Size kPhoneGoldenSize = Size(390, 844);

/// Loads bundled fonts so golden screenshots render with the correct typefaces
/// rather than the system fallback. Must be called once per test file after
/// [TestWidgetsFlutterBinding.ensureInitialized].
Future<void> loadGoldenFonts() async {
  final fontLoader = FontLoader('Cinzel Decorative')
    ..addFont(rootBundle.load('assets/fonts/CinzelDecorative-Bold.ttf'));
  await fontLoader.load();
}

Future<void> pumpGoldenApp(
  WidgetTester tester,
  Widget child, {
  Size size = kPhoneGoldenSize,
  ThemeData? theme,
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadGoldenFonts();

  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? ThemeData.light(),
      home: child,
    ),
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 200));
}
