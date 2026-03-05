import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ArchetypeCard - Displays character archetype templates
///
/// Design specs:
/// - Icon + name + trait chips
/// - "Use Template" button for quick character creation
/// - Tap to auto-fill character attributes
/// - Accessible with screen reader support
/// - Parent hover shows description (for parents, not kids)
class ArchetypeCard extends StatelessWidget {
  final String? icon; // Optional fallback emoji
  final String? imagePath; // Path to archetype image
  final String name;
  final String description; // For parent tooltips only
  final String specialAbility; // NEW: Displayed on card
  final List<String> traits;
  final VoidCallback onUseTemplate;
  final bool isSelected;

  const ArchetypeCard({
    super.key,
    this.icon,
    this.imagePath,
    required this.name,
    required this.description,
    required this.specialAbility,
    required this.traits,
    required this.onUseTemplate,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$name archetype, $description',
      hint: 'Tap to use this character template',
      child: Tooltip(
        message: description, // Shows on hover for parents
        waitDuration: const Duration(milliseconds: 500),
        child: InkWell(
          onTap: onUseTemplate,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedScale(
            scale: isSelected ? 1.03 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            width: 160, // Fixed width for horizontal scroll
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLight.withAlpha(38) : AppColors.surface,
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        AppColors.gold.withAlpha(80),
                        AppColors.primaryLight.withAlpha(40),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isSelected ? AppColors.gold : Colors.grey.shade300,
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withAlpha(140),
                        blurRadius: 16,
                        spreadRadius: 3,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: AppColors.primary.withAlpha(80),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                if (isSelected)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.18,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          gradient: const RadialGradient(
                            colors: [AppColors.goldLight, Colors.transparent],
                            radius: 1.1,
                            center: Alignment(-0.6, -0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                SingleChildScrollView(
                  physics: const ClampingScrollPhysics(), // Prevent bounce effect on cards
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Image or Icon/Emoji fallback
                      if (imagePath != null)
                        Image.asset(
                          imagePath!,
                          width: 116,
                          height: 116,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Text(
                            icon ?? '✨',
                            style: const TextStyle(fontSize: 64),
                          ),
                        )
                      else
                        Text(
                          icon ?? '✨',
                          style: const TextStyle(fontSize: 64),
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      // Archetype name
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Trait chips
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: traits.map((trait) => _TraitChip(label: trait)).toList(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      
                      // Special Ability Display
                      Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(
                           color: AppColors.primary.withValues(alpha: 0.1),
                           borderRadius: BorderRadius.circular(AppRadius.sm),
                           border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                         ),
                         child: Text(
                            specialAbility, 
                            style: TextStyle(
                              fontSize: 11, 
                              fontStyle: FontStyle.italic,
                              color: AppColors.textDark,
                            ),
                            textAlign: TextAlign.center,
                         ),
                      ),

                      // "Use Template" button
                      if (!isSelected) // Hint text instead of button
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Tap to Select',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textDark.withAlpha(128),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

/// Small trait chip for archetypes
class _TraitChip extends StatelessWidget {
  final String label;

  const _TraitChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.gold.withAlpha(80), // Increased opacity
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.gold.withAlpha(200), // Darker border
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

/// Predefined character archetypes
class CharacterArchetypes {
  static const adventurer = ArchetypeData(
    icon: '⚡',
    imagePath: 'assets/images/archetypes/storm_rider_framed.png',
    name: 'The Storm Rider',
    description: 'Commands wind and weather, brave explorer',
    traits: ['Brave', 'Curious', 'Determined'],
    specialAbility: 'Can command wind and weather to soar through storms',
    attributes: {
      'energy': 80,
      'sociability': 70,
      'creativity': 60,
      'confidence': 85,
      'empathy': 50,
      'adventurousness': 95,
    },
  );

  static const thinker = ArchetypeData(
    icon: '🧩',
    imagePath: 'assets/images/archetypes/quiz_whiz_framed.png',
    name: 'The Quiz Whiz',
    description: 'Solves tricky puzzles and brain teasers',
    traits: ['Smart', 'Modest', 'Curious'],
    specialAbility: 'Can solve any quiz, puzzle, or brain teaser with clever thinking',
    attributes: {
      'energy': 40,
      'sociability': 30,
      'creativity': 75,
      'confidence': 60,
      'empathy': 70,
      'adventurousness': 40,
    },
  );

  static const artist = ArchetypeData(
    icon: '🎨',
    imagePath: 'assets/images/archetypes/master_creator_framed.png',
    name: 'The Master Creator',
    description: 'Magic paintbrush brings drawings to life',
    traits: ['Creative', 'Expressive', 'Imaginative'],
    specialAbility: 'Has a magic paintbrush that brings drawings to life',
    attributes: {
      'energy': 60,
      'sociability': 50,
      'creativity': 95,
      'confidence': 70,
      'empathy': 80,
      'adventurousness': 55,
    },
  );

  static const helper = ArchetypeData(
    icon: '💚',
    imagePath: 'assets/images/archetypes/heart_healer_framed.png',
    name: 'The Heart Healer',
    description: 'Senses emotions and heals broken spirits',
    traits: ['Caring', 'Patient', 'Loyal'],
    specialAbility: 'Can sense emotions and heal broken spirits with kindness',
    attributes: {
      'energy': 50,
      'sociability': 85,
      'creativity': 50,
      'confidence': 60,
      'empathy': 95,
      'adventurousness': 45,
    },
  );

  static const athlete = ArchetypeData(
    icon: '🏃',
    imagePath: 'assets/images/archetypes/lightning_runner_framed.png',
    name: 'The Lightning Runner',
    description: 'Moves faster than sound, leaves stardust trails',
    traits: ['Energetic', 'Fast', 'Determined'],
    specialAbility: 'Moves faster than sound and leaves trails of stardust',
    attributes: {
      'energy': 95,
      'sociability': 75,
      'creativity': 40,
      'confidence': 85,
      'empathy': 60,
      'adventurousness': 70,
    },
  );

  static const shyOne = ArchetypeData(
    icon: '🦉',
    imagePath: 'assets/images/archetypes/animal_whisperer_framed.png',
    name: 'The Animal Whisperer',
    description: 'Talks to animals and hears nature\'s secrets',
    traits: ['Kind', 'Observant', 'Gentle'],
    specialAbility: 'Can talk to animals and move unseen like a shadow',
    attributes: {
      'energy': 35,
      'sociability': 25,
      'creativity': 70,
      'confidence': 40,
      'empathy': 85,
      'adventurousness': 30,
    },
  );

  static List<ArchetypeData> get all => [
        adventurer,
        thinker,
        artist,
        helper,
        athlete,
        shyOne,
      ];
}

class ArchetypeData {
  final String? icon; // Optional fallback emoji
  final String? imagePath; // Path to archetype image
  final String name;
  final String description;
  final List<String> traits;
  final Map<String, int> attributes;
  final String specialAbility; // New: physics-defying power for adventures

  const ArchetypeData({
    this.icon,
    this.imagePath,
    required this.name,
    required this.description,
    required this.traits,
    required this.attributes,
    required this.specialAbility,
  });
}

/// Drum/slot-machine style spinning wheel for archetype selection.
///
/// Shows 3 items at a time. The center item snaps and is auto-selected.
/// An animated details banner below the wheel shows the selected archetype's
/// special ability.
class ArchetypeWheelSelector extends StatefulWidget {
  final List<ArchetypeData> archetypes;
  final String? initialSelectedId;
  final ValueChanged<ArchetypeData> onSelected;

  const ArchetypeWheelSelector({
    super.key,
    required this.archetypes,
    this.initialSelectedId,
    required this.onSelected,
  });

  @override
  State<ArchetypeWheelSelector> createState() => _ArchetypeWheelSelectorState();
}

class _ArchetypeWheelSelectorState extends State<ArchetypeWheelSelector> {
  late FixedExtentScrollController _controller;
  late int _selectedIndex;

  static const double _itemExtent = 88.0;

  @override
  void initState() {
    super.initState();
    final idx = widget.archetypes.indexWhere(
      (a) => a.name == widget.initialSelectedId,
    );
    _selectedIndex = idx >= 0 ? idx : 0;
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
    // Auto-select the centered item on mount.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onSelected(widget.archetypes[_selectedIndex]);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const wheelHeight = _itemExtent * 3;
    final selected = widget.archetypes[_selectedIndex];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: wheelHeight,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              // Gold "center window" highlight
              Positioned(
                top: _itemExtent + 4,
                left: 12,
                right: 12,
                child: IgnorePointer(
                  child: Container(
                    height: _itemExtent - 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gold, width: 2.5),
                      color: AppColors.gold.withAlpha(25),
                    ),
                  ),
                ),
              ),
              // The wheel
              ListWheelScrollView.useDelegate(
                controller: _controller,
                itemExtent: _itemExtent,
                diameterRatio: 2.0,
                physics: const FixedExtentScrollPhysics(),
                overAndUnderCenterOpacity: 0.4,
                onSelectedItemChanged: (index) {
                  setState(() => _selectedIndex = index);
                  widget.onSelected(widget.archetypes[index]);
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: widget.archetypes.length,
                  builder: (context, index) {
                    if (index < 0 || index >= widget.archetypes.length) {
                      return null;
                    }
                    return _WheelItem(archetype: widget.archetypes[index]);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Animated details banner for the selected archetype
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.12),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _ArchetypeDetailsBanner(
            key: ValueKey(selected.name),
            archetype: selected,
          ),
        ),
      ],
    );
  }
}

class _WheelItem extends StatelessWidget {
  final ArchetypeData archetype;

  const _WheelItem({required this.archetype});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: archetype.imagePath != null
                ? Image.asset(
                    archetype.imagePath!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _ArchetypeIconFallback(icon: archetype.icon),
                  )
                : _ArchetypeIconFallback(icon: archetype.icon),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  archetype.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: archetype.traits
                      .map((t) => _TraitChip(label: t))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchetypeIconFallback extends StatelessWidget {
  final String? icon;
  const _ArchetypeIconFallback({this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Center(
        child: Text(icon ?? '✨', style: const TextStyle(fontSize: 36)),
      ),
    );
  }
}

class _ArchetypeDetailsBanner extends StatelessWidget {
  final ArchetypeData archetype;
  const _ArchetypeDetailsBanner({super.key, required this.archetype});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              archetype.specialAbility,
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
