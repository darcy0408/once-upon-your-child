// lib/character_gallery_screen.dart
// Character Gallery with Edit, Delete, and Feelings Wheel integration

import 'package:flutter/material.dart';
import 'avatar_models.dart';
import 'avatar_builder_screen.dart';
import 'feelings_wheel_screen.dart';
import 'feelings_wheel_data.dart';
import 'expressive_avatar_widget.dart';
import 'sunset_jungle_theme.dart';

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

  void _createCharacter() async {
    final result = await Navigator.push<EnhancedCharacter>(
      context,
      MaterialPageRoute(
        builder: (context) => const AvatarBuilderScreen(),
      ),
    );

    if (result != null) {
      widget.onCharacterAdded(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.name} created!'),
          backgroundColor: SunsetJungleTheme.jungleLeaf,
        ),
      );
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

    if (result != null) {
      widget.onCharacterUpdated(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.name} updated!'),
          backgroundColor: SunsetJungleTheme.jungleLeaf,
        ),
      );
    }
  }

  void _deleteCharacter(EnhancedCharacter character) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Character?',
          style: TextStyle(fontFamily: 'Quicksand'),
        ),
        content: Text(
          'Are you sure you want to delete ${character.name}? This cannot be undone.',
          style: const TextStyle(fontFamily: 'Quicksand'),
        ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${character.name} deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${character.name} is feeling ${result.tertiary}!'),
          backgroundColor: SunsetJungleTheme.jungleLeaf,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Characters'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: SunsetJungleTheme.headerGradient,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createCharacter,
            tooltip: 'Create Character',
          ),
        ],
      ),
      backgroundColor: SunsetJungleTheme.creamLight,
      body: widget.characters.isEmpty
          ? _buildEmptyState()
          : _buildCharacterGrid(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCharacter,
        backgroundColor: SunsetJungleTheme.sunsetCoral,
        icon: const Icon(Icons.add),
        label: const Text(
          'New Character',
          style: TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '🌳',
            style: TextStyle(fontSize: 80),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Characters Yet!',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: SunsetJungleTheme.jungleDeepGreen,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Create your first character to start\nyour emotional learning adventure!',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 16,
              color: SunsetJungleTheme.jungleOlive,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _createCharacter,
            style: SunsetJungleTheme.primaryButtonStyle,
            icon: const Icon(Icons.add),
            label: const Text('Create Character'),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
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
    return Container(
      decoration: SunsetJungleTheme.cardDecoration,
      child: Column(
        children: [
          // Character name
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              character.name,
              style: const TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: SunsetJungleTheme.jungleDeepGreen,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Big expressive avatar
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ExpressiveAvatarWidget(
                avatar: character.avatar,
                feeling: _characterFeelings[character.id],
                size: 200,
                showLabel: true,
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.emoji_emotions,
                        label: 'Feeling',
                        color: const Color(0xFFFFD93D),
                        onTap: () => _showFeelingsWheel(character),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.edit,
                        label: 'Edit',
                        color: SunsetJungleTheme.jungleLeaf,
                        onTap: () => _editCharacter(character),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: _buildActionButton(
                    icon: Icons.delete,
                    label: 'Delete',
                    color: const Color(0xFFFF6B6B),
                    onTap: () => _deleteCharacter(character),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Quicksand',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
