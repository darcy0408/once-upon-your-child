import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Size kPhoneGoldenSize = Size(390, 844);

Future<void> pumpGoldenApp(
  WidgetTester tester,
  Widget child, {
  Size size = kPhoneGoldenSize,
  ThemeData? theme,
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();

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
