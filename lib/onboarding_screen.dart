import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;
  final VoidCallback? onSkipConfirmed;
  final VoidCallback? onTryCharacterDemo;
  final VoidCallback? onPreviewStoryDemo;

  const OnboardingScreen({
    super.key,
    required this.onFinished,
    this.onSkipConfirmed,
    this.onTryCharacterDemo,
    this.onPreviewStoryDemo,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  final Color _primary = const Color(0xFF2E7D32);
  final Color _accent = const Color(0xFF4CAF50);

  late final List<_OnboardingPageContent> _pages;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pages = _OnboardingPageContent.buildPages(
      primary: _primary,
      accent: _accent,
      onTryCharacterDemo: widget.onTryCharacterDemo,
      onPreviewStoryDemo: widget.onPreviewStoryDemo,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLastPage => _currentIndex == _pages.length - 1;
  String get _stepLabel => 'Step ${_currentIndex + 1}/${_pages.length}';
  String get _timeEstimate {
    final remaining = (_pages.length - _currentIndex);
    final minutes = (remaining * 0.5).ceil();
    return '$minutes min left';
  }

  void _handleNext() {
    if (_isLastPage) {
      widget.onFinished();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  Future<void> _confirmSkip() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip onboarding?'),
        content: const Text(
          'You can always revisit tutorials later inside Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
    if (result ?? false) {
      widget.onSkipConfirmed?.call();
      widget.onFinished();
    }
  }

  Widget _buildPage(_OnboardingPageContent page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: page.build(context),
        ),
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pages.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentIndex == index ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: _currentIndex == index ? _primary : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stepLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _primary,
                        ),
                      ),
                      Text(
                        _timeEstimate,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _confirmSkip,
                    child: const Text('Skip Tutorial'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (_, index) => _buildPage(_pages[index]),
              ),
            ),
            const SizedBox(height: 12),
            _buildDots(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  onPressed: _handleNext,
                  child: Text(
                    _isLastPage ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

abstract class _OnboardingPageContent {
  const _OnboardingPageContent();

  Widget build(BuildContext context);

  static List<_OnboardingPageContent> buildPages({
    required Color primary,
    required Color accent,
    VoidCallback? onTryCharacterDemo,
    VoidCallback? onPreviewStoryDemo,
  }) {
    return [
      _WelcomePage(primary: primary, accent: accent),
      _CharacterDemoPage(
        primary: primary,
        accent: accent,
        onTryIt: onTryCharacterDemo,
      ),
      _StoryDemoPage(
        primary: primary,
        accent: accent,
        onPreview: onPreviewStoryDemo,
      ),
      _FeaturesPage(primary: primary, accent: accent),
      _GettingStartedPage(primary: primary, accent: accent),
    ];
  }
}

class _WelcomePage extends _OnboardingPageContent {
  final Color primary;
  final Color accent;

  const _WelcomePage({required this.primary, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: accent.withOpacity(0.15),
          child: Icon(Icons.auto_stories, size: 40, color: primary),
        ),
        const SizedBox(height: 24),
        Text(
          'Welcome to Story Weaver',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Create Magical Stories Together',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: primary),
        ),
        const SizedBox(height: 12),
        Text(
          'Personalized therapeutic stories that help children explore feelings, adventures, and growth—crafted with love and imagination.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            _FeaturePill(text: 'Personalized tales'),
            _FeaturePill(text: 'Kid-friendly design'),
            _FeaturePill(text: 'Therapeutic focus'),
          ],
        ),
      ],
    );
  }
}

class _CharacterDemoPage extends _OnboardingPageContent {
  final Color primary;
  final Color accent;
  final VoidCallback? onTryIt;

  const _CharacterDemoPage({
    required this.primary,
    required this.accent,
    this.onTryIt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bring Characters to Life',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Create & customize heroes',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: primary),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: accent.withOpacity(0.08),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  CircleAvatar(child: Icon(Icons.person)),
                  SizedBox(width: 12),
                  Text(
                    'Ari the Explorer',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  Text('Age 7'),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Strengths: Brave, Curious'),
              const SizedBox(height: 4),
              const Text('Goal: Be kinder to friends'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: onTryIt,
                label: const Text('Try it'),
                icon: const Icon(Icons.edit),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoryDemoPage extends _OnboardingPageContent {
  final Color primary;
  final Color accent;
  final VoidCallback? onPreview;

  const _StoryDemoPage({
    required this.primary,
    required this.accent,
    this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Guide Every Story',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Pick themes, companions, or interactive mode',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: primary),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(color: accent.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Theme'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: const [
                  Chip(label: Text('Brave Adventures')),
                  Chip(label: Text('New Sibling')),
                  Chip(label: Text('Mindful Moments')),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: const [
                  Icon(Icons.pets),
                  SizedBox(width: 8),
                  Text('Companion: Loyal Dog'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: const [
                  Text('Interactive Mode'),
                  Spacer(),
                  Switch(value: true, onChanged: null),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Preview story'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturesPage extends _OnboardingPageContent {
  final Color primary;
  final Color accent;

  const _FeaturesPage({required this.primary, required this.accent});

  @override
  Widget build(BuildContext context) {
    final features = [
      ('Achievements', 'Earn badges for healthy habits', Icons.emoji_events),
      ('Offline Stories', 'Save bedtime favorites', Icons.cloud_off),
      ('Feelings Helper', 'Tap emotions & coping tools', Icons.favorite),
      ('Coloring Pages', 'Print scenes from stories', Icons.palette),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unlock Powerful Features',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Tools that keep families engaged',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: primary),
        ),
        const SizedBox(height: 16),
        ...features.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: accent.withOpacity(0.08),
            ),
            child: Row(
              children: [
                Icon(item.$3, color: primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(item.$2),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Learn more'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GettingStartedPage extends _OnboardingPageContent {
  final Color primary;
  final Color accent;

  const _GettingStartedPage({required this.primary, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ready to begin?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Let’s create your first story',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: primary),
        ),
        const SizedBox(height: 16),
        const _StepTile(
          number: 1,
          title: 'Choose your hero',
          description: 'Pick a child or create a new character',
        ),
        const _StepTile(
          number: 2,
          title: 'Select a theme',
          description: 'Match feelings, growth areas, or magical adventures',
        ),
        const _StepTile(
          number: 3,
          title: 'Tap “Create My Story”',
          description: 'Stories are ready in seconds with coping ideas built in',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: primary.withOpacity(0.1),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tip: Kids love tapping the Feelings Helper before stories!',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final String text;

  const _FeaturePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final int number;
  final String title;
  final String description;

  const _StepTile({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              number.toString(),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
