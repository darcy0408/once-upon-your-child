import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models/api_error.dart';
import 'package:story_weaver_app/utils/character_limit_handler.dart';

void main() {
  final limitBody = <String, dynamic>{
    'error': 'Character limit reached',
    'code': 'CHARACTER_LIMIT_REACHED',
    'characters_count': 6,
    'characters_limit': 6,
    'tier': 'premium',
  };

  group('ApiError character-limit detection', () {
    test('403 + CHARACTER_LIMIT_REACHED is detected with the limit', () {
      final e = ApiError.fromJson(limitBody, statusCode: 403);
      expect(e.isCharacterLimitReached, isTrue);
      expect(e.charactersLimit, 6);
    });

    test('other 403s and other statuses are not', () {
      expect(
        ApiError.fromJson({'error': 'Forbidden'}, statusCode: 403)
            .isCharacterLimitReached,
        isFalse,
      );
      expect(
        ApiError.fromJson(limitBody, statusCode: 500).isCharacterLimitReached,
        isFalse,
      );
    });
  });

  group('showCharacterLimitIfReached', () {
    Future<void> pumpHost(WidgetTester tester, Object error, List<bool> out) {
      return tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  out.add(await showCharacterLimitIfReached(context, error)),
              child: const Text('go'),
            ),
          ),
        ),
      ));
    }

    testWidgets('shows the dialog with the backend limit', (tester) async {
      final out = <bool>[];
      await pumpHost(
          tester, ApiError.fromJson(limitBody, statusCode: 403), out);
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Does someone want to join the adventure?'),
          findsOneWidget);
      expect(find.textContaining('limit of 6 characters'), findsOneWidget);

      await tester.tap(find.text('Maybe later'));
      await tester.pumpAndSettle();
      expect(out, [true]);
    });

    testWidgets('returns false and shows nothing for other errors',
        (tester) async {
      final out = <bool>[];
      await pumpHost(tester, Exception('boom'), out);
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(out, [false]);
    });
  });
}
