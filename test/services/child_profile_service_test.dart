import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/caregiver_service.dart';
import 'package:story_weaver_app/services/child_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = ChildProfileService();
  late List<http.Request> requests;
  var authCalls = 0;

  /// Two siblings, A active, each with caregiver names.
  Future<void> seedSiblings() async {
    await service.saveProfile(ChildProfile(id: 'a', name: 'Ada', age: 5));
    await service.saveProfile(ChildProfile(id: 'b', name: 'Ben', age: 9));
    await service.setActiveProfile(ChildProfile(id: 'a', name: 'Ada', age: 5));
    await CaregiverService().save('a', const CaregiverInfo(primary: 'Mommy'));
    await CaregiverService().save('b', const CaregiverInfo(primary: 'Papa'));
  }

  void useServer({required int deleteStatus, String signsInAs = 'u1'}) {
    ApiServiceManager.setTestClient(MockClient((request) async {
      if (request.url.path.contains('/auth/')) {
        authCalls++;
        return http.Response(
            jsonEncode({'token': 'mock', 'user_id': signsInAs}), 200);
      }
      requests.add(request);
      return http.Response(jsonEncode({'deleted': true}), deleteStatus);
    }));
  }

  setUp(() async {
    // This device has signed in before, as account u1.
    SharedPreferences.setMockInitialValues({'story_weaver_user_id': 'u1'});
    await ApiServiceManager.resetAuthForTest();
    requests = [];
    authCalls = 0;
  });

  test('a device that never signed in deletes locally, creating no account',
      () async {
    SharedPreferences.setMockInitialValues({});
    await seedSiblings();
    useServer(deleteStatus: 200);

    expect(await service.deleteProfile('a'), isTrue);

    expect(authCalls, 0);
    expect(requests, isEmpty);
    expect((await service.loadProfiles()).map((p) => p.id), ['b']);
  });

  test('a sign-in that changes account mid-delete keeps the profile',
      () async {
    await seedSiblings();
    // The server answers, but as a different (new, empty) account.
    useServer(deleteStatus: 200, signsInAs: 'someone-else');

    expect(await service.deleteProfile('a'), isFalse);

    expect((await service.loadProfiles()).map((p) => p.id), ['a', 'b']);
    expect((await CaregiverService().load('a')).primary, 'Mommy');
  });

  tearDown(() => ApiServiceManager.setTestClient(null));

  test('deleting one child removes only that child', () async {
    await seedSiblings();
    useServer(deleteStatus: 200);

    expect(await service.deleteProfile('a'), isTrue);

    // Only that profile's notes are asked for; never the whole account.
    expect(requests, hasLength(1));
    expect(requests.single.method, 'DELETE');
    expect(requests.single.url.path,
        '/child-profiles/a/parent-hidden-context');
    expect(requests.any((r) => r.url.path.contains('/api/user/')), isFalse);

    final left = await service.loadProfiles();
    expect(left.map((p) => p.id), ['b']);
    expect(await service.getActiveProfileId(), isNull);
    expect((await CaregiverService().load('a')).primary, isNull);
    // The sibling is untouched.
    expect((await CaregiverService().load('b')).primary, 'Papa');
  });

  test('deleting the inactive sibling keeps the active one active', () async {
    await seedSiblings();
    useServer(deleteStatus: 200);

    expect(await service.deleteProfile('b'), isTrue);

    expect((await service.loadProfiles()).map((p) => p.id), ['a']);
    expect(await service.getActiveProfileId(), 'a');
    expect((await CaregiverService().load('a')).primary, 'Mommy');
  });

  test('a failed server call keeps the profile so it can be retried',
      () async {
    await seedSiblings();
    useServer(deleteStatus: 500);

    expect(await service.deleteProfile('a'), isFalse);

    expect((await service.loadProfiles()).map((p) => p.id), ['a', 'b']);
    expect(await service.getActiveProfileId(), 'a');
    expect((await CaregiverService().load('a')).primary, 'Mommy');

    // Back online: the same delete now goes through.
    useServer(deleteStatus: 200);
    expect(await service.deleteProfile('a'), isTrue);
    expect((await service.loadProfiles()).map((p) => p.id), ['b']);
  });
}
