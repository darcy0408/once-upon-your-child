# Codex - Navigation & Mobile UX Tasks (Week 2)

**Status**: Ready to start (Bottom navigation completed!)
**Priority**: HIGH - Building on Week 1 foundation

---

## Current Status Summary

### ✅ Completed
- Bottom Navigation Bar (4 tabs: Create, Library, Feelings, Settings)
- Onboarding screen created
- Feelings Corner screen (non-blocking, voluntary check-ins)
- Feelings analytics service

### 🎯 Next Focus
- Floating Action Buttons (FABs)
- Mobile ergonomics improvements
- Accessibility enhancements

---

## Task C1: Implement Floating Action Buttons on Story Result (Priority: HIGH)

**Objective**: Add FABs for quick actions on story result screen to improve mobile UX.

### Context:
From UX_IMPLEMENTATION_PLAN.md Week 2:
> Users struggle to find save/share buttons at bottom of long stories. Add floating action buttons for primary actions.

### Design Spec:
```
Position: Bottom-right corner
Actions (3 buttons):
1. Share (blue) - Icons.share
2. Regenerate (orange) - Icons.refresh
3. Save Story (green/primary) - Icons.save + label

Layout: Column (vertical stack)
Spacing: 12px between buttons
```

### Implementation Steps:

1. **Read Current Story Result Screen**:
   ```bash
   # Check existing structure around line 1500+
   cat lib/story_result_screen.dart | awk 'NR>=1490 && NR<=1530'
   ```

2. **Add FAB Stack** (around line 1524, before closing Stack children):
   ```dart
   // Floating Action Buttons (bottom-right)
   Positioned(
     right: 16,
     bottom: 16,
     child: Column(
       mainAxisSize: MainAxisSize.min,
       crossAxisAlignment: CrossAxisAlignment.end,
       children: [
         FloatingActionButton.small(
           heroTag: 'fab_share',
           backgroundColor: Colors.blueAccent,
           tooltip: 'Share story',
           onPressed: _shareStory,
           child: const Icon(Icons.share),
         ),
         const SizedBox(height: 12),
         FloatingActionButton.small(
           heroTag: 'fab_regenerate',
           backgroundColor: Colors.orangeAccent,
           tooltip: 'Regenerate story',
           onPressed: _isLoading ? null : _createAnotherStory,
           child: const Icon(Icons.refresh),
         ),
         const SizedBox(height: 12),
         FloatingActionButton.extended(
           heroTag: 'fab_save',
           backgroundColor: AppColors.primary,
           foregroundColor: Colors.white,
           icon: const Icon(Icons.save),
           label: const Text('Save Story'),
           onPressed: _saveStory,
         ),
       ],
     ),
   ),
   ```

3. **Verify Methods Exist**:
   - `_shareStory()` - should exist around line 990+
   - `_createAnotherStory()` - exists at line 1033
   - `_saveStory()` - should exist around line 850+

4. **Add Analytics**:
   - Track FAB usage vs regular button usage:
   ```dart
   void _trackFABAction(String action) {
     StoryAnalytics.logEvent('fab_action', {
       'action': action,
       'screen': 'story_result',
     });
   }
   ```
   - Add to each FAB onPressed

5. **Test on Mobile**:
   ```bash
   # Run on mobile or browser with mobile viewport
   flutter run -d chrome --web-browser-flag="--window-size=375,812"
   ```
   - Verify FABs don't overlap content
   - Test all three actions
   - Verify tooltips appear on hover

### Deliverables:
- FABs added to story result screen
- All actions working
- Analytics tracking implemented
- Mobile testing completed
- Screenshot in TEAM_COORDINATION.md

---

## Task C2: Implement Touch-Friendly Controls (Priority: HIGH)

**Objective**: Increase tap target sizes to meet accessibility standards (44x44dp minimum).

### Areas to Enhance:

1. **Character Selection Grid** (lib/main_story.dart around line 1210):
   ```dart
   // Current: 70x70 containers
   // Update to: 80x80 minimum
   Container(
     width: 80,  // Increased from 70
     height: 80, // Add explicit height
     // ... rest of styling
   )
   ```

2. **Theme Selection** (lib/main_story.dart around line 1320):
   ```dart
   // Increase padding in buttons
   ElevatedButton(
     style: ElevatedButton.styleFrom(
       padding: const EdgeInsets.symmetric(
         horizontal: 20, // Increased from 16
         vertical: 16,   // Increased from 12
       ),
       minimumSize: const Size(120, 48), // Ensure minimum size
     ),
     // ...
   )
   ```

3. **Companion Selection** (lib/main_story.dart around line 1480):
   ```dart
   // Increase companion cards
   Container(
     width: 80,  // Increased from 70
     height: 100, // Increased from 90
     // ...
   )
   ```

4. **Bottom Navigation** (lib/widgets/app_bottom_navigation.dart):
   - Verify icons are at least 24x24
   - Check padding meets 44x44 target
   - Current implementation should be good, just verify

### Testing Checklist:
- [ ] All interactive elements at least 44x44dp
- [ ] Spacing prevents accidental taps
- [ ] Works on small screens (iPhone SE: 375x667)
- [ ] No overlap on large screens

### Deliverables:
- All tap targets meet 44x44dp minimum
- Spacing optimized for mobile
- Testing completed on multiple screen sizes
- Document changes in TEAM_COORDINATION.md

---

## Task C3: Implement Swipe Gestures for Story Navigation (Priority: MEDIUM)

**Objective**: Add swipe-left/right to navigate between story pages.

### Context:
Story result screen has a PageView for multi-page stories. Users should be able to swipe to navigate.

### Implementation:

1. **Locate Story Pager** (lib/story_result_screen.dart):
   ```bash
   grep -n "_buildStoryPager" lib/story_result_screen.dart
   ```

2. **Verify PageView Configuration**:
   - Should have PageController
   - Should support swipe gestures
   - Example implementation:
   ```dart
   Widget _buildStoryPager(double screenHeight) {
     return SizedBox(
       height: screenHeight * 0.6,
       child: PageView.builder(
         controller: _pageController,  // Ensure this exists
         itemCount: _storyPages.length,
         onPageChanged: (index) {
           setState(() => _currentPageIndex = index);
           // Track page views
           StoryAnalytics.logEvent('story_page_viewed', {
             'page_number': index + 1,
             'total_pages': _storyPages.length,
           });
         },
         itemBuilder: (context, index) {
           return Padding(
             padding: const EdgeInsets.all(16),
             child: Text(
               _storyPages[index],
               style: TextStyle(fontSize: _fontSize),
             ),
           );
         },
       ),
     );
   }
   ```

3. **Add Page Indicator**:
   - Add dots below story to show current page:
   ```dart
   // Below PageView
   Row(
     mainAxisAlignment: MainAxisAlignment.center,
     children: List.generate(
       _storyPages.length,
       (index) => Container(
         margin: const EdgeInsets.symmetric(horizontal: 4),
         width: index == _currentPageIndex ? 12 : 8,
         height: 8,
         decoration: BoxDecoration(
           shape: BoxShape.circle,
           color: index == _currentPageIndex
             ? AppColors.primary
             : Colors.grey.shade300,
         ),
       ),
     ),
   )
   ```

4. **Add Swipe Tutorial** (first-time only):
   - Use SharedPreferences to track if user has seen tutorial
   - Show overlay with swipe animation on first story

### Testing:
- Test swipe left/right
- Verify page indicator updates
- Test on touch devices
- Check accessibility (screen reader support)

### Deliverables:
- Swipe gestures working
- Page indicator visible
- Tutorial implemented
- Analytics tracking page views

---

## Task C4: Improve Onboarding Flow (Priority: MEDIUM)

**Objective**: Polish onboarding experience based on Week 1 implementation.

### Current State:
- Onboarding screen exists (lib/onboarding_screen.dart)
- OnboardingService tracks completion

### Enhancements Needed:

1. **Add Progress Indicator**:
   ```dart
   // At top of each onboarding page
   LinearProgressIndicator(
     value: (currentStep + 1) / totalSteps,
     backgroundColor: Colors.grey.shade200,
     valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
   )
   ```

2. **Add Skip Button**:
   - Allow users to skip onboarding
   - Track skip rate in analytics:
   ```dart
   TextButton(
     onPressed: () {
       OnboardingAnalytics.logSkip(currentStep: currentStep);
       _completeOnboarding();
     },
     child: const Text('Skip'),
   )
   ```

3. **Add Character Creation in Onboarding**:
   - Step 1: Welcome
   - Step 2: Create first character (inline, simplified)
   - Step 3: Choose first story theme
   - Step 4: Generate first story (with tutorial)

4. **Improve Visuals**:
   - Add illustrations for each step
   - Use Lottie animations if available
   - Make text child-friendly

### Testing:
- Complete full onboarding flow
- Test skip functionality
- Verify analytics tracking
- Check first-time user experience

### Deliverables:
- Enhanced onboarding flow
- Skip button working
- Character creation integrated
- Analytics tracking
- Testing completed

---

## Task C5: Implement Pull-to-Refresh on Library Screen (Priority: LOW)

**Objective**: Add pull-to-refresh to saved stories screen for better mobile UX.

### Implementation:

1. **Locate Saved Stories Screen**:
   ```bash
   cat lib/saved_stories_screen.dart | head -50
   ```

2. **Wrap Content in RefreshIndicator**:
   ```dart
   @override
   Widget build(BuildContext context) {
     return Scaffold(
       appBar: AppBar(title: const Text('Saved Stories')),
       body: RefreshIndicator(
         onRefresh: _refreshStories,
         child: _stories.isEmpty
           ? _buildEmptyState()
           : ListView.builder(
               itemCount: _stories.length,
               itemBuilder: (context, index) => _buildStoryCard(_stories[index]),
             ),
       ),
     );
   }
   ```

3. **Implement Refresh Method**:
   ```dart
   Future<void> _refreshStories() async {
     setState(() => _isLoading = true);

     try {
       final stories = await StorageService.getStories();
       if (mounted) {
         setState(() {
           _stories = stories;
           _isLoading = false;
         });
       }

       // Track refresh
       StoryAnalytics.logEvent('stories_refreshed', {
         'count': stories.length,
       });
     } catch (e) {
       if (mounted) {
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Failed to refresh stories')),
         );
       }
     }
   }
   ```

4. **Add Visual Feedback**:
   - RefreshIndicator handles pull animation
   - Add success message after refresh

### Testing:
- Pull down on story list
- Verify refresh works
- Test with empty list
- Check loading state

### Deliverables:
- Pull-to-refresh implemented
- Works on all story lists
- Analytics tracking
- Testing completed

---

## Task C6: Accessibility Audit & Fixes (Priority: MEDIUM)

**Objective**: Ensure app meets WCAG 2.1 AA standards.

### Audit Areas:

1. **Semantic Labels**:
   ```bash
   # Find widgets missing semantics
   grep -n "IconButton" lib/main_story.dart lib/story_result_screen.dart
   ```
   - Add Semantics widgets or semantic properties:
   ```dart
   IconButton(
     icon: const Icon(Icons.favorite),
     tooltip: 'Add to favorites',  // ✓ Good
     onPressed: _toggleFavorite,
     // Add semantic label if tooltip not enough
   )
   ```

2. **Color Contrast**:
   - Check all text/background combinations
   - Use contrast checker: https://webaim.org/resources/contrastchecker/
   - Minimum ratios:
     - Normal text: 4.5:1
     - Large text (18pt+): 3:1
     - UI components: 3:1

3. **Focus Indicators**:
   - Verify keyboard navigation works
   - Check focus order is logical
   - Test with tab key

4. **Screen Reader Support**:
   - Test with TalkBack (Android) or VoiceOver (iOS)
   - Verify all interactive elements are announced
   - Check reading order

5. **Text Scaling**:
   ```dart
   # Test with large text
   flutter run -d chrome --web-renderer html --dart-define=FLUTTER_WEB_USE_SKIA=false
   # Then use browser zoom to 200%
   ```
   - Verify layout doesn't break
   - Check text doesn't truncate

### Testing Tools:
```bash
# Run accessibility audit
flutter analyze
dart run accessibility_audit.dart  # If script exists
```

### Deliverables:
- Audit report with findings
- All critical issues fixed
- Documentation of accessibility features
- Testing completed with screen reader

---

## Priority Order

1. **C1**: Floating Action Buttons (HIGH - immediate UX improvement)
2. **C2**: Touch-Friendly Controls (HIGH - accessibility requirement)
3. **C6**: Accessibility Audit (MEDIUM - compliance)
4. **C3**: Swipe Gestures (MEDIUM - nice to have)
5. **C4**: Onboarding Polish (MEDIUM - affects conversion)
6. **C5**: Pull-to-Refresh (LOW - minor feature)

---

## Notes for Codex

- Excellent work on bottom navigation! 🎉
- Focus on mobile-first design
- Test on actual devices if possible
- Use Flutter DevTools for debugging
- Commit after each task
- Update TEAM_COORDINATION.md with progress

---

## Success Criteria

- [ ] FABs implemented and tested
- [ ] All tap targets meet 44x44dp
- [ ] Swipe gestures working
- [ ] Onboarding flow enhanced
- [ ] Pull-to-refresh implemented
- [ ] Accessibility audit completed
- [ ] No build errors
- [ ] Manual testing on mobile completed
