import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/coloring_book_service.dart';
import 'package:story_weaver_app/coloring_screen.dart';

void main() {
  Finder drawingCanvasFinder() {
    return find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is DrawingPainter,
    );
  }

  ColoringPage buildPage() {
    return ColoringPage(
      id: 'page-1',
      storyId: 'story-1',
      pageTitle: 'Forest Friends',
      imageUrl: 'https://example.com/coloring.png',
      createdAt: DateTime.utc(2026, 2, 16),
    );
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ColoringScreen(coloringPage: buildPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('image loading area is rendered', (tester) async {
    await pumpScreen(tester);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('color palette renders expected swatches', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(GestureDetector), findsWidgets);
    expect(drawingCanvasFinder(), findsOneWidget);
  });

  testWidgets('color application via drag creates drawing points',
      (tester) async {
    await pumpScreen(tester);

    await tester.drag(drawingCanvasFinder(), const Offset(30, 30));
    await tester.pump();

    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user_colorings');
    expect(raw, isNotNull);

    final decoded = jsonDecode(raw!) as List<dynamic>;
    final first = decoded.first as Map<String, dynamic>;
    final coloredAreas = first['coloredAreas'] as Map<String, dynamic>;
    expect(coloredAreas.keys, isNotEmpty);
  });

  testWidgets('save functionality shows confirmation', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(find.text('✅ Coloring saved!'), findsOneWidget);
  });

  testWidgets('share/export control is available and tappable', (tester) async {
    await pumpScreen(tester);

    expect(find.byTooltip('Print/Export'), findsOneWidget);
    await tester.tap(find.byTooltip('Print/Export'));
    await tester.pump();

    expect(find.byType(ColoringScreen), findsOneWidget);
  });

  testWidgets('clear drawing removes points after confirmation',
      (tester) async {
    await pumpScreen(tester);

    // Add some points
    await tester.drag(drawingCanvasFinder(), const Offset(30, 30));
    await tester.pump();

    await tester.tap(find.byTooltip('Clear All'));
    await tester.pumpAndSettle();

    expect(find.text('Clear Coloring?'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    // Verify drawing points are cleared (by trying to save)
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user_colorings');
    final decoded = jsonDecode(raw!) as List<dynamic>;
    final first = decoded.first as Map<String, dynamic>;
    final coloredAreas = first['coloredAreas'] as Map<String, dynamic>;
    expect(coloredAreas.keys, isEmpty);
  });
}
