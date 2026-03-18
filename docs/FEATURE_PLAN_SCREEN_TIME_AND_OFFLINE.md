# Feature Plan: Screen Time Controls & Offline Mode

## Status Update - 2026-03-12

- Completed the first implementation slice for Feature A (Screen Time Controls):
  - A1. Added screen-time settings storage to `ParentalConsentService`
  - A2. Added `ScreenTimeService`
  - A3. Added `TimesUpScreen`
  - A4. Started `ScreenTimeService` from `main.dart`
  - A5. Wired app-level listeners for wind-down, limit reached, and bedtime lockout
  - A6. Added screen-time controls to `ParentControlsScreen`
- Verification completed with:
  - `dart analyze lib/services/parental_consent_service.dart lib/services/screen_time_service.dart lib/screens/times_up_screen.dart lib/main.dart lib/screens/parent_controls_screen.dart`
  - Result: `No issues found!`
- `lib/main_story.dart` still has pre-existing analyzer warnings unrelated to this slice; they were not expanded in this commit.

Two new features for Story Weaver, aimed at the top parent requests for kids' apps.

**Important conventions:**
- Dart uses **camelCase** for all method/variable names (snake_case causes compile errors)
- Always add `if (mounted)` checks before `setState` or `ScaffoldMessenger` calls after any `await`
- Use the existing `GoogleFonts.fredoka()` for all text
- Use the existing `AppColors` and `AppSpacing` from `lib/theme/app_theme.dart`
- Gold accent color: `Color(0xFFFFD700)`
- Container style: `Colors.white.withAlpha(20)` background, `Colors.white24` border, 12px radius
- Reuse the existing `_SectionHeader`, `_ControlTile`, and `_ActionTile` widget patterns from `parent_controls_screen.dart`

---

## FEATURE A: Screen Time Controls

### Overview

Parents can set a daily time limit (15/30/45/60/90 minutes or unlimited). The app tracks usage per day and shows a gentle "wind-down" warning at 5 minutes remaining, then a "time's up" screen that only a parent can bypass (via math gate). A bedtime lockout option prevents app use after a set hour.

---

### A1. Add Screen Time Settings to ParentalConsentService

**File:** `lib/services/parental_consent_service.dart`

Add these constants after the existing `_keyAllowPhotoAvatar` on line 11:

```dart
  static const _keyDailyLimitMinutes = 'screen_time_daily_limit';
  static const _keyBedtimeLockoutHour = 'screen_time_bedtime_hour';
  static const _keyBedtimeLockoutMinute = 'screen_time_bedtime_minute';
  static const _keyBedtimeLockoutEnabled = 'screen_time_bedtime_enabled';
```

Add these methods at the bottom of the class, before the closing `}`:

```dart
  /// Returns daily limit in minutes. null = unlimited (default).
  Future<int?> getDailyLimitMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getInt(_keyDailyLimitMinutes);
    return (val == null || val <= 0) ? null : val;
  }

  Future<void> setDailyLimitMinutes(int? minutes) async {
    final prefs = await SharedPreferences.getInstance();
    if (minutes == null || minutes <= 0) {
      await prefs.remove(_keyDailyLimitMinutes);
    } else {
      await prefs.setInt(_keyDailyLimitMinutes, minutes);
    }
  }

  Future<bool> isBedtimeLockoutEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBedtimeLockoutEnabled) ?? false;
  }

  /// Returns bedtime hour and minute as a record. Defaults to 20:00 (8 PM).
  Future<({int hour, int minute})> getBedtimeLockout() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      hour: prefs.getInt(_keyBedtimeLockoutHour) ?? 20,
      minute: prefs.getInt(_keyBedtimeLockoutMinute) ?? 0,
    );
  }

  Future<void> setBedtimeLockout({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBedtimeLockoutEnabled, enabled);
    await prefs.setInt(_keyBedtimeLockoutHour, hour);
    await prefs.setInt(_keyBedtimeLockoutMinute, minute);
  }
```

---

### A2. Create the ScreenTimeService (usage tracker)

**New file:** `lib/services/screen_time_service.dart`

This is a singleton that runs a 1-minute periodic timer. It stores daily usage in SharedPreferences keyed by date string (`screen_time_2026-03-12`).

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'parental_consent_service.dart';

/// Tracks daily app usage and enforces screen time limits.
///
/// Call [start] from main.dart after app init.
/// Listen to [onLimitReached] and [onWindDown] streams for UI triggers.
class ScreenTimeService {
  ScreenTimeService._();
  static final ScreenTimeService instance = ScreenTimeService._();

  final _consentService = const ParentalConsentService();
  Timer? _ticker;

  /// Fires when 5 minutes remain.
  final StreamController<int> _windDownController = StreamController.broadcast();
  Stream<int> get onWindDown => _windDownController.stream;

  /// Fires when limit is reached. Payload = daily limit in minutes.
  final StreamController<int> _limitReachedController = StreamController.broadcast();
  Stream<int> get onLimitReached => _limitReachedController.stream;

  /// Fires when bedtime lockout is active.
  final StreamController<void> _bedtimeController = StreamController.broadcast();
  Stream<void> get onBedtimeLockout => _bedtimeController.stream;

  bool _windDownFired = false;
  bool _limitFired = false;

  /// The SharedPreferences key for today's usage.
  String get _todayKey =>
      'screen_time_${DateTime.now().toIso8601String().substring(0, 10)}';

  /// Start the usage tracker. Call once from main.dart.
  void start() {
    _ticker?.cancel();
    _windDownFired = false;
    _limitFired = false;
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _tick() async {
    // Increment today's usage by 1 minute
    final prefs = await SharedPreferences.getInstance();
    final used = (prefs.getInt(_todayKey) ?? 0) + 1;
    await prefs.setInt(_todayKey, used);

    // Check bedtime lockout
    final bedtimeEnabled = await _consentService.isBedtimeLockoutEnabled();
    if (bedtimeEnabled) {
      final bedtime = await _consentService.getBedtimeLockout();
      final now = DateTime.now();
      final bedtimeToday = DateTime(now.year, now.month, now.day,
          bedtime.hour, bedtime.minute);
      if (now.isAfter(bedtimeToday)) {
        _bedtimeController.add(null);
        return; // Don't also fire limit warnings
      }
    }

    // Check daily limit
    final limit = await _consentService.getDailyLimitMinutes();
    if (limit == null) return; // Unlimited

    final remaining = limit - used;

    if (remaining <= 5 && remaining > 0 && !_windDownFired) {
      _windDownFired = true;
      _windDownController.add(remaining);
    }

    if (remaining <= 0 && !_limitFired) {
      _limitFired = true;
      _limitReachedController.add(limit);
    }
  }

  /// Returns today's usage in minutes.
  Future<int> getTodayUsageMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_todayKey) ?? 0;
  }

  /// Returns remaining minutes today, or null if unlimited.
  Future<int?> getRemainingMinutes() async {
    final limit = await _consentService.getDailyLimitMinutes();
    if (limit == null) return null;
    final used = await getTodayUsageMinutes();
    return (limit - used).clamp(0, limit);
  }

  /// Call when a parent unlocks extra time via math gate.
  /// Adds [extraMinutes] bonus to today's limit by reducing recorded usage.
  Future<void> grantExtraTime(int extraMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_todayKey) ?? 0;
    await prefs.setInt(_todayKey, (used - extraMinutes).clamp(0, 9999));
    _limitFired = false;
    _windDownFired = false;
  }
}
```

---

### A3. Create the TimesUpScreen

**New file:** `lib/screens/times_up_screen.dart`

This screen appears when the daily limit is reached or bedtime lockout activates. It covers the entire screen and can only be dismissed by solving a simple math problem (same pattern as the existing math gate in the app).

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/screen_time_service.dart';

/// Full-screen overlay shown when screen time limit is reached.
/// Parent must solve a math problem to grant 15 extra minutes.
class TimesUpScreen extends StatefulWidget {
  /// 'limit' for daily limit reached, 'bedtime' for bedtime lockout.
  final String reason;

  const TimesUpScreen({super.key, required this.reason});

  @override
  State<TimesUpScreen> createState() => _TimesUpScreenState();
}

class _TimesUpScreenState extends State<TimesUpScreen> {
  late int _a, _b, _answer;
  final _controller = TextEditingController();
  String? _error;
  bool _solved = false;

  @override
  void initState() {
    super.initState();
    _generateProblem();
  }

  void _generateProblem() {
    final rng = Random();
    _a = 10 + rng.nextInt(40); // 10-49
    _b = 10 + rng.nextInt(40);
    _answer = _a + _b;
  }

  void _check() {
    final input = int.tryParse(_controller.text.trim());
    if (input == _answer) {
      setState(() => _solved = true);
      ScreenTimeService.instance.grantExtraTime(15);
      // Pop after a moment so parent sees the success state
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    } else {
      setState(() => _error = 'Not quite! Try again.');
      _controller.clear();
      _generateProblem();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBedtime = widget.reason == 'bedtime';
    final title = isBedtime ? 'Bedtime!' : 'Time\'s Up!';
    final message = isBedtime
        ? 'It\'s past bedtime. Time to put the app away and get some sleep!'
        : 'You\'ve used all your screen time for today. Great job playing!';
    final icon = isBedtime ? Icons.bedtime_rounded : Icons.timer_off_rounded;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B2E),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: const Color(0xFFFFD700), size: 80),
                const SizedBox(height: AppSpacing.lg),
                Text(title,
                    style: GoogleFonts.fredoka(
                        color: Colors.white, fontSize: 32,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.md),
                Text(message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.fredoka(
                        color: Colors.white70, fontSize: 16)),
                const SizedBox(height: AppSpacing.xl),

                // Parent math gate
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      Text('Parents: solve to add 15 minutes',
                          style: GoogleFonts.fredoka(
                              color: Colors.white54, fontSize: 13)),
                      const SizedBox(height: AppSpacing.sm),
                      Text('$_a + $_b = ?',
                          style: GoogleFonts.fredoka(
                              color: Colors.white, fontSize: 24)),
                      const SizedBox(height: AppSpacing.sm),
                      if (_solved)
                        Text('Correct! 15 extra minutes granted.',
                            style: GoogleFonts.fredoka(
                                color: const Color(0xFF4CAF50), fontSize: 16))
                      else ...[
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _controller,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20),
                            decoration: InputDecoration(
                              hintText: '??',
                              hintStyle: TextStyle(
                                  color: Colors.white.withAlpha(80)),
                              enabledBorder: UnderlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Colors.white24)),
                              focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Color(0xFFFFD700))),
                            ),
                            onSubmitted: (_) => _check(),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(_error!,
                              style: GoogleFonts.fredoka(
                                  color: Colors.redAccent, fontSize: 13)),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton(
                          onPressed: _check,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD700),
                          ),
                          child: Text('Submit',
                              style: GoogleFonts.fredoka(
                                  color: Colors.black, fontSize: 16)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

---

### A4. Wire Up ScreenTimeService in main.dart

**File:** `lib/main.dart`

Find the line where `AppTtsService.instance.init()` is called (should be around line 27). Add the screen time service start right after it:

```dart
import 'services/screen_time_service.dart'; // ADD at top with other imports
```

Then after the `AppTtsService.instance.init()` call:

```dart
ScreenTimeService.instance.start();
```

---

### A5. Listen for Limit Events in the App Shell

**File:** `lib/main_story.dart` (or wherever your top-level MaterialApp / Navigator lives)

You need to listen to the three streams from `ScreenTimeService` and push the `TimesUpScreen` when they fire. Add this in the `initState` of your root stateful widget:

```dart
import '../services/screen_time_service.dart';
import '../screens/times_up_screen.dart';
```

In `initState`, after `super.initState()`:

```dart
    ScreenTimeService.instance.onWindDown.listen((remaining) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$remaining minutes left! Time to start wrapping up.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    });

    ScreenTimeService.instance.onLimitReached.listen((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const TimesUpScreen(reason: 'limit'),
        ),
      );
    });

    ScreenTimeService.instance.onBedtimeLockout.listen((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const TimesUpScreen(reason: 'bedtime'),
        ),
      );
    });
```

**Important:** Store the `StreamSubscription` objects and cancel them in `dispose()`:

```dart
late final StreamSubscription _windDownSub;
late final StreamSubscription _limitSub;
late final StreamSubscription _bedtimeSub;

// In initState, assign:
_windDownSub = ScreenTimeService.instance.onWindDown.listen(...);
_limitSub = ScreenTimeService.instance.onLimitReached.listen(...);
_bedtimeSub = ScreenTimeService.instance.onBedtimeLockout.listen(...);

// In dispose:
_windDownSub.cancel();
_limitSub.cancel();
_bedtimeSub.cancel();
```

---

### A6. Add Screen Time Controls to Parent Controls Screen

**File:** `lib/screens/parent_controls_screen.dart`

Add new state variables in `_ParentControlsScreenState` after `_loading` (line 18):

```dart
  int? _dailyLimitMinutes;
  bool _bedtimeEnabled = false;
  int _bedtimeHour = 20;
  int _bedtimeMinute = 0;
  int _todayUsage = 0;
```

Update `initState` to load screen time settings. Replace the existing `initState` (lines 21-26) with:

```dart
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final allowPhoto = await _consentService.getAllowPhotoAvatar();
    final limit = await _consentService.getDailyLimitMinutes();
    final bedtimeEnabled = await _consentService.isBedtimeLockoutEnabled();
    final bedtime = await _consentService.getBedtimeLockout();
    final usage = await ScreenTimeService.instance.getTodayUsageMinutes();
    if (mounted) {
      setState(() {
        _allowPhotoAvatar = allowPhoto;
        _dailyLimitMinutes = limit;
        _bedtimeEnabled = bedtimeEnabled;
        _bedtimeHour = bedtime.hour;
        _bedtimeMinute = bedtime.minute;
        _todayUsage = usage;
        _loading = false;
      });
    }
  }
```

Add this import at the top:

```dart
import '../services/screen_time_service.dart';
```

Now add the Screen Time section in the ListView's children list. Place it right BEFORE the "More parental controls coming soon" text (line 89). Replace that "More parental controls" text with the new section:

```dart
                  _SectionHeader(title: 'Screen Time'),
                  // Daily usage display
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.today, color: Color(0xFFFFD700)),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Used today: $_todayUsage min'
                          '${_dailyLimitMinutes != null ? " / $_dailyLimitMinutes min" : ""}',
                          style: GoogleFonts.fredoka(
                              color: Colors.white, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Daily limit picker
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Daily limit',
                              style: GoogleFonts.fredoka(
                                  color: Colors.white, fontSize: 15)),
                        ),
                        DropdownButton<int?>(
                          value: _dailyLimitMinutes,
                          dropdownColor: const Color(0xFF1E0A3C),
                          style: GoogleFonts.fredoka(
                              color: Colors.white, fontSize: 14),
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Unlimited')),
                            DropdownMenuItem(value: 15, child: Text('15 min')),
                            DropdownMenuItem(value: 30, child: Text('30 min')),
                            DropdownMenuItem(value: 45, child: Text('45 min')),
                            DropdownMenuItem(value: 60, child: Text('1 hour')),
                            DropdownMenuItem(value: 90, child: Text('1.5 hours')),
                            DropdownMenuItem(value: 120, child: Text('2 hours')),
                          ],
                          onChanged: (v) async {
                            await _consentService.setDailyLimitMinutes(v);
                            if (mounted) setState(() => _dailyLimitMinutes = v);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Bedtime lockout toggle
                  _ControlTile(
                    title: 'Bedtime lockout',
                    subtitle: _bedtimeEnabled
                        ? 'App locks at ${_bedtimeHour.toString().padLeft(2, '0')}:${_bedtimeMinute.toString().padLeft(2, '0')}. '
                          'Tap the time to change it.'
                        : 'When enabled, the app will lock after a set bedtime.',
                    value: _bedtimeEnabled,
                    onChanged: (v) async {
                      await _consentService.setBedtimeLockout(
                        enabled: v,
                        hour: _bedtimeHour,
                        minute: _bedtimeMinute,
                      );
                      if (mounted) setState(() => _bedtimeEnabled = v);
                    },
                  ),
                  if (_bedtimeEnabled)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                                hour: _bedtimeHour, minute: _bedtimeMinute),
                          );
                          if (picked != null) {
                            await _consentService.setBedtimeLockout(
                              enabled: true,
                              hour: picked.hour,
                              minute: picked.minute,
                            );
                            if (mounted) {
                              setState(() {
                                _bedtimeHour = picked.hour;
                                _bedtimeMinute = picked.minute;
                              });
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.access_time,
                                  color: Color(0xFFFFD700), size: 20),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'Bedtime: ${_bedtimeHour.toString().padLeft(2, '0')}:${_bedtimeMinute.toString().padLeft(2, '0')}',
                                style: GoogleFonts.fredoka(
                                    color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
```

---

## FEATURE B: Offline Mode (Surfacing Existing Infrastructure)

### Overview

The app already saves stories in Isar and has a SharedPreferences cache with LRU eviction. The missing pieces are:
1. A visible "My Library" / saved stories screen accessible from the main nav
2. Network status awareness so the app gracefully tells the user when they're offline
3. Auto-download of TTS audio for saved stories so they can be re-read offline

---

### B1. Add `connectivity_plus` Dependency

**File:** `pubspec.yaml`

Add under `dependencies` (alphabetically with the other packages):

```yaml
  connectivity_plus: ^6.1.0
```

Then run `flutter pub get`.

---

### B2. Create a NetworkStatusService

**New file:** `lib/services/network_status_service.dart`

```dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Lightweight singleton that exposes whether the device is online.
class NetworkStatusService {
  NetworkStatusService._();
  static final NetworkStatusService instance = NetworkStatusService._();

  final _connectivity = Connectivity();
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onStatusChange => _controller.stream;

  StreamSubscription? _sub;

  Future<void> init() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final online = !results.contains(ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(_isOnline);
        debugPrint('Network status: ${_isOnline ? "online" : "offline"}');
      }
    });
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
```

---

### B3. Initialize NetworkStatusService in main.dart

**File:** `lib/main.dart`

Add the import:

```dart
import 'services/network_status_service.dart';
```

In the `main()` function, right after `WidgetsFlutterBinding.ensureInitialized()` and before the app runs:

```dart
await NetworkStatusService.instance.init();
```

---

### B4. Show Offline Banner in the App Shell

**File:** `lib/main_story.dart` (or your root widget with the bottom nav / app scaffold)

Add a `StreamBuilder` that listens to `NetworkStatusService.instance.onStatusChange` and shows a small banner at the top of the screen when offline.

Find the `Scaffold` in your root widget's `build` method. Wrap the `body` in a `Column` with an optional offline banner:

```dart
import '../services/network_status_service.dart';

// Inside the build method, replace `body: <existing body>` with:
body: Column(
  children: [
    StreamBuilder<bool>(
      stream: NetworkStatusService.instance.onStatusChange,
      initialData: NetworkStatusService.instance.isOnline,
      builder: (context, snapshot) {
        if (snapshot.data == true) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: Colors.orange.shade800,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.cloud_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                'You\'re offline. Saved stories are still available!',
                style: GoogleFonts.fredoka(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        );
      },
    ),
    Expanded(child: /* <existing body widget goes here> */),
  ],
),
```

---

### B5. Add Offline Guard to Story Generation

**File:** `lib/screens/wizard_steps/magic_review_step.dart`

Find the "Make Magic" button's `onPressed` handler (the method that calls `ApiServiceManager.generateStory`). At the very beginning of that method, add a network check:

```dart
import '../../services/network_status_service.dart'; // ADD at top

// At the start of the generate method:
if (!NetworkStatusService.instance.isOnline) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You need an internet connection to create a new story. '
            'Try reading a saved story from your library while offline!'),
        backgroundColor: Colors.orange,
      ),
    );
  }
  return;
}
```

---

### B6. Add Offline Guard to Bedtime Mode

**File:** `lib/screens/bedtime_wizard_screen.dart`

In the `_generateAndReadStory` method (line 253), add a network check at the very top, before building `_wizardData`:

```dart
import '../services/network_status_service.dart'; // ADD at top with other imports

// At line 253, the start of _generateAndReadStory:
Future<void> _generateAndReadStory() async {
    if (!NetworkStatusService.instance.isOnline) {
      await _speak("Oh no, we need the internet to make a new story. Let's try again when we're back online. Goodnight!");
      if (mounted) Navigator.of(context).pop();
      return;
    }
    // ... rest of existing method unchanged
```

---

### B7. Create a SavedStoriesScreen (Library)

**New file:** `lib/screens/saved_stories_screen.dart`

This screen reads from the existing `OfflineStoryService` and displays saved stories in a list. Tapping one opens it in `StoryResultScreen` with offline data.

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/offline_story_service.dart';
import '../story_result_screen.dart';

class SavedStoriesScreen extends StatefulWidget {
  const SavedStoriesScreen({super.key});

  @override
  State<SavedStoriesScreen> createState() => _SavedStoriesScreenState();
}

class _SavedStoriesScreenState extends State<SavedStoriesScreen> {
  List<Map<String, dynamic>> _stories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stories = await OfflineStoryService.getAllStories();
    if (mounted) {
      setState(() {
        _stories = stories;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gradientStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('My Library',
            style: GoogleFonts.fredoka(color: Colors.white, fontSize: 22)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.gradientStart, Color(0xFF1E0A3C)],
          ),
        ),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : _stories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_stories,
                            color: Colors.white38, size: 64),
                        const SizedBox(height: AppSpacing.md),
                        Text('No saved stories yet!',
                            style: GoogleFonts.fredoka(
                                color: Colors.white54, fontSize: 18)),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Stories you create will appear here.',
                            style: GoogleFonts.fredoka(
                                color: Colors.white38, fontSize: 14)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: _stories.length,
                    itemBuilder: (context, index) {
                      final story = _stories[index];
                      final title =
                          story['title'] as String? ?? 'Untitled Story';
                      final theme = story['theme'] as String? ?? '';
                      final isFavorite =
                          story['isFavorite'] as bool? ?? false;
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: GestureDetector(
                          onTap: () {
                            // Navigate to StoryResultScreen with saved data.
                            // You will need to adapt this to your StoryResultScreen
                            // constructor — pass the story text and metadata.
                            // This is a placeholder for the navigation:
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => StoryResultScreen(
                                  storyText: story['storyText'] as String? ?? '',
                                  storyTitle: title,
                                  storyId: story['storyId'] as String?,
                                  // Pass other fields your StoryResultScreen expects
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding:
                                const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isFavorite
                                      ? Icons.star_rounded
                                      : Icons.auto_stories,
                                  color: isFavorite
                                      ? const Color(0xFFFFD700)
                                      : Colors.white54,
                                  size: 28,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(title,
                                          style: GoogleFonts.fredoka(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight:
                                                  FontWeight.w600)),
                                      if (theme.isNotEmpty)
                                        Text(theme,
                                            style: GoogleFonts.fredoka(
                                                color: Colors.white54,
                                                fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    color: Colors.white54),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
```

**Important note for the implementer:** The `StoryResultScreen` constructor may have different required parameters than shown above. Read `lib/story_result_screen.dart`'s constructor carefully and adapt the navigation call accordingly. The key fields available from `OfflineStoryService.getAllStories()` are: `storyId`, `title`, `storyText`, `theme`, `isFavorite`, `isCompleted`, `tone`, `length`.

---

### B8. Add Library Button to Main Navigation

This depends on your app's navigation structure. Find where the main bottom navigation or sidebar is defined (likely in `lib/main_story.dart` or a similar shell widget). Add a "Library" icon/tab that navigates to `SavedStoriesScreen`.

Example — if you have a bottom navigation bar, add a new tab:

```dart
BottomNavigationBarItem(
  icon: Icon(Icons.library_books),
  label: 'Library',
),
```

And handle the tap to push `SavedStoriesScreen`.

If navigation is through the wizard header (like the Bedtime button), add a similar `_LabeledNavButton`:

```dart
_LabeledNavButton(
  icon: Icons.library_books,
  label: 'Library',
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SavedStoriesScreen()),
    );
  },
),
```

---

## Verification Checklist

After implementing all tasks, verify:

### Screen Time
- [ ] Parent Controls screen shows the new Screen Time section with daily limit dropdown
- [ ] Setting a limit to 1 minute triggers the TimesUpScreen after 1 minute of use
- [ ] TimesUpScreen math gate works — wrong answer regenerates the problem, correct answer dismisses and grants 15 minutes
- [ ] Bedtime lockout triggers TimesUpScreen with "bedtime" reason after the set hour
- [ ] Wind-down SnackBar appears at 5 minutes remaining
- [ ] `dart analyze lib/` shows no new warnings

### Offline Mode
- [ ] Offline banner appears when device loses connectivity
- [ ] Banner disappears when connectivity returns
- [ ] "Make Magic" button shows SnackBar when offline instead of attempting generation
- [ ] Bedtime Mode speaks a friendly offline message and exits
- [ ] Saved Stories screen shows previously generated stories
- [ ] Tapping a saved story opens it for re-reading
- [ ] Empty state shows when no stories are saved
- [ ] `flutter pub get` succeeds with the new `connectivity_plus` dependency
- [ ] `dart analyze lib/` shows no new warnings
