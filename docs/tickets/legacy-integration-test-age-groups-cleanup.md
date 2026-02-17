# Ticket: Stabilize Legacy Integration Tests (`test_age_groups.py`)

## Summary
`backend/tests/integration/test_age_groups.py` is currently incompatible with the active codebase and blocks adoption of full-folder integration CI.

## Current Failures
- `TypeError`: `StoryGenerationService.__init__()` no longer accepts `api_key=...`.
- Assertion mismatch: tests expect `word_count_target`/`word_count` fields not present in current `AGE_CONSTRAINTS` structure.

## Why This Matters
- Prevents running `pytest tests/integration -q` in CI.
- Forces CI to target only the new stable module (`test_story_generation_integration.py`) instead of all integration tests.

## Scope
- Update legacy tests in `backend/tests/integration/test_age_groups.py` to match current service constructor and current age constraint schema.
- Keep test intent intact: age calibration, vocabulary progression, and content appropriateness.
- Ensure no production code changes are required solely to satisfy outdated expectations.

## Acceptance Criteria
1. `python -m pytest backend/tests/integration/test_age_groups.py -q` passes.
2. `python -m pytest backend/tests/integration -q` passes end-to-end.
3. CI `backend-test` can safely switch from single-module integration run to full integration folder run.

## Suggested Implementation Notes
- Refactor fixtures to instantiate `StoryGenerationService` with current signature.
- Replace obsolete key assertions with checks that map to the current `AGE_CONSTRAINTS` nested fields (e.g., `standard`, `rhyme`, `ltr` ranges).
- Keep mocking deterministic and aligned with `backend/tests/conftest.py`.
