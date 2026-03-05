# Frontend Test Coverage Report
**Date:** 2026-02-13
**Overall Coverage:** 21.0% (Partial - See Analysis of Gaps)

## Coverage Summary by Module

| Module | Lines | Covered | Coverage |
|--------|-------|---------|----------|
| `lib` | 585 | 112 | 19.1% |
| `lib\config` | 37 | 11 | 29.7% |
| `lib\data` | 23 | 0 | 0.0% |
| `lib\models` | 270 | 55 | 20.4% |
| `lib\screens` | 218 | 159 | 72.9% |
| `lib\services` | 1119 | 137 | 12.2% |
| **TOTAL** | **2252** | **474** | **21.0%** |

## Analysis of Gaps

1. **Coverage Tool Instability:** 
   - The reported 21% coverage is based on partial runs. Full coverage collection via `flutter test --coverage` consistently fails on this environment with `Service has disappeared` errors during large widget/integration test runs.
   - Most widget tests (`test/widgets/`) and integration tests (`test/integration/`) are passing (117/117 total tests pass), but their coverage data is not fully captured in the final `lcov.info`.

2. **Core Services (12.2%):**
   - While unit tests exist for `StripeService`, `SubscriptionSyncService`, and `IsarService`, many secondary services and complex logic branches remain uncovered in the captured data.

3. **Data & Models (0-20%):**
   - Static data files and some model helper methods lack explicit unit tests, though they are exercised by widget tests.

## Recommendations

1. **Infrastructure:**
   - Investigate alternative coverage collection methods for Windows or run coverage in a Linux-based CI environment where `lcov` is more stable.
   - Use `combine_coverage` scripts to merge results from smaller, more stable test runs.

2. **Testing Gaps:**
   - Add explicit unit tests for `lib/data/` logic to ensure scenario data is correctly structured.
   - Increase coverage for `ApiServiceManager` error handling paths.

3. **Maintenance:**
   - Continue maintaining the 100% pass rate (currently 117/117).
   - Address remaining info-level lints in legacy code to reach a perfect analysis state.

## Test Statistics
- **Total Passed:** 117
- **Total Failed:** 0
- **Total Duration:** ~5 minutes (without coverage overhead)
