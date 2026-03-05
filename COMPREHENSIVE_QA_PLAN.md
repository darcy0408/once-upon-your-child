# Comprehensive QA & Testing Plan 2026

**App:** Story Weaver
**Version:** 1.0.2 (Pre-Launch)
**Date:** January 28, 2026
**Objective:** Verify functional correctness, content quality, and age-appropriateness across all story permutations before public launch.

---

## 1. Test Matrix (Permutations)

This matrix defines the core variables to test. We aim for representative coverage rather than checking every single combination (which would be thousands).

| Variable | Values to Test | Notes |
| :--- | :--- | :--- |
| **Age Group** | 4, 7, 9, 12, 15 | Covers Toddler, Early Reader, Middle Grade, Tween, Teen. |
| **Gender** | Boy, Girl | Check pronoun consistency (he/she). |
| **Story Mode** | Regular, Rhyme Time, Learn to Read, Pick-a-Path | The 4 core engines. |
| **Story Length** | Short, Medium, Long | Check word count constraints. |
| **Companions** | None, Pet (Dragon), Friend (Wizard) | Check "Companion Contract" (must appear/help). |
| **Custom Elements** | None, "I want a purple tree" | Check verbatim inclusion. |
| **Illustrations** | Off, On | Check presence/absence and style match. |

---

## 2. Manual Test Cases (The "Magic Check")

These high-level flows validate the end-to-end user experience.

### ✅ Test Case A: The "First Time User" Flow
1.  **Launch App:** Clear storage/fresh install.
2.  **Wizard Step 1 (Hero):** Create "Leo" (Age 7, Boy). Select "Explorer" style.
    *   *Check:* Avatar generates (OpenRouter fallback if Gemini fails).
3.  **Wizard Step 2 (Feelings):** Select "Excited" -> "To Explore".
    *   *Check:* Feelings Wheel UI works (Progressive replacement).
4.  **Wizard Step 3 (Companions):** Select "Sparky the Dragon".
5.  **Wizard Step 4 (Magic):** Enable "Illustrations".
6.  **Generate:** "Regular Story" (Standard length).
    *   *Check:* Story generates (~700 words).
    *   *Check:* Illustration appears at top.
    *   *Check:* Sparky is in the story and image.
    *   *Check:* "Leo" is the hero.
7.  **Restart:** Refresh page / Restart app.
    *   *Check:* "Leo" is saved in "Pick an Existing Hero".

### ✅ Test Case B: The "Little Reader" Flow (Age 4)
1.  **Select Hero:** Create "Mia" (Age 4).
2.  **Mode:** "Learn to Read".
3.  **Generate:**
    *   *Check:* Text is very simple (CVC words: cat, hat, run).
    *   *Check:* Short sentences (1 per line).
    *   *Check:* Repetitive structure.
    *   *Check:* No scary content.

### ✅ Test Case C: The "Pick-a-Path" Adventure (Age 10)
1.  **Select Hero:** Create "Sam" (Age 10).
2.  **Mode:** "Pick-a-Path".
3.  **Generate:**
    *   *Check:* Opening segment has ~2 choices.
    *   *Check:* Choices are "Action-oriented" (e.g., "Open the door" vs "Run away").
    *   *Check:* Making a choice loads the *next* segment correctly.
    *   *Check:* Story state (inventory/health) persists (if visible).

### ✅ Test Case D: The "Custom Wish" Flow
1.  **Select Hero:** Any.
2.  **Wizard Step 4:** Enter "I want to meet a talking toaster" in "Your Story Ideas".
3.  **Generate:** Regular Story.
    *   *Check:* The story *literally* contains a talking toaster.

---

## 3. Specific Feature Deep Dives

### 🎨 Illustrations & Coloring
*   **Single Image Enforcement:**
    *   Verify `IllustrationSettingsDialog` has NO slider for number of images.
    *   Verify `ColoringSettingsDialog` has NO slider for number of pages.
    *   Generate 1 Coloring Page -> Verify exactly 1 image is returned.
*   **Style Consistency:**
    *   Age 4: Simple, bold lines (Coloring), Cartoon style (Illustration).
    *   Age 15: Intricate details (Coloring), Digital Art/Watercolor (Illustration).

### 🛡️ Safety & Age Gating
*   **Toddler Safety:**
    *   Input: "Scary monster eating people".
    *   Output: Should be sanitized to "Friendly monster eating snacks" or rejected.
*   **Teen Tone:**
    *   Input: Age 15.
    *   Output: Should NOT use words like "tummy," "potty," or condescending "good job." Should use "stomach," "bathroom," "well done."

### 💾 Persistence (Web Specific)
*   **Local Storage:**
    *   Create Hero -> Close Tab -> Open Tab -> Hero exists.
    *   Create Story -> Save -> Close Tab -> Open Tab -> Story exists in Library.

---

## 4. Automated Content Audit (Scripted)

Use `tools/run_content_audit.py` (to be created) to verify backend logic without consuming API quota.

**What it checks:**
1.  **Prompt Logic:** Does the backend generate the *correct instructions* for the LLM?
    *   *Example:* If Age=4, does prompt say "Vocabulary: CVC words"?
    *   *Example:* If Mode=Rhyme, does prompt say "Scheme: AABB"?
2.  **Constraint Enforcement:**
    *   *Example:* Word count ranges match `AGE_CONSTRAINTS`.
    *   *Example:* Forbidden words list is present for young ages.

**How to run:**
```bash
python tools/run_content_audit.py
```

---

## 5. Improvement Opportunities (To Look For)

During testing, observe:
*   **Pacing:** Do "Long" stories feel *too* long or repetitive?
*   **Engagement:** Do "Pick-a-Path" choices feel meaningful or arbitrary?
*   **Visuals:** Do avatars look consistent with their description (hair color, etc.)?
*   **Speed:** Is generation time acceptable (<30s)?

---

**Sign-off:**
- [ ] Manual Tests Passed
- [ ] Automated Audit Passed
- [ ] Visual Inspection Passed
