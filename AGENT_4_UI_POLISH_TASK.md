# YOU ARE AGENT 4 - UI Polish & Animations

**⚠️ IMPORTANT: You are Agent 4. This is YOUR task file. Do NOT read other agent files.**

---

## Your Assignment

**Task:** Add animations, transitions, and UI polish to improve user experience
**Your Branch:** `feature/ui-polish-animations`
**Estimated Time:** 2 days
**Terminal:** WSL Codex

---

## BEFORE YOU START - Branch Verification

Run these commands and verify:

```bash
cd /mnt/c/dev/story-weaver-app
git checkout main
git pull origin main
git checkout -b feature/ui-polish-animations

# VERIFY YOU'RE ON THE RIGHT BRANCH
git branch --show-current
# Must show: feature/ui-polish-animations

# If it shows anything else, STOP and ask supervisor
```

---

## Your File Scope (ONLY TOUCH THESE)

✅ **You CAN modify:**
- `lib/widgets/` (ADD animations to existing widgets)
- `lib/widgets/animated_story_card.dart` (CREATE)
- `lib/widgets/page_transition.dart` (CREATE)
- `lib/widgets/shimmer_placeholder.dart` (CREATE)
- `lib/widgets/bounce_button.dart` (CREATE)
- `lib/theme/animations.dart` (CREATE animation constants)
- `lib/story_result_screen.dart` (ADD animations)
- `lib/interactive_story_screen.dart` (ADD page transitions)
- `lib/onboarding_screen.dart` (ADD animations)

❌ **DO NOT touch:**
- Provider files (`lib/providers/**`) - Agent 2 owns
- Test files (`test/**`) - Agent 3 owns
- Backend files (`backend/**`)
- `lib/saved_stories_screen.dart` - Agent 2 owns
- `lib/settings_screen.dart` - Agent 2 owns

---

## Step-by-Step Instructions

### Step 1: Create Animation Constants (15 minutes)

Create `lib/theme/animations.dart`:

```dart
import 'package:flutter/animation.dart';

class AppAnimations {
  // Durations
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration verySlow = Duration(milliseconds: 800);

  // Curves
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOut = Curves.easeOut;
  static const Curve bounce = Curves.bounceOut;
  static const Curve elastic = Curves.elasticOut;

  // Page transitions
  static const Duration pageTransition = Duration(milliseconds: 350);

  // Story reveal
  static const Duration storyReveal = Duration(milliseconds: 600);

  // Button press
  static const Duration buttonPress = Duration(milliseconds: 100);
}
```

---

### Step 2: Create Animated Story Card (1 hour)

Create `lib/widgets/animated_story_card.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/animations.dart';

class AnimatedStoryCard extends StatefulWidget {
  final String title;
  final String preview;
  final VoidCallback? onTap;
  final int index;

  const AnimatedStoryCard({
    super.key,
    required this.title,
    required this.preview,
    this.onTap,
    this.index = 0,
  });

  @override
  State<AnimatedStoryCard> createState() => _AnimatedStoryCardState();
}

class _AnimatedStoryCardState extends State<AnimatedStoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.normal,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.easeOut,
    ));

    // Stagger animation based on index
    Future.delayed(
      Duration(milliseconds: 50 * widget.index),
      () {
        if (mounted) {
          _controller.forward();
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Card(
          elevation: 2,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.preview,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
```

---

### Step 3: Create Page Transitions (45 minutes)

Create `lib/widgets/page_transition.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/animations.dart';

enum PageTransitionType {
  fade,
  slide,
  scale,
  rotation,
}

class CustomPageRoute<T> extends PageRoute<T> {
  final Widget child;
  final PageTransitionType transitionType;
  final Duration duration;
  final Curve curve;

  CustomPageRoute({
    required this.child,
    this.transitionType = PageTransitionType.slide,
    this.duration = AppAnimations.pageTransition,
    this.curve = AppAnimations.easeInOut,
    RouteSettings? settings,
  }) : super(settings: settings);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => duration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return child;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    switch (transitionType) {
      case PageTransitionType.fade:
        return FadeTransition(
          opacity: animation,
          child: child,
        );

      case PageTransitionType.slide:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: curve,
          )),
          child: child,
        );

      case PageTransitionType.scale:
        return ScaleTransition(
          scale: Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: curve,
          )),
          child: child,
        );

      case PageTransitionType.rotation:
        return RotationTransition(
          turns: Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: curve,
          )),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
    }
  }
}

// Extension for easy navigation with transitions
extension NavigationExtension on BuildContext {
  Future<T?> navigateWithTransition<T>({
    required Widget page,
    PageTransitionType transition = PageTransitionType.slide,
  }) {
    return Navigator.of(this).push<T>(
      CustomPageRoute(
        child: page,
        transitionType: transition,
      ),
    );
  }
}
```

---

### Step 4: Create Shimmer Placeholder (30 minutes)

Create `lib/widgets/shimmer_placeholder.dart`:

```dart
import 'package:flutter/material.dart';

class ShimmerPlaceholder extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerPlaceholder({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Story card shimmer placeholder
class StoryCardShimmer extends StatelessWidget {
  const StoryCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerPlaceholder(
              width: 200,
              height: 24,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            ShimmerPlaceholder(
              width: double.infinity,
              height: 16,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            ShimmerPlaceholder(
              width: double.infinity,
              height: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### Step 5: Create Bounce Button (30 minutes)

Create `lib/widgets/bounce_button.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/animations.dart';

class BounceButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double scaleFactor;

  const BounceButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.scaleFactor = 0.95,
  });

  @override
  State<BounceButton> createState() => _BounceButtonState();
}

class _BounceButtonState extends State<BounceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.buttonPress,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null ? _onTapDown : null,
      onTapUp: widget.onPressed != null ? _onTapUp : null,
      onTapCancel: widget.onPressed != null ? _onTapCancel : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
```

---

### Step 6: Add Animations to Story Result Screen (1 hour)

Update `lib/story_result_screen.dart`:

Add imports:
```dart
import 'widgets/page_transition.dart';
import 'theme/animations.dart';
```

Add animated text reveal:
```dart
class _StoryResultScreenState extends State<StoryResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _textController;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();

    _textController = AnimationController(
      vsync: this,
      duration: AppAnimations.storyReveal,
    );

    _textAnimation = CurvedAnimation(
      parent: _textController,
      curve: AppAnimations.easeInOut,
    );

    // Start animation after a brief delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _textController.forward();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Story')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Animated story text
            FadeTransition(
              opacity: _textAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(_textAnimation),
                child: Text(
                  widget.storyText,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### Step 7: Add Page Transitions (30 minutes)

Update `lib/interactive_story_screen.dart`:

Add navigation with custom transitions:

```dart
import 'widgets/page_transition.dart';

// Replace Navigator.push with:
context.navigateWithTransition(
  page: StoryResultScreen(storyText: result),
  transition: PageTransitionType.slide,
);
```

---

### Step 8: Add Onboarding Animations (1 hour)

Update `lib/onboarding_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'widgets/bounce_button.dart';
import 'theme/animations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: AppAnimations.normal,
    );

    _slideController = AnimationController(
      vsync: this,
      duration: AppAnimations.normal,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeController);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: AppAnimations.easeOut,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _nextPage() {
    setState(() => _currentPage++);
    _fadeController.reset();
    _slideController.reset();
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildPage(_currentPage),
                  ),
                ),
              ),
              BounceButton(
                onPressed: _nextPage,
                child: ElevatedButton(
                  onPressed: null, // Disabled, BounceButton handles tap
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(int page) {
    // Onboarding page content
    return Center(
      child: Text('Onboarding Page $page'),
    );
  }
}
```

---

### Step 9: Testing (30 minutes)

Run the app and test animations:

```bash
flutter run -d chrome
```

**Manual tests:**
1. Navigate between screens → verify smooth transitions
2. Scroll story cards → verify staggered animations
3. Press buttons → verify bounce effect
4. Load stories → verify shimmer placeholders
5. View story result → verify text reveal animation
6. Go through onboarding → verify page transitions

---

### Step 10: Commit and Push

```bash
git add lib/widgets/ lib/theme/animations.dart lib/story_result_screen.dart lib/interactive_story_screen.dart lib/onboarding_screen.dart

git commit -m "Feature: Add UI polish and animations

- Create animation constants in theme/animations.dart
- Add AnimatedStoryCard with fade/slide entrance
- Add CustomPageRoute with multiple transition types
- Add ShimmerPlaceholder for loading states
- Add BounceButton for tactile feedback
- Add story text reveal animation to StoryResultScreen
- Add page transitions to InteractiveStoryScreen
- Add onboarding animations with fade/slide

Benefits:
- Professional, polished user experience
- Smooth transitions between screens
- Visual feedback for user actions
- Loading states look intentional
- Delightful micro-interactions
- Improved perceived performance

🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com>"

git push origin feature/ui-polish-animations
```

---

### Step 11: Report Completion

Update `TEAM_COORDINATION.md`:

```markdown
## Agent 4 - UI Polish & Animations | 2025-12-04

### Task: Add Animations and UI Polish

### Files Changed
- Created: lib/theme/animations.dart (animation constants)
- Created: lib/widgets/animated_story_card.dart (staggered entrance)
- Created: lib/widgets/page_transition.dart (4 transition types)
- Created: lib/widgets/shimmer_placeholder.dart (loading skeletons)
- Created: lib/widgets/bounce_button.dart (tactile feedback)
- Modified: lib/story_result_screen.dart (text reveal animation)
- Modified: lib/interactive_story_screen.dart (page transitions)
- Modified: lib/onboarding_screen.dart (fade/slide animations)

### Animations Added
- Story card entrance (fade + slide, staggered)
- Page transitions (fade, slide, scale, rotation)
- Button press feedback (bounce/scale)
- Text reveal (fade + slide)
- Loading shimmer (gradient animation)
- Onboarding transitions (fade + slide)

### Manual Testing
- [x] Story cards animate on load
- [x] Page transitions smooth
- [x] Buttons bounce on press
- [x] Shimmer shows during loading
- [x] Story text reveals gracefully
- [x] Onboarding flows smoothly

### Status
✅ COMPLETE - Ready for supervisor verification
```

Then report:
```
✅ Agent 4 COMPLETE - UI polish and animations complete, pushed to feature/ui-polish-animations
```

---

## Success Criteria

- [x] Animation constants defined
- [x] 5 new animated widgets created
- [x] 3 screens enhanced with animations
- [x] Smooth transitions throughout app
- [x] Loading states look polished
- [x] Manual testing completed

---

## IMPORTANT REMINDERS

**Branch Check:**
- Always verify: `git branch --show-current` shows `feature/ui-polish-animations`

**File Scope:**
- ONLY touch widget files and allowed screens
- DO NOT modify provider files (Agent 2)
- DO NOT modify test files (Agent 3)
- DO NOT modify saved_stories_screen or settings_screen

**Testing:**
- Test on web (chrome) for smooth performance
- Verify animations don't slow down app
- Check accessibility (screen readers still work)

**DO NOT:**
- Merge to main
- Work outside your file scope
- Add heavy animations that hurt performance

---

**Ready? Start with Step 1: Create Animation Constants**

Good luck! ✨
