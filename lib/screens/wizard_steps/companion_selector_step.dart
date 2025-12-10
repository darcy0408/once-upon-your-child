import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pill_button.dart';
import '../wizard_story_screen.dart';

/// Step 3: The Companion Selector
///
/// Layout:
/// - Grid of cute animal companions
/// - Each companion has animation on tap
/// - Selected companion gets gold glowing aura
/// - Continue button
class CompanionSelectorStep extends StatefulWidget {
  final WizardData wizardData;
  final VoidCallback onNext;

  const CompanionSelectorStep({
    super.key,
    required this.wizardData,
    required this.onNext,
  });

  @override
  State<CompanionSelectorStep> createState() => _CompanionSelectorStepState();
}

class _CompanionSelectorStepState extends State<CompanionSelectorStep> {
  String? _selectedCompanion;

  final List<Companion> _companions = [
    Companion(
      id: 'dragon',
      emoji: '🐉',
      name: 'Tiny Dragon',
      color: AppColors.dragonOrange,
      greeting: 'I\'m ready to help!',
    ),
    Companion(
      id: 'owl',
      emoji: '🦉',
      name: 'Wise Owl',
      color: AppColors.owlBlue,
      greeting: 'Let\'s be wise together!',
    ),
    Companion(
      id: 'cat',
      emoji: '🐱',
      name: 'Playful Cat',
      color: AppColors.catPurple,
      greeting: 'Purr-fect adventure awaits!',
    ),
    Companion(
      id: 'dog',
      emoji: '🐕',
      name: 'Loyal Dog',
      color: AppColors.dogBrown,
      greeting: 'I\'ll be your best friend!',
    ),
    Companion(
      id: 'unicorn',
      emoji: '🦄',
      name: 'Magic Unicorn',
      color: AppColors.primaryLight,
      greeting: 'Let\'s make magic!',
    ),
    Companion(
      id: 'fox',
      emoji: '🦊',
      name: 'Clever Fox',
      color: AppColors.gold,
      greeting: 'Ready for clever fun!',
    ),
  ];

  void _selectCompanion(Companion companion) {
    setState(() {
      _selectedCompanion = companion.id;
      widget.wizardData.selectedCompanion = companion.id;
      widget.wizardData.companionName = companion.name;
    });
  }

  bool get _canContinue => _selectedCompanion != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Text(
            'Choose a Companion',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Subtitle
          Text(
            'Pick a friend to join your adventure',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textDark.withAlpha(179), // 70% opacity
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),

          // Companion grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.lg,
                mainAxisSpacing: AppSpacing.lg,
                childAspectRatio: 1.0,
              ),
              itemCount: _companions.length,
              itemBuilder: (context, index) {
                final companion = _companions[index];
                final isSelected = _selectedCompanion == companion.id;

                return _CompanionCard(
                  companion: companion,
                  isSelected: isSelected,
                  onTap: () => _selectCompanion(companion),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Continue button
          if (_canContinue)
            Center(
              child: PillButton(
                emoji: '➡️',
                label: 'Continue',
                onTap: widget.onNext,
                variant: PillButtonVariant.purple,
                isSelected: true,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class Companion {
  final String id;
  final String emoji;
  final String name;
  final Color color;
  final String greeting;

  Companion({
    required this.id,
    required this.emoji,
    required this.name,
    required this.color,
    required this.greeting,
  });
}

class _CompanionCard extends StatefulWidget {
  final Companion companion;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompanionCard({
    required this.companion,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CompanionCard> createState() => _CompanionCardState();
}

class _CompanionCardState extends State<_CompanionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  bool _showGreeting = false;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onTap();
    _bounceController.forward(from: 0.0);
    setState(() => _showGreeting = true);
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() => _showGreeting = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: '${widget.companion.name} companion',
      hint: widget.companion.greeting,
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.companion.color.withAlpha(51)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: widget.isSelected
                  ? widget.companion.color
                  : Colors.grey.shade300,
              width: widget.isSelected ? 3 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppColors.goldLight.withAlpha(128),
                      blurRadius: 16,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Companion emoji with bounce animation
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _bounceAnimation,
                    child: Text(
                      widget.companion.emoji,
                      style: const TextStyle(fontSize: 64),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.companion.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              // Greeting bubble (appears on tap)
              if (_showGreeting)
                Positioned(
                  top: 8,
                  child: AnimatedOpacity(
                    opacity: _showGreeting ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: widget.companion.color,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        widget.companion.greeting,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textLight,
                              fontSize: 12,
                            ),
                      ),
                    ),
                  ),
                ),

              // Selected checkmark
              if (widget.isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
