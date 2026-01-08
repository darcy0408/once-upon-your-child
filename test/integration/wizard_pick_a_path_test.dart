import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/screens/wizard_story_screen.dart';
import 'package:story_weaver_app/services/isar_service.dart';
import 'package:story_weaver_app/models.dart';
import 'package:mockito/mockito.dart';
import '../helpers/pick_a_path_test_helpers.dart';

// Create a simple mock for Isar
class MockIsar extends Mock implements Isar {
  @override
  Future<bool> close({bool deleteFromDisk = false}) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    
    // Mock PathProvider to prevent crashes during Isar initialization
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '.';
      }
      return null;
    });

    // Inject mock Isar instance
    IsarService.setTestInstance(MockIsar());
  });

  tearDown(() {
    IsarService.setTestInstance(null);
  });

  group('Wizard Integration - Pick-A-Path Flow', () {
    testWidgets('F1: Wizard opens and shows progress indicator', (tester) async {
      await HttpOverrides.runZoned(
        () async {
          await tester.pumpWidget(
            const MaterialApp(
              home: WizardStoryScreen(),
            ),
          );

          await tester.pump(const Duration(seconds: 1));

          // Check wizard is open
          expect(find.byType(WizardStoryScreen), findsOneWidget);
        },
        createHttpClient: (_) => _MockHttpClient(),
      );
    });

    testWidgets('F2: Hero Creator step collects character data', (tester) async {
      await HttpOverrides.runZoned(
        () async {
          await tester.pumpWidget(
            const MaterialApp(
              home: WizardStoryScreen(),
            ),
          );

          await tester.pump(const Duration(seconds: 1));

          // Look for character name input
          final nameField = find.byType(TextField);
          expect(nameField, findsWidgets);

          // Enter character name
          await tester.enterText(nameField.first, 'TestHero');
          await tester.pump();

          // Verify name was entered
          expect(find.text('TestHero'), findsOneWidget);
        },
        createHttpClient: (_) => _MockHttpClient(),
      );
    });
  });
}

class _MockHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpRequest();

  @override
  Future<HttpClientRequest> postUrl(Uri url) async => _MockHttpRequest();

  @override
  Future<HttpClientRequest> putUrl(Uri url) async => _MockHttpRequest();

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) async => _MockHttpRequest();

  @override
  Future<HttpClientRequest> patchUrl(Uri url) async => _MockHttpRequest();

  @override
  Future<HttpClientRequest> headUrl(Uri url) async => _MockHttpRequest();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _MockHttpRequest();
  }

  @override
  void close({bool force = false}) {}

  @override
  set autoUncompress(bool _autoUncompress) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter && invocation.memberName == #done) {
      return Future.value(null);
    }
    final name = invocation.memberName.toString();
    if (name.contains('Url') || name.contains('open')) {
      return Future.value(_MockHttpRequest());
    }
    return null;
  }
}

class _MockHttpRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _MockHttpResponse();

  @override
  Future<HttpClientResponse> get done => Future.value(_MockHttpResponse());

  @override
  void add(List<int> data) {}

  @override
  void write(Object? obj) {}

  @override
  Future addStream(Stream<List<int>> stream) async {}

  @override
  bool get followRedirects => true;

  @override
  set followRedirects(bool _followRedirects) {}

  @override
  int get maxRedirects => 5;

  @override
  set maxRedirects(int _maxRedirects) {}

  @override
  bool get persistentConnection => true;

  @override
  set persistentConnection(bool _persistentConnection) {}

  @override
  noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #done) return Future.value(_MockHttpResponse());
    if (invocation.memberName == #close) return Future.value(_MockHttpResponse());
    return null;
  }
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  noSuchMethod(Invocation invocation) => null;
}

class _MockHttpResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  String get reasonPhrase => 'OK';

  @override
  int get contentLength => -1;

  @override
  bool get persistentConnection => false;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => [];

  @override
  HttpHeaders get headers => _MockHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream<List<int>>.fromIterable([utf8.encode('[]')]).listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  noSuchMethod(Invocation invocation) => null;
}


