import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';

void main() {
  group('JSON Parsing Robustness', () {
    test('Extracts JSON from clean response', () {
      const input = '{"key": "value"}';
      final result = ApiServiceManager.cleanJsonForTesting(input);
      expect(result, '{"key": "value"}');
    });

    test('Extracts JSON from markdown code block', () {
      const input = '''
Here is the JSON:
```json
{
  "key": "value"
}
```
''';
      final result = ApiServiceManager.cleanJsonForTesting(input);
      expect(result, contains('"key": "value"'));
      expect(result.trim().startsWith('{'), isTrue);
      expect(result.trim().endsWith('}'), isTrue);
    });

    test('Extracts JSON from generic code block', () {
      const input = '''
```
{
  "key": "value"
}
```
''';
      final result = ApiServiceManager.cleanJsonForTesting(input);
      expect(result, contains('"key": "value"'));
    });

    test('Extracts JSON from response with text before and after without code blocks', () {
      // This is the tricky case where Gemini forgets code blocks
      const input = '''
Sure, here is the JSON:
{
  "key": "value"
}
Hope you like it!
''';
      final result = ApiServiceManager.cleanJsonForTesting(input);
      expect(result, contains('"key": "value"'));
      // The regex should capture the object
      expect(result.trim().startsWith('{'), isTrue);
      expect(result.trim().endsWith('}'), isTrue);
    });
    
    test('Handles multiple generic backticks confuses split', () {
       const input = '''
```
{
  "title": "Story `Title`"
}
```
''';
       final result = ApiServiceManager.cleanJsonForTesting(input);
       expect(result, contains('"title": "Story `Title`"'));
    });
  });
}
