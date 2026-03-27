# Plan: Fix Uptime Dashboard Displaying Wrong Metrics

- **Date**: 2026-03-28
- **Project(s)**: HomeCollector, HomeUI
- **Goal**: Fix incorrect uptime granularity (30d/90d using hourly instead of daily) and validate with backtests.
- **Status**: DONE (2026-03-28)

## Context

Read these files before proceeding:
- `projects/homeui.md` — HomeUI project mapping
- `projects/homeapi.md` — HomeAPI project mapping (for ecosystem context)
- `projects/homecollector.md` — HomeCollector project mapping

## Root Cause Analysis

**Bug**: `HOURLY_RANGES` in `HomeCollector/app/helpers/parsing.py` was set to `frozenset({"1h", "7d", "30d", "90d"})` — including ALL ranges. Per the router docstrings, only `1h` and `7d` should use hourly granularity; `30d` and `90d` should use daily.

**Impact**:
1. `/api/uptime/history` and `/api/uptime/history/bulk` returned hourly data (~720-2160 points) instead of daily (~30-90 points) for 30d/90d ranges
2. `fill_missing_hours()` carried forward uptime values across hundreds of hours, inflating displayed uptime percentages
3. Heartbeat bars showed averaged hourly data including carry-forward entries, masking real downtime
4. Excessive API payload sizes (24x larger than needed for 90d)
5. Integration tests **also asserted the wrong behavior** — they validated hourly was used for 30d/90d

**Unrelated fix discovered**: HomeUI E2E tests for the uptime page were missing domain API mocks (`/api/domains/status`, `/api/domains/history/bulk`), causing unmocked requests to hit the real server, return 401, and redirect to login — making all uptime E2E tests fail.

## Steps

### Step 1: Fix HOURLY_RANGES constant — DONE
- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **File**: `app/helpers/parsing.py:15`
- **Change**: `frozenset({"1h", "7d", "30d", "90d"})` → `frozenset({"1h", "7d"})`
- **Acceptance criteria**:
  - [x] 30d and 90d ranges route to `get_daily_uptime_stats` and `fill_missing_days`
  - [x] 1h and 7d ranges still route to `get_hourly_uptime_stats` and `fill_missing_hours`

### Step 2: Fix integration tests — DONE
- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Files**: `tests/integration/routers/test_uptime.py`
- **Parallel with**: Step 1
- **Changes**:
  - `test_get_history_success` — mock `get_daily_uptime_stats` instead of hourly for 30d
  - `test_get_history_30d_uses_daily` — assert `get_daily_uptime_stats` called, hourly not called
  - `test_get_bulk_history_90d_uses_daily` — assert `get_daily_uptime_stats` called, hourly not called
- **Acceptance criteria**:
  - [x] Tests correctly assert daily CRUD for 30d/90d
  - [x] Tests correctly assert hourly CRUD for 1h/7d

### Step 3: Fix unit tests for HOURLY_RANGES — DONE
- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **File**: `tests/unit/helpers/test_parsing.py`
- **Change**: `test_hourly_ranges_entries` now asserts 30d/90d are NOT in HOURLY_RANGES
- **Acceptance criteria**:
  - [x] Assert `len(HOURLY_RANGES) == 2`
  - [x] Assert `"30d" not in HOURLY_RANGES`
  - [x] Assert `"90d" not in HOURLY_RANGES`

### Step 4: Run HomeCollector tests and push — DONE
- **Project**: HomeCollector
- **Result**: 532 passed, 0 failed
- **Commit**: `fix(uptime): use daily granularity for 30d/90d ranges instead of hourly`
- **Pushed**: `dev` branch

### Step 5: Add E2E backtests for uptime dashboard — DONE
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **File**: `e2e/monitoring/uptime.spec.ts`
- **Changes**:
  - Added domain API mocks to `mockUptimeApis()` (fixes auth redirect on all tests)
  - Added 7 new backtest cases in "Uptime Page — metric correctness" describe block:
    1. Per-service uptime percentages display correctly
    2. Heartbeat bars render with service data
    3. Operational status label for up services
    4. Major Outage status label for down services
    5. Time range switching triggers correct API calls with range params
    6. Range footer labels ("90d ago" / "Today")
    7. Domain reachability section renders when domains exist
- **Acceptance criteria**:
  - [x] All 16 uptime E2E tests pass
  - [x] Domain mocks prevent auth redirect
  - [x] Range switching verified via request interception

### Step 6: Run HomeUI tests and push — DONE
- **Project**: HomeUI
- **Result**: 16 passed, 0 failed (uptime tests)
- **Commit**: `test(e2e): add uptime dashboard backtests and fix domain API mocking`
- **Pushed**: `prod` branch

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Fix HOURLY_RANGES → HomeCollector @ app/helpers/parsing.py
  Step 2: Fix integration tests → HomeCollector @ tests/integration/routers/test_uptime.py
  Step 3: Fix unit tests → HomeCollector @ tests/unit/helpers/test_parsing.py

Wave 2 (after wave 1):
  Step 4: Run all 532 HomeCollector tests → PASS ✓
  Step 4: Commit and push → dev branch ✓

Wave 3 (after wave 2):
  Step 5: Add E2E backtests + fix domain mocks → HomeUI @ e2e/monitoring/uptime.spec.ts

Wave 4 (after wave 3):
  Step 6: Run 16 uptime E2E tests → PASS ✓
  Step 6: Commit and push → prod branch ✓
```

## Post-Execution Checklist
- [x] All HomeCollector tests pass (532/532)
- [x] All HomeUI uptime E2E tests pass (16/16)
- [x] Changes pushed to remote
- [x] Pipeline will validate on push (monitor Discord for results)
