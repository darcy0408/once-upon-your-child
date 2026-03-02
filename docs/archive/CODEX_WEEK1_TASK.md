# Codex Task: Build Emotion Insights Dashboard (Week 1)

## 🎯 Goal
Create a dashboard that shows parents their child's emotional patterns over the past 7 days using existing emotion check-in data.

---

## 📍 Working Location
```bash
Directory: /mnt/c/dev/story-weaver-app
Branch: codex-dev
Setup:
  git checkout codex-dev
  git merge main -m "Merge main for Week 1 insights task"
```

**IMPORTANT:** You are working on `codex-dev` branch. Do NOT work directly on main.

---

## 📦 What Already Exists (DO NOT MODIFY)

### Files You'll USE (read from these):
- `lib/emotions_learning_system.dart`
  - `class EmotionCheckIn` - stores emotion data (already has emotionId, intensity, whatHappened, timestamp)
  - `class EmotionsLearningService` - has `getCheckIns()` method
  - This is the data source for your dashboard

- `lib/pre_story_feelings_dialog.dart`
  - Shows how feelings are collected
  - Reference for UI patterns

### Files You'll MODIFY:
- `lib/main_story.dart` - add "Insights" navigation tab
- `pubspec.yaml` - might need chart library

---

## 🏗️ Files to CREATE

### 1. lib/services/emotion_insights_service.dart
```dart
// Create this new service file

import 'package:shared_preferences/shared_preferences.dart';
import '../emotions_learning_system.dart';

class EmotionTrend {
  final String emotionId;
  final String emotionName;
  final String emoji;
  final int count;
  final double averageIntensity;

  EmotionTrend({
    required this.emotionId,
    required this.emotionName,
    required this.emoji,
    required this.count,
    required this.averageIntensity,
  });
}

class EmotionInsightsService {
  final EmotionsLearningService _emotionService = EmotionsLearningService();

  /// Get emotion frequency and intensity for last N days
  Future<Map<String, EmotionTrend>> getEmotionTrends({int days = 7}) async {
    // TODO: Implement
    // 1. Get check-ins from last N days using _emotionService.getCheckIns()
    // 2. Filter by date (DateTime.now() - Duration(days: days))
    // 3. Group by emotionId
    // 4. Calculate count and average intensity for each
    // 5. Get emotion metadata (name, emoji) from EmotionsLearningService.getEmotionById()
    // 6. Return Map<emotionId, EmotionTrend>
  }

  /// Get list of recent check-ins with details
  Future<List<EmotionCheckInSummary>> getRecentCheckIns({int limit = 10}) async {
    // TODO: Implement
    // 1. Get all check-ins
    // 2. Sort by timestamp descending
    // 3. Take first 'limit' items
    // 4. Enrich with emotion metadata
    // 5. Return list
  }

  /// Get simple stats for quick summary
  Future<EmotionStats> getWeeklyStats() async {
    // TODO: Implement
    // Return: total check-ins, unique emotions, most common emotion, average intensity
  }
}

class EmotionCheckInSummary {
  final String emotionId;
  final String emotionName;
  final String emoji;
  final int intensity;
  final String? context;
  final DateTime timestamp;

  EmotionCheckInSummary({
    required this.emotionId,
    required this.emotionName,
    required this.emoji,
    required this.intensity,
    this.context,
    required this.timestamp,
  });
}

class EmotionStats {
  final int totalCheckIns;
  final int uniqueEmotions;
  final String? mostCommonEmotion;
  final double averageIntensity;

  EmotionStats({
    required this.totalCheckIns,
    required this.uniqueEmotions,
    this.mostCommonEmotion,
    required this.averageIntensity,
  });
}
```

**Requirements:**
- Use existing `EmotionsLearningService` to read data
- Handle edge cases (no data yet, old data)
- Make methods async (data from SharedPreferences)
- Add error handling (try/catch)

---

### 2. lib/insights_screen.dart
```dart
// Create this new screen

import 'package:flutter/material.dart';
import 'services/emotion_insights_service.dart';
import 'sunset_jungle_theme.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final _insightsService = EmotionInsightsService();
  bool _isLoading = true;
  EmotionStats? _stats;
  Map<String, EmotionTrend>? _trends;
  List<EmotionCheckInSummary>? _recentCheckIns;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final stats = await _insightsService.getWeeklyStats();
      final trends = await _insightsService.getEmotionTrends(days: 7);
      final recent = await _insightsService.getRecentCheckIns(limit: 10);

      setState(() {
        _stats = stats;
        _trends = trends;
        _recentCheckIns = recent;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Show error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emotion Insights'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: SunsetJungleTheme.headerGradient,
          ),
        ),
      ),
      backgroundColor: SunsetJungleTheme.creamLight,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_stats == null || _stats!.totalCheckIns == 0) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsCard(),
            const SizedBox(height: 20),
            _buildTrendsSection(),
            const SizedBox(height: 20),
            _buildRecentCheckIns(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    // TODO: Implement
    // Show friendly message: "No emotions tracked yet. Create a story to get started!"
  }

  Widget _buildStatsCard() {
    // TODO: Implement
    // Card showing:
    // - Total check-ins this week
    // - Unique emotions explored
    // - Most common emotion (with emoji)
    // - Average intensity
  }

  Widget _buildTrendsSection() {
    // TODO: Implement
    // Bar chart or list showing emotion frequency
    // Each emotion: emoji, name, count, average intensity bar
    // Consider using fl_chart package or simple Container bars
  }

  Widget _buildRecentCheckIns() {
    // TODO: Implement
    // List of recent check-ins
    // Each item: emoji, emotion name, intensity dots (●●●○○), timestamp, context
    // Tap to see more details
  }
}
```

**UI Requirements:**
- Use existing `SunsetJungleTheme` colors
- Match design patterns from other screens
- Show empty state if no data
- Add pull-to-refresh
- Loading states
- Error handling

**Chart Options:**
- **Option A:** Use `fl_chart` package (add to pubspec.yaml)
- **Option B:** Build simple bar chart with Container widgets
- **Recommendation:** Option B for simplicity (this is MVP)

---

### 3. Modify lib/main_story.dart

**Add navigation tab to bottom bar:**

Find the existing bottom navigation (or create if doesn't exist) and add:

```dart
// Around line 500-600 in the build method
BottomNavigationBar(
  currentIndex: _selectedTabIndex,
  onTap: (index) {
    setState(() => _selectedTabIndex = index);
  },
  items: const [
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: 'Stories',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.insights), // NEW TAB
      label: 'Insights',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: 'Characters',
    ),
  ],
),

// Then in body, use IndexedStack or switch statement:
body: IndexedStack(
  index: _selectedTabIndex,
  children: [
    _buildStoriesTab(), // existing content
    const InsightsScreen(), // NEW
    _buildCharactersTab(), // existing or new
  ],
),
```

**If bottom nav doesn't exist yet:**
- Add it as the main navigation pattern
- Make sure "Insights" is the 2nd tab
- Handle tab switching state

---

## 📋 Acceptance Criteria

### Must Have:
- [ ] `EmotionInsightsService` correctly calculates trends from last 7 days
- [ ] `InsightsScreen` displays:
  - Total check-ins count
  - Number of unique emotions
  - Most common emotion
  - Simple emotion frequency list (emotion, count, avg intensity)
- [ ] Empty state when no data exists
- [ ] Loading state while fetching data
- [ ] Insights tab appears in main navigation
- [ ] No crashes or errors
- [ ] Works offline (uses cached data)

### Nice to Have:
- [ ] Simple bar chart visualization
- [ ] Tap emotion to see related stories
- [ ] Pull-to-refresh
- [ ] Smooth animations

### Do NOT Add:
- ❌ Premium features (30-day history)
- ❌ PDF export
- ❌ Email sharing
- ❌ Complex charts
- ❌ Gamification

---

## 🧪 Testing Checklist

Before committing, test:
- [ ] Works with 0 check-ins (empty state)
- [ ] Works with 1 check-in
- [ ] Works with 10+ check-ins
- [ ] Works with data older than 7 days (should be filtered out)
- [ ] Calculations are correct (count, averages)
- [ ] Emoji displays correctly
- [ ] Navigation works (can go to insights and back)
- [ ] No console errors or warnings

---

## 🎨 Design Guidelines

### Colors (Use SunsetJungleTheme):
- Background: `SunsetJungleTheme.creamLight`
- Cards: `Colors.white` with shadow
- Primary text: `SunsetJungleTheme.jungleDeepGreen`
- Accent: `SunsetJungleTheme.sunsetCoral`

### Typography:
- Title: 20px, bold
- Section headers: 16px, bold
- Body: 14px, regular
- Use Quicksand font family (already in theme)

### Spacing:
- Screen padding: 16px
- Card padding: 16px
- Between sections: 20px
- Between list items: 12px

### Icons:
- Emotion emoji: 28-32px
- Navigation icons: 24px
- Info icons: 20px

---

## 📚 Reference Examples

### Similar Screens to Study:
- `lib/emotions_screen.dart` - emotion display patterns
- `lib/feelings_wheel_screen.dart` - card layouts
- `lib/story_result_screen.dart` - multi-section layout

### Data Access Pattern:
```dart
// This is how to get emotion data:
final emotionService = EmotionsLearningService();
final checkIns = await emotionService.getCheckIns();

// Filter last 7 days:
final now = DateTime.now();
final cutoff = now.subtract(const Duration(days: 7));
final recentCheckIns = checkIns.where((c) => c.timestamp.isAfter(cutoff)).toList();

// Get emotion details:
final emotion = emotionService.getEmotionById(checkIn.emotionId);
```

---

## ⚠️ Common Pitfalls to Avoid

1. **Don't modify emotion check-in logic** - just read the data
2. **Don't add new SharedPreferences keys** - use existing data
3. **Handle null/empty gracefully** - users might have no data
4. **Don't overcomplicate charts** - simple bars are fine for MVP
5. **Match existing UI patterns** - don't introduce new design system
6. **Test with real data** - create some stories first to populate

---

## 🚀 When You're Done

1. **Commit your changes:**
```bash
git add .
git commit -m "Add emotion insights dashboard

- Create EmotionInsightsService for trend calculations
- Create InsightsScreen with weekly emotion stats
- Add Insights tab to main navigation
- Show emotion frequency, intensity averages
- Handle empty states and loading

Ref: 3_WEEK_MVP_PLAN.md Week 1 - Codex Task"
```

2. **Let Claude know** - I'll review and merge to main

---

## ❓ Questions During Development?

If you get stuck:
1. Check existing emotion service methods in `emotions_learning_system.dart`
2. Look at how other screens handle loading/empty states
3. Test with print statements to debug calculations
4. Ask Claude - I'm here to help!

---

## 🎯 Success Looks Like

At the end of this task, parents should be able to:
1. Tap "Insights" tab
2. See "5 emotions explored this week"
3. See a list: "Worried (3x), Happy (2x), Sad (1x)..."
4. See average intensity for each
5. Think: "Oh wow, my child has been worried a lot. Let's talk about that."

That's it! Keep it simple. This is the foundation. ✨

---

**Estimated Time:** 1-2 days
**Priority:** P0 (blocking Week 2)
**Owner:** Codex
**Reviewer:** Claude
**Target Completion:** Day 3-4 of Week 1
