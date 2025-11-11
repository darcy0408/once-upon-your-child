# Codex Tasks - 21-Day Launch Plan
**Assigned To:** Codex (OpenAI o1/o1-mini)
**Your Strengths:** Frontend development, testing, UX polish, production details
**Claude's Focus:** Backend infrastructure, critical path items, integrations

---

## 🎯 Your Mission

You'll handle **10 major tasks** across the 21 days, focusing on:
- Frontend testing and quality
- User experience polish
- Offline functionality
- Production-ready features
- Final launch polish

**Work in parallel with Claude** - you won't block each other!

---

## 🚀 START HERE: Your First Task

**TASK 1: Frontend Widget Tests** is your first task (Days 3-4).
Branch: `codex/frontend-tests`

---

## 📋 Your Complete Task List (In Order)

### **TASK 1: Frontend Widget Tests** ✅
**Days:** 3-4 (alongside Claude's backend tests)
**Branch:** `codex/frontend-tests`
**Priority:** CRITICAL

**What to do:**
1. Create test framework structure:
   ```bash
   # In story-weaver-app root
   mkdir -p test/widgets
   mkdir -p test/integration
   ```

2. **Widget tests to write:**
   ```dart
   // test/widgets/character_creation_test.dart
   void main() {
     testWidgets('Character creation form validates required fields', (tester) async {
       await tester.pumpWidget(CharacterCreationScreenEnhanced());

       // Try to submit empty form
       await tester.tap(find.text('Create Character'));
       await tester.pump();

       // Should show validation errors
       expect(find.text('Required'), findsWidgets);
     });

     testWidgets('Feelings wheel selection works', (tester) async {
       // Test feelings wheel interaction
       // Test emotion selection
       // Test intensity slider
     });
   }
   ```

3. **Integration tests to write:**
   ```dart
   // test/integration/story_creation_flow_test.dart
   void main() {
     testWidgets('Complete story creation flow', (tester) async {
       // Mock ApiServiceManager
       // Create character
       // Select feelings
       // Generate story
       // Verify story displayed
     });

     testWidgets('Paywall limits work correctly', (tester) async {
       // Create 3 stories (free tier limit)
       // 4th story should show paywall
     });

     testWidgets('Offline caching works', (tester) async {
       // Create story online
       // Go offline
       // Story should still load from cache
     });
   }
   ```

4. **Run tests and fix issues:**
   ```bash
   flutter test
   flutter test --coverage
   ```

**Deliverable:** Test suite with >70% coverage on critical flows

**Files to create:**
- `test/widgets/character_creation_test.dart`
- `test/widgets/feelings_wheel_test.dart`
- `test/widgets/story_result_test.dart`
- `test/integration/story_creation_flow_test.dart`
- `test/integration/paywall_test.dart`
- `test/integration/offline_test.dart`

---

### **TASK 2: Backend Resilience (Retry Logic)** 🔄
**Day:** 9
**Branch:** `codex/backend-resilience`
**Priority:** HIGH

**What to do:**
1. Add retry logic to `ApiServiceManager`:
   ```dart
   // lib/services/api_service_manager.dart

   Future<String> _generateStoryWithRetry({
     required String characterName,
     required String theme,
     required int age,
     // ... other params
   }) async {
     int attempts = 0;
     Duration delay = Duration(seconds: 2);

     while (attempts < 3) {
       try {
         return await _generateStoryWithBackend(
           characterName: characterName,
           theme: theme,
           age: age,
           // ... pass all params
         );
       } catch (e) {
         attempts++;
         print('Story generation attempt $attempts failed: $e');

         if (attempts >= 3) {
           // All retries exhausted
           rethrow;
         }

         // Exponential backoff: 2s, 4s, 8s
         await Future.delayed(delay);
         delay *= 2;
       }
     }
     throw Exception('Should never reach here');
   }
   ```

2. **Add timeouts:**
   ```dart
   final response = await http.post(
     Uri.parse(endpoint),
     headers: {'Content-Type': 'application/json'},
     body: jsonEncode(body),
   ).timeout(
     Duration(seconds: 30),
     onTimeout: () {
       throw TimeoutException('Story generation timed out');
     },
   );
   ```

3. **Improve error messages:**
   ```dart
   } catch (e) {
     String userMessage;
     if (e is SocketException) {
       userMessage = 'Check your internet connection and try again';
     } else if (e is TimeoutException) {
       userMessage = 'This is taking longer than usual. Try again?';
     } else if (e is HttpException) {
       userMessage = 'Our story engine is taking a break. Try again soon!';
     } else {
       userMessage = 'Something went wrong. Please try again.';
     }

     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text(userMessage)),
     );
   }
   ```

4. **Test retry logic:**
   - Test with flaky network
   - Verify exponential backoff works
   - Check user-friendly errors display

**Deliverable:** Robust error handling with automatic retries

---

### **TASK 3: Build Flavors Configuration** ⚙️
**Day:** 15
**Branch:** `codex/build-flavors`
**Priority:** MEDIUM

**What to do:**
1. **Set up flavor config:**
   ```dart
   // lib/config/flavor_config.dart
   enum Flavor {
     development,
     staging,
     production,
   }

   class FlavorConfig {
     final Flavor flavor;
     final String name;
     final String backendUrl;
     final Color primaryColor;

     FlavorConfig._internal({
       required this.flavor,
       required this.name,
       required this.backendUrl,
       required this.primaryColor,
     });

     static FlavorConfig? _instance;

     static FlavorConfig get instance {
       return _instance ??= _getConfig();
     }

     static FlavorConfig _getConfig() {
       const flavorString = String.fromEnvironment('FLAVOR', defaultValue: 'development');

       switch (flavorString) {
         case 'production':
           return FlavorConfig._internal(
             flavor: Flavor.production,
             name: 'Story Weaver',
             backendUrl: 'https://story-weaver-app-production.up.railway.app',
             primaryColor: Colors.deepPurple,
           );
         case 'staging':
           return FlavorConfig._internal(
             flavor: Flavor.staging,
             name: 'Story Weaver (Staging)',
             backendUrl: 'https://story-weaver-staging.up.railway.app',
             primaryColor: Colors.orange,
           );
         default:
           return FlavorConfig._internal(
             flavor: Flavor.development,
             name: 'Story Weaver (Dev)',
             backendUrl: 'http://127.0.0.1:5000',
             primaryColor: Colors.green,
           );
       }
     }
   }
   ```

2. **Update Environment.dart:**
   ```dart
   // lib/config/environment.dart
   class Environment {
     static String get backendUrl => FlavorConfig.instance.backendUrl;
     static bool get isProduction => FlavorConfig.instance.flavor == Flavor.production;
     static String get appName => FlavorConfig.instance.name;
   }
   ```

3. **Create launch configurations:**
   ```json
   // .vscode/launch.json
   {
     "version": "0.2.0",
     "configurations": [
       {
         "name": "Development",
         "request": "launch",
         "type": "dart",
         "program": "lib/main.dart",
         "args": [
           "--dart-define=FLAVOR=development"
         ]
       },
       {
         "name": "Staging",
         "request": "launch",
         "type": "dart",
         "program": "lib/main.dart",
         "args": [
           "--dart-define=FLAVOR=staging"
         ]
       },
       {
         "name": "Production",
         "request": "launch",
         "type": "dart",
         "program": "lib/main.dart",
         "args": [
           "--dart-define=FLAVOR=production"
         ]
       }
     ]
   }
   ```

4. **Update build commands:**
   ```bash
   # Development
   flutter run --dart-define=FLAVOR=development

   # Staging
   flutter build web --dart-define=FLAVOR=staging

   # Production
   flutter build web --dart-define=FLAVOR=production --release
   flutter build apk --dart-define=FLAVOR=production --release
   flutter build ipa --dart-define=FLAVOR=production --release
   ```

**Deliverable:** Easy environment switching without code changes

---

### **TASK 4: Offline Functionality (Isar Database)** 📱
**Day:** 16
**Branch:** `codex/offline-isar`
**Priority:** HIGH

**What to do:**
1. **Install Isar:**
   ```yaml
   # pubspec.yaml
   dependencies:
     isar: ^3.1.0
     isar_flutter_libs: ^3.1.0
     path_provider: ^2.1.1

   dev_dependencies:
     isar_generator: ^3.1.0
     build_runner: ^2.4.6
   ```

2. **Define schemas:**
   ```dart
   // lib/models/cached_story.dart
   import 'package:isar/isar.dart';

   part 'cached_story.g.dart';

   @collection
   class CachedStory {
     Id id = Isar.autoIncrement;

     late String storyId;
     late String title;
     late String storyText;
     late String theme;
     late String wisdomGem;
     late DateTime createdAt;
     late String characterId;

     @Index()
     late String characterName;
   }

   @collection
   class CachedCharacter {
     Id id = Isar.autoIncrement;

     late String characterId;
     late String name;
     late int age;
     late String gender;
     late String role;
     // ... all character fields
   }
   ```

3. **Create Isar service:**
   ```dart
   // lib/services/isar_service.dart
   class IsarService {
     static late Isar isar;

     static Future<void> initialize() async {
       final dir = await getApplicationDocumentsDirectory();
       isar = await Isar.open(
         [CachedStorySchema, CachedCharacterSchema],
         directory: dir.path,
       );
     }

     // Cache story
     static Future<void> cacheStory(SavedStory story) async {
       final cached = CachedStory()
         ..storyId = story.id
         ..title = story.title
         ..storyText = story.storyText
         ..theme = story.theme
         ..wisdomGem = story.wisdomGem
         ..createdAt = story.createdAt
         ..characterId = story.characters.first.id
         ..characterName = story.characters.first.name;

       await isar.writeTxn(() async {
         await isar.cachedStorys.put(cached);
       });
     }

     // Get cached stories
     static Future<List<CachedStory>> getCachedStories() async {
       return await isar.cachedStorys
         .where()
         .sortByCreatedAtDesc()
         .findAll();
     }
   }
   ```

4. **Implement offline-first pattern:**
   ```dart
   // lib/offline_stories_screen.dart
   @override
   void initState() {
     super.initState();
     _loadStories();
   }

   Future<void> _loadStories() async {
     // 1. Show cached data immediately
     final cached = await IsarService.getCachedStories();
     setState(() {
       _stories = _convertToSavedStories(cached);
       _isLoading = false;
     });

     // 2. Fetch fresh data in background
     try {
       final fresh = await StorageService().getSavedStories();
       if (mounted && fresh.isNotEmpty) {
         setState(() => _stories = fresh);
         // Update cache
         for (var story in fresh) {
           await IsarService.cacheStory(story);
         }
       }
     } catch (e) {
       // Offline or error - cached data is fine
       print('Could not fetch fresh stories: $e');
     }
   }
   ```

5. **Add sync indicator:**
   ```dart
   // In app bar
   actions: [
     if (_isSyncing)
       Padding(
         padding: EdgeInsets.all(12),
         child: CircularProgressIndicator(color: Colors.white),
       ),
     if (!_isOnline)
       Padding(
         padding: EdgeInsets.all(12),
         child: Icon(Icons.cloud_off, color: Colors.orange),
       ),
   ]
   ```

**Deliverable:** App works great offline with local cache

---

### **TASK 5: StoryResultScreen Polish** ✨
**Day:** 17 (morning)
**Branch:** `codex/story-result-polish`
**Priority:** MEDIUM

**What to do:**
1. **Complete TODOs in story_result_screen.dart:**
   ```dart
   // Find around line 450-455
   // TODO: Hydrate avatar appearance

   // Replace with:
   Widget _buildCharacterAvatar() {
     if (widget.characterId == null) {
       return SizedBox.shrink();
     }

     return FutureBuilder<Character?>(
       future: _getCharacter(widget.characterId!),
       builder: (context, snapshot) {
         if (!snapshot.hasData) return CircularProgressIndicator();

         final character = snapshot.data!;
         return Column(
           children: [
             CircleAvatar(
               radius: 40,
               backgroundImage: NetworkImage(
                 AvatarService.generateDicebearUrl(
                   seed: character.name,
                   hairColor: character.hair ?? 'brown',
                   eyeColor: character.eyes ?? 'blue',
                 ),
               ),
             ),
             SizedBox(height: 8),
             Text(
               character.name,
               style: TextStyle(
                 fontSize: 18,
                 fontWeight: FontWeight.bold,
               ),
             ),
             if (character.outfit != null)
               Text(
                 'Wearing: ${character.outfit}',
                 style: TextStyle(fontSize: 12, color: Colors.grey),
               ),
           ],
         );
       },
     );
   }
   ```

2. **Add export/share functionality:**
   ```dart
   // Add share button
   import 'package:share_plus/share_plus.dart';

   IconButton(
     icon: Icon(Icons.share),
     onPressed: () async {
       await Share.share(
         '${widget.title}\n\n${widget.storyText}\n\n${widget.wisdomGem}',
         subject: 'Story from Story Weaver',
       );
     },
   )
   ```

3. **Enhance celebration dialog:**
   ```dart
   // Tie wisdom gem into achievement celebration
   void _showCompletionCelebration() {
     showDialog(
       context: context,
       builder: (context) => AchievementCelebrationDialog(
         title: 'Story Complete!',
         message: widget.wisdomGem,
         achievementIcon: '📖',
         onDismiss: () {
           Navigator.pop(context);
           // Optionally show post-story feelings dialog
         },
       ),
     );
   }
   ```

**Deliverable:** Polished story result screen with all features working

---

### **TASK 6: Onboarding Flow** 📚
**Day:** 17 (afternoon)
**Branch:** `codex/onboarding`
**Priority:** MEDIUM

**What to do:**
1. **Create onboarding screen:**
   ```dart
   // lib/onboarding_screen.dart
   class OnboardingScreen extends StatefulWidget {
     @override
     State<OnboardingScreen> createState() => _OnboardingScreenState();
   }

   class _OnboardingScreenState extends State<OnboardingScreen> {
     final PageController _pageController = PageController();
     int _currentPage = 0;

     final List<OnboardingPage> _pages = [
       OnboardingPage(
         title: 'Create Characters',
         description: 'Build unique characters with personalities and feelings',
         image: 'assets/onboarding/character.png',
       ),
       OnboardingPage(
         title: 'Choose Feelings',
         description: 'Explore 72+ emotions with our feelings wheel',
         image: 'assets/onboarding/feelings.png',
       ),
       OnboardingPage(
         title: 'Get Your Story',
         description: 'AI creates personalized, therapeutic stories',
         image: 'assets/onboarding/story.png',
       ),
     ];

     @override
     Widget build(BuildContext context) {
       return Scaffold(
         body: Column(
           children: [
             Expanded(
               child: PageView.builder(
                 controller: _pageController,
                 itemCount: _pages.length,
                 onPageChanged: (index) {
                   setState(() => _currentPage = index);
                 },
                 itemBuilder: (context, index) {
                   return _buildPage(_pages[index]);
                 },
               ),
             ),
             _buildBottomNav(),
           ],
         ),
       );
     }
   }
   ```

2. **Check if first time user:**
   ```dart
   // In main_story.dart initState
   @override
   void initState() {
     super.initState();
     _checkFirstTime();
   }

   Future<void> _checkFirstTime() async {
     final prefs = await SharedPreferences.getInstance();
     final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

     if (!hasSeenOnboarding) {
       await Navigator.push(
         context,
         MaterialPageRoute(builder: (_) => OnboardingScreen()),
       );
       await prefs.setBool('has_seen_onboarding', true);
     }
   }
   ```

3. **Create interactive tutorials:**
   - Show tooltip on first feelings wheel use
   - Highlight "Create Story" button on first character
   - Quick tips overlay for key features

**Deliverable:** Smooth first-time user experience

---

### **TASK 7: UI/UX Polish Pass** ✨
**Day:** 17 (continued)
**Branch:** `codex/ui-polish` (same as Task 5-6)
**Priority:** HIGH

**What to do:**
1. **Consistent loading states:**
   ```dart
   // Create shared loading widget
   // lib/widgets/story_loading.dart
   class StoryLoadingIndicator extends StatelessWidget {
     final String message;

     @override
     Widget build(BuildContext context) {
       return Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           CircularProgressIndicator(
             valueColor: AlwaysStoppedAnimation<Color>(
               Colors.deepPurple,
             ),
           ),
           SizedBox(height: 16),
           Text(
             message,
             style: TextStyle(fontSize: 16),
             textAlign: TextAlign.center,
           ),
         ],
       );
     }
   }

   // Use everywhere:
   if (_isLoading) StoryLoadingIndicator(message: 'Creating your story...')
   ```

2. **Smooth transitions:**
   ```dart
   // Add hero animations for character avatars
   Hero(
     tag: 'character-${character.id}',
     child: CircleAvatar(...),
   )

   // Add page route animations
   Navigator.push(
     context,
     PageRouteBuilder(
       pageBuilder: (context, animation, secondaryAnimation) => StoryResultScreen(...),
       transitionsBuilder: (context, animation, secondaryAnimation, child) {
         return FadeTransition(
           opacity: animation,
           child: child,
         );
       },
     ),
   );
   ```

3. **Responsive design checks:**
   ```dart
   // Test on different sizes
   - iPhone SE (small)
   - iPhone 15 (medium)
   - iPad (large)
   - Web desktop

   // Use MediaQuery for responsive layouts
   final screenWidth = MediaQuery.of(context).size.width;
   final crossAxisCount = screenWidth > 600 ? 4 : 2;
   ```

4. **Accessibility:**
   ```dart
   // Add semantic labels
   Semantics(
     label: 'Create new character',
     button: true,
     child: FloatingActionButton(...),
   )

   // Test with TalkBack/VoiceOver
   // Test with large fonts
   // Verify color contrast
   ```

**Deliverable:** Professional, polished UI across all screens

---

### **TASK 8: Analytics Integration** 📊
**Day:** 18
**Branch:** `codex/analytics`
**Priority:** HIGH

**What to do:**
1. **Set up Firebase Analytics:**
   ```yaml
   # pubspec.yaml
   dependencies:
     firebase_core: ^2.24.2
     firebase_analytics: ^10.7.4
   ```

2. **Initialize in main.dart:**
   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await Firebase.initializeApp();
     runApp(MyApp());
   }
   ```

3. **Track key events:**
   ```dart
   // lib/services/analytics_service.dart
   class AnalyticsService {
     static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

     // Character events
     static Future<void> logCharacterCreated({
       required int age,
       required String characterType,
     }) async {
       await _analytics.logEvent(
         name: 'character_created',
         parameters: {
           'age': age,
           'character_type': characterType,
           'timestamp': DateTime.now().toIso8601String(),
         },
       );
     }

     // Story events
     static Future<void> logStoryCreated({
       required String theme,
       required int characterAge,
       required bool usedFeelingsWheel,
       required String storyMode,
     }) async {
       await _analytics.logEvent(
         name: 'story_created',
         parameters: {
           'theme': theme,
           'character_age': characterAge,
           'used_feelings_wheel': usedFeelingsWheel,
           'story_mode': storyMode, // 'regular', 'learning', 'interactive'
         },
       );
     }

     // Feelings wheel events
     static Future<void> logFeelingSelected({
       required String coreEmotion,
       required String tertiaryEmotion,
       required int intensity,
     }) async {
       await _analytics.logEvent(
         name: 'feeling_selected',
         parameters: {
           'core_emotion': coreEmotion,
           'tertiary_emotion': tertiaryEmotion,
           'intensity': intensity,
         },
       );
     }

     // Paywall events
     static Future<void> logPaywallShown(String location) async {
       await _analytics.logEvent(
         name: 'paywall_shown',
         parameters: {'location': location},
       );
     }

     static Future<void> logPurchaseCompleted({
       required String productId,
       required double price,
     }) async {
       await _analytics.logPurchase(
         value: price,
         currency: 'USD',
         parameters: {'product_id': productId},
       );
     }
   }
   ```

4. **Add tracking throughout app:**
   ```dart
   // In character_creation_screen_enhanced.dart
   await AnalyticsService.logCharacterCreated(
     age: age,
     characterType: _characterType,
   );

   // In main_story.dart
   await AnalyticsService.logStoryCreated(
     theme: _selectedTheme,
     characterAge: _selectedCharacter!.age,
     usedFeelingsWheel: currentFeeling != null,
     storyMode: _learningToReadMode ? 'learning' : 'regular',
   );

   // In pre_story_feelings_dialog.dart
   await AnalyticsService.logFeelingSelected(
     coreEmotion: selectedFeeling.core,
     tertiaryEmotion: selectedFeeling.tertiary,
     intensity: intensity,
   );
   ```

**Deliverable:** Comprehensive analytics for product decisions

---

### **TASK 9: User-Facing Documentation** 📖
**Day:** 19
**Branch:** `codex/user-docs`
**Priority:** HIGH

**What to do:**
1. **Create amazing README.md:**
   ```markdown
   # Story Weaver - Personalized Therapeutic Stories for Children

   ## 🌟 What is Story Weaver?

   Story Weaver creates personalized, therapeutic stories that help children:
   - 🎭 Explore and understand their emotions
   - 🌈 Build emotional vocabulary (72+ feelings!)
   - 💪 Develop coping strategies
   - 📚 Enjoy age-appropriate content

   ## 📱 Features

   ### Emotional Check-Ins
   [Screenshot of feelings wheel]
   Choose from 72+ emotions organized by our comprehensive feelings wheel

   ### Personalized Characters
   [Screenshot of character creation]
   Create unique characters with personalities, interests, and challenges

   ### AI-Generated Stories
   [Screenshot of story]
   Get therapeutic stories tailored to your child's age and emotions

   ### Parent Tools
   [Screenshot of insights]
   Track emotional patterns and get conversation starters

   ## 🚀 Get Started in 3 Steps

   1. **Create a Character**
      - Choose appearance, personality, interests
      - Set their age for appropriate content

   2. **Pick a Feeling** (optional)
      - Explore the feelings wheel
      - Select what your child is experiencing

   3. **Get Your Story**
      - AI creates a personalized story
      - Read together and discuss

   ## 💎 Subscription Plans

   ### Free Tier
   - 3 stories per day
   - Basic feelings wheel
   - Character creation

   ### Premium ($9.99/month)
   - Unlimited stories
   - Full feelings wheel (72+ emotions)
   - Parent insights dashboard
   - Priority story generation
   - Offline access

   ## 📥 Download

   - [iOS App Store](#) - Coming soon
   - [Google Play](#) - Coming soon
   - [Web App](https://reliable-sherbet-2352c4.netlify.app)

   ## 🛟 Support

   Need help? Have questions?
   - Email: support@storyweaver.app
   - Twitter: @StoryWeaverApp
   - FAQ: [Link to FAQ]

   ## 🔐 Privacy & Security

   - Your data is encrypted
   - No third-party sharing
   - COPPA compliant
   - [Privacy Policy](#)

   ## 🎓 For Therapists

   Story Weaver is designed with therapeutic principles:
   - Emotion-focused coping strategies
   - Age-appropriate content
   - Feelings wheel based on emotion science
   - Measurable emotional tracking

   Contact us for bulk licensing: therapist@storyweaver.app

   ---

   Made with ❤️ for children's emotional wellbeing
   ```

2. **Take screenshots:**
   - Character creation screen
   - Feelings wheel interface
   - Generated story example
   - Insights dashboard
   - Mobile and desktop views

3. **Create simple FAQ:**
   ```markdown
   # Frequently Asked Questions

   ## General

   **Q: What age is this for?**
   A: Ages 3-16. Content adapts to your child's age.

   **Q: How does the AI work?**
   A: We use Google's Gemini AI to create stories based on your character and feelings.

   **Q: Is it safe?**
   A: Yes! All content is filtered for age-appropriateness.

   ## Technical

   **Q: Does it work offline?**
   A: Premium users can save stories for offline reading.

   **Q: What devices are supported?**
   A: iOS, Android, and web browsers.

   ## Billing

   **Q: Can I try before buying?**
   A: Yes! Free tier gives you 3 stories per day.

   **Q: Can I cancel anytime?**
   A: Yes, cancel from your account settings.
   ```

**Deliverable:** Professional user-facing documentation

---

### **TASK 10: Final QA & Bug Bash** 🐛
**Day:** 20
**Branch:** Work on `main` (fix bugs directly)
**Priority:** CRITICAL

**What to do:**
1. **Create testing checklist:**
   ```markdown
   ## Story Creation Flow
   - [ ] Create character (all types)
   - [ ] Generate regular story
   - [ ] Generate learning to read story
   - [ ] Generate interactive story
   - [ ] Skip feelings check-in
   - [ ] Use feelings wheel
   - [ ] Story displays correctly
   - [ ] Wisdom gem shows

   ## Offline Mode
   - [ ] Create story online
   - [ ] Go offline (airplane mode)
   - [ ] Stories still load
   - [ ] Sync indicator shows
   - [ ] Go back online
   - [ ] Sync works

   ## Paywall
   - [ ] Free tier: 3 stories work
   - [ ] 4th story shows paywall
   - [ ] Purchase subscription
   - [ ] Unlimited stories work
   - [ ] Restore purchases works

   ## Different Devices
   - [ ] iPhone (iOS)
   - [ ] Android phone
   - [ ] iPad
   - [ ] Web desktop
   - [ ] Web mobile

   ## Error Scenarios
   - [ ] No internet: friendly error
   - [ ] Slow connection: retry works
   - [ ] Backend error: doesn't crash
   - [ ] Invalid API key: clear message

   ## Accessibility
   - [ ] Large fonts work
   - [ ] Screen reader works
   - [ ] Color contrast good
   - [ ] Touch targets 44x44+
   ```

2. **Test on all platforms:**
   ```bash
   # iOS
   flutter run -d ios

   # Android
   flutter run -d android

   # Web
   flutter run -d chrome
   ```

3. **Performance profiling:**
   ```bash
   flutter run --profile
   # Use DevTools to find bottlenecks
   # Fix slow screens
   # Check for memory leaks
   ```

4. **Document all bugs found:**
   ```markdown
   ## Critical Bugs (Must fix before launch)
   - [ ] [Bug description]
   - [ ] [Bug description]

   ## High Priority (Should fix before launch)
   - [ ] [Bug description]

   ## Medium Priority (Can fix post-launch)
   - [ ] [Bug description]

   ## Known Issues (Document, fix later)
   - [ ] [Bug description]
   ```

5. **Fix all critical bugs immediately**

**Deliverable:** App is thoroughly tested and critical bugs are fixed

---

## 🗓️ Your Timeline at a Glance

| Task # | Days | Task | Priority |
|--------|------|------|----------|
| 1 | 3-4 | Frontend tests | CRITICAL |
| 2 | 9 | Backend resilience | HIGH |
| 3 | 15 | Build flavors | MEDIUM |
| 4 | 16 | Offline (Isar) | HIGH |
| 5 | 17 | Story result polish | MEDIUM |
| 6 | 17 | Onboarding | MEDIUM |
| 7 | 17 | UX polish | HIGH |
| 8 | 18 | Analytics | HIGH |
| 9 | 19 | User docs | HIGH |
| 10 | 20 | Final QA | CRITICAL |

**Total: 10 tasks across 8 work days**

---

## 💡 Tips for Success

### Branch Strategy:
```bash
# Start each task
git checkout main
git pull origin main
git checkout -b codex/[task-name]

# When done
git add .
git commit -m "[Feature] Brief description"
git push origin codex/[task-name]

# Let Claude review and merge
```

### Communication:
- Mark tasks complete when done
- Share any blockers immediately
- Ask Claude for help if stuck on Flutter/Dart

### Testing:
- Run `flutter test` before every commit
- Test on real devices, not just emulator
- Use `flutter analyze` to catch issues

---

## 🎯 Success Criteria

By Day 20, you will have:
- ✅ Comprehensive test suite (>70% coverage)
- ✅ Robust error handling with retries
- ✅ Offline-first functionality
- ✅ Professional UX polish
- ✅ Analytics tracking key metrics
- ✅ User-facing documentation
- ✅ Multi-environment support
- ✅ Zero critical bugs

**You've got this! Focus on user experience and quality - that's your strength! 🚀**
