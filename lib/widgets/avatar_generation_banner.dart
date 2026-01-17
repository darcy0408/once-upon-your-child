import 'package:flutter/material.dart';
import '../services/avatar_generation_state.dart';

/// Banner that shows avatar generation progress
class AvatarGenerationBanner extends StatelessWidget {
  const AvatarGenerationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AvatarGenerationState(),
      builder: (context, _) {
        final state = AvatarGenerationState();

        // Don't show if not generating and no completed avatar
        if (!state.isGenerating && state.completedAvatar == null && state.error == null) {
          return const SizedBox.shrink();
        }

        Color backgroundColor;
        IconData icon;
        String message;
        Color textColor = Colors.white;

        if (state.error != null) {
          // Error state
          backgroundColor = Colors.red.shade600;
          icon = Icons.error_outline;
          message = 'Avatar generation failed';
        } else if (state.completedAvatar != null) {
          // Success state
          backgroundColor = Colors.green.shade600;
          icon = Icons.check_circle_outline;
          message = 'Your avatar is ready! 🎨';
        } else {
          // Generating state
          backgroundColor = const Color(0xFF6C63FF);
          icon = Icons.hourglass_empty;
          final elapsed = state.elapsedSeconds;
          message = 'Creating your avatar... ${elapsed}s elapsed';
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (state.isGenerating)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (state.error != null)
                TextButton(
                  onPressed: () => AvatarGenerationState().reset(),
                  child: const Text(
                    'Dismiss',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
