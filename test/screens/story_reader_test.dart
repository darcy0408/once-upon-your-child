import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/story_reader_screen.dart';

void main() {
  const ttsChannel = MethodChannel('flutter_tts');

  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
  }

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async {
      switch (call.method) {
        case 'setLanguage':
        case 'setSpeechRate':
        case 'setPitch':
        case 'stop':
          return 1;
        case 'speak':
          return 1;
        case 'pause':
          return 1;
        default:
          return 1;
      }
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
  });

  Widget buildSubject() {
    return const MaterialApp(
      home: StoryReaderScreen(
        title: 'The Star Trail',
        storyText: 'Once upon a moonlit night, Luna followed a shining map.',
        characterName: 'Luna',
      ),
    );
  }

  testWidgets('renders title, text, and character banner', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('The Star Trail'), findsOneWidget);
    expect(find.textContaining('A story for Luna'), findsOneWidget);
    expect(find.byType(RichText), findsWidgets);
  });

  testWidgets('read action is wired and keeps reader screen visible',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Read'), findsOneWidget);
    await tester.tap(find.text('Read'));
    await tester.pump();

    expect(find.byType(StoryReaderScreen), findsOneWidget);
  });

  testWidgets('stop action is available after starting playback',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Read'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(find.byType(StoryReaderScreen), findsOneWidget);
  });

  testWidgets('stop resets playback state', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Read'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();

    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('back button returns to previous route', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const StoryReaderScreen(
                          title: 'The Star Trail',
                          storyText: 'A short story.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Reader'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open Reader'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Open Reader'), findsOneWidget);
  });
}
