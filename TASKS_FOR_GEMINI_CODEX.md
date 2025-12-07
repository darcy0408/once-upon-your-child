# Detailed Task Lists for Gemini/Codex

This file contains step-by-step instructions for fixing two critical bugs in the Story Weaver app. Tasks are ordered by priority and include exact file locations, code snippets, and testing instructions.

---

## 🔴 TASK 1: Fix Avatar Images Not Displaying (HIGH PRIORITY)

### Problem Summary
Avatar images from DiceBear API don't display in character creation. They appear as blank spaces when network requests fail because there's no error handling in the SvgPicture.network() widget.

### File to Modify
**Location:** `lib/customizable_avatar_widget.dart`

### Step-by-Step Fix

#### Step 1: Add Error Handling to SvgPicture.network

**Current Code (Lines 53-66):**
```dart
child: SvgPicture.network(
  imageUrl,
  key: ValueKey(imageUrl),
  fit: BoxFit.contain,
  width: size,
  height: size,
  placeholderBuilder: (context) => Center(
    child: SizedBox(
      width: size * 0.35,
      height: size * 0.35,
      child: const CircularProgressIndicator(strokeWidth: 3),
    ),
  ),
),
```

**REPLACE WITH:**
```dart
child: SvgPicture.network(
  imageUrl,
  key: ValueKey(imageUrl),
  fit: BoxFit.contain,
  width: size,
  height: size,
  placeholderBuilder: (context) => Center(
    child: SizedBox(
      width: size * 0.35,
      height: size * 0.35,
      child: const CircularProgressIndicator(strokeWidth: 3),
    ),
  ),
  // Add this error handler to show fallback icon when SVG fails to load
  semanticsLabel: 'Character Avatar',
),
```

**Note:** Unfortunately, `flutter_svg`'s `SvgPicture.network()` doesn't have a built-in `errorBuilder` parameter like `Image.network()` does. We need a different approach.

#### Step 2: Replace SvgPicture.network with FutureBuilder Pattern

**COMPLETE REPLACEMENT for lines 28-72:**

```dart
@override
Widget build(BuildContext context) {
  final imageUrl = avatar.toAvataaarsUrl(circleBackground: false);

  // Debug: print the avatar URL
  print('🎭 Avatar URL: $imageUrl');

  final devicePixelRatio =
      MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;

  return SizedBox(
    width: size,
    height: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF6EA),
            Color(0xFFE8F9F3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ClipOval(
          child: FutureBuilder(
            future: _loadSvg(imageUrl),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // Loading state
                return Center(
                  child: SizedBox(
                    width: size * 0.35,
                    height: size * 0.35,
                    child: const CircularProgressIndicator(strokeWidth: 3),
                  ),
                );
              } else if (snapshot.hasError || !snapshot.hasData) {
                // Error state - show fallback icon
                return Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: Icon(
                      Icons.person,
                      size: size * 0.5,
                      color: Colors.grey[600],
                    ),
                  ),
                );
              } else {
                // Success state - display SVG
                return SvgPicture.network(
                  imageUrl,
                  key: ValueKey(imageUrl),
                  fit: BoxFit.contain,
                  width: size,
                  height: size,
                );
              }
            },
          ),
        ),
      ),
    ),
  );
}

Future<bool> _loadSvg(String url) async {
  try {
    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 5),
    );
    return response.statusCode == 200;
  } catch (e) {
    print('❌ Failed to load avatar SVG: $e');
    return false;
  }
}
```

#### Step 3: Add Required Import

**Add this import at the top of the file (after existing imports):**
```dart
import 'package:http/http.dart' as http;
```

#### Step 4: Testing Instructions

1. **Hot reload the app** on your phone
2. **Navigate to character creation screen**
3. **Try creating a character**:
   - Avatars should load normally
   - If internet is slow/unavailable, you should see a person icon placeholder
   - No more blank spaces!
4. **Test offline**: Turn off WiFi and see if fallback works
5. **Check logs**: You should see either:
   - `🎭 Avatar URL: https://...` (successful)
   - `❌ Failed to load avatar SVG: ...` (error caught)

---

## 🟡 TASK 2: Fix Network Error When Creating Stories (MEDIUM PRIORITY)

### Problem Summary
Users get network errors when trying to generate stories. The backend is healthy and accessible, but the app might have SSL/certificate issues or improper error messages.

### Files to Investigate

1. **Primary:** `lib/services/api_service_manager.dart`
2. **Secondary:** `lib/quick_story_screen.dart`
3. **Config:** `lib/config/flavor_config.dart`

### Step-by-Step Fix

#### Step 1: Add Better Error Logging

**File:** `lib/services/api_service_manager.dart`

**Find this code (around lines 48-51):**
```dart
} on SocketException catch (error) {
  debugPrint('Network error while calling $uri: $error');
  rethrow;
}
```

**REPLACE WITH:**
```dart
} on SocketException catch (error) {
  debugPrint('❌ Network error while calling $uri');
  debugPrint('   Error details: $error');
  debugPrint('   Backend URL: $_localBackendUrl');
  throw Exception(
    'Cannot connect to server. Please check your internet connection and try again.\n\nServer: $_localBackendUrl',
  );
} on HandshakeException catch (error) {
  debugPrint('❌ SSL/TLS error while calling $uri: $error');
  throw Exception(
    'Secure connection failed. This might be a certificate issue.\n\nDetails: $error',
  );
} on http.ClientException catch (error) {
  debugPrint('❌ HTTP Client error while calling $uri: $error');
  throw Exception(
    'Request failed: ${error.message}\n\nPlease try again.',
  );
}
```

**Also add this import at the top:**
```dart
import 'dart:io';
```

#### Step 2: Add Same Error Handling to GET Method

**Find the GET method (around lines 75-77):**
```dart
} on SocketException catch (error) {
  debugPrint('Network error while calling $uri: $error');
  rethrow;
}
```

**REPLACE WITH:** (same as above)
```dart
} on SocketException catch (error) {
  debugPrint('❌ Network error while calling $uri');
  debugPrint('   Error details: $error');
  debugPrint('   Backend URL: $_localBackendUrl');
  throw Exception(
    'Cannot connect to server. Please check your internet connection and try again.\n\nServer: $_localBackendUrl',
  );
} on HandshakeException catch (error) {
  debugPrint('❌ SSL/TLS error while calling $uri: $error');
  throw Exception(
    'Secure connection failed. This might be a certificate issue.\n\nDetails: $error',
  );
} on http.ClientException catch (error) {
  debugPrint('❌ HTTP Client error while calling $uri: $error');
  throw Exception(
    'Request failed: ${error.message}\n\nPlease try again.',
  );
}
```

#### Step 3: Test Backend Connectivity

**Create a new file:** `test_backend_connection.dart` in the root directory

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const backendUrl = 'https://story-weaver-app-production.up.railway.app';

  print('Testing backend connection...');
  print('URL: $backendUrl');

  try {
    // Test 1: Health check
    print('\n1. Testing /health endpoint...');
    final healthResponse = await http.get(
      Uri.parse('$backendUrl/health'),
    ).timeout(Duration(seconds: 10));

    print('   Status: ${healthResponse.statusCode}');
    print('   Response: ${healthResponse.body}');

    if (healthResponse.statusCode == 200) {
      print('   ✅ Health check passed!');
    } else {
      print('   ❌ Health check failed!');
    }

    // Test 2: Generate story endpoint
    print('\n2. Testing /api/stories/generate endpoint...');
    final storyResponse = await http.post(
      Uri.parse('$backendUrl/api/stories/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'character_name': 'Test',
        'age': 5,
        'theme': 'friendship',
        'user_id': 'test-user',
      }),
    ).timeout(Duration(seconds: 30));

    print('   Status: ${storyResponse.statusCode}');
    if (storyResponse.statusCode == 200) {
      print('   ✅ Story generation works!');
    } else {
      print('   ❌ Story generation failed!');
      print('   Response: ${storyResponse.body}');
    }

  } catch (e) {
    print('\n❌ Connection failed!');
    print('Error: $e');
    print('\nThis error means the app cannot reach the backend server.');
  }
}
```

**Run this test:**
```bash
cd C:\dev\story-weaver-app
dart run test_backend_connection.dart
```

#### Step 4: Testing Instructions

1. **Run the connection test** (see Step 3 above)
2. **If test passes**, the backend is fine
3. **If test fails**, check:
   - Internet connection
   - Firewall settings
   - Backend might be down (check Railway dashboard)
4. **Hot reload the app** and try creating a story
5. **Check logs** for the new error messages:
   - Should see ❌ emoji and detailed error info
   - Error message should tell user exactly what went wrong

---

## 🟢 TASK 3: Additional Improvements (OPTIONAL - Low Priority)

### Add Network Status Indicator

**File:** `lib/quick_story_screen.dart` or `lib/main_story.dart`

**Before story generation, check connectivity:**

```dart
// Add this helper method
Future<bool> _checkConnectivity() async {
  try {
    final result = await http.get(
      Uri.parse(Environment.backendUrl + '/health'),
    ).timeout(Duration(seconds: 5));
    return result.statusCode == 200;
  } catch (e) {
    return false;
  }
}

// Use it before generating story
Future<void> _generateStory() async {
  // Check connectivity first
  final isConnected = await _checkConnectivity();
  if (!isConnected) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No connection to server. Please check your internet.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  // ... rest of story generation code
}
```

---

## 📋 SUMMARY FOR AI AGENTS

### Priority Order
1. **FIRST:** Fix avatar loading (Task 1) - Most visible issue
2. **SECOND:** Improve error messages (Task 2) - Better UX
3. **THIRD:** Add connectivity check (Task 3) - Nice to have

### Testing Checklist
After implementing fixes, test:
- [ ] Avatar images display correctly
- [ ] Fallback icon shows when network fails
- [ ] Story generation works
- [ ] Error messages are clear and helpful
- [ ] App doesn't crash on network errors
- [ ] Hot reload works for all changes

### Files Modified
1. `lib/customizable_avatar_widget.dart` - Avatar error handling
2. `lib/services/api_service_manager.dart` - Better error messages
3. `test_backend_connection.dart` - New file for testing

### Estimated Time
- Task 1: 15-20 minutes (avatar fix)
- Task 2: 10-15 minutes (error handling)
- Task 3: 10 minutes (optional connectivity check)

**Total: ~40 minutes**

---

## 🚀 FOR GEMINI OR CODEX

**You can work on these tasks independently. Each task is self-contained.**

**Commands to run after making changes:**
```bash
# Regenerate if needed
dart run build_runner build --delete-conflicting-outputs

# Hot reload in terminal
# (Press 'r' in the running flutter session)

# Or restart app
flutter run -d adb-RFCW41NT2YD-LjWjCI._adb-tls-connect._tcp
```

**Good luck! 🎯**
