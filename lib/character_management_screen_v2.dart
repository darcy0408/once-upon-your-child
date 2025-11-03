// lib/character_management_screen_v2.dart
// Enhanced version with DELETE functionality and visual avatars

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'character_creation_screen_enhanced.dart';
import 'character_edit_screen_enhanced.dart';
import 'subscription_service.dart';
import 'paywall_dialog.dart';
import 'enhanced_character_avatar.dart';

class CharacterManagementScreenV2 extends StatefulWidget {
  const CharacterManagementScreenV2({super.key});

  @override
  State<CharacterManagementScreenV2> createState() =>
      _CharacterManagementScreenV2State();
}

class _CharacterManagementScreenV2State
    extends State<CharacterManagementScreenV2> {
  late Future<List<Character>> _charactersFuture;
  final _subscriptionService = SubscriptionService();

  @override
  void initState() {
    super.initState();
    _charactersFuture = _fetchCharacters();
  }

  Future<List<Character>> _fetchCharacters() async {
    final url = Uri.parse('http://127.0.0.1:5000/get-characters');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List list =
          (decoded is List) ? decoded : (decoded['items'] as List);
      return list.map((j) => Character.fromJson(j)).toList().cast<Character>();
    } else {
      throw Exception(
          'Failed to load characters. Status code: ${response.statusCode}');
    }
  }

  Future<void> _deleteCharacter(Character character) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Character'),
        content: Text(
            'Are you sure you want to delete ${character.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final url = Uri.parse('http://127.0.0.1:5000/characters/${character.id}');
      final response = await http.delete(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${character.name} was deleted'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshCharacters();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete character'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _refreshCharacters() {
    setState(() {
      _charactersFuture = _fetchCharacters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Kids'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshCharacters,
            tooltip: 'Refresh List',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final snapshot = await _charactersFuture;
          final currentCount = snapshot.length;
          final canCreate =
              await _subscriptionService.canCreateCharacter(currentCount);

          if (!canCreate) {
            final maxChars = await _subscriptionService.getMaxCharacters();
            await PaywallDialog.showCharacterLimitDialog(
              context,
              maxCharacters: maxChars,
            );
            return;
          }

          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
                builder: (_) => const CharacterCreationScreenEnhanced()),
          );
          if (created == true) {
            _refreshCharacters();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Character>>(
        future: _charactersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final characters = snapshot.data ?? const <Character>[];
          if (characters.isEmpty) {
            return const Center(
              child: Text(
                'No kids yet.\nTap + to add one!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: characters.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final c = characters[i];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: EnhancedCharacterAvatar(character: c, size: 50),
                  title: Text(
                    c.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      if ((c.age != null && c.age! > 0) ||
                          (c.gender != null && c.gender!.trim().isNotEmpty))
                        Text(
                          [
                            if (c.age != null && c.age! > 0) 'Age ${c.age}',
                            if (c.gender != null && c.gender!.trim().isNotEmpty)
                              c.gender!.trim(),
                          ].join(' • '),
                        ),
                      if (c.role != null && c.role!.isNotEmpty)
                        Text(
                          c.role!,
                          style: TextStyle(
                            color: Colors.deepPurple.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.deepPurple),
                        tooltip: 'Edit',
                        onPressed: () async {
                          final updated =
                              await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CharacterEditScreenEnhanced(character: c),
                            ),
                          );
                          if (updated == true) {
                            _refreshCharacters();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Delete',
                        onPressed: () => _deleteCharacter(c),
                      ),
                    ],
                  ),
                  onTap: () async {
                    final updated = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) =>
                            CharacterEditScreenEnhanced(character: c),
                      ),
                    );
                    if (updated == true) {
                      _refreshCharacters();
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
