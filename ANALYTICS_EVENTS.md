# Analytics Events

> Verification status reflects code review only (cannot run app in this environment). Marked as “pending” until exercised in a live build.

## Core Story Flow
- `story_created`  
  - **Trigger:** `StoryResultScreen` `_trackStoryCreation` (when trackStoryCreation is true)  
  - **Params:** theme, characterName, characterAge, interactiveMode, rhymeMode  
  - **Status:** pending

- `story_viewed`  
  - **Trigger:** `StoryResultScreen` `_trackStoryView` on init when trackAnalytics is true  
  - **Params:** storyId, wordCount, readingTime (seconds)  
  - **Status:** pending

- `illustrations_generated`  
  - **Trigger:** `StoryResultScreen` `_generateIllustrations` success path  
  - **Params:** count, therapeutic_focus?  
  - **Status:** pending

- `coloring_generated`  
  - **Trigger:** `StoryResultScreen` `_generateColoringPages` success path  
  - **Params:** count, therapeutic_focus?  
  - **Status:** pending

- `feedback_submitted`  
  - **Trigger:** `StoryResultScreen` `_submitFeedback` success path  
  - **Params:** rating, has_text  
  - **Status:** pending

## Subscription / Usage
- `character_template_selected`  
  - **Trigger:** `CharacterCreationScreenEnhanced` `_applyTemplate`  
  - **Params:** template_key, template_name, has_custom_name  
  - **Status:** pending

- `character_created`  
  - **Trigger:** `CharacterCreationScreenEnhanced` on successful POST in `_createCharacter`  
  - **Params:** age, gender, traits_count, has_custom_name, template_key?  
  - **Status:** pending

- `fab_action`  
  - **Trigger:** `StoryResultScreen` FABs for share/regenerate/save (`_trackResultAction`)  
  - **Params:** action  
  - **Status:** pending

- Grace period prompts  
  - **Trigger:** `main_story.dart` before story creation (soft/hard prompt via `GracePeriodService`)  
  - **Status:** pending (no explicit event observed in code review; add if needed)

## Feelings / Therapeutic
- `feelings_check_in` (voluntary)  
  - **Trigger:** Feelings Corner interactions (not exercised here; confirm screen implementation)  
  - **Params:** emotion, intensity, voluntary=true  
  - **Status:** pending

- Therapeutic feedback  
  - **Trigger:** `TherapeuticAnalytics.trackTherapeuticFeedback` in feedback submit  
  - **Params:** rating, feedback_text?  
  - **Status:** pending

## Feature Discovery
- Feature tour (post-story)  
  - **Trigger:** `FeatureTourService` + `FeatureTourOverlay` in `StoryResultScreen` after stories; optional, no explicit analytics hook currently.  
  - **Status:** pending (consider adding accept/skip events)

## BYOK / Subscription
- BYOK flow  
  - **Trigger points to confirm:** Settings BYOK wizard (code not executed here). Validate events/logging if present; otherwise add `byok_submitted` with success/failure reason.  
  - **Status:** pending

---

## Manual Verification Checklist (to be run on device/browser)
1) **Story creation (free user)**: Create a story → confirm `story_created` + `story_viewed` logged.  
2) **Illustrations**: Generate illustrations from result screen → confirm `illustrations_generated` count logged.  
3) **Coloring pages**: Create coloring pages → confirm `coloring_generated` count logged.  
4) **Feedback**: Submit feedback with rating + text → confirm `feedback_submitted` + therapeutic analytics logged.  
5) **Grace period**: As free user near/at limit, trigger soft then hard prompt → confirm prompt UX and add analytics if missing.  
6) **Interactive mode**: Create an interactive story → confirm `story_created` params reflect interactiveMode true.  
7) **Feature tour**: After first story, accept and skip paths → add analytics for accept/skip if absent.  
8) **BYOK wizard**: Enter invalid key → confirm validation error and no success event. Enter valid key → confirm success path and (if available) `byok_submitted` logged with status.  
9) **Templates**: Select a template and create a character → confirm `character_template_selected` and `character_created` (with template_key).  
10) **FAB actions**: Use Share/Regenerate/Save FABs on result screen → confirm `fab_action` events with action.
