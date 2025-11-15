import 'package:flutter/material.dart';
import 'package:story_weaver_core/story_weaver_core.dart';

void main() {
  runApp(const StoryWeaverMVP());
}

class StoryWeaverMVP extends StatelessWidget {
  const StoryWeaverMVP({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Story Weaver',
      theme: AppTheme.light(),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Story Weaver'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to Story Weaver',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'AI-powered storytelling for families. Create amazing stories with your favorite characters!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton.primary(
              label: 'Create New Story',
              onPressed: () {
                // TODO: Navigate to story creation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Story creation coming soon!'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton.secondary(
              label: 'View Saved Stories',
              onPressed: () {
                // TODO: Navigate to saved stories
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Saved stories coming soon!'),
                    backgroundColor: AppColors.secondary,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
