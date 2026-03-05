# Avatar System Debug Instructions

## How to Test and Get Debug Output

### Step 1: Run the App
```bash
flutter run -d chrome
```

### Step 2: Open DevTools Console
1. In Chrome, press **F12** or **Ctrl+Shift+I** to open Developer Tools
2. Click on the **Console** tab
3. Keep it open while testing

### Step 3: Navigate to Character Creation
1. In your app, click the button to create a new character
2. You should see the character creation form

### Step 4: Look for the "Customize Avataaars" Button
**Important:** Look carefully in the avatar customization section
- It should be a **TEAL/CYAN colored button**
- Text should say either:
  - "Customize Avataaars" (if no avatar customized yet)
  - "Edit Avataaars" (if avatar already customized)
- It should be **next to** the "AI Avatar" button (purple)

**Question:** Do you see this button? (Yes/No)

### Step 5: Click the Button
If you see the button, click it.

**Watch the Console** - You should see output like:
```
[Character Creation] Opening Avataaars Picker...
[Character Creation] Initializing avatar service...
[Character Creation] Avatar service initialized successfully
[Character Creation] Character age: 8
[Character Creation] Navigating to Avatar Picker Screen...
```

### Step 6: Check What Happens Next

**Scenario A: New Screen Opens**
- Avatar Picker screen should open
- You should see a preview area at the top
- Below that, expandable sections for customization options

**Watch the Console** - You should see:
```
[Avatar Picker] Fetching preview with selections: {}
[Avatar Picker] Received SVG: <svg ...
```

**Scenario B: Error Message**
If you see a red snackbar with an error, copy the error message

**Scenario C: Nothing Happens**
Button click doesn't do anything - check console for errors

### Step 7: Report Back

Please tell me:
1. **Did you see the "Customize Avataaars" button?** (Yes/No)
2. **What happened when you clicked it?**
   - New screen opened
   - Error message appeared
   - Nothing happened
3. **Console output** - Copy and paste what you see in the console

---

## If Button Doesn't Appear

The button might not be visible because:
1. You're using a different character creation screen
2. The UI layout is different
3. Need to scroll down to see it

**Try this:**
- Scroll down in the character creation form
- Look in the "Avatar" or "Appearance" section
- Take a screenshot and describe what you see

---

## Quick Visual Guide

The button layout should look like this:

```
┌─────────────────────────────────┐
│   [Avatar Preview Area]         │
│                                 │
│  ┌──────────┐  ┌──────────────┐│
│  │AI Avatar │  │Customize     ││
│  │ (Purple) │  │Avataaars     ││
│  │          │  │(Teal/Cyan)   ││
│  └──────────┘  └──────────────┘│
└─────────────────────────────────┘
```

If you don't see this layout, please describe what you DO see in the avatar/appearance section.
