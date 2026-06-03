import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/local/story_local.dart';
import '../theme/app_theme.dart';

class StoryCard extends ConsumerWidget {
  final StoryLocal story;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const StoryCard({
    super.key,
    required this.story,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine gradient based on theme
    final gradient = _getThemeGradient(story.theme);

    return Card(
      elevation: 4,
      shadowColor: gradient.colors.first.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // Background Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    gradient.colors.first.withValues(alpha: 0.1),
                    gradient.colors.last.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Theme Icon & Favorite
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ThemeBadge(theme: story.theme),
                      IconButton(
                        icon: Icon(
                          story.isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: story.isFavorite ? Colors.red : Colors.grey.shade400,
                          size: 20,
                        ),
                        tooltip: 'Toggle favorite',
                        onPressed: onToggleFavorite,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        style: const ButtonStyle(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    story.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Quicksand', // Ensure Magical font if available
                          height: 1.2,
                        ),
                  ),
                  const SizedBox(height: 8),

                  // Snippet
                  Expanded(
                    child: Text(
                      story.storyText,
                      maxLines: 4,
                      overflow: TextOverflow.fade,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                            height: 1.4,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Footer: Date & Actions
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(story.createdAt),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                      const Spacer(),
                      // Interactive Badge if applicable
                      if (story.isInteractive)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.purple.shade100),
                          ),
                          child: const Text(
                            'Interactive',
                            style: TextStyle(fontSize: 10, color: Colors.purple),
                          ),
                        ),
                      // More Options
                       PopupMenuButton<String>(
                        icon: Icon(Icons.more_horiz, color: Colors.grey.shade600),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                         onSelected: (value) {
                           if (value == 'share') onShare();
                           if (value == 'delete') onDelete();
                         },
                         itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                           const PopupMenuItem<String>(
                             value: 'share',
                             child: Row(
                               children: [
                                 Icon(Icons.share, size: 18),
                                 SizedBox(width: 8),
                                 Text('Share'),
                               ],
                             ),
                           ),
                           const PopupMenuItem<String>(
                             value: 'delete',
                             child: Row(
                               children: [
                                 Icon(Icons.delete, color: Colors.red, size: 18),
                                 SizedBox(width: 8),
                                 Text('Delete', style: TextStyle(color: Colors.red)),
                               ],
                             ),
                           ),
                         ],
                       ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient _getThemeGradient(String theme) {
    // Simple mapping for now, can be expanded
    switch (theme.toLowerCase()) {
      case 'adventure':
        return const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)]);
      case 'fantasy':
      case 'magic':
      case 'unicorns':
      case 'dragons':
        return const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFE040FB)]);
      case 'space':
        return const LinearGradient(colors: [Color(0xFF3F51B5), Color(0xFF2196F3)]);
      case 'ocean':
        return const LinearGradient(colors: [Color(0xFF00BCD4), Color(0xFF03A9F4)]);
      default:
        return const LinearGradient(colors: [AppColors.primary, AppColors.secondary]);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _ThemeBadge extends StatelessWidget {
  final String theme;

  const _ThemeBadge({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getThemeIcon(theme), size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            theme,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getThemeIcon(String theme) {
    switch (theme.toLowerCase()) {
      case 'adventure': return Icons.explore;
      case 'magic': return Icons.auto_awesome;
      case 'space': return Icons.rocket_launch;
      case 'ocean': return Icons.water;
      default: return Icons.book;
    }
  }
}
