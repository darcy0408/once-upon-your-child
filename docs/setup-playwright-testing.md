# Setup Playwright for Automated UI Testing

## Option 1: Playwright with Python (Easiest for Windows)

### Install Playwright:
```bash
pip install playwright pytest-playwright
playwright install chromium
```

### Create test file: `test_character_system.py`

```python
import pytest
from playwright.sync_api import Page, expect

def test_character_library_loads(page: Page):
    """Test that character library opens and displays characters"""
    # Navigate to wizard
    page.goto("http://localhost:8080")

    # Wait for wizard to load
    page.wait_for_selector("text=Create a Character", timeout=30000)

    # Click character library icon
    page.click('[aria-label="My Characters"]')  # Adjust selector

    # Verify library opened
    expect(page.locator("text=My Characters")).to_be_visible()

    # Count character cards
    cards = page.locator('[data-testid="character-card"]')
    expect(cards).to_have_count(7)

    # Take screenshot for Claude to analyze
    page.screenshot(path="character-library.png")

def test_character_selection(page: Page):
    """Test selecting existing character in wizard"""
    page.goto("http://localhost:8080")

    # Wait for wizard
    page.wait_for_selector("text=Create a Character")

    # Click "My Characters" tab
    page.click("text=My Characters")

    # Select first character
    page.click('[data-testid="character-card"]:first-child')

    # Verify gold glow (check CSS class)
    selected = page.locator('[data-testid="character-card"]:first-child')
    expect(selected).to_have_class(regex=r'.*selected.*')

    # Verify name populated
    name_field = page.locator('input[placeholder*="Hero Name"]')
    expect(name_field).not_to_be_empty()

    page.screenshot(path="character-selected.png")

def test_create_and_save_character(page: Page):
    """Test creating new character and auto-save"""
    page.goto("http://localhost:8080")

    # Click Create New tab
    page.click("text=Create New")

    # Fill character details
    page.fill('input[placeholder*="Hero Name"]', "TestHero")
    page.fill('input[type="number"]', "9")

    # Select archetype
    page.click("text=The Brave Adventurer")

    # Continue through steps
    page.click("text=Continue")
    page.click("text=Continue")
    page.click("text=Continue")

    # Generate story
    page.click("text=Make Magic")

    # Wait for story generation (may take time)
    page.wait_for_selector("text=My Magical Story", timeout=60000)

    # Verify character was saved (check via API)
    page.screenshot(path="story-generated.png")

def test_delete_character(page: Page):
    """Test deleting character from library"""
    page.goto("http://localhost:8080")

    # Open library
    page.click('[aria-label="My Characters"]')

    # Click delete on first character
    page.click('[data-testid="character-card"]:first-child [aria-label="Delete"]')

    # Confirm deletion
    page.click("text=Delete")

    # Verify snackbar
    expect(page.locator("text=deleted")).to_be_visible()

    # Verify character removed
    cards = page.locator('[data-testid="character-card"]')
    expect(cards).to_have_count(6)

    page.screenshot(path="character-deleted.png")

# Run tests
# pytest test_character_system.py --headed --slowmo=1000
```

### Run Tests:
```bash
# Run tests and see browser
pytest test_character_system.py --headed --slowmo=1000

# Run headless and fast
pytest test_character_system.py

# Run specific test
pytest test_character_system.py::test_character_library_loads
```

---

## Option 2: Playwright with Node.js

### Install:
```bash
npm install -D @playwright/test
npx playwright install chromium
```

### Create test file: `tests/character-system.spec.ts`

```typescript
import { test, expect } from '@playwright/test';

test('character library displays all characters', async ({ page }) => {
  await page.goto('http://localhost:8080');

  // Wait for wizard
  await page.waitForSelector('text=Create a Character');

  // Open character library
  await page.click('[aria-label="My Characters"]');

  // Verify library loaded
  await expect(page.locator('text=My Characters')).toBeVisible();

  // Count characters
  const cards = page.locator('[data-testid="character-card"]');
  await expect(cards).toHaveCount(7);

  // Take screenshot
  await page.screenshot({ path: 'character-library.png' });
});

test('can select existing character', async ({ page }) => {
  await page.goto('http://localhost:8080');
  await page.click('text=My Characters');

  // Click first character
  await page.click('[data-testid="character-card"]:first-child');

  // Verify selection
  const selected = page.locator('[data-testid="character-card"]:first-child');
  await expect(selected).toHaveClass(/selected/);

  await page.screenshot({ path: 'character-selected.png' });
});
```

### Run:
```bash
npx playwright test
npx playwright test --headed --slowmo=1000
```

---

## Option 3: Flutter Integration Tests (Native)

### Create: `integration_test/character_system_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:story_weaver_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Character System Tests', () {
    testWidgets('Character library displays characters', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to library
      await tester.tap(find.byIcon(Icons.people));
      await tester.pumpAndSettle();

      // Verify characters loaded
      expect(find.text('My Characters'), findsOneWidget);

      // Count character cards
      expect(find.byType(CharacterCard), findsNWidgets(7));
    });

    testWidgets('Can select existing character', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Tap "My Characters" tab
      await tester.tap(find.text('My Characters'));
      await tester.pumpAndSettle();

      // Tap first character
      await tester.tap(find.byType(CharacterCard).first);
      await tester.pumpAndSettle();

      // Verify name populated
      expect(find.text('TestSibling'), findsOneWidget);
    });
  });
}
```

### Run:
```bash
flutter test integration_test/character_system_test.dart
```

---

## Option 4: Selenium + Python (Traditional)

```bash
pip install selenium webdriver-manager
```

```python
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

driver = webdriver.Chrome()
driver.get("http://localhost:8080")

# Wait for wizard
wait = WebDriverWait(driver, 10)
wait.until(EC.presence_of_element_located((By.XPATH, "//text()[contains(.,'Create a Character')]")))

# Take screenshot
driver.save_screenshot("wizard-loaded.png")

driver.quit()
```

---

## 🎯 My Recommendation:

**For immediate testing: Install Playwright + Python**

```bash
pip install playwright pytest-playwright
playwright install chromium
```

Then I can:
1. Write automated test scripts
2. Run them for you
3. Analyze screenshots
4. Report detailed results

**Want me to set this up now?** I can:
- Install Playwright
- Write comprehensive test suite
- Run all tests
- Give you detailed pass/fail report

Just say "yes, set up Playwright" and I'll do it! 🚀
