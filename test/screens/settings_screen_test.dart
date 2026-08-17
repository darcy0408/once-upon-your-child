import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    return _MockHttpClientRequest(url);
  }

  @override
  bool autoUncompress = true;

  @override
  void close({bool force = false}) {}
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  _MockHttpClientRequest([this.url]);

  final Uri? url;

  @override
  bool followRedirects = false;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  int contentLength = -1;

  @override
  Encoding encoding = utf8;

  @override
  bool bufferOutput = true;

  @override
  final HttpHeaders headers = _NoopHttpHeaders();

  @override
  void add(List<int> data) {}

  @override
  void write(Object? object) {}

  @override
  Future addStream(Stream<List<int>> stream) async {
    await stream.drain();
  }

  @override
  Future flush() async {}

  @override
  Future<HttpClientResponse> close() async {
    return _MockHttpClientResponse(url);
  }

  @override
  Future<HttpClientResponse> get done async => _MockHttpClientResponse(url);
}

class _NoopHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void removeAll(String name) {}

  @override
  String? value(String name) => null;

  @override
  List<String>? operator [](String name) => null;

  @override
  void forEach(void Function(String name, List<String> values) action) {}
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  _MockHttpClientResponse([this.url]);

  final Uri? url;

  bool get _isAnthropicApi {
    final host = url?.host ?? '';
    return host.contains('anthropic.com') ||
        (url?.path ?? '').contains('/messages');
  }

  @override
  int get statusCode => _isAnthropicApi ? 400 : 200;

  @override
  String get reasonPhrase => _isAnthropicApi ? 'Bad Request' : 'OK';

  @override
  int get contentLength => -1;

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => _NoopHttpHeaders();

  @override
  List<Cookie> get cookies => const [];

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    final body = _isAnthropicApi
        ? jsonEncode({
            'error': {'message': 'Malformed key'}
          })
        : '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>';
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
    // Use timed pumps instead of pumpAndSettle to avoid infinite animation timeouts
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = _MockHttpOverrides();
  });

  tearDown(() {
    HttpOverrides.global = null;
  });

  testWidgets('no dark-mode toggle is offered', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpSettingsScreen(tester);

    // The old test here asserted the toggle existed and wrote 'dark' to
    // SharedPreferences — which it genuinely did. What it never checked was
    // whether anything rendered differently, and nothing did: MaterialApp was
    // never given a themeMode, so the switch moved, the preference persisted,
    // and the app looked identical. Palette is band-driven by design, so the
    // control was removed rather than backfilled with a real dark theme.
    expect(find.text('Dark Mode'), findsNothing);
  });

  testWidgets('premium subscription card is shown', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpSettingsScreen(tester);

    expect(find.text('Premium Subscription'), findsOneWidget);
  });

  testWidgets('account/legal settings open privacy policy screen',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpSettingsScreen(tester);

    await tester.ensureVisible(find.text('Privacy Policy'));
    await tester.tap(find.text('Privacy Policy'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Privacy Policy'), findsWidgets);
  });
}
