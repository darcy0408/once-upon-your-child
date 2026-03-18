# Character System Testing Checklist

**Date:** 2025-12-16
**Branch:** feature/library-ui-polish
**Tester:** Claude AI Assistant

---

## Pre-Test Setup

**Backend Status:** ✅ Running on localhost:5000
**Current Characters in DB:** 7 characters (Darcy x4, TestSibling, TestChar, d)

---

## Test 1: Character Selection UI in Wizard ⏳

**Objective:** Verify users can select existing characters in Step 1

### Steps:
1. Open wizard (should load to Step 1)
2. Look for "My Characters" / "Create New" toggle at top
3. Click "My Characters" tab
4. Verify horizontal scrolling list of 7 characters appears
5. Click on "TestSibling" (6 years old)
6. Verify:
   - ✅ Name field shows "TestSibling"
   - ✅ Age shows 6
   - ✅ Gold glow on selected card
   - ✅ Can click "Continue" button

**Status:** ⏳ PENDING
**Result:**
**Issues:**

---

## Test 2: Character Library Screen ⏳

**Objective:** Verify character library displays all characters correctly

### Steps:
1. From wizard, click people icon (👥) in top bar
2. Verify Character Library screen opens
3. Check grid displays 7 character cards
4. Verify each card shows:
   - Character emoji
   - Name
   - Age
   - Role
   - "Story" button
   - Delete icon
5. Try pull-to-refresh gesture

**Status:** ⏳ PENDING
**Result:**
**Issues:**

---

## Test 3: Delete Character ⏳

**Objective:** Verify character deletion works correctly

### Steps:
1. In Character Library, tap delete icon on character "d" (8 years)
2. Verify confirmation dialog appears
3. Click "Delete"
4. Verify:
   - ✅ Success snackbar appears
   - ✅ Character disappears from grid
   - ✅ Grid shows 6 characters now
5. Verify backend:
   ```bash
   curl http://localhost:5000/get-characters | grep '"name"' | wc -l
   # Should show 6 now
   ```

**Status:** ⏳ PENDING
**Result:**
**Issues:**

---

## Test 4: Create New Character & Auto-Save ⏳

**Objective:** Verify new characters are saved automatically when generating story

### Steps:
1. Click "New Character" FAB in library
2. In wizard Step 1, click "Create New" tab
3. Enter name: "TestHero"
4. Enter age: 9
5. Select archetype: "The Brave Adventurer"
6. Click Continue
7. Complete Step 2 (select any emotion)
8. Complete Step 3 (skip companions)
9. In Step 4, click "Make Magic"
10. Wait for story generation
11. After story generates, go back to Character Library
12. Verify "TestHero" (9 years) appears in grid
13. Verify backend:
    ```bash
    curl http://localhost:5000/get-characters | grep -A 2 "TestHero"
    # Should show TestHero with age 9
    ```

**Status:** ⏳ PENDING
**Result:**
**Issues:**

---

## Test 5: Create Story with Existing Character ⏳

**Objective:** Verify "Create Story" button in library works

### Steps:
1. In Character Library, click "Story" button on "TestSibling" card
2. Verify wizard opens
3. Verify Step 1 shows:
   - ✅ "My Characters" tab is selected
   - ✅ "TestSibling" card has gold glow
   - ✅ Name and age are pre-filled
4. Complete wizard and generate story
5. Verify story generates successfully

**Status:** ⏳ PENDING
**Result:**
**Issues:**

---

## Test 6: Add Existing Character as Sibling ⏳

**Objective:** Verify saved characters can be added as siblings

### Steps:
1. Open wizard, create new character "MainHero" (age 10)
2. Select archetype
3. Scroll down to "Friends & Siblings" section
4. Click the dropdown/popup menu icon (person with +)
5. Verify dropdown shows existing characters (TestSibling, TestChar, etc.)
6. Select "TestSibling"
7. Verify:
   - ✅ "TestSibling (Friend, 6)" chip appears
   - ✅ Can remove chip by clicking X

**Status:** ⏳ PENDING
**Result:**
**Issues:**

---

## Test 7: Siblings as Companions in Step 3 ⏳

**Objective:** Verify added siblings appear as companion options

### Steps:
1. Continue from Test 6 (MainHero with TestSibling as sibling)
2. Click Continue to Step 2
3. Complete Step 2
4. In Step 3 (Companion Selector), look for TestSibling
5. Verify:
   - ✅ TestSibling appears as a companion card
   - ✅ Has emoji (👶 or 🧒 based on age 6)
   - ✅ Can be selected/deselected
6. Select TestSibling as companion
7. Continue to Step 4 and generate story
8. Verify story includes both MainHero and TestSibling

**Status:** ⏳ PENDING
**Result:**
**Issues:**

---

## Test 8: Character with Pets ⏳

**Objective:** Verify pets are saved and loaded with characters

### Steps:
1. Create new character "PetLover" (age 8)
2. In Step 1, add a pet:
   - Click "Add Pet"
   - Name: "Fluffy"
   - Species: Cat
   - Personality: "Loves naps"
3. Verify pet chip appears
4. Complete wizard and generate story
5. Return to wizard, select "PetLover" from "My Characters"
6. Verify:
   - ✅ Pet "Fluffy" appears in pets section
   - ✅ Pet details are correct

**Status:** ⏳ PENDING
**Result:**
**Issues:**

---

## Test 9: Edge Case - Empty Character Library ⏳

**Objective:** Verify empty state displays correctly

### Steps:
1. Delete all characters from library (or use fresh database)
2. Verify empty state shows:
   - ✅ 📚 emoji
   - ✅ "No Characters Yet" message
   - ✅ "Create Character" button
3. Click "Create Character" button
4. Verify wizard opens

**Status:** ⏳ SKIPPED (would require deleting all test data)
**Result:**
**Issues:**

---

## Test 10: Toggle Between Create New and My Characters ⏳

**Objective:** Verify smooth switching between modes

### Steps:
1. Open wizard to Step 1
2. Select "My Characters" tab
3. Select a character
4. Switch to "Create New" tab
5. Verify:
   - ✅ Character selection clears
   - ✅ Archetype selection shows
   - ✅ Name field is empty
6. Switch back to "My Characters"
7. Verify character list still displays correctly

**Status:** ⏳ PENDING
**Result:**
**Issues:**

---

## Summary

**Total Tests:** 10
**Passed:** 0
**Failed:** 0
**Skipped:** 0
**In Progress:** 10

**Critical Issues Found:**
- None yet

**Minor Issues Found:**
- None yet

**Recommendation:**
⏳ Testing in progress...

---

## Notes

- Testing performed on Chrome web (flutter run -d chrome)
- Backend version: Development
- Database: SQLite (characters.db)
