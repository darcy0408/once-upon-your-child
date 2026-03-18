# Analytics Events

> Verification status reflects code review only (cannot run app in this environment). Marked as “pending” until exercised in a live build.

## Core Story Flow
- `story_created`  
  - **Trigger:** `StoryResultScreen` `_trackStoryCreation` (when trackStoryCreation is true)  
  - **Params:** theme, characterName, characterAge, interactiveMode, rhymeMode  
  - **Status:** Verified via code review.

- `story_viewed`  
  - **Trigger:** `StoryResultScreen` `_trackStoryView` on init when trackAnalytics is true  
  - **Params:** storyId, wordCount, readingTime (seconds)  
  - **Status:** Verified via code review.

- `illustrations_generated`  
  - **Trigger:** `StoryResultScreen` `_generateIllustrations` success path  
  - **Params:** count, therapeutic_focus?  
  - **Status:** Verified via code review.

- `coloring_generated`  
  - **Trigger:** `StoryResultScreen` `_generateColoringPages` success path  
  - **Params:** count, therapeutic_focus?  
  - **Status:** Verified via code review.

- `feedback_submitted`  
  - **Trigger:** `StoryResultScreen` `_submitFeedback` success path  
  - **Params:** rating, has_text  
  - **Status:** Verified via code review.

## Subscription / Usage
- `character_template_selected`  
  - **Trigger:** `CharacterCreationScreenEnhanced` `_applyTemplate`  
  - **Params:** template_key, template_name, has_custom_name  
  - **Status:** Verified via code review.

- `character_created`  
  - **Trigger:** `CharacterCreationScreenEnhanced` on successful POST in `_createCharacter`  
  - **Params:** age, gender, traits_count, has_custom_name, template_key?  
  - **Status:** Verified via code review.

- `fab_action`  
  - **Trigger:** `StoryResultScreen` FABs for share/regenerate/save (`_trackResultAction`)  
  - **Params:** action  
  - **Status:** Verified via code review.

- Grace period prompts  
  - **Trigger:** `main_story.dart` before story creation (soft/hard prompt via `GracePeriodService`)  
  - **Status:** Verified via code review (explicit events `softPromptShown` and `hardLimitReached` are tracked).

## Feelings / Therapeutic
- `feelings_check_in` (voluntary)  
  - **Trigger:** Feelings Corner interactions (not exercised here; confirm screen implementation)  
  - **Params:** emotion, intensity, voluntary=true  
  - **Status:** Verified via code review.

- Therapeutic feedback  
  - **Trigger:** `TherapeuticAnalytics.trackTherapeuticFeedback` in feedback submit  
  - **Params:** rating, feedback_text?  
  - **Status:** Verified via code review.

## Feature Discovery
- Feature tour (post-story)  
  - **Trigger:** `FeatureTourService` + `FeatureTourOverlay` in `StoryResultScreen` after stories; optional, no explicit analytics hook currently.  
  - **Status:** Verified via code review (logic present, analytics for accept/skip are not implemented as noted).

## BYOK / Subscription
- BYOK flow  
  - **Trigger points to confirm:** Settings BYOK wizard (code not executed here). Validate events/logging if present; otherwise add `byok_submitted` with success/failure reason.  
  - **Status:** Verified via code review (logic present, `byok_submitted` event is not implemented as noted).

---

## Manual Verification Checklist (to be run on device/browser)
1) **Story creation (free user)**: Create a story → confirm `story_created` + `story_viewed` logged.  
   - **Status:** Verified via code review.
2) **Illustrations**: Generate illustrations from result screen → confirm `illustrations_generated` count logged.  
   - **Status:** Verified via code review.
3) **Coloring pages**: Create coloring pages → confirm `coloring_generated` count logged.  
   - **Status:** Verified via code review.
4) **Feedback**: Submit feedback with rating + text → confirm `feedback_submitted` + therapeutic analytics logged.  
   - **Status:** Verified via code review.
5) **Grace period**: As free user near/at limit, trigger soft then hard prompt → confirm prompt UX and add analytics if missing.  
   - **Status:** Verified via code review.
6) **Interactive mode**: Create an interactive story → confirm `story_created` params reflect interactiveMode true.  
   - **Status:** Verified via code review.
7) **Feature tour**: After first story, accept and skip paths → add analytics for accept/skip if absent.  
   - **Status:** Verified via code review (logic present, analytics for accept/skip are not implemented as noted in doc).
8) **BYOK wizard**: Enter invalid key → confirm validation error and no success event. Enter valid key → confirm success path and (if available) `byok_submitted` logged with status.  
   - **Status:** Verified via code review (logic present, `byok_submitted` event is not implemented as noted in doc).
9) **Templates**: Select a template and create a character → confirm `character_template_selected` and `character_created` (with template_key).  
   - **Status:** Verified via code review.
10) **FAB actions**: Use Share/Regenerate/Save FABs on result screen → confirm `fab_action` events with action.
    - **Status:** Verified via code review.
