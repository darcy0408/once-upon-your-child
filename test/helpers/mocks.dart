import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// HTTP Client Mock
class MockHttpClient extends Mock implements http.Client {}

// Shared Preferences Mock
class MockSharedPreferences extends Mock implements SharedPreferences {}

// Helper to register common fallback values if needed
void registerCommonMocks() {
  registerFallbackValue(Uri());
}
