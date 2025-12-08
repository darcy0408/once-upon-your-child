import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const backendUrl = 'https://story-weaver-app-production.up.railway.app';

  print('Testing backend connection...');
  print('URL: $backendUrl');

  try {
    // Test 1: Health check
    print('\n1. Testing /health endpoint...');
    final healthResponse = await http.get(
      Uri.parse('$backendUrl/health'),
    ).timeout(Duration(seconds: 10));

    print('   Status: ${healthResponse.statusCode}');
    print('   Response: ${healthResponse.body}');

    if (healthResponse.statusCode == 200) {
      print('   ? Health check passed!');
    } else {
      print('   ?? Health check failed!');
    }

    // Test 2: Generate story endpoint
    print('\n2. Testing /api/stories/generate endpoint...');
    final storyResponse = await http.post(
      Uri.parse('$backendUrl/api/stories/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'character_name': 'Test',
        'age': 5,
        'theme': 'friendship',
        'user_id': 'test-user',
      }),
    ).timeout(Duration(seconds: 30));

    print('   Status: ${storyResponse.statusCode}');
    if (storyResponse.statusCode == 200) {
      print('   ? Story generation works!');
    } else {
      print('   ?? Story generation failed!');
      print('   Response: ${storyResponse.body}');
    }
  } catch (e) {
    print('\n? Connection failed!');
    print('Error: $e');
    print('\nThis error means the app cannot reach the backend server.');
  }
}
