import 'package:flutter/material.dart';
import '../services/child_profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';

class ChildProfileManagerScreen extends StatefulWidget {
  const ChildProfileManagerScreen({super.key});

  @override
  State<ChildProfileManagerScreen> createState() =>
      _ChildProfileManagerScreenState();
}

class _ChildProfileManagerScreenState
    extends State<ChildProfileManagerScreen> {
  final _service = ChildProfileService();
  List<ChildProfile> _profiles = [];
  String? _activeProfileId;
  bool _loading = true;

  static const _emojis = ['🧒', '👧', '🧑', '👦', '🌟', '🦄', '🐉', '🧙'];
  static const _colors = [
    '#9C27B0',
    '#E91E63',
    '#2196F3',
    '#4CAF50',
    '#FF9800',
    '#00BCD4',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await _service.loadProfiles();
    final activeId = await _service.getActiveProfileId();
    if (mounted) {
      setState(() {
        _profiles = profiles;
        _activeProfileId = activeId;
        _loading = false;
      });
    }
  }

  Future<void> _showProfileDialog({ChildProfile? existing}) async {
    final nameController =
        TextEditingController(text: existing?.name ?? '');
    int selectedAge = existing?.age ?? 8;
    String selectedEmoji = existing?.avatarEmoji ?? '🧒';
    String selectedColor = existing?.colorHex ?? '#9C27B0';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E0A3C),
          title: Text(
            existing == null ? 'Add Profile' : 'Edit Profile',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name field
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: Colors.white12,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                // Age selector
                const Text('Age',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 16,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final age = i + 3;
                      final isSelected = age == selectedAge;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedAge = age),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.white12,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(
                                    color: AppColors.primaryLight, width: 2)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '$age',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white60,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Emoji picker
                const Text('Avatar',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _emojis.map((emoji) {
                    final isSelected = emoji == selectedEmoji;
                    return GestureDetector(
                      onTap: () =>
                          setDialogState(() => selectedEmoji = emoji),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white12,
                          border: isSelected
                              ? Border.all(
                                  color: const Color(0xFFFFD700), width: 2)
                              : null,
                        ),
                        child: Center(
                          child: Text(emoji,
                              style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Color picker
                const Text('Colour',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _colors.map((hex) {
                    final clean = hex.replaceFirst('#', '');
                    final color =
                        Color(int.parse('FF$clean', radix: 16));
                    final isSelected = hex == selectedColor;
                    return GestureDetector(
                      onTap: () =>
                          setDialogState(() => selectedColor = hex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: isSelected
                              ? Border.all(
                                  color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.7),
                                    blurRadius: 8,
                                  )
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final profile = existing == null
                    ? ChildProfile(
                        name: name,
                        age: selectedAge,
                        avatarEmoji: selectedEmoji,
                        colorHex: selectedColor,
                      )
                    : existing.copyWith(
                        name: name,
                        age: selectedAge,
                        avatarEmoji: selectedEmoji,
                        colorHex: selectedColor,
                      );
                await _service.saveProfile(profile);
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadProfiles();
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteProfile(ChildProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E0A3C),
        title: const Text('Delete profile?',
            style: TextStyle(color: Colors.white)),
        content: Text('Remove "${profile.name}"?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final fullyDeleted = await _service.deleteProfile(profile.id);
      await _loadProfiles();
      if (!fullyDeleted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Profile removed from this device, but we couldn't reach our "
              "servers to delete the stored data. Please try again when "
              "you're back online.",
            ),
          ),
        );
      }
    }
  }

  Color _hexColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120226),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Manage Profiles',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Profile'),
        onPressed: () => _showProfileDialog(),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _profiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🧒',
                          style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 16),
                      const Text('No profiles yet',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('Tap + Add Profile to get started',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _profiles.length,
                  itemBuilder: (ctx, i) {
                    final profile = _profiles[i];
                    final isActive = profile.id == _activeProfileId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _hexColor(profile.colorHex)
                                  .withValues(alpha: 0.9),
                              border: isActive
                                  ? Border.all(
                                      color: const Color(0xFFFFD700),
                                      width: 2.5)
                                  : null,
                            ),
                            child: Center(
                              child: Text(profile.avatarEmoji,
                                  style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                          title: Text(
                            profile.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? const Color(0xFFFFD700)
                                  : Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            'Age ${profile.age}${isActive ? ' · Active' : ''}',
                            style: TextStyle(
                              color: isActive
                                  ? const Color(0xFFFFD700).withValues(alpha: 0.8)
                                  : Colors.white54,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded,
                                    color: Colors.white54),
                                tooltip: 'Edit profile',
                                onPressed: () =>
                                    _showProfileDialog(existing: profile),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Colors.red),
                                tooltip: 'Delete profile',
                                onPressed: () => _deleteProfile(profile),
                              ),
                            ],
                          ),
                          onTap: () async {
                            await _service.setActiveProfile(profile);
                            await _loadProfiles();
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
