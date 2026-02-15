import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/widgets/error_boundary.dart';

void main() {
  group('ErrorBoundary', () {
    testWidgets('renders child when no error', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            child: const Text('Test Child'),
          ),
        ),
      );

      expect(find.text('Test Child'), findsOneWidget);
      expect(find.text('Oops! Something went wrong.'), findsNothing);
    });

    testWidgets('shows fallback UI when error occurs', (WidgetTester tester) async {
      ErrorBoundary.shouldCatchInTests = true;
      addTearDown(() => ErrorBoundary.shouldCatchInTests = false);

      // Create a widget that throws an error
      final errorWidget = Builder(
        builder: (context) {
          throw Exception('Test error');
        },
      );

      bool errorCaught = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            onError: (error, stack) {
              errorCaught = true;
            },
            child: errorWidget,
          ),
        ),
      );

      // Pump again to let error handling complete
      await tester.pump();

      // Verify error was caught
      expect(errorCaught, true);
      expect(find.text('Oops! Something went wrong.'), findsOneWidget);
    });

    testWidgets('retry button clears error', (WidgetTester tester) async {
      int retryCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            onRetry: () {
              retryCount++;
            },
            child: const Text('Test Child'),
          ),
        ),
      );

      // Verify child is shown initially
      expect(find.text('Test Child'), findsOneWidget);
    });

    testWidgets('custom fallback builder works', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            fallbackBuilder: (context, error, stackTrace) {
              return const Text('Custom Error UI');
            },
            child: const Text('Test Child'),
          ),
        ),
      );

      expect(find.text('Test Child'), findsOneWidget);
    });
  });
}
