// lib/character_selection_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config/environment.dart';
import 'models.dart'; // Assuming your Character model is in here
import 'character_creation_screen_enhanced.dart';
import 'widgets/app_button.dart';

class CharacterSelectionScreen extends StatefulWidget {
  const CharacterSelectionScreen({super.key});

  @override
  State<CharacterSelectionScreen> createState() =>
      _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends State<CharacterSelectionScreen> {
  late Future<List<Character>> _charactersFuture;

  @override
  void initState() {
    super.initState();
    _charactersFuture = _fetchCharacters();
  }

  Future<List<Character>> _fetchCharacters() async {
    try {
      final response = await http.get(
        Uri.parse('${Environment.backendUrl}/get-characters'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Character.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load characters: ${response.statusCode}');
      }
    } catch (e) {
      // In a real app, you'd want to show a proper error message
      debugPrint('Error fetching characters: $e');
      return []; // Return empty list on error
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
    // TODO: Implement the logic to proceed with the selected character
    // For now, we'll just pop and return the character
    Navigator.of(context).pop(character);
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
          AppButton(
            onPressed: _navigateToCharacterCreation,
            text: 'Create a Character',
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterList(List<Character> characters) {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: characters.length,
      itemBuilder: (context, index) {
        final character = characters[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            leading: const Icon(Icons.person, size: 40), // Placeholder for avatar
            title: Text(character.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Age: ${character.age}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _selectCharacter(character),
          ),
        );
      },
    );
  }
}
