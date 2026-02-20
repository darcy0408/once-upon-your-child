// lib/character_selection_screen.dart

import 'package:flutter/material.dart';
import 'models.dart'; // Assuming your Character model is in here
import 'character_creation_screen_enhanced.dart';
import 'screens/wizard_story_screen.dart';
import 'widgets/app_button.dart';
import 'services/isar_service.dart';
import 'services/api_service_manager.dart';

class CharacterSelectionScreen extends StatefulWidget {
  const CharacterSelectionScreen({super.key});

  @override
  State<CharacterSelectionScreen> createState() =>
      _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends State<CharacterSelectionScreen> {
  late Future<List<Character>> _charactersFuture;
  Character? _selectedCharacter;
  List<Character> _allCharacters = [];

  @override
  void initState() {
    super.initState();
    _charactersFuture = _fetchCharacters();
  }

  Future<List<Character>> _fetchCharacters() async {
    try {
      final api = ApiServiceManager();
      final response = await api.get('/get-characters');
      final List<dynamic> data = response['data'] is List
          ? response['data'] as List<dynamic>
          : (response['items'] as List<dynamic>? ?? const []);
      final characters = data
          .map((json) => Character.fromJson(json as Map<String, dynamic>))
          .toList();

      // Sync to local storage for offline access
      try {
        await IsarService.syncCharactersFromApi(data);
      } catch (e) {
        debugPrint('Failed to sync characters to local storage: $e');
      }

      _allCharacters = characters;
      return characters;
    } catch (e) {
      // Network error - fallback to local storage
      debugPrint('Network error, loading from local storage: $e');
      final local = await IsarService.getAllCharacters();
      _allCharacters = local;
      return local;
    }
  }

  void _navigateToCharacterCreation() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (context) => const CharacterCreationScreenEnhanced()),
    );
    // If a character was created, refresh the list
    if (result == true) {
      setState(() {
        _charactersFuture = _fetchCharacters();
      });
    }
  }

  void _selectCharacter(Character character) {
    setState(() {
      _selectedCharacter = character;
    });
  }

  void _proceedWithSelectedCharacter() {
    final selected = _selectedCharacter;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a character first.')),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => WizardStoryScreen(
          initialCharacter: selected,
          availableCharacters: _allCharacters,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Hero'),
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder<List<Character>>(
        future: _charactersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final characters = snapshot.data ?? [];

          if (characters.isEmpty) {
            return _buildEmptyState();
          }

          return _buildCharacterList(characters);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCharacterCreation,
        icon: const Icon(Icons.add),
        label: const Text('Create New Character'),
        backgroundColor: Colors.deepPurple,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton.icon(
            onPressed: _selectedCharacter == null
                ? null
                : _proceedWithSelectedCharacter,
            icon: const Icon(Icons.arrow_forward),
            label: Text(
              _selectedCharacter == null
                  ? 'Select a Character to Continue'
                  : 'Continue as ${_selectedCharacter!.name}',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No characters found.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a new character to get started!',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          AppButton.primary(
            onPressed: _navigateToCharacterCreation,
            label: 'Create a Character',
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterList(List<Character> characters) {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: 0.75,
      ),
      itemCount: characters.length,
      itemBuilder: (context, index) {
        final character = characters[index];
        return Card(
          color: _selectedCharacter?.id == character.id
              ? Colors.deepPurple.withValues(alpha: 0.08)
              : null,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: _selectedCharacter?.id == character.id
                  ? Colors.deepPurple
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: () => _selectCharacter(character),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Hero(
                      tag: 'avatar_${character.id}',
                      child: character.buildAvatar(size: 100),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    character.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Age: ${character.age}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
