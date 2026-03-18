# Avatar UI Testing Checklist

**Status**: App is loading on http://localhost:8080
**Mode**: Mock Mode (FREE instant avatars)
**Date**: 2025-12-29

---

## 🎯 What We're Testing

The avatar system has already been verified:
- ✅ Backend mock endpoint working (tested with curl)
- ✅ Backend real endpoint ready (Gemini → OpenRouter fallback)
- ⏳ Frontend UI integration (testing now)

---

## 📋 Step-by-Step Testing

### Step 1: Open the App (In Progress)

The app should open automatically in Chrome at:
**http://localhost:8080**

**What to check**:
- [ ] App loads without errors
- [ ] No red error screens
- [ ] Homepage displays properly

---

### Step 2: Find Avatar Creation UI

Based on the code (`lib/screens/wizard_steps/hero_creator_step.dart:519`), the avatar button is in the **Hero Creator** step of the story wizard.

**How to access**:
1. Click **"Create a Story"** or similar button on homepage
2. You should enter the **Story Wizard**
3. First step is **"Hero Creator"** (character creation)
4. Look for a button with:
   - 🎨 Face icon
   - Text: "Create Avatar" or "Generate Avatar"
   - Or: A circular button near character preview

**Location**: The button appears in the character details section below the character preview.

---

### Step 3: Open Avatar Creator

**Click the avatar button**

**Expected**: A full-screen overlay opens with:
- Title: "Create Your Magic Avatar"
- Close button (X) in top left
- Style selection chips (Pixar, Watercolor, Cartoon, Clay)
- Dropdown menus for:
  - Hair Style
  - Hair Color
  - Skin Tone
  - Outfit
- Optional hair details text field
- Two buttons at bottom:
  - "Generate in Background" (purple, recommended)
  - "Wait Here Instead" (outlined)

**If overlay doesn't open**:
- Check browser console (F12) for errors
- Look for JavaScript errors (red text)
- Note any error messages

---

### Step 4: Customize Avatar Settings

**Fill in the form**:
- **Style**: Select "Pixar" (or any style)
- **Hair Style**: Select any (e.g., "Long Curly")
- **Hair Color**: Select any (e.g., "Brown")
- **Skin Tone**: Select any (e.g., "Medium Tan")
- **Outfit**: Select any (e.g., "Explorer Jacket")
- **Hair Details**: (optional) Leave blank for now

**What to check**:
- [ ] All dropdowns work
- [ ] Style chips are clickable
- [ ] Form feels responsive
- [ ] No visual glitches

---

### Step 5: Generate Avatar (Mock Mode)

**Click**: "Wait Here Instead" (to see it happen)

**Expected behavior**:
1. Button becomes disabled
2. Loading spinner appears
3. Message: "Creating your magic portrait..."
4. **INSTANT** response (should take < 1 second in mock mode)
5. Avatar preview appears (300x300 image)
6. Image shows placeholder with:
   - Character initial and age
   - "MOCK" watermark
   - Colored background (based on style)

**What to check**:
- [ ] Loading state shows
- [ ] Avatar appears in < 2 seconds
- [ ] Image is visible (not broken)
- [ ] Shows placeholder (not real AI art)
- [ ] "That looks like me!" button appears

**If it takes > 5 seconds**:
- Something is wrong (might be calling real endpoint)
- Check browser Network tab (F12 → Network)
- Look for request to `/avatar/generate-avatar-mock`

---

### Step 6: Check Browser Console (CRITICAL)

**Press F12** to open Developer Tools

**Console Tab**:
Look for:
- ❌ Red errors (JavaScript errors)
- ⚠️ Yellow warnings
- 📡 Debug messages (should see "📡 Sending avatar generation request")

**Copy any errors you see**

**Network Tab**:
1. Click "Generate Avatar" again
2. Look for request to: `/avatar/generate-avatar-mock`
3. Check:
   - [ ] Status: 200 (green)
   - [ ] Response time: < 100ms
   - [ ] Response contains `image_base64`
   - [ ] Response has `is_mock: true`

---

### Step 7: Accept Avatar

**Click**: "That looks like me!" button

**Expected**:
- Overlay closes
- Character preview updates with avatar
- Character now has avatar assigned

**What to check**:
- [ ] Overlay closes smoothly
- [ ] Character shows avatar (in preview area)
- [ ] No errors in console

---

### Step 8: Test Re-Roll (Optional)

**Click avatar button again**

**Click**: "Try Another" button (if visible)

**Expected**:
- Generates new avatar
- Different placeholder (different color or style)
- Re-roll counter decrements

**What to check**:
- [ ] Re-roll works
- [ ] New avatar is different
- [ ] Limited to 3 re-rolls

---

### Step 9: Test Background Generation (Optional)

**Click avatar button again**

**Click**: "Generate in Background"

**Expected**:
- Overlay closes immediately
- You can continue with story creation
- Banner/notification appears when avatar is ready
- Avatar automatically applies when complete

**What to check**:
- [ ] Overlay closes right away
- [ ] Can continue using app
- [ ] Notification appears
- [ ] Avatar applies automatically

---

### Step 10: Complete Story Creation

**Continue through wizard**:
- Add any other story details
- Click "Create Story" or "Generate Story"

**What to check**:
- [ ] Avatar persists through wizard
- [ ] Avatar is saved with character
- [ ] No errors during story creation

---

### Step 11: Check Avatar in Story

**After story is created**:
- View the story result
- Look for character avatar display

**What to check**:
- [ ] Avatar shows in story screen
- [ ] Avatar persists in character library
- [ ] Avatar displays correctly

---

## 🐛 Common Issues to Check

### Issue 1: Avatar Button Not Found
**Symptom**: Can't find avatar creation button
**Possible causes**:
- Feature might be hidden
- Need to progress further in wizard
- Route not properly configured

**Check**:
- Look for face icon 🎨 or profile icon
- Check character creation section
- Try different wizard steps

---

### Issue 2: Slow Generation (> 5 seconds)
**Symptom**: Avatar takes forever to generate
**Cause**: Might be calling real endpoint instead of mock
**Fix**:
- Check `lib/services/avatar_generation_service.dart:27`
- Should call `/avatar/generate-avatar-mock`
- Not `/avatar/generate-avatar`

---

### Issue 3: Broken Image
**Symptom**: Avatar shows broken image icon
**Possible causes**:
- Backend not responding
- CORS issue
- Image data format problem

**Check**:
- Verify backend running: http://localhost:5000/health
- Check Network tab for 404 or 500 errors
- Look at response data format

---

### Issue 4: Console Errors
**Symptom**: Red errors in browser console
**Common errors**:
- CORS errors
- Network failed to fetch
- Undefined/null reference
- Type mismatch

**Action**: Copy full error message for debugging

---

## 📊 Test Results Template

```markdown
## Avatar UI Test Results

### ✅ What Works
- [ ] Avatar button accessible
- [ ] Overlay opens
- [ ] Form inputs work
- [ ] Avatar generates instantly (< 2s)
- [ ] Avatar displays correctly
- [ ] No console errors
- [ ] Background generation works

### ❌ Issues Found
1. [Describe issue]
   - Steps to reproduce
   - Error messages
   - Screenshots

### 🎨 User Experience
- Navigation: Easy / Confusing
- Form: Intuitive / Cluttered
- Speed: Instant / Slow
- Visual: Polished / Needs work

### 📷 Screenshots
- [Attach screenshots]

### 💡 Recommendations
- Deploy with avatars: YES / NO
- Fixes needed: [List]
- Priority: HIGH / MEDIUM / LOW
```

---

## 🎯 Success Criteria

**Avatar system is ready if**:
- ✅ Avatar button is easy to find
- ✅ Generation is instant in mock mode (< 2s)
- ✅ Avatar displays without errors
- ✅ No critical bugs in console
- ✅ User experience is smooth

**If ALL criteria met** → ✅ Ready to deploy with avatars!

**If issues found** → Document and decide: Fix or defer to v1.1

---

## 🔍 Debug Commands

```bash
# Check backend health
curl http://localhost:5000/health

# Verify mock mode
curl http://localhost:5000/usage/mock-mode

# Test avatar endpoint directly
curl -X POST http://localhost:5000/avatar/generate-avatar-mock \
  -H "Content-Type: application/json" \
  -d '{"character_name": "Test", "age": 8, "style": "pixar"}'
```

---

**Ready to test!** The app should be loaded by now. Start with Step 2! 🚀
