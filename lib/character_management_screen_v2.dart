// lib/character_management_screen_v2.dart
// Enhanced version with DELETE functionality and visual avatars

import 'package:flutter/material.dart';

import 'models.dart';
import 'character_creation_screen_enhanced.dart';
import 'character_edit_screen_enhanced.dart';
import 'character_evolution_screen.dart';
import 'subscription_service.dart';
import 'paywall_dialog.dart';
import 'enhanced_character_avatar.dart';
import 'services/api_service_manager.dart';

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
    final api = ApiServiceManager();
    final response = await api.get('/get-characters');
    final List<dynamic> list = response['data'] is List
        ? response['data'] as List<dynamic>
        : (response['items'] as List<dynamic>? ?? const []);
    return list
        .map((j) => Character.fromJson(j as Map<String, dynamic>))
        .toList()
        .cast<Character>();
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
      final api = ApiServiceManager();
      await api.delete('/characters/${character.id}');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${character.name} was deleted'),
          backgroundColor: Colors.green,
        ),
      );
      _refreshCharacters();
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
            if (!context.mounted) return;
            await PaywallDialog.showCharacterLimitDialog(
              context,
              maxCharacters: maxChars,
            );
            return;
          }

          if (!context.mounted) return;
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

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'You have ${characters.length}/5 characters',
                  style: TextStyle(
                    fontSize: 16,
                    color: characters.length >= 5 ? Colors.red : Colors.grey[700],
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
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
                      Builder(
                        builder: (_) {
                          final genderDisplay = c.gender?.trim();
                          final parts = <String>[];
                          if (c.age > 0) {
                            parts.add('Age ${c.age}');
                          }
                          if (genderDisplay != null &&
                              genderDisplay.isNotEmpty) {
                            parts.add(genderDisplay);
                          }
                          if (parts.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Text(parts.join(' • '));
                        },
                      ),
                      if (c.role.trim().isNotEmpty)
                        Text(
                          c.role.trim(),
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
                         icon: const Icon(Icons.trending_up, color: Colors.green),
                         tooltip: 'View Growth',
                         onPressed: () {
                           Navigator.of(context).push(
                             MaterialPageRoute(
                               builder: (_) => CharacterEvolutionScreen(character: c),
                             ),
                           );
                         },
                       ),
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
          ),
                ),
              ],
            );
        },
      ),
    );
  }
}
