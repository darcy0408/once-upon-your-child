import 'package:flutter/material.dart';

class QualityBadge extends StatelessWidget {
  final String qualityBadge;
  final int overallScore;
  final VoidCallback? onTap;

  const QualityBadge({
    super.key,
    required this.qualityBadge,
    required this.overallScore,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getBadgeColor();
    final icon = _getBadgeIcon();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              '$qualityBadge ($overallScore)',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBadgeColor() {
    switch (qualityBadge.toLowerCase()) {
      case 'excellent':
        return Colors.green.shade700;
      case 'great':
        return Colors.green.shade600;
      case 'good':
        return Colors.blue.shade600;
      case 'fair':
        return Colors.orange.shade600;
      case 'needs improvement':
      default:
        return Colors.red.shade600;
    }
  }

  IconData _getBadgeIcon() {
    switch (qualityBadge.toLowerCase()) {
      case 'excellent':
        return Icons.star;
      case 'great':
        return Icons.thumb_up;
      case 'good':
        return Icons.check_circle;
      case 'fair':
        return Icons.warning;
      case 'needs improvement':
      default:
        return Icons.error;
    }
  }

  static void showQualityDetails(
    BuildContext context,
    Map<String, dynamic> qualityData,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Story Quality Analysis'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildScoreRow('Overall Score', qualityData['overall_score'], '/100'),
              const SizedBox(height: 8),
              _buildScoreRow('Length Score', qualityData['length_score'], '/100'),
              _buildScoreRow('Therapeutic Score', qualityData['therapeutic_score'], '/100'),
              _buildScoreRow('Readability Score', qualityData['readability_score'], '/100'),
              _buildScoreRow('Age Appropriateness', qualityData['age_appropriateness_score'], '/100'),
              const SizedBox(height: 16),
              _buildInfoRow('Word Count', qualityData['word_count'].toString()),
              _buildInfoRow('Sentences', qualityData['sentence_count'].toString()),
              _buildInfoRow('Avg Words/Sentence', qualityData['avg_words_per_sentence'].toString()),
              _buildInfoRow('Grade Level', qualityData['grade_level'].toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Widget _buildScoreRow(String label, dynamic score, String suffix) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            '$score$suffix',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
