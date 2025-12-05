import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/character_creation_screen_enhanced.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Character creation form validates required fields', (tester) async {
    await HttpOverrides.runZoned(
      () async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: CharacterCreationScreenEnhanced()),
          ),
        );

        // Wait for the widget to be built
        await tester.pumpAndSettle();

        // Scroll to the create button at the bottom of the form
        final createButton = find.text('Create Character');
        await tester.scrollUntilVisible(
          createButton,
          500.0, // Scroll 500 pixels at a time
          scrollable: find.byType(Scrollable).first,
        );

        // Tap the create button without entering data
        await tester.tap(createButton);
        await tester.pumpAndSettle();

        // Required validators should trigger
        expect(find.text('Required'), findsWidgets);
      },
      createHttpClient: (_) => _FakeAvatarHttpClient(),
    );
  });
}

class _FakeAvatarHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _FakeAvatarHttpRequest(method: method, uri: url);
  }

  @override
  void close({bool force = false}) {}

  @override
  bool autoUncompress = true;

  @override
  Duration? connectionTimeout;

  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  int? maxConnectionsPerHost;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAvatarHttpRequest implements HttpClientRequest {
  _FakeAvatarHttpRequest({required this.method, required this.uri});

  @override
  final String method;

  @override
  final Uri uri;

  @override
  final HttpHeaders headers = HttpHeaders();

  @override
  bool bufferOutput = false;

  @override
  int contentLength = 0;

  @override
  Encoding encoding = utf8;

  @override
  bool followRedirects = false;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = false;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}

  @override
  void add(List<int> data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain();

  @override
  Future<void> flush() async {}

  @override
  Future<HttpClientResponse> close() async => _FakeAvatarHttpResponse(uri);

  @override
  Future<HttpClientResponse> get done async => _FakeAvatarHttpResponse(uri);

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAvatarHttpResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeAvatarHttpResponse(Uri uri)
      : _bytes = uri.path.toLowerCase().endsWith('.svg')
            ? utf8.encode('<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>')
            : base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y5QKUkAAAAASUVORK5CYII=',
              );

  final List<int> _bytes;

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _bytes.length;

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  CompressionState get compressionState => CompressionState.notCompressed;

  @override
  HttpHeaders get headers => HttpHeaders();

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => const [];

  @override
  Future<Socket> detachSocket() => throw UnimplementedError();

  @override
  Future<bool> any(bool Function(List<int> element) test) => Stream<List<int>>.fromIterable([_bytes]).any(test);

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
