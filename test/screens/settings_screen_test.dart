import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/services/secure_storage_service.dart';
import 'package:story_weaver_app/settings_screen.dart';

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _MockHttpClientRequest();
  }

  @override
  bool autoUncompress = true;
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async {
    return _MockHttpClientResponse();
  }
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 400;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    final body = jsonEncode({
      'error': {'message': 'Malformed key'}
    });
    return Stream.value(utf8.encode(body)).listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

void main() {
  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
  }

  Future<void> pumpSettingsScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = _MockHttpOverrides();
  });

  tearDown(() {
    HttpOverrides.global = null;
  });

  testWidgets('theme toggle switches dark mode on', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpSettingsScreen(tester);

    expect(find.text('Dark Mode'), findsOneWidget);
    final darkModeTile = tester
        .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Dark Mode'));
    darkModeTile.onChanged?.call(true);
    await tester.pumpAndSettle();
    final secondDarkModeTile = tester
        .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Dark Mode'));
    secondDarkModeTile.onChanged?.call(true);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');
  });

  testWidgets('enabling own key reveals reading and validation controls',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpSettingsScreen(tester);

    await tester.tap(find.text('Use my own Gemini API key'));
    await tester.pumpAndSettle();

    expect(find.text('Gemini API Key'), findsOneWidget);
    expect(find.text('Validate & Save'), findsOneWidget);
    expect(find.text('How do I get an API key?'), findsOneWidget);
  });

  testWidgets('account/legal settings open privacy policy screen',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpSettingsScreen(tester);

    await tester.ensureVisible(find.text('Privacy Policy'));
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();

    expect(find.text('Privacy Policy'), findsWidgets);
  });

  testWidgets('subscription-style benefits are shown for BYOK users',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpSettingsScreen(tester);

    await tester.tap(find.text('Use my own Gemini API key'));
    await tester.pumpAndSettle();

    expect(find.text('Benefits'), findsOneWidget);
    expect(find.textContaining('No subscription needed'), findsOneWidget);
  });

  testWidgets('clear API key flow removes stored key', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({'use_own_api_key': true});
    await SecureStorageService.saveApiKey('gemini', 'AIza-test-key');

    await pumpSettingsScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('Gemini API Key'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    final saved = await SecureStorageService.getApiKey('gemini');
    expect(saved, isNull);
    expect(find.text('API key cleared'), findsOneWidget);
  });

  testWidgets('validates empty API key', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpSettingsScreen(tester);

    await tester.tap(find.text('Use my own Gemini API key'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Validate & Save'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter an API key'), findsOneWidget);
  });
}
