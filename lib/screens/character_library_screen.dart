import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service_manager.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../config/environment.dart';
import 'wizard_story_screen.dart';
import 'character_editor_screen.dart';
import 'chronicles_list_screen.dart';
import '../widgets/safe_asset_image.dart';
import '../widgets/archetype_card.dart';

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
  bool? _backendOnline;
  bool _isCheckingBackend = false;
  DateTime? _lastBackendCheck;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  Future<void> _checkBackendStatus() async {
    if (mounted) {
      setState(() => _isCheckingBackend = true);
    }

    bool online = false;
    try {
      final healthUri = Uri.parse('${Environment.backendUrl}/health');
      final response = await http.get(healthUri).timeout(
            const Duration(seconds: 3),
          );
      online = response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      online = false;
    }

    if (mounted) {
      setState(() {
        _backendOnline = online;
        _isCheckingBackend = false;
        _lastBackendCheck = DateTime.now();
      });
    }
  }

  Future<void> _loadCharacters() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    unawaited(_checkBackendStatus());

    try {
      final api = ApiServiceManager();
      final response = await api.get('/get-characters');

      // Response is wrapped as {'data': [...]} if it's a list
      final List<dynamic> characterList = response['data'] is List
          ? response['data']
          : (response['characters'] ?? []);
      final characters = characterList
          .map((data) => Character.fromJson(data as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _characters = characters;
          _isLoading = false;
        });
        debugPrint('✅ Loaded ${characters.length} characters');
      }
    } catch (e) {
      debugPrint('⚠️ Error loading characters: $e');
      if (mounted) {
        setState(() {
          _error = 'Error loading characters: $e';
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
        content: Text(
            'Are you sure you want to delete ${character.name}? This cannot be undone.'),
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

    try {
      final api = ApiServiceManager();
      await api.delete('/characters/${character.id}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${character.name} deleted'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadCharacters(); // Reload the list
      }
    } catch (e) {
      debugPrint('Error deleting character: $e');
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
          initialStep: 1, // Skip creation, start at Feeling Selection
        ),
      ),
    ).then((_) => _loadCharacters());
  }

  void _editCharacter(Character character) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterEditorScreen(
          character: character,
        ),
      ),
    ).then((edited) {
      if (edited == true) {
        _loadCharacters(); // Reload if character was edited
      }
    });
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
        child: Column(
          children: [
            if (_isCheckingBackend || _backendOnline == false)
              _BackendStatusBanner(
                isChecking: _isCheckingBackend,
                isOnline: _backendOnline,
                backendUrl: Environment.backendUrl,
                lastChecked: _lastBackendCheck,
                onRefresh: _checkBackendStatus,
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: AppColors.error,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  _error!,
                                  style:
                                      const TextStyle(color: AppColors.error),
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            color: AppColors.textDark,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      'Create your first character to get started!',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: AppColors.textDark
                                                .withAlpha(179),
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: AppSpacing.xl),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const WizardStoryScreen(),
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
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
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
                                    onEdit: () => _editCharacter(character),
                                    onCreateStory: () =>
                                        _createStoryWithCharacter(character),
                                  );
                                },
                              ),
                            ),
            ),
          ],
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

class _BackendStatusBanner extends StatelessWidget {
  final bool isChecking;
  final bool? isOnline;
  final String backendUrl;
  final DateTime? lastChecked;
  final Future<void> Function() onRefresh;

  const _BackendStatusBanner({
    required this.isChecking,
    required this.isOnline,
    required this.backendUrl,
    required this.lastChecked,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final bool offline = isOnline == false;
    final Color background = offline
        ? AppColors.error.withAlpha(25)
        : AppColors.success.withAlpha(25);
    final Color border = offline ? AppColors.error : AppColors.success;
    final Color iconColor = offline ? AppColors.error : AppColors.success;
    final IconData icon = isChecking
        ? Icons.sync
        : offline
            ? Icons.cloud_off
            : Icons.cloud_done;
    final String statusText = isChecking
        ? 'Story service is waking up'
        : offline
            ? 'Story service is waking up'
            : 'Story service is ready';

    final String subtitle = isChecking
        ? 'Please wait a moment, then tap Retry.'
        : offline
            ? 'Please wait a moment, then tap Retry.'
            : lastChecked != null
                ? 'Checked ${lastChecked!.hour.toString().padLeft(2, '0')}:${lastChecked!.minute.toString().padLeft(2, '0')}'
                : 'Ready to load your characters.';

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: border.withAlpha(160)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            color: iconColor,
            tooltip: 'Retry',
            onPressed: isChecking ? null : onRefresh,
          ),
        ],
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final Character character;
  final String emoji;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onCreateStory;

  const _CharacterCard({
    required this.character,
    required this.emoji,
    required this.onDelete,
    required this.onEdit,
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
          // Character avatar and name
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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Avatar Image
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ClipOval(
                        child: _buildAvatarImage(),
                      ),
                    ),
                  ),
                  // Name overlay (bottom)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(0), // Covered by parent
                          bottomRight: Radius.circular(0),
                        ),
                      ),
                      child: Text(
                        character.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                    label: CharacterArchetypes.all
                            .where((a) => a.name == character.role)
                            .firstOrNull
                            ?.nameForAge(character.age) ??
                        character.role,
                  ),
                  if (character.likes != null &&
                      character.likes!.isNotEmpty) ...[
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
            child: Column(
              children: [
                Row(
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
                    const SizedBox(width: 4),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final userId = await ApiServiceManager().getUserId();
                          if (userId == null) return;
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChroniclesListScreen(
                                  userId: userId,
                                  character: character,
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.history_edu, size: 16),
                        label: const Text('Chronicle', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      color: AppColors.primary,
                      tooltip: 'Edit',
                      iconSize: 20,
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      color: AppColors.error,
                      tooltip: 'Delete',
                      iconSize: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage() {
    final generated = character.generatedAvatar;
    if (generated != null && generated.imageBase64.isNotEmpty) {
      final data = generated.imageBase64;
      final isUrl = data.startsWith('http://') || data.startsWith('https://');
      final isAsset = data.startsWith('assets/');
      if (isAsset) {
        return SafeAssetImage(data, fit: BoxFit.cover);
      }
      if (isUrl) {
        return Image.network(data, fit: BoxFit.cover);
      }
      try {
        return Image.memory(base64Decode(data.split(',').last), fit: BoxFit.cover);
      } catch (_) {
        return _buildPlaceholder();
      }
    }

    if (character.avatar != null) {
      return Image.network(
        character.avatar!.toAvataaarsUrl(),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return SafeAssetImage(
      'assets/images/character_placeholder.png',
      fit: BoxFit.cover,
      placeholder: SafeAssetImage(
        'thePlaceholderImageBeforeCharacterGeneration.jpeg',
        fit: BoxFit.cover,
        placeholder: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 40),
          ),
        ),
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
