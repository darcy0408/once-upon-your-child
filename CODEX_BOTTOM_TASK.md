# CODEX BOTTOM: Emotion Insights Dashboard (Week 1 Task A)

## 🚫 RESET YOUR CONTEXT

**IGNORE everything about:**
- ❌ Previous analyzer cleanup work
- ❌ withOpacity/withValues changes you made
- ❌ State class renaming
- ❌ Any modifications to main_story.dart you were working on

**Those changes were exploratory. We're starting fresh with a NEW task.**

---

## 📍 Your Working Location

```bash
cd /mnt/c/dev/story-weaver-app
git checkout codex-dev
git reset --hard origin/codex-dev  # Discard any local changes
git pull origin codex-dev
```

**Branch:** `codex-dev`
**Status:** Clean slate, insights dashboard NOT built yet

---

## 🎯 Your Single Goal

Build a dashboard that shows parents their child's emotional patterns over the past 7 days.

**Example:**
- Parent taps "Insights" tab
- Sees: "5 emotions explored this week"
- Sees list: "Worried (3x, avg intensity 3.5), Happy (2x, avg intensity 4.0)"
- Sees recent check-ins with timestamps

---

## 📖 READ THESE FILES FIRST

### 1. Read the full task specification:
```bash
cat CODEX_WEEK1_TASK.md
```
This has ALL the details you need.

### 2. Understand what data exists:
```bash
# Emotion data service (READ DATA FROM HERE)
cat lib/emotions_learning_system.dart | grep -A 20 "class EmotionCheckIn"
cat lib/emotions_learning_system.dart | grep -A 10 "getCheckIns"
```

### 3. Check reference screens for UI patterns:
```bash
# Example screens to match design style
ls lib/emotions_screen.dart
ls lib/feelings_wheel_screen.dart
ls lib/story_result_screen.dart
```

---

## 📦 Files You Will Create/Modify

### CREATE:
1. **lib/services/emotion_insights_service.dart**
   - `getEmotionTrends({int days = 7})` - Returns emotion frequency map
   - `getRecentCheckIns({int limit = 10})` - Returns recent check-ins list
   - `getWeeklyStats()` - Returns summary stats

   ```dart
   class EmotionInsightsService {
     final EmotionsLearningService _emotionService = EmotionsLearningService();

     Future<Map<String, EmotionTrend>> getEmotionTrends({int days = 7}) async {
       // 1. Get all check-ins
       final checkIns = await _emotionService.getCheckIns();

       // 2. Filter last N days
       final cutoff = DateTime.now().subtract(Duration(days: days));
       final recent = checkIns.where((c) => c.timestamp.isAfter(cutoff)).toList();

       // 3. Group by emotionId, count, calculate avg intensity
       // 4. Return Map<emotionId, EmotionTrend>
     }
   }
   ```

2. **lib/insights_screen.dart**
   - Full dashboard UI
   - `_buildStatsCard()` - Shows total check-ins, unique emotions, most common
   - `_buildTrendsSection()` - Shows emotion frequency list
   - `_buildRecentCheckIns()` - Shows timeline of recent check-ins
   - Empty state when no data
   - Pull-to-refresh
   - Loading state

### MODIFY:
3. **lib/main_story.dart**
   - Add "Insights" tab to bottom navigation
   - Use `IndexedStack` to show `InsightsScreen`

   ```dart
   // Around line 500-600, add navigation
   BottomNavigationBar(
     currentIndex: _selectedTabIndex,
     onTap: (index) => setState(() => _selectedTabIndex = index),
     items: const [
       BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Stories'),
       BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'Insights'), // NEW
       BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Characters'),
     ],
   ),
   ```

---

## ✅ Acceptance Criteria

Before committing, verify:

- [ ] `EmotionInsightsService` exists with 3 methods implemented
- [ ] Correctly calculates emotion trends from last 7 days
- [ ] `InsightsScreen` displays:
  - [ ] Total check-ins count
  - [ ] Number of unique emotions
  - [ ] Most common emotion
  - [ ] Emotion frequency list (emotion, count, avg intensity)
- [ ] Empty state when no data exists
- [ ] Loading state while fetching data
- [ ] Insights tab appears in main navigation
- [ ] No crashes or errors
- [ ] Works offline (uses cached data)

---

## 🧪 How to Test

### 1. Create test data:
```bash
flutter run
```

### 2. Generate check-ins:
1. Create 3-4 stories with different emotions
2. Do pre-story feelings check each time
3. Vary emotions: Worried (2x), Happy (1x), Sad (1x)
4. Vary intensities: 3, 4, 2, 5

### 3. Test insights dashboard:
1. Tap "Insights" tab in bottom navigation
2. Should see loading indicator briefly
3. Should see stats card:
   - "4 emotions explored this week"
   - "3 unique emotions"
   - "Most common: Worried 😟"
4. Should see trends list:
   - Worried 😟 - 2x, avg intensity 3.5
   - Happy 😊 - 1x, avg intensity 4.0
   - Sad 😢 - 1x, avg intensity 2.0
5. Should see recent check-ins timeline

### 4. Test edge cases:
- No data yet (empty state: "No emotions tracked yet")
- Data older than 7 days (should be filtered out)
- Pull to refresh
- Navigate away and back (should maintain state)

---

## 🚨 Common Mistakes to Avoid

1. **DON'T modify emotion check-in logic** - Just read the data
2. **DON'T add new SharedPreferences keys** - Use existing `EmotionsLearningService`
3. **DON'T overcomplicate charts** - Simple list is fine for MVP
4. **DO handle null/empty gracefully** - Users might have no data
5. **DO match existing UI patterns** - Use SunsetJungleTheme colors
6. **DO test with real data** - Create stories first to populate

---

## 🎨 UI Guidelines

Use **SunsetJungleTheme** colors:
```dart
// Background
backgroundColor: SunsetJungleTheme.creamLight,

// Cards
Card(
  color: Colors.white,
  elevation: 2,
  child: Padding(
    padding: EdgeInsets.all(16),
    child: ...
  ),
)

// Text colors
style: TextStyle(
  color: SunsetJungleTheme.jungleDeepGreen, // primary text
  fontSize: 16,
  fontWeight: FontWeight.bold,
)

// Accent
color: SunsetJungleTheme.sunsetCoral,
```

### Stats Card Layout:
```
┌─────────────────────────────┐
│  Weekly Emotion Summary     │
├─────────────────────────────┤
│  📊 4 check-ins this week   │
│  🎨 3 unique emotions       │
│  🌟 Most common: Worried 😟 │
│  📈 Avg intensity: 3.5/5    │
└─────────────────────────────┘
```

### Trends List Layout:
```
Emotion Trends (Last 7 Days)
┌─────────────────────────────┐
│ 😟 Worried                  │
│ 2 times • Avg intensity 3.5 │
│ ████████░░                  │ 70% bar
├─────────────────────────────┤
│ 😊 Happy                    │
│ 1 time • Avg intensity 4.0  │
│ ████░░░░░░                  │ 40% bar
└─────────────────────────────┘
```

---

## 📝 Implementation Order

### Step 1: Service Layer (30 min)
1. Create `lib/services/emotion_insights_service.dart`
2. Implement `getEmotionTrends()` with date filtering
3. Implement `getWeeklyStats()` for summary
4. Test with print statements

### Step 2: Screen Structure (20 min)
1. Create `lib/insights_screen.dart`
2. Add basic Scaffold with AppBar
3. Add loading/empty states
4. Test navigation

### Step 3: Data Display (40 min)
1. Implement `_buildStatsCard()`
2. Implement `_buildTrendsSection()` with simple bars
3. Implement `_buildRecentCheckIns()` list
4. Connect to service, test with real data

### Step 4: Navigation Integration (20 min)
1. Modify `main_story.dart`
2. Add bottom navigation bar with Insights tab
3. Wire up tab switching
4. Test full flow

### Step 5: Polish (20 min)
1. Add pull-to-refresh
2. Add error handling
3. Test all edge cases
4. Run `flutter analyze`

**Total estimated time:** 2-2.5 hours

---

## 📝 Commit Message When Done

```bash
git add .
git commit -m "Add emotion insights dashboard

- Create EmotionInsightsService for trend calculations
  - getEmotionTrends() filters last 7 days, groups by emotion
  - getWeeklyStats() returns summary stats
  - getRecentCheckIns() returns timeline of check-ins
- Create InsightsScreen with weekly emotion stats UI
  - Stats card: total check-ins, unique emotions, most common
  - Trends list: emotion frequency with avg intensity
  - Recent check-ins timeline
  - Empty state and loading state
  - Pull-to-refresh support
- Add Insights tab to main navigation
- Match SunsetJungleTheme design system
- Handle offline mode with cached data

Completes Week 1 Task A: Emotion insights dashboard
Ref: CODEX_WEEK1_TASK.md"
```

---

## ❓ Questions?

1. **"Should I work on post-story check?"** → NO. That's Codex Top's job.
2. **"Should I use fl_chart package?"** → NO. Use simple Container bars (MVP).
3. **"Where do I get emotion data?"** → From `EmotionsLearningService.getCheckIns()`
4. **"Should I modify EmotionCheckIn model?"** → NO. Just read existing data.
5. **"What about the analyzer cleanup I did?"** → Discard it. Focus on this task.

---

## 🚀 Start Command

```bash
# 1. Get on right branch and reset
git checkout codex-dev
git reset --hard origin/codex-dev
git pull origin codex-dev

# 2. Read the full spec
cat CODEX_WEEK1_TASK.md

# 3. Start coding
mkdir -p lib/services
# Create lib/services/emotion_insights_service.dart
```

**Focus only on insights dashboard. Ignore everything else.**

---

**Estimated Time:** 2-2.5 hours
**Priority:** P0 (blocking Week 1 completion)
**Success Metric:** Parents see emotion patterns and trends
