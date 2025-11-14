// lib/character_gallery_screen.dart
// Character gallery polished with shared theming and analytics

import 'dart:async';

import 'package:flutter/material.dart';

import 'avatar_builder_screen.dart';
import 'avatar_models.dart';
import 'feelings_wheel_data.dart';
import 'feelings_wheel_screen.dart';
import 'services/avatar_service.dart';
import 'services/character_analytics.dart';
import 'theme/app_theme.dart';
import 'widgets/app_button.dart';
import 'widgets/app_card.dart';

class CharacterGalleryScreen extends StatefulWidget {
  final List<EnhancedCharacter> characters;
  final Function(EnhancedCharacter) onCharacterAdded;
  final Function(EnhancedCharacter) onCharacterUpdated;
  final Function(String) onCharacterDeleted;

  const CharacterGalleryScreen({
    super.key,
    required this.characters,
    required this.onCharacterAdded,
    required this.onCharacterUpdated,
    required this.onCharacterDeleted,
  });

  @override
  State<CharacterGalleryScreen> createState() => _CharacterGalleryScreenState();
}

class _CharacterGalleryScreenState extends State<CharacterGalleryScreen> {
  // Track each character's most recent feeling selection locally
  final Map<String, SelectedFeeling> _characterFeelings = {};

  void _trackInteraction(
    String action,
    EnhancedCharacter character, {
    SelectedFeeling? feeling,
  }) {
    unawaited(
      CharacterAnalytics.trackGalleryInteraction(
        action: action,
        characterId: character.id,
        characterName: character.name,
        age: character.age,
        gender: character.gender,
        feeling: feeling?.tertiary,
      ),
    );
  }

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? AppColors.primary,
      ),
    );
  }

  void _createCharacter() async {
    final result = await Navigator.push<EnhancedCharacter>(
      context,
      MaterialPageRoute(
        builder: (context) => const AvatarBuilderScreen(),
      ),
    );

    if (!mounted) return;
    if (result != null) {
      widget.onCharacterAdded(result);
      _trackInteraction('created', result);
      _showSnack('${result.name} created!');
    }
  }

  void _editCharacter(EnhancedCharacter character) async {
    final result = await Navigator.push<EnhancedCharacter>(
      context,
      MaterialPageRoute(
        builder: (context) => AvatarBuilderScreen(
          initialCharacter: character,
          isEdit: true,
        ),
      ),
    );

    if (!mounted) return;
    if (result != null) {
      widget.onCharacterUpdated(result);
      _trackInteraction('edited', result);
      _showSnack('${result.name} updated!');
    }
  }

  void _deleteCharacter(EnhancedCharacter character) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Character?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text('Delete ${character.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onCharacterDeleted(character.id);
              setState(() {
                _characterFeelings.remove(character.id);
              });
              Navigator.pop(context);
              _trackInteraction('deleted', character);
              _showSnack('${character.name} deleted', color: AppColors.error);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFeelingsWheel(EnhancedCharacter character) async {
    final result = await Navigator.push<SelectedFeeling>(
      context,
      MaterialPageRoute(
        builder: (context) => FeelingsWheelScreen(
          currentFeeling: _characterFeelings[character.id],
        ),
      ),
    );

    if (!mounted) return;
    if (result != null) {
      final updatedCharacter = character.copyWith(
        avatar: character.avatar.copyWith(
          eyeType: result.eyeType,
          mouthType: result.mouthType,
        ),
      );
      setState(() {
        _characterFeelings[character.id] = result;
      });
      widget.onCharacterUpdated(updatedCharacter);
      _trackInteraction('feeling_updated', character, feeling: result);
      _showSnack('${character.name} is feeling ${result.tertiary}!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCharacters = widget.characters.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Characters'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createCharacter,
            tooltip: 'Create Character',
          ),
        ],
      ),
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: hasCharacters ? _buildCharacterGrid() : _buildEmptyState(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCharacter,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('New Character'),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 56)),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No characters yet',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create a character to start your emotional learning adventure.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.primary(
              label: 'Create Character',
              icon: Icons.add,
              onPressed: _createCharacter,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterGrid() {
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: widget.characters.length,
      itemBuilder: (context, index) {
        final character = widget.characters[index];
        return _buildCharacterCard(character);
      },
    );
  }

  Widget _buildCharacterCard(EnhancedCharacter character) {
    final theme = Theme.of(context);
    final feeling = _characterFeelings[character.id];
    final mappedHair = _mapAvatarHairColor(character.avatar);
    final mappedOutfit = _mapAvatarOutfit(character.avatar);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            character.name,
            style: theme.textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AvatarService.buildAvatarWidget(
                  characterId: character.id,
                  hairColor: mappedHair,
                  eyeColor: null,
                  outfit: mappedOutfit,
                  size: 160,
                ),
                if (feeling != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Chip(
                    label: Text('Feeling ${feeling.tertiary}'),
                    backgroundColor:
                        AppColors.accent.withValues(alpha: 0.15),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.emoji_emotions,
                  label: 'Feeling',
                  backgroundColor: AppColors.secondary,
                  onTap: () => _showFeelingsWheel(character),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.edit,
                  label: 'Edit',
                  backgroundColor: AppColors.primary,
                  onTap: () => _editCharacter(character),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildActionButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            backgroundColor: AppColors.error,
            onTap: () => _deleteCharacter(character),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  String? _mapAvatarHairColor(CharacterAvatar avatar) {
    final value = avatar.hairColor.toLowerCase();
    if (value.contains('black')) return 'black';
    if (value.contains('blonde') || value.contains('gold')) return 'blonde';
    if (value.contains('platinum')) return 'white';
    if (value.contains('auburn')) return 'auburn';
    if (value.contains('red')) return 'red';
    if (value.contains('brown')) return 'brown';
    if (value.contains('pink')) return 'pink';
    if (value.contains('purple')) return 'purple';
    if (value.contains('blue')) return 'blue';
    if (value.contains('green')) return 'green';
    if (value.contains('silver') ||
        value.contains('gray') ||
        value.contains('grey')) {
      return 'gray';
    }
    return null;
  }

  String? _mapAvatarOutfit(CharacterAvatar avatar) {
    final value = avatar.clothingStyle.toLowerCase();
    if (value.contains('hoodie') ||
        value.contains('shirt') ||
        value.contains('overall')) {
      return 'casual';
    }
    if (value.contains('sweater') || value.contains('graphic')) {
      return 'sporty';
    }
    if (value.contains('blazer') || value.contains('dress')) {
      return 'fancy';
    }
    if (value.contains('cape') || value.contains('hero')) {
      return 'superhero';
    }
    return null;
  }
}
