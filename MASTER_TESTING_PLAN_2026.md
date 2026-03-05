# Master Testing Plan - Story Weaver App (2026)

**Date:** January 3, 2026
**Objective:** Comprehensive verification of frontend and backend functionality, focusing on "Phase 3" enhancements (Interactive Stories, Character System).

---

## 1. Backend Testing Strategy

**Tools:** `pytest`, `unittest`, Custom Python Scripts
**Location:** `tests/`, `backend/tests/`

### 1.1 Unit Tests (Models & Utilities)
*   **Goal:** Verify database models, prompt builders, and utility functions work in isolation.
*   **Key Tests:**
    *   `InteractiveAdventurePromptBuilder` (Strict word counts, "Contract" terminology).
    *   `StorySegment` model serialization.
    *   `User` model (including new fields like `stories_created_count`).

### 1.2 Integration Tests (Services & Endpoints)
*   **Goal:** Verify API endpoints correctly invoke services and interact with the database.
*   **Key Tests:**
    *   `POST /generate-interactive-story`: Creates story, segments, inventory, and state.
    *   `POST /continue-interactive-story`: Updates state, inventory, and appends segments.
    *   `GET /interactive-story/{id}`: Retrieves full story context.
    *   `POST /generate-story` (Legacy/Standard): Verifies standard story generation.

### 1.3 End-to-End Backend Verification
*   **Goal:** Simulate a full user session via API calls.
*   **Key Flows:**
    *   Create Character -> Generate Story -> Save Story -> Verify in Library.
    *   Interactive Story: Start -> Make Choice -> Make Choice -> Reach Ending.

---

## 2. Frontend Testing Strategy

**Tools:** `flutter test`, `integration_test`
**Location:** `test/`, `integration_test/`

### 2.1 Widget Tests
*   **Goal:** Verify UI components render correctly and handle basic interactions.
*   **Key Components:**
    *   `WizardStep1`: Character input/selection.
    *   `InteractiveStoryScreen`: Choice buttons, text display, inventory UI.
    *   `CharacterLibrary`: Grid rendering, delete action.

### 2.2 Integration Tests (Mocked)
*   **Goal:** Verify full app flows without relying on the real backend (using Mock Services).
*   **Key Flows:**
    *   Full Wizard Flow (Step 1 -> 4 -> Generation -> Result).
    *   Interactive Story Flow (Pick-A-Path selection -> Reading -> Choosing).

---

## 3. Execution Plan

### Step 1: Backend Verification
1.  Run `quick_test.py` for immediate health check. ✅
2.  Run `tests/test_backend_comprehensive.py` (includes Prompt Builder & API integration). ✅
3.  **NEW:** Create and run `tests/test_backend_interactive_flow.py` (simulates full 7-segment adventure). ✅

### Step 2: Frontend Verification
1.  Run `flutter test` for all unit/widget tests. ❌ (Failed)
2.  Run specific integration tests (if available/runnable).

### Step 3: Reporting
1.  Aggregate results into `TEST_RESULTS_SUMMARY_2026.md`. ✅
2.  Document any new bugs found.

---

## 4. Current Status (Refreshed 2026-02-16)

*   **Backend:** ✅ PASSED. All tests including flow simulation are green.
*   **Frontend:** ✅ PASSED in latest local validation runs.
    *   `flutter test --no-pub -r compact` -> 132/132 passed
    *   `flutter test --no-pub test/unit/services -r compact` -> 51/51 passed
*   **Backend API Contracts:** ✅ PASSED in latest local validation run.
    *   `cd backend; python -m pytest tests/api -q` -> 77/77 passed

---

## 5. Next Focus (Post-Baseline)

1.  Keep the passing baseline stable in CI (same command set as above).
2.  Add higher-value coverage where behavior is still under-specified:
    *   Auth edge cases and ownership boundary checks
    *   Failure-mode contract assertions (timeouts, malformed payloads, partial backend outages)
    *   Deterministic flake checks (seeded/concurrency sweeps) for integration/widget flows

### 5.1 Execution Queue (Actionable)

1.  **P0 - CI baseline lock**
    *   Ensure CI runs:
        *   `flutter test --no-pub -r compact`
        *   `flutter test --no-pub test/unit/services -r compact`
        *   `cd backend; python -m pytest tests/api -q`
        *   `cd backend; python -m pytest tests/security -q`
2.  **P0 - Flake sweep harness**
    *   Add deterministic seed + concurrency sweep for historically noisy Flutter integration/widget tests.
3.  **P1 - Frontend service negative-path expansion**
    *   Add retry/cache/auth-header edge-case assertions in `test/unit/services/`.
4.  **P1 - API contract marker/workflow alignment**
    *   Verify `pytest -m api_contract` scope matches intended CI contract coverage.
5.  **P2 - Deprecation warning cleanup**
    *   Replace `datetime.utcnow()` usage in backend tests/fixtures with timezone-aware UTC patterns.
