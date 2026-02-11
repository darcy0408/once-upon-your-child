import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isar/isar.dart';

// ============================================================================
// HTTP & NETWORK MOCKS
// ============================================================================

/// Mock HTTP Client for API calls
class MockHttpClient extends Mock implements http.Client {}

/// Mock HTTP Response
class MockHttpResponse extends Mock implements http.Response {}

// ============================================================================
// STORAGE MOCKS
// ============================================================================

/// Mock SharedPreferences
class MockSharedPreferences extends Mock implements SharedPreferences {}

/// Mock Isar Database
class MockIsar extends Mock implements Isar {}

/// Mock Isar Collection
class MockIsarCollection<T> extends Mock implements IsarCollection<T> {}

/// Mock Isar QueryBuilder
class MockQueryBuilder<T> extends Mock implements QueryBuilder<T, T, QWhere> {}

// ============================================================================
// SERVICE MOCKS (for integration testing)
// ============================================================================

// Note: Service mocks should be created using mocktail in individual test files
// Example:
// class MockSubscriptionService extends Mock implements SubscriptionService {}
// class MockStripeService extends Mock implements StripeService {}
// class MockIsarService extends Mock implements IsarService {}
// class MockApiServiceManager extends Mock implements ApiServiceManager {}

// ============================================================================
// FALLBACK VALUE REGISTRATION
// ============================================================================

/// Register common fallback values for mocktail matchers
void registerCommonMocks() {
  // HTTP fallbacks
  registerFallbackValue(Uri());
  registerFallbackValue(http.Request('GET', Uri()));

  // Headers fallback
  registerFallbackValue(<String, String>{});
}

// ============================================================================
// TEST HELPERS
// ============================================================================

/// Create a mock HTTP response with JSON body
http.Response createMockJsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
  Map<String, String>? headers,
}) {
  return http.Response(
    body.toString(),
    statusCode,
    headers: headers ?? {'content-type': 'application/json'},
  );
}

/// Create a mock HTTP error response
http.Response createMockErrorResponse({
  int statusCode = 500,
  String? message,
}) {
  return http.Response(
    message ?? 'Internal Server Error',
    statusCode,
    headers: {'content-type': 'text/plain'},
  );
}
