# Plan: Monitoring Dashboard Improvements

- **Date**: 2026-03-21
- **Project(s)**: HomeCollector, HomeUI
- **Goal**: Fix uptime bugs, improve chart hover density, adjust panels across all monitoring pages, and add Anime services.

## Context

Read these files before proceeding:
- `projects/homeui.md` — HomeUI mapping, tech stack, testing strategy
- `projects/homecollector.md` — HomeCollector mapping, API structure, testing strategy
- Each step lists specific context files the executing agent must read

## Issues Summary

| # | Page | Issue | Affects |
|---|------|-------|---------|
| 1 | Overview | Show test coverage per project, sort by most tests (desc), make list scrollable | HomeUI |
| 2 | Test Results | Overall graph wrong: missing days don't carry forward last known results | HomeUI |
| 3 | Performance | Remove "Load 1m" stat card, make uptime panel match overview page style | HomeUI |
| 4 | All dashboards | Hover/tooltip sparse on wider time ranges — need smooth, dense hover points | HomeUI + HomeCollector |
| 5 | Usage | Disk stat card shows per-second, should show total for range. Remove Processes stat card | HomeUI |
| 6 | Uptime | Multiple bugs: false outage, wrong check counts per step, wrong failure ranges, missing Anime services | HomeCollector + HomeUI |

## Steps

### Step 1: Add Anime API and Anime APP to monitored services

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: Steps 2, 3, 5, 7
- **Description**: Add `anime-api` and `anime-app` to `DEFAULT_MONITORED_SERVICES` in `config.py`. Anime-API is a backend service (FastAPI). Anime-APP is a frontend (like HomeUI/Portfolio). Both need Docker + HTTP monitoring.
- **Context files to read**:
  - `config.py` lines 108-196 — existing service definitions for format reference
  - Read Anime-API's `docker-compose.yaml` and Anime-APP's `docker-compose.yaml` for container names and ports
- **Acceptance criteria**:
  - [ ] `anime-api` added to group "Services" with `monitor_type: "both"` and correct health URL
  - [ ] `anime-app` added to group "Pages" with `monitor_type: "both"` and correct health URL
  - [ ] Existing tests still pass
  - [ ] Add unit test for the new service config entries

---

### Step 2: Fix uptime per-day aggregation — carry forward missing days

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: Steps 1, 3, 5, 7
- **Description**: The `get_daily_uptime_stats` CRUD function only returns days where checks exist. The bulk history endpoint returns these gaps to the UI, causing the uptime graph to show "no data" (gray) or calculate wrong aggregates for days with no checks. Fix the `history/bulk` and `history` endpoints to fill in missing days: if a service has no checks on day X, carry forward the last known day's uptime percentage with `total_checks: 0` to indicate it's a carry-forward. This ensures the heartbeat bar accurately represents that the service still existed even if no new checks ran.
- **Context files to read**:
  - `app/crud/uptime_check.py` lines 89-123 — `get_daily_uptime_stats` query
  - `app/routers/uptime.py` lines 84-106, 151-182 — history and bulk history endpoints
  - `app/schemas/uptime.py` — `DayUptimePercent` schema
- **Acceptance criteria**:
  - [ ] Bulk history returns continuous date ranges (no gaps) for the requested range
  - [ ] Days with no checks show the previous day's uptime_percent with total_checks=0
  - [ ] If a service has never been checked, those days remain absent (no fabricated data)
  - [ ] Unit tests cover gap-filling logic
  - [ ] Existing uptime tests still pass

---

### Step 3: Fix uptime status — prevent false "Major Outage" and fix per-segment check counts

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: Steps 1, 2, 5, 7
- **Description**: Two related issues:
  1. **False outage**: The status endpoint returns "down" based on `services_down` count. This might be triggered by stale checks or checks from a brief blip. Investigate whether the status endpoint uses the most recent check only, and whether a single failed HTTP check (while Docker is "up") could cause this. The `http_monitor.py` merge logic (line 85-107) needs review — if the health_url returns a non-200 temporarily, the whole service goes "down" even if Docker shows it running. Consider: if Docker is "up" and HTTP fails, status should be "degraded" not "down".
  2. **Check counts**: The HeartbeatBar tooltip currently shows `total_checks` from the daily aggregate, which sums ALL checks for the entire day. When a segment represents a sub-day time window, it should ideally show only checks within that segment's time range. However, since the backend only provides daily aggregation, the fix should be in the tooltip: either show "X checks (daily)" to clarify, or — if we want per-segment accuracy — we need a new endpoint returning hourly buckets. The pragmatic fix: clarify the tooltip text.
- **Context files to read**:
  - `app/routers/uptime.py` lines 39-81 — status endpoint
  - `app/services/http_monitor.py` — merge logic and status determination
  - `app/services/docker_monitor.py` — Docker status
  - `app/crud/uptime_check.py` lines 47-66 — get_latest_checks_per_service
- **Acceptance criteria**:
  - [ ] If Docker reports "up" but HTTP health check fails once, status is "degraded" not "down"
  - [ ] Only mark "down" if both Docker AND HTTP report failure, or Docker reports container stopped
  - [ ] Unit tests for status derivation logic
  - [ ] Existing tests pass

---

### Step 4: Add hourly uptime history endpoint for sub-day segments

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: —
- **Depends on**: Step 3
- **Description**: Add a new CRUD function `get_hourly_uptime_stats` that groups checks by hour (not day), and expose it via the existing endpoints when `range=1h` or `range=7d`. For `range=1h`, return minute-level buckets. For `range=7d`, return hourly buckets. For `range=30d/90d`, keep daily buckets. This enables the heartbeat bar to show accurate per-segment data for shorter ranges.

  Add to uptime CRUD: `get_hourly_uptime_stats(db, service_name, since)` which groups by `date_trunc('hour', checked_at)`.

  Update the bulk history endpoint to accept granularity or auto-detect based on range:
  - `1h` → minute buckets (group by 5-min intervals)
  - `7d` → hourly buckets
  - `30d` → daily buckets (existing)
  - `90d` → daily buckets (existing)
- **Context files to read**:
  - `app/crud/uptime_check.py` — existing daily aggregation pattern
  - `app/routers/uptime.py` — existing endpoints
  - `app/schemas/uptime.py` — response schemas
- **Acceptance criteria**:
  - [ ] New granularity-aware uptime history works for 1h, 7d, 30d, 90d ranges
  - [ ] Response schema supports both hourly and daily entries (use ISO timestamp instead of date string for hourly)
  - [ ] Unit tests for hourly aggregation
  - [ ] Bulk endpoint returns appropriate granularity based on range

---

### Step 5: Increase Prometheus query resolution for longer time ranges

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: Steps 1, 2, 3, 7
- **Description**: The chart hover issue (image #1 — sparse data points on 7d range) is caused by large step sizes in Prometheus queries. Currently:
  - `7d` → 300s (5 min) step = ~2016 points (OK)
  - `30d` → 900s (15 min) step = ~2880 points (OK but could be denser)
  - `90d` → 3600s (1 hour) step = ~2160 points (OK)

  The real issue is on the frontend: `interval="preserveStartEnd"` in Recharts causes most X-axis ticks/hover points to be skipped. The fix is primarily in Step 7 (frontend). However, we should also ensure the backend doesn't under-sample. Adjust steps:
  - `7d` → 180s (3 min) — more hover resolution
  - `30d` → 600s (10 min)
  - `90d` → 1800s (30 min)

  This doubles data density for smoother hovering.
- **Context files to read**:
  - `app/schemas/system.py` lines 115-125 — `RANGE_CONFIG` mapping
  - `app/services/prometheus_service.py` — step calculation logic
- **Acceptance criteria**:
  - [ ] Updated step sizes in `RANGE_CONFIG`
  - [ ] Existing tests pass
  - [ ] Verify response sizes are still reasonable (~4000 points max)

---

### Step 6: Fix disk stat card on Usage page (sum not rate) + remove Processes stat card

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Steps 8, 9
- **Depends on**: — (frontend only)
- **Description**: On the Usage page:
  1. **Disk stat card**: Currently shows `lastDiskIo?.read_bytes_per_sec / write_bytes_per_sec` (a rate). It should show the total disk I/O bytes transferred in the selected time range, similar to how network totals are summed. Sum `read_bytes_per_sec * step_interval` across all data points, or better: sum the `increase()` values if the API returns them. Review what the backend returns for disk I/O — if it returns rates, multiply by interval; if it returns totals, just sum.
  2. **Remove Processes stat card**: Delete the Processes StatCard from the top stat row (lines 257-260).
- **Context files to read**:
  - `src/features/dashboard/pages/UsagePage.tsx` lines 224-261 — stat cards
  - `src/api/monitoring.ts` — usage history fetch
  - Check `src/types/api/monitoring.ts` for `DiskIoDataPoint` shape
- **Acceptance criteria**:
  - [ ] Disk stat card shows summed disk I/O for the selected range (not per-second rate)
  - [ ] Processes stat card removed from top row
  - [ ] Process chart below still exists (only the stat card is removed)
  - [ ] Unit tests updated (remove process stat test if exists, add/update disk total test)

---

### Step 7: Fix chart hover density across all dashboard pages (smooth hovering)

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Steps 6, 8, 9
- **Depends on**: Step 5 (backend data density)
- **Description**: The hover issue (image #1) shows that when set to 7d, you only get a few hover points. The root cause: `interval="preserveStartEnd"` on XAxis makes Recharts skip most tick labels — but also reduces hover resolution because the chart treats each data point as hoverable only near visible ticks.

  Fix across ALL chart pages (SystemPerformancePage, UsagePage, TestResultsPage):
  1. Remove `interval="preserveStartEnd"` from XAxis
  2. Instead, calculate a dynamic `interval` based on data length: show ~10-15 tick labels but keep ALL data points hoverable
  3. Add `activeDot` config to ensure hover shows on every data point
  4. Set XAxis `tickCount` or compute `interval={Math.ceil(data.length / 12)}` for clean tick spacing
  5. Ensure the Tooltip `trigger="axis"` is set (default in Recharts area/line charts) — this enables hovering on any X position, not just exact data points

  This affects:
  - `SystemPerformancePage.tsx` — 5 charts (CPU, RAM, Disk, Load, Network)
  - `UsagePage.tsx` — 5 charts (Memory, Network, Disk I/O, Process, Docker)
  - `TestResultsProjectChart.tsx` — per-project test charts
- **Context files to read**:
  - `src/features/dashboard/pages/SystemPerformancePage.tsx` — all XAxis configs
  - `src/features/dashboard/pages/UsagePage.tsx` — all XAxis configs
  - `src/features/dashboard/components/TestResultsProjectChart.tsx` — XAxis config
- **Acceptance criteria**:
  - [ ] Hovering over any point in the chart shows a tooltip with the exact timestamp and value
  - [ ] ~10-15 X-axis tick labels visible (not every point, but not just 2-3)
  - [ ] Works correctly for all time ranges (1h, 24h, 7d, 30d, 90d)
  - [ ] No visual regression on short time ranges (1h, 24h)

---

### Step 8: Overview page — test coverage display, sorting, scrollable list

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Steps 6, 7, 9
- **Description**: Three changes to the Overview page's test results panel (AllurePanel):
  1. **Show coverage per project**: Each `AllureProjectCard` should display the coverage percentage. The coverage data is already available via `useCoverageCurrent()` — pass coverage map to AllurePanel.
  2. **Sort by test count**: Sort projects by `total` tests descending (most tests at top).
  3. **Scrollable**: Set a fixed max-height on the AllurePanel project list and make it `overflow-y: auto`. The card's outer container should not grow/shrink beyond its allocated space.
- **Context files to read**:
  - `src/features/dashboard/pages/OverviewPage.tsx` lines 225-228 — AllurePanel usage
  - `src/features/dashboard/components/AllurePanel.tsx` — current panel implementation
  - `src/features/dashboard/components/AllureProjectCard.tsx` — per-project card
  - `src/hooks/useCoverageCurrent.ts` or equivalent — coverage hook
- **Acceptance criteria**:
  - [ ] Each project card shows its coverage % (colored: green >=80%, amber >=60%, red <60%)
  - [ ] Projects sorted by total test count descending
  - [ ] Panel has fixed height with scroll when content overflows
  - [ ] Panel does not change size regardless of number of projects
  - [ ] Unit test for sorting logic

---

### Step 9: Performance page — remove Load 1m stat card, match uptime panel to overview

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Steps 6, 7, 8
- **Description**:
  1. **Remove Load 1m stat card**: Delete the "Load 1m" StatCard from the top row (lines 195-198). The load chart below still shows 1m/5m/15m.
  2. **Match uptime panel**: Replace the current plain uptime StatCard (lines 199-203) with the same full uptime pill used on the Overview page (`SystemMetricsPanel`'s uptime pill style: shows `Xd Yh Zm` format with clock icon and "System Uptime" subtitle).
- **Context files to read**:
  - `src/features/dashboard/pages/SystemPerformancePage.tsx` lines 172-208 — stat cards
  - `src/features/dashboard/components/SystemMetricsPanel.tsx` lines 133-160 — overview uptime pill
- **Acceptance criteria**:
  - [ ] Load 1m stat card removed from top row
  - [ ] Uptime stat card matches overview page style (formatted as `Xd Yh Zm`, clock icon, subtitle)
  - [ ] Visual consistency with overview page uptime pill
  - [ ] No regression on other stat cards

---

### Step 10: Test Results page — fix overall graph carry-forward logic

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Steps 6, 7, 8, 9
- **Description**: The aggregated "All Projects" chart on TestResultsPage has a bug: if a project's tests ran on 20.03 but NOT on 21.03, the 21.03 aggregation does NOT include that project's tests. This is wrong — those tests still exist, they just didn't run.

  Fix the aggregation logic in `TestResultsPage.tsx` (lines 83-183):
  1. After Step 1 (getting latest per project per date), create a "carry-forward" map
  2. For each date in the range, if a project has no snapshot for that date, use the last known snapshot from a previous date
  3. This means: iterate dates chronologically. For each project, maintain a "last known" state. If the project has a snapshot on this date, use it. If not, carry forward the last known snapshot.
  4. The aggregation in Step 2 then sums ALL projects (including carry-forwards) for each date

  Example: Project A has 100 tests on 20.03. Project B has 50 tests on 20.03 and 21.03. On 21.03, the graph should show 150 total (100 carried from A + 50 from B), not just 50.
- **Context files to read**:
  - `src/features/dashboard/pages/TestResultsPage.tsx` lines 83-183 — aggregation logic
- **Acceptance criteria**:
  - [ ] Overall graph carries forward last known test results for projects that didn't run on a given date
  - [ ] Only carry forward within the data range (don't fabricate data before first ever run)
  - [ ] Total test count on any date = sum of latest results per project up to that date
  - [ ] Unit test for carry-forward aggregation logic

---

### Step 11: Uptime page — fix HeartbeatBar tooltip and segment accuracy

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Steps 6, 7, 8, 9, 10
- **Depends on**: Steps 2, 3, 4 (backend fixes)
- **Description**: Update HeartbeatBar to:
  1. **Use granular data**: When backend returns hourly/minute buckets (Step 4), map segments to the correct time bucket instead of daily.
  2. **Fix tooltip check count**: Show only checks within the segment's time range, not total daily checks. With hourly data from Step 4, this is automatic. For daily data (30d/90d), show "X checks (daily total)".
  3. **Fix time range coloring**: A segment should only be amber/red if the failure occurred within that segment's time window. With hourly data, a few-minute outage only colors 1-2 segments red, not the entire day.
  4. **Handle missing data gracefully**: With carry-forward from Step 2, gray segments should be rare.
- **Context files to read**:
  - `src/features/dashboard/components/HeartbeatBar.tsx` — current implementation
  - `src/features/dashboard/components/ServiceRow.tsx` — how HeartbeatBar is used
  - `src/types/api/uptime.ts` — data types
- **Acceptance criteria**:
  - [ ] Tooltip shows check count for the segment's time window only
  - [ ] Brief outages (minutes) only color affected segments, not entire day
  - [ ] Time labels in tooltip accurately reflect the segment's time range
  - [ ] Works correctly for all uptime ranges (1h, 7d, 30d, 90d)

---

### Step 12: Integration testing and verification

- **Project**: HomeCollector, HomeUI
- **Directory**: both
- **Parallel with**: —
- **Depends on**: All previous steps
- **Description**: Run full test suites on both projects. Verify visual behavior manually on the deployed dashboards.
- **Context files to read**:
  - `CLAUDE.md` in both projects — test commands
- **Acceptance criteria**:
  - [ ] `PYTHONPATH=. pytest tests/ -v --cov=app --cov-fail-under=70` passes on HomeCollector
  - [ ] `npm run test:ci` passes on HomeUI (70% coverage)
  - [ ] `npm run test:e2e` passes on HomeUI
  - [ ] All monitoring pages load correctly after deployment
  - [ ] Hover shows smooth, dense data points on all charts at all time ranges

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel — independent backend + frontend changes):
  Step 1:  Add Anime services to config          → HomeCollector @ /Users/gregor/dev/922/HomeCollector
  Step 2:  Fix uptime gap-filling (carry-forward) → HomeCollector @ /Users/gregor/dev/922/HomeCollector
  Step 3:  Fix false outage status logic          → HomeCollector @ /Users/gregor/dev/922/HomeCollector
  Step 5:  Increase Prometheus step resolution    → HomeCollector @ /Users/gregor/dev/922/HomeCollector
  Step 7:  Fix chart hover density (all pages)    → HomeUI @ /Users/gregor/dev/922/HomeUI
  Step 6:  Fix Usage disk stat + remove processes → HomeUI @ /Users/gregor/dev/922/HomeUI
  Step 8:  Overview page test panel improvements  → HomeUI @ /Users/gregor/dev/922/HomeUI
  Step 9:  Performance page stat card changes     → HomeUI @ /Users/gregor/dev/922/HomeUI
  Step 10: Test Results carry-forward fix         → HomeUI @ /Users/gregor/dev/922/HomeUI

Wave 2 (after Wave 1 backend steps):
  Step 4:  Add hourly uptime history endpoint     → HomeCollector @ /Users/gregor/dev/922/HomeCollector

Wave 3 (after Wave 2):
  Step 11: Update HeartbeatBar for granular data  → HomeUI @ /Users/gregor/dev/922/HomeUI

Wave 4 (after all):
  Step 12: Integration testing and verification   → Both projects
```

## Agent Execution Guide

### Wave 1 — HomeCollector agents (run in parallel)

**Agent 1A**: Steps 1 + 5 (simple config changes)
```
Project: HomeCollector
Directory: /Users/gregor/dev/922/HomeCollector

Read first:
- CLAUDE.md
- config.py (lines 108-196)
- app/schemas/system.py (lines 115-125)
- /Users/gregor/dev/922/Anime-API/docker-compose.yaml (for container name + port)
- /Users/gregor/dev/922/Anime-APP/docker-compose.yaml (for container name + port)

Tasks:
1. Add anime-api and anime-app to DEFAULT_MONITORED_SERVICES in config.py
2. Update RANGE_CONFIG step sizes: 7d→180s, 30d→600s, 90d→1800s
3. Run tests, fix if needed
4. Commit separately: one for anime services, one for step sizes
```

**Agent 1B**: Steps 2 + 3 (uptime logic fixes)
```
Project: HomeCollector
Directory: /Users/gregor/dev/922/HomeCollector

Read first:
- CLAUDE.md
- app/crud/uptime_check.py
- app/routers/uptime.py
- app/services/http_monitor.py
- app/services/docker_monitor.py
- app/schemas/uptime.py

Tasks:
1. Fix http_monitor merge logic: if Docker="up" but HTTP fails → "degraded" not "down"
2. Add gap-filling to uptime history: fill missing days with carry-forward data
3. Add unit tests for both fixes
4. Run full test suite
5. Commit separately: one for status fix, one for gap-filling
```

### Wave 1 — HomeUI agents (run in parallel)

**Agent 1C**: Steps 6 + 9 (simple panel removals/adjustments)
```
Project: HomeUI
Directory: /Users/gregor/dev/922/HomeUI

Read first:
- CLAUDE.md
- src/features/dashboard/pages/UsagePage.tsx
- src/features/dashboard/pages/SystemPerformancePage.tsx
- src/features/dashboard/components/SystemMetricsPanel.tsx

Tasks:
1. UsagePage: Change disk stat card to show summed disk I/O for range
2. UsagePage: Remove Processes stat card (keep process chart)
3. PerformancePage: Remove Load 1m stat card
4. PerformancePage: Update uptime stat card to match overview style (Xd Yh Zm, clock icon, subtitle)
5. Update tests
6. Commit: one for Usage, one for Performance
```

**Agent 1D**: Steps 7 + 8 (chart hover + overview panel)
```
Project: HomeUI
Directory: /Users/gregor/dev/922/HomeUI

Read first:
- CLAUDE.md
- src/features/dashboard/pages/SystemPerformancePage.tsx
- src/features/dashboard/pages/UsagePage.tsx
- src/features/dashboard/components/TestResultsProjectChart.tsx
- src/features/dashboard/pages/OverviewPage.tsx
- src/features/dashboard/components/AllurePanel.tsx
- src/features/dashboard/components/AllureProjectCard.tsx
- src/api/monitoring.ts (for coverage hooks)

Tasks:
1. ALL chart XAxis: Replace interval="preserveStartEnd" with dynamic interval={Math.ceil(data.length / 12)}
2. Ensure Recharts Tooltip shows on every hover position
3. AllurePanel: Accept coverageMap prop, pass to cards
4. AllureProjectCard: Display coverage % with color coding
5. AllurePanel: Sort projects by total tests descending
6. AllurePanel: Add fixed max-height with overflow-y scroll
7. Update tests
8. Commit: one for hover fix, one for overview panel
```

**Agent 1E**: Step 10 (test results carry-forward)
```
Project: HomeUI
Directory: /Users/gregor/dev/922/HomeUI

Read first:
- CLAUDE.md
- src/features/dashboard/pages/TestResultsPage.tsx (lines 83-183)

Tasks:
1. Refactor aggregation logic: for each date, carry forward last known per-project snapshots
2. Extract carry-forward logic into a testable pure function
3. Add unit tests for the aggregation function
4. Commit: test results carry-forward fix
```

### Wave 2

**Agent 2A**: Step 4 (hourly uptime endpoint)
```
Project: HomeCollector
Directory: /Users/gregor/dev/922/HomeCollector

Read first:
- CLAUDE.md
- app/crud/uptime_check.py
- app/routers/uptime.py
- app/schemas/uptime.py

Tasks:
1. Add get_hourly_uptime_stats CRUD function
2. Update bulk history endpoint to use granularity based on range
3. Update schemas to support hourly timestamps
4. Add unit tests
5. Commit: granularity-aware uptime history
```

### Wave 3

**Agent 3A**: Step 11 (HeartbeatBar update)
```
Project: HomeUI
Directory: /Users/gregor/dev/922/HomeUI

Read first:
- CLAUDE.md
- src/features/dashboard/components/HeartbeatBar.tsx
- src/features/dashboard/components/ServiceRow.tsx
- src/types/api/uptime.ts
- src/api/uptime.ts

Tasks:
1. Update HeartbeatBar to handle hourly data from new endpoint
2. Map segments to correct time buckets based on data granularity
3. Fix tooltip to show per-segment check counts
4. Update tests
5. Commit: HeartbeatBar granular data support
```

### Wave 4

**Agent 4A**: Step 12 (verification)
```
Run in both projects:
- HomeCollector: PYTHONPATH=. pytest tests/ -v --cov=app --cov-fail-under=70
- HomeUI: npm run test:ci && npm run test:e2e
- Manual verification of all monitoring pages
```

## Post-Execution Checklist
- [ ] All tests pass (both projects, 70% coverage minimum)
- [ ] Documentation updated (if API changes)
- [ ] Pipeline green (both projects)
- [ ] Changes reviewed against best practices in project mappings
- [ ] All monitoring pages load and display correctly
- [ ] Hover behavior smooth across all time ranges
- [ ] Uptime page shows accurate status (no false outages)
- [ ] Anime API and Anime APP appear on uptime page
- [ ] Test Results overall graph carries forward correctly
