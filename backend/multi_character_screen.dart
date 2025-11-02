// lib/multi_character_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';  // Fixed import
import 'package:http/http.dart' as http;
import 'models.dart';
import 'story_result_screen.dart';

class MultiCharacterScreen extends StatefulWidget {
  const MultiCharacterScreen({super.key});

  @override
  State<MultiCharacterScreen> createState() => _MultiCharacterScreenState();
}

class _MultiCharacterScreenState extends State<MultiCharacterScreen> {
  List<Character> _allCharacters = [];
  bool _isLoading = true;
  String? _error;

  // State for user selections
  final Set<String> _selectedCharacterIds = {};
  String? _mainCharacterId;
  String _selectedTheme = 'Friendship';

  @override
  void initState() {
    super.initState();
    _fetchCharacters();
  }

  Future<void> _fetchCharacters() async {
final url = Uri.parse('http://127.0.0.1:5000/get-characters');      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _allCharacters = data.map((json) => Character.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load characters');
      }
    } catch (e) {
      setState(() {
        _error = "Could not fetch characters. Is the server running?";
        _isLoading = false;
      });
    }
  }

  Future<void> _generateStory() async {
    if (_mainCharacterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a main character.')),
      );
      return;
    }
    
    setState(() => _isLoading = true);

    final url = Uri.parse('http://127.0.0.1:5000/generate-multi-character-story');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'character_ids': _selectedCharacterIds.toList(),
          'main_character_id': _mainCharacterId,
          'theme': _selectedTheme,
        }),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final mainCharName = _allCharacters.firstWhere((c) => c.id == _mainCharacterId).name;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => StoryResultScreen(
              title: 'A Tale of Friendship',
              storyText: data['story'],
              wisdomGem: 'Working together makes any adventure better!',
            ),
          ));
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate story. Please try again.')),
          );
        }
      }

    } catch(e) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Could not connect to server.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    // Get the full character objects that have been selected
    final selectedCharacters = _allCharacters.where((c) => _selectedCharacterIds.contains(c.id)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Create a Group Story')),
      body: _isLoading && _allCharacters.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Section 1: Select all characters for the story
                    Text('1. Select characters for the story', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: _allCharacters.map((character) {
                          return CheckboxListTile(
                            title: Text(character.name),
                            subtitle: Text(character.role),
                            value: _selectedCharacterIds.contains(character.id),
                            onChanged: (isSelected) {
                              setState(() {
                                if (isSelected == true) {
                                  _selectedCharacterIds.add(character.id);
                                } else {
                                  _selectedCharacterIds.remove(character.id);
                                  // If the deselected character was the main one, reset it
                                  if (_mainCharacterId == character.id) {
                                    _mainCharacterId = null;
                                  }
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section 2: Choose the main character from the selected ones
                    Text('2. Choose the main character', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (selectedCharacters.isEmpty)
                      const Text('Select one or more characters above to choose a protagonist.')
                    else
                      Container(
                         decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: selectedCharacters.map((character) {
                            return RadioListTile<String>(
                              title: Text(character.name),
                              value: character.id,
                              groupValue: _mainCharacterId,
                              onChanged: (value) {
                                setState(() {
                                  _mainCharacterId = value;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Section 3: Generate Story Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _generateStory,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator() 
                        : const Text('Generate Group Story'),
                    ),
                  ],
                ),
    );
  }
}