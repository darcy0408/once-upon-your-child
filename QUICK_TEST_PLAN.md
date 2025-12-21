# 10-Minute Quick Test Plan

**App URL:** http://localhost:8080
**Backend:** http://localhost:5000

---

## ✅ Test 1: Character Selection UI (2 min)

**What to do:**
1. Open http://localhost:8080
2. You should see wizard Step 1
3. Look for "My Characters" / "Create New" toggle at top
4. Click "My Characters" tab
5. Should see 7 character cards in horizontal scroll
6. Click on any character (e.g., "TestSibling")
7. Verify gold glow and name/age populate

**Expected Result:**
- Toggle appears (if 7 characters loaded ✅)
- Cards display with emoji, name, age
- Selection works with gold glow

---

## ✅ Test 2: Character Library (2 min)

**What to do:**
1. Click the people icon (👥) in top bar of wizard
2. Character Library screen should open
3. Should see grid of 7 character cards
4. Each card should have:
   - Emoji
   - Name
   - Age & Role
   - "Story" button
   - Delete icon

**Expected Result:**
- Library displays all 7 characters
- Grid layout looks good
- Navigation works

---

## ✅ Test 3: Delete Character (1 min)

**What to do:**
1. In library, tap delete icon on character "d" (8 years)
2. Confirm deletion
3. Should see success message
4. Character should disappear
5. Grid should show 6 characters now

**Backend Verification:**
After deleting, I'll check: `curl http://localhost:5000/get-characters` should show 6 characters

---

## ✅ Test 4: Create Story from Library (2 min)

**What to do:**
1. In library, click "Story" button on "TestSibling"
2. Wizard should open with TestSibling pre-selected
3. Complete wizard quickly (select any options)
4. Click "Make Magic"
5. Story should generate

**Expected Result:**
- Pre-selection works
- Story generates successfully
- No errors

---

## ✅ Test 5: Create New Character & Auto-Save (3 min)

**What to do:**
1. From library, click "New Character" button (FAB)
2. Click "Create New" tab
3. Enter name: "TestHero"
4. Age: 9
5. Select archetype: "The Brave Adventurer"
6. Continue through all steps
7. Generate story
8. Return to library

**Expected Result:**
- Character saves after story generation
- "TestHero" appears in library
- Backend has the new character

**Backend Verification:**
After story generation, I'll check for "TestHero" in database

---

## 🚀 Quick Verification Commands

**After each test, you can verify backend state:**

```bash
# Count characters
curl -s http://localhost:5000/get-characters | grep -c '"name"'

# List character names
curl -s http://localhost:5000/get-characters | grep '"name"' | cut -d'"' -f4

# Check specific character
curl -s http://localhost:5000/get-characters | grep -A 5 "TestHero"
```

---

## 🎯 Critical Success Criteria

**PASS if:**
- ✅ Character selection toggle appears
- ✅ Selecting character loads their data
- ✅ Character library displays all characters
- ✅ Delete removes character from DB
- ✅ New character auto-saves after story
- ✅ No critical errors in console

**FAIL if:**
- ❌ App crashes
- ❌ Characters don't load
- ❌ Features don't work at all
- ❌ Data corruption

---

## Ready to Test!

**Start here:** http://localhost:8080

**Run through Tests 1-5 above (10 minutes total)**

**Report back:**
- Which tests passed ✅
- Which failed ❌
- Any issues found 🐛

Then I'll verify backend state and we'll decide if ready to merge!
