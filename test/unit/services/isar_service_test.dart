import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:story_weaver_app/models/local/character_local_io.dart';
import 'package:story_weaver_app/services/isar_service_io.dart';

import '../../helpers/mocks.dart';

void main() {
  late MockIsar mockIsar;
  late MockIsarCollection<CharacterLocal> mockCharacterCollection;
  late Future<int?> Function(Isar, String) defaultFindExistingCharacterId;

  setUpAll(() {
    registerFallbackValue(CharacterLocal());
    // The real dedup lookup runs an Isar `.filter().characterIdEqualTo()`
    // query built from generated extension methods that mocktail cannot stub,
    // so capture the default and swap in a controllable seam per test.
    defaultFindExistingCharacterId = IsarService.findExistingCharacterId;
  });

  setUp(() {
    mockIsar = MockIsar();
    mockCharacterCollection = MockIsarCollection<CharacterLocal>();

    when(() => mockIsar.collection<CharacterLocal>())
        .thenReturn(mockCharacterCollection);
    when(() => mockCharacterCollection.put(any())).thenAnswer((_) async => 1);
    when(() => mockIsar.close()).thenAnswer((_) async => true);

    // Default: no prior row for any characterId (fresh insert path).
    IsarService.findExistingCharacterId = (_, __) async => null;

    IsarService.setTestInstance(mockIsar);
  });

  tearDown(() {
    IsarService.setTestInstance(null);
    IsarService.findExistingCharacterId = defaultFindExistingCharacterId;
  });

  group('IsarService', () {
    test('getInstance returns injected test instance', () async {
      final result = await IsarService.getInstance();
      expect(result, same(mockIsar));
    });

    test('getInstance returns same instance across calls', () async {
      final first = await IsarService.getInstance();
      final second = await IsarService.getInstance();

      expect(identical(first, second), isTrue);
    });

    test('instance getter returns injected instance', () {
      expect(IsarService.instance, same(mockIsar));
    });

    test('instance getter throws when not initialized', () {
      IsarService.setTestInstance(null);

      expect(() => IsarService.instance, throwsException);
    });

    test('saveCharacter writes character to collection', () async {
      final character = CharacterLocal()
        ..characterId = 'char_1'
        ..name = 'Luna'
        ..age = 8
        ..createdAt = DateTime(2026, 1, 1);

      await IsarService.saveCharacter(character);

      verify(() => mockCharacterCollection.put(character)).called(1);
    });

    test('saveCharacter propagates collection write failures', () async {
      final character = CharacterLocal()
        ..characterId = 'char-fail'
        ..name = 'Failing Character'
        ..age = 8
        ..createdAt = DateTime(2026, 1, 5);
      when(() => mockCharacterCollection.put(character))
          .thenThrow(Exception('write failed'));

      expect(
        () => IsarService.saveCharacter(character),
        throwsA(isA<Exception>()),
      );
    });

    test('saveCharacter forwards exact object instance', () async {
      final character = CharacterLocal()
        ..characterId = 'char_2'
        ..name = 'Kai'
        ..age = 7
        ..createdAt = DateTime(2026, 1, 2);

      await IsarService.saveCharacter(character);

      final captured = verify(() => mockCharacterCollection.put(captureAny()))
          .captured
          .single as CharacterLocal;
      expect(identical(captured, character), isTrue);
    });

    test('syncCharactersFromApi with empty list does not write', () async {
      await IsarService.syncCharactersFromApi(const []);

      verifyNever(() => mockCharacterCollection.put(any()));
    });

    test('syncCharactersFromApi maps one character payload', () async {
      final payload = <String, dynamic>{
        'id': 'api-1',
        'name': 'Milo',
        'age': '9',
        'avatar_url': 'https://example.com/a.png',
        'createdAt': '2026-01-10T00:00:00.000Z',
      };

      await IsarService.syncCharactersFromApi([payload]);

      final stored = verify(() => mockCharacterCollection.put(captureAny()))
          .captured
          .single as CharacterLocal;
      expect(stored.characterId, 'api-1');
      expect(stored.name, 'Milo');
      expect(stored.age, 9);
      expect(stored.avatarUrl, 'https://example.com/a.png');
      expect(stored.isSyncedToServer, isTrue);
    });

    test('syncCharactersFromApi writes each character in list', () async {
      final payload = [
        <String, dynamic>{
          'id': 'api-1',
          'name': 'Ari',
          'age': 6,
        },
        <String, dynamic>{
          'id': 'api-2',
          'name': 'Noor',
          'age': 10,
        },
      ];

      await IsarService.syncCharactersFromApi(payload);

      final stored = verify(() => mockCharacterCollection.put(captureAny()))
          .captured
          .cast<CharacterLocal>();
      expect(stored.length, 2);
      expect(stored[0].characterId, 'api-1');
      expect(stored[1].characterId, 'api-2');
    });

    test('syncCharactersFromApi reuses existing row id to update in place',
        () async {
      // A prior local row exists for this characterId → its auto-increment id
      // must be copied onto the incoming row so put() updates instead of
      // inserting a duplicate (the non-unique-index dedup fix).
      IsarService.findExistingCharacterId =
          (_, id) async => id == 'api-1' ? 42 : null;

      await IsarService.syncCharactersFromApi([
        <String, dynamic>{'id': 'api-1', 'name': 'Milo', 'age': 9},
      ]);

      final stored = verify(() => mockCharacterCollection.put(captureAny()))
          .captured
          .single as CharacterLocal;
      expect(stored.characterId, 'api-1');
      expect(stored.id, 42);
    });

    test('syncCharactersFromApi propagates failure after partial writes',
        () async {
      final payload = [
        <String, dynamic>{
          'id': 'api-ok',
          'name': 'Ari',
          'age': 6,
        },
        <String, dynamic>{
          'id': 'api-fail',
          'name': 'Noor',
          'age': 10,
        },
      ];
      when(() => mockCharacterCollection.put(any())).thenAnswer((invocation) {
        final character = invocation.positionalArguments.first as CharacterLocal;
        if (character.characterId == 'api-fail') {
          throw Exception('put failed');
        }
        return Future<int>.value(1);
      });

      expect(
        () => IsarService.syncCharactersFromApi(payload),
        throwsA(isA<Exception>()),
      );
    });

    test('syncCharactersFromApi defaults malformed age to zero', () async {
      final payload = <String, dynamic>{
        'id': 'api-bad-age',
        'name': 'Ivy',
        'age': 'not-a-number',
      };

      await IsarService.syncCharactersFromApi([payload]);

      final stored = verify(() => mockCharacterCollection.put(captureAny()))
          .captured
          .single as CharacterLocal;
      expect(stored.characterId, 'api-bad-age');
      expect(stored.age, 0);
    });

    test('saveCharacter handles concurrent writes', () async {
      final first = CharacterLocal()
        ..characterId = 'char-c1'
        ..name = 'Nora'
        ..age = 8
        ..createdAt = DateTime(2026, 1, 3);
      final second = CharacterLocal()
        ..characterId = 'char-c2'
        ..name = 'Zane'
        ..age = 9
        ..createdAt = DateTime(2026, 1, 4);

      await Future.wait([
        IsarService.saveCharacter(first),
        IsarService.saveCharacter(second),
      ]);

      final stored = verify(() => mockCharacterCollection.put(captureAny()))
          .captured
          .cast<CharacterLocal>();
      expect(stored.length, 2);
      expect(stored.map((c) => c.characterId),
          containsAll(<String>['char-c1', 'char-c2']));
    });

    test('close closes instance and clears singleton', () async {
      await IsarService.close();

      verify(() => mockIsar.close()).called(1);
      expect(() => IsarService.instance, throwsException);
    });

    test('close is safe when service is not initialized', () async {
      IsarService.setTestInstance(null);

      await IsarService.close();

      expect(() => IsarService.instance, throwsException);
    });
  });
}
