// MT-397: the COPPA consent code-entry step must tell a parent which failure
// they hit, and what to do about it.
//
// The backend deliberately returns ONE identical body for every rejection of
// POST /api/user/<id>/consent/verify ({"verified": false, "error": "Invalid or
// expired code"}) so it never reveals which check failed. The HTTP status is
// the only thing that separates a wrong code (400) from an expired/absent one
// (410) from a burnt attempt cap (429).
//
// Before this fix `ApiError` discarded the status, so the client could not tell
// them apart even in principle: every rejection surfaced as the same catch-all
// "Could not verify right now", and the "that code did not match" branch was
// unreachable. A parent whose code had expired was told to try again, and
// retyping the dead code burned attempts on it forever.
//
// These tests pin both halves: the status survives the trip through
// ApiServiceManager, and each status maps to distinct, actionable copy.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models/api_error.dart';
import 'package:story_weaver_app/screens/parental_consent_screen.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/parental_consent_service.dart';

/// The non-distinguishing body the verify endpoint returns for every rejection
/// (backend/routes/user_routes.py, `_fail`).
const _opaqueFailureBody = {
  'verified': false,
  'success': false,
  'error': 'Invalid or expired code',
};

/// Stubs auth so the service can resolve a user id, then answers the consent
/// endpoints with [consentResponse].
void _stubBackend(http.Response Function(http.Request) consentResponse) {
  ApiServiceManager.setTestClient(MockClient((request) async {
    if (request.method == 'POST' &&
        request.url.path.contains('/auth/anonymous')) {
      return http.Response(
        jsonEncode({'token': 'mock_token', 'user_id': 'anon_test123'}),
        200,
      );
    }
    if (request.url.path.contains('/consent/')) {
      return consentResponse(request);
    }
    return http.Response('{}', 200);
  }));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiServiceManager.resetAuthForTest();
  });

  tearDown(() async {
    ApiServiceManager.setTestClient(null);
    await ApiServiceManager.resetAuthForTest();
  });

  group('ApiError carries the HTTP status', () {
    test('fromJson records the status it arrived with', () {
      final error = ApiError.fromJson(
        Map<String, dynamic>.from(_opaqueFailureBody),
        statusCode: 410,
      );

      expect(error.statusCode, 410);
    });

    test('statusCode is null when no status is supplied', () {
      final error =
          ApiError.fromJson(Map<String, dynamic>.from(_opaqueFailureBody));

      expect(error.statusCode, isNull);
    });

    // The three rejections are byte-identical apart from the status, so this is
    // the only place the distinction can survive.
    for (final status in [400, 410, 429]) {
      test('verifyEmailConsent surfaces status $status from an opaque body',
          () async {
        _stubBackend((_) => http.Response(jsonEncode(_opaqueFailureBody), status));

        await expectLater(
          ParentalConsentService().verifyEmailConsent(code: 'ABC123'),
          throwsA(isA<ApiError>()
              .having((e) => e.statusCode, 'statusCode', status)),
        );
      });
    }
  });

  group('consentVerifyErrorMessage', () {
    test('400 tells the parent the code was wrong, not expired', () {
      final message = consentVerifyErrorMessage(400);

      expect(message, contains('did not match'));
      expect(message, isNot(contains('Resend')));
    });

    test('410 sends the parent to Resend rather than retyping', () {
      final message = consentVerifyErrorMessage(410);

      expect(message, contains('expired'));
      expect(message, contains('Resend'));
    });

    test('429 explains the attempt cap and sends them to Resend', () {
      final message = consentVerifyErrorMessage(429);

      expect(message, contains('Too many tries'));
      expect(message, contains('Resend'));
    });

    test('an unknown or absent status falls back to a transient message', () {
      expect(consentVerifyErrorMessage(500), contains('Could not verify'));
      expect(consentVerifyErrorMessage(null), contains('Could not verify'));
    });

    test('every status yields a distinct message', () {
      final messages = [400, 410, 429, null].map(consentVerifyErrorMessage);

      expect(messages.toSet(), hasLength(4));
    });
  });

  group('requestEmailVerification reports the expiry window', () {
    test('reads expires_in_minutes from the server instead of assuming it',
        () async {
      _stubBackend(
        (_) => http.Response(
          jsonEncode({'success': true, 'expires_in_minutes': 15}),
          200,
        ),
      );

      final result = await ParentalConsentService().requestEmailVerification(
        age: 8,
        parentEmail: 'parent@example.com',
      );

      expect(result.queued, isTrue);
      expect(result.expiresInMinutes, 15);
    });

    test('tolerates a backend that omits the window', () async {
      _stubBackend(
        (_) => http.Response(jsonEncode({'success': true}), 200),
      );

      final result = await ParentalConsentService().requestEmailVerification(
        age: 8,
        parentEmail: 'parent@example.com',
      );

      expect(result.queued, isTrue);
      expect(result.expiresInMinutes, isNull);
    });

    test('reports not-queued when the backend declines to send', () async {
      _stubBackend(
        (_) => http.Response(jsonEncode({'success': false}), 200),
      );

      final result = await ParentalConsentService().requestEmailVerification(
        age: 8,
        parentEmail: 'parent@example.com',
      );

      expect(result.queued, isFalse);
    });
  });
}
