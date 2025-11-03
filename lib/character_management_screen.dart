// lib/character_management_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'character_creation_screen_enhanced.dart';
import 'character_edit_screen.dart';
import 'subscription_service.dart';
import 'paywall_dialog.dart';

class CharacterManagementScreen extends StatefulWidget {
  const CharacterManagementScreen({super.key});

  @override
  State<CharacterManagementScreen> createState() =>
      _CharacterManagementScreenState();
}

class _CharacterManagementScreenState extends State<CharacterManagementScreen> {
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

      // Your backend returns either a raw list OR {"items": [...]}
      final List list =
          (decoded is List) ? decoded : (decoded['items'] as List);

      return list.map((j) => Character.fromJson(j)).toList().cast<Character>();
    } else {
      throw Exception(
          'Failed to load characters. Status code: ${response.statusCode}');
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
          // Check character limit
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

          // Go to the creation screen; after returning, refresh list
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
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple.shade100,
                    child: Text(
                      c.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
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
                        icon: const Icon(Icons.edit, color: Colors.deepPurple),
                        tooltip: 'Edit',
                        onPressed: () async {
                          final updated =
                              await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => CharacterEditScreen(character: c),
                            ),
                          );
                          if (updated == true) {
                            _refreshCharacters();
                          }
                        },
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                  onTap: () async {
                    final updated = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => CharacterEditScreen(character: c),
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
