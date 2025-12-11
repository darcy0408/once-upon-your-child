import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/local/character_local.dart';
import '../services/isar_service.dart';

part 'character_provider.g.dart';

@riverpod
class CharacterList extends _$CharacterList {
  @override
  Future<List<CharacterLocal>> build() async {
    final isar = await IsarService.getInstance();
    return await isar.characterLocals.where().findAll();
  }

  Future<void> addCharacter(CharacterLocal character) async {
    final isar = await IsarService.getInstance();
    await isar.writeTxn(() async {
      await isar.characterLocals.put(character);
    });
    ref.invalidateSelf();
  }

  Future<void> deleteCharacter(int id) async {
    final isar = await IsarService.getInstance();
    await isar.writeTxn(() async {
      await isar.characterLocals.delete(id);
    });
    ref.invalidateSelf();
  }

  Future<void> updateCharacter(CharacterLocal character) async {
    final isar = await IsarService.getInstance();
    await isar.writeTxn(() async {
      await isar.characterLocals.put(character);
    });
    ref.invalidateSelf();
  }
}

/// Provider for the currently selected character
@riverpod
class SelectedCharacter extends _$SelectedCharacter {
  @override
  CharacterLocal? build() {
    return null;
  }

  void selectCharacter(CharacterLocal character) {
    state = character;
  }

  void clearSelection() {
    state = null;
  }
}
