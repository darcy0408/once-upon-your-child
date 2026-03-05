import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/services/stripe_service.dart';
import '../../helpers/mocks.dart';

void main() {
  late StripeService stripeService;
  late MockHttpClient mockHttpClient;

  setUpAll(() {
    registerCommonMocks();
  });

  setUp(() async {
    mockHttpClient = MockHttpClient();
    SharedPreferences.setMockInitialValues({
      'story_weaver_auth_token': 'mock_token',
      'story_weaver_user_id': 'user_123',
    });
    stripeService = StripeService(httpClient: mockHttpClient);
  });

  group('StripeService', () {
    test('createCheckoutSession returns session data on successful POST',
        () async {
      final mockResponse = {
        'id': 'cs_test_123',
        'url': 'https://checkout.stripe.com/pay/cs_test_123',
      };

      when(() => mockHttpClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ))
          .thenAnswer(
              (_) async => http.Response(jsonEncode(mockResponse), 200));

      final result = await stripeService.createCheckoutSession(
        tier: 'premium',
        userId: 'user_123',
      );

      expect(result['id'], 'cs_test_123');
      expect(result['url'], contains('stripe.com'));
      verify(() => mockHttpClient.post(
            any(
              that: predicate<Uri>(
                (uri) => uri.path.endsWith('/create-checkout-session'),
              ),
            ),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).called(1);
    });

    test('createCheckoutSession sends provided user ID', () async {
      when(() => mockHttpClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ))
          .thenAnswer(
              (_) async => http.Response(jsonEncode({'id': 'cs_test'}), 200));

      await stripeService.createCheckoutSession(
          tier: 'premium', userId: 'user_abc');

      final captured = verify(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          )).captured.single as String;
      final payload = jsonDecode(captured) as Map<String, dynamic>;

      expect(payload['tier'], 'premium');
      expect(payload['user_id'], 'user_abc');
    });

    test('createCheckoutSession sends bearer token when present', () async {
      when(() => mockHttpClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ))
          .thenAnswer(
              (_) async => http.Response(jsonEncode({'id': 'cs_test'}), 200));

      await stripeService.createCheckoutSession(
          tier: 'premium', userId: 'user_123');

      final headers = verify(() => mockHttpClient.post(
            any(),
            headers: captureAny(named: 'headers'),
            body: any(named: 'body'),
          )).captured.single as Map<String, String>;

      expect(headers['Content-Type'], 'application/json');
      expect(headers['Authorization'], 'Bearer mock_token');
    });

    test('createCheckoutSession omits bearer token when not present', () async {
      SharedPreferences.setMockInitialValues({
        'story_weaver_auth_token': '',
        'story_weaver_user_id': 'user_123',
      });
      stripeService = StripeService(httpClient: mockHttpClient);

      when(() => mockHttpClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ))
          .thenAnswer(
              (_) async => http.Response(jsonEncode({'id': 'cs_test'}), 200));

      await stripeService.createCheckoutSession(
          tier: 'premium', userId: 'user_123');

      final headers = verify(() => mockHttpClient.post(
            any(),
            headers: captureAny(named: 'headers'),
            body: any(named: 'body'),
          )).captured.single as Map<String, String>;

      expect(headers['Content-Type'], 'application/json');
      expect(headers.containsKey('Authorization'), isFalse);
    });

    test('createCheckoutSession throws exception on non-200 response',
        () async {
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('Error', 400));

      expect(
        () => stripeService.createCheckoutSession(tier: 'premium'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to create checkout session'),
          ),
        ),
      );
    });

    test('createCheckoutSession surfaces network errors', () async {
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenThrow(const SocketException('No network'));

      expect(
        () => stripeService.createCheckoutSession(tier: 'premium'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Network error creating checkout session'),
          ),
        ),
      );
    });

    test('getSubscriptionStatus returns status data on successful GET',
        () async {
      final mockResponse = {
        'status': 'active',
        'tier': 'premium',
      };

      when(() => mockHttpClient.get(
                any(),
                headers: any(named: 'headers'),
              ))
          .thenAnswer(
              (_) async => http.Response(jsonEncode(mockResponse), 200));

      final result = await stripeService.getSubscriptionStatus('user_123');

      expect(result['status'], 'active');
      expect(result['tier'], 'premium');
    });

    test('getSubscriptionStatus returns inactive status on 404', () async {
      when(() => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response('Not Found', 404));

      final result = await stripeService.getSubscriptionStatus('user_123');

      expect(result['status'], 'inactive');
      expect(result['tier'], 'free');
    });

    test('getSubscriptionStatus calls subscription endpoint with user id',
        () async {
      when(() => mockHttpClient.get(
                any(),
                headers: any(named: 'headers'),
              ))
          .thenAnswer((_) async => http.Response(
              jsonEncode({'status': 'active', 'tier': 'premium'}), 200));

      await stripeService.getSubscriptionStatus('user_999');

      final capturedUri = verify(() => mockHttpClient.get(
            captureAny(),
            headers: any(named: 'headers'),
          )).captured.single as Uri;
      expect(capturedUri.path,
          endsWith('/api/stripe/subscription-status/user_999'));
    });

    test('getSubscriptionStatus throws exception on other error status codes',
        () async {
      when(() => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response('Server Error', 500));

      expect(
        () => stripeService.getSubscriptionStatus('user_123'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to get subscription status'),
          ),
        ),
      );
    });

    test('getSubscriptionStatus throws on malformed JSON payload', () async {
      when(() => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response('{bad-json', 200));

      expect(
        () => stripeService.getSubscriptionStatus('user_123'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Network error getting subscription status'),
          ),
        ),
      );
    });

    test('getSubscriptionStatus returns empty map for empty 200 body',
        () async {
      when(() => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response('', 200));

      final result = await stripeService.getSubscriptionStatus('user_123');
      expect(result, isEmpty);
    });

    test('cancelSubscription returns true on successful cancellation',
        () async {
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('', 200));

      final result = await stripeService.cancelSubscription('user_123');

      expect(result, isTrue);

      final captured = verify(() => mockHttpClient.post(
            any(
              that: predicate<Uri>(
                (uri) => uri.path.endsWith('/cancel-subscription'),
              ),
            ),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          )).captured.single as String;
      final payload = jsonDecode(captured) as Map<String, dynamic>;
      expect(payload['user_id'], 'user_123');
    });

    test('cancelSubscription sends authorization header', () async {
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('', 200));

      await stripeService.cancelSubscription('user_123');

      final headers = verify(() => mockHttpClient.post(
            any(),
            headers: captureAny(named: 'headers'),
            body: any(named: 'body'),
          )).captured.single as Map<String, String>;

      expect(headers['Authorization'], 'Bearer mock_token');
    });

    test('cancelSubscription returns false on failed cancellation', () async {
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('Error', 500));

      final result = await stripeService.cancelSubscription('user_123');

      expect(result, isFalse);
    });

    test('cancelSubscription returns false on network exceptions', () async {
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenThrow(const SocketException('offline'));

      final result = await stripeService.cancelSubscription('user_123');

      expect(result, isFalse);
    });
  });
}
