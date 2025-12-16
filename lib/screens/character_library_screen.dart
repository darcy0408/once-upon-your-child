import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import 'wizard_story_screen.dart';

/// Character Library Screen
///
/// Displays all saved characters in a beautiful grid
/// Features:
/// - View all saved characters
/// - Delete characters
/// - Create new story with a character
/// - Character stats (age, role, etc.)
class CharacterLibraryScreen extends StatefulWidget {
  const CharacterLibraryScreen({super.key});

  @override
  State<CharacterLibraryScreen> createState() => _CharacterLibraryScreenState();
}

class _CharacterLibraryScreenState extends State<CharacterLibraryScreen> {
  List<Character> _characters = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final url = Uri.parse('${Environment.backendUrl}/get-characters');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> characterList = decoded is List ? decoded : (decoded['characters'] ?? []);
        final characters = characterList
            .map((data) => Character.fromJson(data))
            .toList();

        if (mounted) {
          setState(() {
            _characters = characters;
            _isLoading = false;
          });
          debugPrint('✅ Loaded ${characters.length} characters');
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load characters (${response.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error loading characters: $e');
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteCharacter(Character character) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Character?'),
        content: Text('Are you sure you want to delete ${character.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final url = Uri.parse('${Environment.backendUrl}/characters/${character.id}');
    try {
      final response = await http.delete(url);
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${character.name} deleted'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadCharacters(); // Reload the list
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete character (${response.statusCode})'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting character: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _createStoryWithCharacter(Character character) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WizardStoryScreen(
          initialCharacter: character,
          availableCharacters: _characters,
        ),
      ),
    );
  }

  String _getEmojiForCharacter(Character character) {
    final role = character.role;
    if (role.contains('Adventurer')) return '🗺️';
    if (role.contains('Thinker')) return '💭';
    if (role.contains('Artist')) return '🎨';
    if (role.contains('Helper')) return '🤝';
    if (role.contains('Athlete')) return '⚡';
    if (role.contains('Shy')) return '😊';
    // Default based on gender
    if (character.gender == 'Boy') return '👦';
    return '👧';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Characters'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.magicalBackground,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _error!,
                            style: const TextStyle(color: AppColors.error),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          ElevatedButton.icon(
                            onPressed: _loadCharacters,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _characters.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '📚',
                                style: TextStyle(fontSize: 80),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                'No Characters Yet',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: AppColors.textDark,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Create your first character to get started!',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: AppColors.textDark.withAlpha(179),
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const WizardStoryScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Create Character'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.textLight,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xl,
                                    vertical: AppSpacing.md,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCharacters,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: AppSpacing.md,
                            mainAxisSpacing: AppSpacing.md,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: _characters.length,
                          itemBuilder: (context, index) {
                            final character = _characters[index];
                            return _CharacterCard(
                              character: character,
                              emoji: _getEmojiForCharacter(character),
                              onDelete: () => _deleteCharacter(character),
                              onCreateStory: () => _createStoryWithCharacter(character),
                            );
                          },
                        ),
                      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WizardStoryScreen(
                availableCharacters: _characters,
              ),
            ),
          ).then((_) => _loadCharacters()); // Reload after returning
        },
        icon: const Icon(Icons.add),
        label: const Text('New Character'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final Character character;
  final String emoji;
  final VoidCallback onDelete;
  final VoidCallback onCreateStory;

  const _CharacterCard({
    required this.character,
    required this.emoji,
    required this.onDelete,
    required this.onCreateStory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.primary.withAlpha(128),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Character emoji and name
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withAlpha(77),
                    AppColors.primaryLight.withAlpha(77),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  topRight: Radius.circular(AppRadius.lg),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 64),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text(
                      character.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Character details
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(
                    icon: Icons.cake,
                    label: '${character.age} years old',
                  ),
                  const SizedBox(height: 4),
                  _DetailRow(
                    icon: Icons.star,
                    label: character.role,
                  ),
                  if (character.likes != null && character.likes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _DetailRow(
                      icon: Icons.favorite,
                      label: character.likes!.take(2).join(', '),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onCreateStory,
                    icon: const Icon(Icons.auto_stories, size: 16),
                    label: const Text('Story', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textLight,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.error,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailRow({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: AppColors.primary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
