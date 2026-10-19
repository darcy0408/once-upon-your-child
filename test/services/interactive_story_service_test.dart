import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/interactive_story_service.dart';

import '../helpers/pick_a_path_test_helpers.dart';

/// MT-465: the picked scene's world bible, plot driver and atmosphere must
/// reach POST /generate-interactive-story under the exact keys the backend
/// reads (worldBible / conflictHook / sensoryPalette).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic>? startBody;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    startBody = null;
    final client = MockClient((request) async {
      if (request.url.path.contains('/auth/anonymous')) {
        return http.Response(
            jsonEncode({'token': 'mock', 'user_id': 'u1'}), 200);
      }
      if (request.url.path.contains('/generate-interactive-story')) {
        startBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(PickAPathTestHelpers.createStartStoryResponseJson()),
          200,
        );
      }
      return http.Response('Not Found', 404);
    });
    InteractiveStoryService.setTestClient(client);
    ApiServiceManager.setTestClient(client);
  });

  tearDown(() {
    InteractiveStoryService.setTestClient(null);
    ApiServiceManager.setTestClient(null);
  });

  Future<void> start({
    String? worldBible,
    String? conflictHook,
    String? sensoryPalette,
  }) async {
    await const InteractiveStoryService().startInteractiveStory(
      userId: 'u1',
      characterId: 'c1',
      theme: 'Magic',
      worldBible: worldBible,
      conflictHook: conflictHook,
      sensoryPalette: sensoryPalette,
    );
  }

  test('sends worldBible, conflictHook and sensoryPalette when given',
      () async {
    await start(
      worldBible: 'A lantern-lit harbor town.',
      conflictHook: 'The tide bell has gone silent.',
      sensoryPalette: 'salt air, warm wood',
    );

    expect(startBody, isNotNull);
    expect(startBody!['worldBible'], 'A lantern-lit harbor town.');
    expect(startBody!['conflictHook'], 'The tide bell has gone silent.');
    expect(startBody!['sensoryPalette'], 'salt air, warm wood');
  });

  test('omits the three keys when null or empty', () async {
    await start(worldBible: null, conflictHook: '', sensoryPalette: null);

    expect(startBody, isNotNull);
    expect(startBody!.containsKey('worldBible'), isFalse);
    expect(startBody!.containsKey('conflictHook'), isFalse);
    expect(startBody!.containsKey('sensoryPalette'), isFalse);
  });
}
