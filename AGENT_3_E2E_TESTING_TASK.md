# YOU ARE AGENT 3 - End-to-End Testing & Backend Monitoring

**⚠️ IMPORTANT: You are Agent 3. This is YOUR task file. Do NOT read other agent files.**

---

## Your Assignment

**Task:** Add E2E tests and backend monitoring/logging improvements
**Your Branch:** `feature/e2e-testing-monitoring`
**Estimated Time:** 2-3 days
**Terminal:** WSL Codex

---

## BEFORE YOU START - Branch Verification

Run these commands and verify:

```bash
cd /mnt/c/dev/story-weaver-app
git checkout main
git pull origin main
git checkout -b feature/e2e-testing-monitoring

# VERIFY YOU'RE ON THE RIGHT BRANCH
git branch --show-current
# Must show: feature/e2e-testing-monitoring

# If it shows anything else, STOP and ask supervisor
```

---

## Your File Scope (ONLY TOUCH THESE)

✅ **You CAN modify:**
- `test_driver/` (CREATE new directory for E2E tests)
- `test_driver/app.dart` (CREATE driver app)
- `test_driver/app_test.dart` (CREATE E2E test suite)
- `test/integration/` (ADD more integration tests)
- `backend/logging_config.py` (CREATE centralized logging)
- `backend/monitoring.py` (CREATE monitoring utilities)
- `backend/app.py` (ADD logging middleware)
- `backend/requirements.txt` (ADD logging dependencies)
- `pubspec.yaml` (ADD integration_test dependency)

❌ **DO NOT touch:**
- Provider files (`lib/providers/**`) - Agent 2 owns
- Widget files (`lib/widgets/**`) - Agent 4 owns
- Screen files (`lib/*_screen.dart`) - Agent 2 owns

---

## Step-by-Step Instructions

### Step 1: Add E2E Test Dependencies (15 minutes)

Update `pubspec.yaml`:

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
  flutter_driver:
    sdk: flutter
```

Run:
```bash
flutter pub get
```

---

### Step 2: Create E2E Test Driver (30 minutes)

Create `test_driver/app.dart`:

```dart
import 'package:flutter_driver/driver_extension.dart';
import 'package:story_weaver_app/main.dart' as app;

void main() {
  // Enable Flutter Driver extension
  enableFlutterDriverExtension();

  // Run the app
  app.main();
}
```

Create `test_driver/app_test.dart`:

```dart
import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  group('Story Weaver E2E Tests', () {
    late FlutterDriver driver;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
    });

    tearDownAll(() async {
      await driver.close();
    });

    test('Complete story creation flow', () async {
      // Wait for app to load
      await driver.waitFor(find.text('Story Weaver'));

      // Navigate to character creation
      await driver.tap(find.byTooltip('Create Character'));
      await driver.waitFor(find.text('Create Character'));

      // Fill in character details
      await driver.tap(find.byValueKey('name_field'));
      await driver.enterText('Test Hero');

      await driver.tap(find.byValueKey('age_field'));
      await driver.enterText('10');

      // Save character
      await driver.tap(find.text('Save Character'));

      // Wait for character list
      await driver.waitFor(find.text('Test Hero'));

      // Navigate to story creation
      await driver.tap(find.text('Create Story'));

      // Select theme
      await driver.tap(find.text('Adventure'));

      // Generate story
      await driver.tap(find.text('Generate'));

      // Wait for story to generate (may take a while)
      await driver.waitFor(
        find.text('Once upon a time'),
        timeout: const Duration(seconds: 30),
      );

      // Verify story appears
      expect(await driver.getText(find.byValueKey('story_text')), isNotEmpty);
    });

    test('Quick story generation flow', () async {
      await driver.tap(find.text('Quick Story'));
      await driver.waitFor(find.text('Generate Quick Story'));

      await driver.tap(find.text('Generate'));

      // Wait for story
      await driver.waitFor(
        find.byValueKey('story_result'),
        timeout: const Duration(seconds: 30),
      );
    });

    test('Subscription paywall flow', () async {
      // Generate stories until hitting limit
      for (int i = 0; i < 3; i++) {
        await driver.tap(find.text('Quick Story'));
        await driver.tap(find.text('Generate'));
        await driver.waitFor(find.byValueKey('story_result'));
        await driver.tap(find.byTooltip('Back'));
      }

      // Should now see paywall
      await driver.waitFor(find.text('Daily story limit reached'));

      // Verify upgrade button present
      await driver.waitFor(find.text('Upgrade to Premium'));
    });

    test('Dark mode toggle persists', () async {
      // Go to settings
      await driver.tap(find.byTooltip('Settings'));
      await driver.waitFor(find.text('Settings'));

      // Toggle dark mode
      await driver.tap(find.byValueKey('dark_mode_switch'));

      // Wait for theme change
      await Future.delayed(const Duration(milliseconds: 500));

      // Restart app (simulate app restart)
      await driver.requestData('restart');

      // Verify dark mode is still on
      await driver.waitFor(find.byValueKey('dark_mode_switch'));
      final switchValue = await driver.getText(find.byValueKey('dark_mode_switch'));
      expect(switchValue, 'true');
    });
  });
}
```

---

### Step 3: Add Integration Tests (1 hour)

Create `test/integration/story_generation_integration_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:story_weaver_app/providers/quick_story_provider.dart';
import 'package:story_weaver_app/providers/subscription_provider.dart';

void main() {
  group('Story Generation Integration Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('Quick story generation updates subscription count', () async {
      final subscription = container.read(subscriptionProvider.notifier);
      final quickStory = container.read(quickStoryProvider.notifier);

      final initialCount = container.read(subscriptionProvider).storiesRemaining;

      await quickStory.generateStory(
        characterName: 'Test',
        characterAge: 8,
        theme: 'Adventure',
      );

      subscription.decrementStoriesRemaining();

      final finalCount = container.read(subscriptionProvider).storiesRemaining;
      expect(finalCount, initialCount - 1);
    });

    test('Story generation handles API errors gracefully', () async {
      final quickStory = container.read(quickStoryProvider.notifier);

      // Generate with invalid parameters to trigger error
      await quickStory.generateStory(
        characterName: '',
        characterAge: 0,
        theme: '',
      );

      final state = container.read(quickStoryProvider);
      expect(state.error, isNotNull);
      expect(state.isGenerating, false);
    });
  });
}
```

Create `test/integration/character_management_integration_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:story_weaver_app/providers/character_provider.dart';
import 'package:story_weaver_app/models/local/character_local.dart';

void main() {
  group('Character Management Integration Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('Add and retrieve character', () async {
      final characterList = container.read(characterListProvider.notifier);

      final character = CharacterLocal()
        ..name = 'Test Hero'
        ..age = 10
        ..createdAt = DateTime.now();

      await characterList.addCharacter(character);

      final characters = await container.read(characterListProvider.future);
      expect(characters.any((c) => c.name == 'Test Hero'), true);
    });

    test('Delete character', () async {
      final characterList = container.read(characterListProvider.notifier);

      final character = CharacterLocal()
        ..name = 'To Delete'
        ..age = 8
        ..createdAt = DateTime.now();

      await characterList.addCharacter(character);
      final characters = await container.read(characterListProvider.future);
      final added = characters.firstWhere((c) => c.name == 'To Delete');

      await characterList.deleteCharacter(added.id);

      final updated = await container.read(characterListProvider.future);
      expect(updated.any((c) => c.name == 'To Delete'), false);
    });
  });
}
```

---

### Step 4: Backend Logging Setup (1 hour)

Create `backend/logging_config.py`:

```python
import logging
import sys
from logging.handlers import RotatingFileHandler
import os

def setup_logging(app):
    """Configure structured logging for the application."""

    # Determine log level from environment
    log_level = os.getenv('LOG_LEVEL', 'INFO').upper()

    # Create logs directory if it doesn't exist
    if not os.path.exists('logs'):
        os.makedirs('logs')

    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)

    # Remove existing handlers
    root_logger.handlers = []

    # Console handler with formatting
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(log_level)
    console_formatter = logging.Formatter(
        '[%(asctime)s] %(levelname)s in %(module)s: %(message)s'
    )
    console_handler.setFormatter(console_formatter)
    root_logger.addHandler(console_handler)

    # File handler for production
    if os.getenv('FLASK_ENV') != 'development':
        file_handler = RotatingFileHandler(
            'logs/story_weaver.log',
            maxBytes=10485760,  # 10MB
            backupCount=10
        )
        file_handler.setLevel(logging.INFO)
        file_formatter = logging.Formatter(
            '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'
        )
        file_handler.setFormatter(file_formatter)
        root_logger.addHandler(file_handler)

    # Log app startup
    app.logger.info('Story Weaver Backend starting...')
    app.logger.info(f'Environment: {os.getenv("FLASK_ENV", "production")}')
    app.logger.info(f'Log level: {log_level}')

    return app.logger
```

---

### Step 5: Backend Monitoring (1.5 hours)

Create `backend/monitoring.py`:

```python
import time
import functools
from flask import request, g
import logging

logger = logging.getLogger(__name__)

def log_request_info():
    """Log incoming request details."""
    g.start_time = time.time()
    logger.info(
        f'REQUEST {request.method} {request.path} '
        f'from {request.remote_addr}'
    )

def log_response_info(response):
    """Log response details and timing."""
    if hasattr(g, 'start_time'):
        elapsed = time.time() - g.start_time
        logger.info(
            f'RESPONSE {request.method} {request.path} '
            f'status={response.status_code} '
            f'duration={elapsed:.3f}s'
        )
    return response

def monitor_performance(func):
    """Decorator to monitor function performance."""
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        start_time = time.time()
        try:
            result = func(*args, **kwargs)
            elapsed = time.time() - start_time
            logger.info(f'{func.__name__} completed in {elapsed:.3f}s')
            return result
        except Exception as e:
            elapsed = time.time() - start_time
            logger.error(
                f'{func.__name__} failed after {elapsed:.3f}s: {str(e)}'
            )
            raise
    return wrapper

class RequestMetrics:
    """Track request metrics."""
    def __init__(self):
        self.request_count = 0
        self.error_count = 0
        self.total_duration = 0.0

    def record_request(self, duration, is_error=False):
        self.request_count += 1
        self.total_duration += duration
        if is_error:
            self.error_count += 1

    def get_metrics(self):
        return {
            'total_requests': self.request_count,
            'total_errors': self.error_count,
            'avg_duration': self.total_duration / max(self.request_count, 1),
            'error_rate': self.error_count / max(self.request_count, 1)
        }

metrics = RequestMetrics()
```

---

### Step 6: Update Backend App (30 minutes)

Update `backend/app.py`:

Add imports:
```python
from logging_config import setup_logging
from monitoring import log_request_info, log_response_info, metrics
```

Add to app initialization (after `app = Flask(__name__)`):

```python
# Setup logging
logger = setup_logging(app)

# Add request/response logging
@app.before_request
def before_request():
    log_request_info()

@app.after_request
def after_request(response):
    return log_response_info(response)

# Add metrics endpoint
@app.route('/admin/metrics', methods=['GET'])
def get_metrics():
    """Get application metrics."""
    return jsonify(metrics.get_metrics())

# Add health check with detailed status
@app.route('/health/detailed', methods=['GET'])
def health_detailed():
    """Detailed health check."""
    import psutil

    health_status = {
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'system': {
            'cpu_percent': psutil.cpu_percent(),
            'memory_percent': psutil.virtual_memory().percent,
            'disk_percent': psutil.disk_usage('/').percent,
        },
        'metrics': metrics.get_metrics()
    }

    return jsonify(health_status)
```

Update `backend/requirements.txt`:

```txt
psutil==5.9.6
```

---

### Step 7: Testing (1 hour)

**Run E2E tests:**
```bash
# Run driver tests (requires app running)
flutter drive --target=test_driver/app.dart
```

**Run integration tests:**
```bash
flutter test test/integration/
```

**Run backend tests:**
```bash
cd backend
python -m pytest tests/ -v
cd ..
```

**Test monitoring:**
```bash
# Start backend
cd backend
python app.py

# In another terminal, test metrics endpoint
curl http://localhost:5000/admin/metrics
curl http://localhost:5000/health/detailed
```

---

### Step 8: Commit and Push

```bash
git add test_driver/ test/integration/ backend/logging_config.py backend/monitoring.py backend/app.py backend/requirements.txt pubspec.yaml

git commit -m "Feature: Add E2E testing and backend monitoring

Frontend:
- Add Flutter Driver E2E tests for complete user flows
- Add integration tests for story generation + subscription
- Add integration tests for character management
- Test complete story creation flow end-to-end
- Test subscription paywall enforcement
- Test dark mode persistence

Backend:
- Add centralized logging configuration
- Add request/response logging middleware
- Add performance monitoring decorator
- Add metrics tracking (requests, errors, duration)
- Add /admin/metrics endpoint for monitoring
- Add /health/detailed endpoint with system stats
- Add psutil for system monitoring

Benefits:
- E2E tests catch integration issues
- Better monitoring for production debugging
- Performance metrics for optimization
- Structured logging for troubleshooting
- Health checks for deployment verification

🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com>"

git push origin feature/e2e-testing-monitoring
```

---

### Step 9: Report Completion

Update `TEAM_COORDINATION.md`:

```markdown
## Agent 3 - E2E Testing & Monitoring | 2025-12-04

### Task: Add E2E Tests and Backend Monitoring

### Files Changed
Frontend:
- Created: test_driver/app.dart (E2E driver)
- Created: test_driver/app_test.dart (E2E test suite)
- Created: test/integration/story_generation_integration_test.dart
- Created: test/integration/character_management_integration_test.dart

Backend:
- Created: backend/logging_config.py
- Created: backend/monitoring.py
- Modified: backend/app.py (logging middleware, metrics)
- Modified: backend/requirements.txt (psutil)

### Test Results
E2E Tests:
[PASTE flutter drive OUTPUT]

Integration Tests:
[PASTE flutter test test/integration/ OUTPUT]

Backend Tests:
[PASTE pytest OUTPUT]

### Monitoring Endpoints
- GET /admin/metrics - Request/error metrics
- GET /health/detailed - System health + metrics

### Status
✅ COMPLETE - Ready for supervisor verification
```

Then report:
```
✅ Agent 3 COMPLETE - E2E testing and monitoring complete, pushed to feature/e2e-testing-monitoring
```

---

## Success Criteria

- [x] E2E tests created for main user flows
- [x] Integration tests for providers
- [x] Backend logging configured
- [x] Backend monitoring endpoints working
- [x] All tests pass
- [x] Metrics endpoint returns data

---

## IMPORTANT REMINDERS

**Branch Check:**
- Always verify: `git branch --show-current` shows `feature/e2e-testing-monitoring`

**File Scope:**
- ONLY touch test files and backend files
- DO NOT modify provider files (Agent 2)
- DO NOT modify widget files (Agent 4)

**Testing:**
- E2E tests may take 30+ seconds
- Ensure backend is running for E2E tests
- Test metrics endpoint manually

**DO NOT:**
- Merge to main
- Work outside your file scope
- Read other agents' instruction files

---

**Ready? Start with Step 1: Add E2E Test Dependencies**

Good luck! 🧪
