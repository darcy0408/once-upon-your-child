# Browser Testing Guide for Pick-A-Path Adventures

## Overview

This guide explains how to run browser-based tests for Pick-A-Path Adventures. There are two approaches:

1. **Automated Integration Tests** - Flutter integration tests that run in Chrome
2. **Manual Browser Testing** - Start the app in Chrome for manual testing

## Option 1: Automated Integration Tests (Recommended)

### Prerequisites

1. **Start the backend server:**
   ```bash
   cd backend
   python app.py
   ```

2. **Ensure Flutter web is enabled:**
   ```bash
   flutter config --enable-web
   ```

### Running Integration Tests in Browser

```bash
# Run all Pick-A-Path E2E tests in Chrome
flutter test integration_test/pick_a_path_adventure_e2e_test.dart -d chrome

# Run with verbose output
flutter test integration_test/pick_a_path_adventure_e2e_test.dart -d chrome --verbose

# Run specific test
flutter test integration_test/pick_a_path_adventure_e2e_test.dart -d chrome --name "Complete wizard flow"
```

### What These Tests Do

The integration tests (`integration_test/pick_a_path_adventure_e2e_test.dart`) automatically:

- ✅ Launch the app in Chrome
- ✅ Navigate through the wizard
- ✅ Enable Interactive Mode
- ✅ Verify story loading
- ✅ Make choices and verify segments
- ✅ Check inventory and status sections
- ✅ Test error handling

### Test Coverage

- **F1-F5**: Wizard flow and Interactive Mode toggle
- **G1-G2**: Story loading and initial segment
- **G3-G4**: Inventory and Status sections
- **G5-G6**: Choice selection and next segment
- **G9-G10**: Story completion
- **H1-H2**: Different story lengths
- **I1-I2**: Error handling

## Option 2: Manual Browser Testing

### Start the App in Chrome

1. **Start backend:**
   ```bash
   cd backend
   python app.py
   ```

2. **Start Flutter app in Chrome:**
   ```bash
   flutter run -d chrome
   ```

3. **The app will open automatically in Chrome**

### Manual Test Checklist

Follow the test plan in `AGENT_2_FRONTEND_TESTING.md`:

1. **Test Suite F: Wizard Integration**
   - [ ] F1: Access wizard
   - [ ] F2: Complete Hero Creator
   - [ ] F3: Select Feelings
   - [ ] F4: Choose Companion
   - [ ] F5: Enable Interactive Mode

2. **Test Suite G: Pick-A-Path Screen**
   - [ ] G1: Story Loading
   - [ ] G2: Initial Segment
   - [ ] G3: Inventory Section
   - [ ] G4: Adventure Status
   - [ ] G5: Make First Choice
   - [ ] G6: Second Segment
   - [ ] G7: Inventory Updates
   - [ ] G8: Status Updates
   - [ ] G9: Story Completion
   - [ ] G10: Completion Screen
   - [ ] G11: Save to Library
   - [ ] G12: Library Display

3. **Test Suite H: Configurations**
   - [ ] H1: Medium Story (3 choices)
   - [ ] H2: Long Story (4 choices)
   - [ ] H3: Age 5 Content
   - [ ] H4: Age 14 Content

4. **Test Suite I: Error Handling**
   - [ ] I1: Network Error (Generation)
   - [ ] I2: Network Error (Choice)
   - [ ] I3: Minimal Data

5. **Test Suite J: UI/UX**
   - [ ] J1: Responsive Layout
   - [ ] J2: Scroll Behavior
   - [ ] J3: Loading States
   - [ ] J4: Haptic Feedback (mobile only)

6. **Test Suite K: Persistence**
   - [ ] K1: Resume Story
   - [ ] K2: Offline Mode

### Taking Screenshots

While testing manually, take screenshots for documentation:

1. Press `F12` to open Chrome DevTools
2. Use the screenshot tool or press `Ctrl+Shift+P` → "Capture screenshot"
3. Save screenshots to `screenshots/` directory

## Option 3: Using Playwright (Advanced)

For more advanced browser automation, you can use Playwright:

### Setup

```bash
# Install Playwright
npm install -g playwright
playwright install chromium

# Or use Python
pip install playwright pytest-playwright
playwright install chromium
```

### Example Test

```python
from playwright.sync_api import sync_playwright

def test_pick_a_path_adventure():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False)
        page = browser.new_page()
        
        # Navigate to app
        page.goto('http://localhost:8080')
        
        # Find and click wizard button
        page.click('text=Create Story')
        
        # Fill character name
        page.fill('input[placeholder*="name"]', 'TestHero')
        
        # Enable Interactive Mode
        page.click('text=Interactive Mode')
        
        # Click Make Magic
        page.click('text=Make Magic')
        
        # Wait for story to load
        page.wait_for_selector('text=Segment 1')
        
        # Take screenshot
        page.screenshot(path='pick_a_path_loaded.png')
        
        browser.close()
```

## Troubleshooting

### Chrome doesn't open

```bash
# Check if Chrome is available
flutter devices

# If Chrome isn't listed, enable web support
flutter config --enable-web
flutter create --platforms=web .
```

### Tests fail with network errors

- Ensure backend is running on `http://localhost:5000`
- Check that `Environment.backendUrl` is set correctly
- Verify mock client is set up in tests

### App doesn't load

- Check browser console (F12) for errors
- Verify Flutter web compilation succeeded
- Try clearing browser cache

## Next Steps

1. **Run automated tests:**
   ```bash
   flutter test integration_test/pick_a_path_adventure_e2e_test.dart -d chrome
   ```

2. **Review test results** and fix any failures

3. **Run manual tests** for UI/UX polish (Test Suite J)

4. **Document results** in `FRONTEND_TEST_RESULTS.md`

## See Also

- `AGENT_2_FRONTEND_TESTING.md` - Detailed manual testing instructions
- `PICK_A_PATH_TESTING_PLAN.md` - Complete test plan
- `test/README_PICK_A_PATH_TESTS.md` - Unit test documentation



