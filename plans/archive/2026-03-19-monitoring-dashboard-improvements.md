# [DONE - 20-03] Plan: Monitoring Dashboard Improvements

- **Date**: 2026-03-19
- **Project(s)**: HomeUI, HomeCollector
- **Goal**: Comprehensive improvements to all monitoring dashboard pages — layout fixes, coverage tracking, dynamic repo discovery, adaptive project rendering, loading UX, and uptime grouping.

## Context

Read these files before proceeding:
- `projects/homeui.md` — HomeUI stack, patterns, testing rules
- `projects/homecollector.md` — HomeCollector stack, architecture, best practices

---

## Steps

### Step 1: Dynamic GitHub Org Repo Discovery (HomeCollector)

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: Step 2
- **Description**:
  Remove the hardcoded `MONITORED_REPOS` list from `app/services/github_service.py`. Replace with a dynamic lookup using the GitHub API that fetches all repos in the configured org (`GITHUB_ORG`).

  **Implementation**:
  - Add a private async method `_get_org_repos(client: httpx.AsyncClient) -> list[str]` that calls `GET /orgs/{org}/repos?per_page=100&type=all&sort=updated` and returns repo names
  - Add in-process caching with a 10-minute TTL (use a `_repos_cache: list[str]` and `_repos_cache_expiry: datetime | None` on the service instance)
  - Replace every usage of `MONITORED_REPOS` in `get_workflow_runs`, `get_paginated_runs`, `get_workflow_stats`, `get_workflow_analytics` with a call to the cached `_get_org_repos()`
  - The `get_commit_activity` method already uses GitHub GraphQL `contributionsCollection` and does not need repo list injection — leave it unchanged
  - Pagination: call multiple pages if the org has >100 repos (`link` header detection), collect all
  - Error fallback: if the GitHub API call for repos fails, log a warning and return an empty list (callers will return empty results rather than crash)

- **Context files to read**:
  - `app/services/github_service.py` — current implementation with hardcoded MONITORED_REPOS
  - `app/routers/github.py` — endpoint wiring
  - `config.py` — GITHUB_ORG, GITHUB_TOKEN

- **Acceptance criteria**:
  - [ ] `MONITORED_REPOS` constant removed from `github_service.py`
  - [ ] Repos are fetched dynamically from GitHub API on first call, then cached for 10 minutes
  - [ ] A new repo added to the 922-Studio org is picked up automatically within 10 minutes (no code change required)
  - [ ] All existing endpoints (`/github/runs`, `/github/analytics`, `/github/runs/paginated`, `/github/stats`) continue to function correctly
  - [ ] Unit tests updated: mock `_get_org_repos` instead of `MONITORED_REPOS`
  - [ ] All existing GitHub-related tests pass

---

### Step 2: Update Uptime Service Groups (HomeCollector)

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: Step 1
- **Description**:
  Update the `DEFAULT_MONITORED_SERVICES` groups in `config.py` and create an Alembic migration to update existing `service_configs` rows in the database.

  **New group assignments**:
  | Service | New Group |
  |---------|-----------|
  | portfolio | Pages |
  | homeui | Pages |
  | sweatvalley-bingo | Pages |
  | home_api_api | Services |
  | homeauth | Services |
  | home_collector_api | Services |
  | discord_bot | Services |
  | shared_postgres | Infrastructure |
  | shared_redis | Infrastructure |
  | traefik | Infrastructure |
  | prometheus | Infrastructure |
  | grafana | Infrastructure |

  **Implementation**:
  1. Update `DEFAULT_MONITORED_SERVICES` in `config.py` with the new group values above
  2. Generate a new Alembic migration: `alembic revision --autogenerate -m "update_service_groups"` (or manually if autogenerate doesn't pick it up)
  3. Migration `upgrade()` must execute SQL `UPDATE service_configs SET group = <new_group> WHERE service_name = <name>` for each changed service
  4. Migration `downgrade()` restores old group values

  **Note on seeding**: `DEFAULT_MONITORED_SERVICES` uses upsert-on-name logic that does NOT overwrite existing records. The migration handles in-place updates for live instances.

- **Context files to read**:
  - `config.py` — DEFAULT_MONITORED_SERVICES definition
  - `app/models/service_config.py` — ServiceConfig model (group field)
  - `alembic/env.py` — migration setup
  - Any existing migration in `alembic/versions/` — to understand naming conventions

- **Acceptance criteria**:
  - [ ] `DEFAULT_MONITORED_SERVICES` groups match the table above
  - [ ] Alembic migration created, `upgrade()` updates all affected rows
  - [ ] `alembic upgrade head` runs successfully on the server
  - [ ] `GET /api/uptime/status` returns services in groups: Pages, Services, Infrastructure
  - [ ] Tests for group structure pass

---

### Step 3: Reusable PanelLoader Component (HomeUI)

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: —
- **Description**:
  Create `src/features/dashboard/components/PanelLoader.tsx` — a compact inline loading animation for use inside dashboard panels. It reuses the same spinning gradient arc + pulsing dots animation from `LoadingScreen`, but without the fullscreen overlay.

  **Specification**:
  - Props: `{ height?: number }` (default `height: 120`)
  - Renders a centered div at the given height with the spinner inside
  - The spinner is the same arc gradient (`#6366f1` → `#06b6d4`) + 3 pulsing dots, but scaled smaller (48px wide instead of 80px)
  - Uses existing CSS animation classes: `loading-spinner`, `loading-dot` (already defined in `index.css`)
  - No overlay, no backdrop — just the animation centered in the panel area

  **Replace "Loading..." text** across all dashboard panel placeholders:
  - `UsagePage.tsx` → `ChartPlaceholder` function: replace `'Loading...'` text with `<PanelLoader />`
  - `GitHubActionsPage.tsx` → `ChartPlaceholder` function: same
  - `TestResultsPage.tsx` → loading state div: replace `Loading test results...` with `<PanelLoader height={80} />`
  - `UptimePage.tsx` → loading badge in header: replace `Loading...` span with `<PanelLoader height={40} />`

  Also write a unit test `PanelLoader.test.tsx` that verifies it renders without crashing and the spinner svg is present.

- **Context files to read**:
  - `src/components/ui/LoadingScreen.tsx` — animation pattern to replicate at smaller scale
  - `src/index.css` — confirm `loading-spinner` and `loading-dot` CSS classes exist and their animation definitions

- **Acceptance criteria**:
  - [ ] `PanelLoader.tsx` created with correct animation and size
  - [ ] All "Loading..." text placeholders replaced with `<PanelLoader />`
  - [ ] Unit test `PanelLoader.test.tsx` passes
  - [ ] No TypeScript errors

---

### Step 4: Overview Page — Network/Disk Panel Layout & Container Sort (HomeUI)

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 5, 6, 7, 8, 9 (after Step 3)
- **Description**:

  **A — Network/Disk panel: title inside card border**

  Currently `NetworkChart` and `DiskChart` render the panel title ("Network I/O", "Disk Space") OUTSIDE the card border (the border only wraps the chart area). The user wants the title inside the card, matching Docker panel style.

  Refactor both components:
  - Wrap the entire component (title + chart area + footer/legend) in a single outer `div` with `backgroundColor: 'var(--card)', border: '1px solid var(--border)', borderRadius: 8`
  - The title row (green accent + label + LIVE badge) becomes the first child inside this outer card div, with appropriate padding
  - The chart area becomes the next child (can have a subtle inner background using `var(--background)`)
  - Remove the `padding: '0 20px 20px 20px'` from the component's own outer wrapper — the parent (`OverviewPage`) already provides section padding via its wrapping div

  **B — Docker containers: sort by CPU in Overview**

  In `OverviewPage.tsx`, the container list is sliced without sorting. Fix:
  ```typescript
  // Before:
  const containerList = containers.data?.containers ?? []

  // After:
  const containerList = [...(containers.data?.containers ?? [])].sort(
    (a, b) => (b.cpu_percent ?? 0) - (a.cpu_percent ?? 0)
  )
  ```
  Note: `ContainerGrid` (used in UptimePage) already sorts — no change needed there.

- **Context files to read**:
  - `src/features/dashboard/components/NetworkChart.tsx` — full component
  - `src/features/dashboard/components/DiskChart.tsx` — full component (find similarly)
  - `src/features/dashboard/pages/OverviewPage.tsx` — container slice logic

- **Acceptance criteria**:
  - [ ] NetworkChart: title "Network I/O" and LIVE badge visually inside the card border
  - [ ] DiskChart: title visually inside the card border (same pattern)
  - [ ] Both panels remain full-width across the Overview page
  - [ ] Docker containers in Overview are sorted by CPU descending
  - [ ] Existing `NetworkChart.test.tsx` and `DiskChart.test.tsx` still pass

---

### Step 5: Overview — Coverage Stat in SystemMetricsPanel (HomeUI)

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 4, 6, 7, 8, 9 (after Step 3)
- **Description**:
  The "TEST HEALTH" pill in `SystemMetricsPanel` shows pass rate but not coverage. Add coverage display.

  **Changes to `OverviewPage.tsx`**:
  - Compute `allureCoveragePercent` from allure data:
    ```typescript
    const coverageProjects = allureProjects.filter(p => p.coverage_percent != null)
    const allureCoverage = coverageProjects.length > 0
      ? coverageProjects.reduce((s, p) => s + (p.coverage_percent ?? 0), 0) / coverageProjects.length
      : null
    ```
  - Pass `allureCoverage` to `SystemMetricsPanel`

  **Changes to `SystemMetricsPanel.tsx`**:
  - Add optional prop `allureCoverage?: number | null`
  - In the TEST HEALTH pill, add a sub-line showing coverage when available:
    ```
    [pass rate]%
    [coverage]% coverage | [N] tests passing
    ```
  - Coverage color: green ≥80%, amber ≥60%, red <60%
  - When coverage is null, show only pass rate (current behavior)
  - Adjust `pillStyle.height` if needed to accommodate extra line

- **Context files to read**:
  - `src/features/dashboard/components/SystemMetricsPanel.tsx` — current TEST HEALTH pill
  - `src/features/dashboard/pages/OverviewPage.tsx` — where allure data is destructured
  - `src/types/api/monitoring.ts` — AllureProjectResult type (to confirm coverage_percent field name)

- **Acceptance criteria**:
  - [ ] TEST HEALTH pill shows both pass rate AND coverage when coverage data is available
  - [ ] Coverage not shown when null (no projects with coverage reporting)
  - [ ] `SystemMetricsPanel.test.tsx` updated to test with and without coverage prop
  - [ ] No TypeScript errors

---

### Step 6: Test Results Page — Coverage Stat, Aggregation Fix & Coverage Overlay (HomeUI)

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 4, 5, 7, 8, 9 (after Step 3)
- **Description**:

  **A — Overall Coverage Stat: adoption-based formula**

  The existing formula averages coverage % values. Replace with adoption-based:
  ```typescript
  // Old: average of projects that have coverage_percent
  // New: % of total projects that have coverage reporting
  const overallCoverage = projects.length > 0
    ? (projects.filter(p => p.coverage_percent != null).length / projects.length) * 100
    : null
  ```
  Example: 3 projects with coverage_percent set, 6 total → 50%.

  Move the Coverage `StatCard` to the front of the summary cards row (before "Total Tests").

  **B — Fix "All Projects" aggregation: one run per project per day**

  The current `aggregatedSnapshots` sums ALL runs for a date across all projects — if one project runs CI 5× in a day, it counts all 5. The correct logic: for each date, take the LATEST snapshot per project, then sum.

  Replace the `aggregatedSnapshots` useMemo in `TestResultsPage.tsx`:
  ```typescript
  const aggregatedSnapshots = useMemo(() => {
    // Step 1: for each (project, date), keep only the latest snapshot
    const latestPerProjectPerDate = new Map<string, AllureHistorySnapshot>()
    for (const proj of historyProjects) {
      for (const snap of proj.reports) {
        if (!snap.created_at) continue
        const dateKey = new Date(snap.created_at).toISOString().slice(0, 10)
        const key = `${proj.project_id}::${dateKey}`
        const existing = latestPerProjectPerDate.get(key)
        if (!existing || new Date(snap.created_at) > new Date(existing.created_at)) {
          latestPerProjectPerDate.set(key, snap)
        }
      }
    }

    // Step 2: group by date and aggregate across projects
    const dateMap = new Map<string, { passed: number; failed: number; broken: number; skipped: number; total: number; created_at: string }>()
    for (const [key, snap] of latestPerProjectPerDate) {
      const dateKey = key.split('::')[1]
      const existing = dateMap.get(dateKey)
      if (existing) {
        existing.passed += snap.passed
        existing.failed += snap.failed
        existing.broken += snap.broken
        existing.skipped += snap.skipped
        existing.total += snap.total
      } else {
        dateMap.set(dateKey, {
          passed: snap.passed, failed: snap.failed,
          broken: snap.broken, skipped: snap.skipped,
          total: snap.total, created_at: snap.created_at,
        })
      }
    }

    // Step 3: sort ascending (oldest left, newest right)
    return Array.from(dateMap.values())
      .sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime())
      .map((d, i) => ({
        report_id: `agg-${i}`,
        created_at: d.created_at,
        passed: d.passed, failed: d.failed,
        broken: d.broken, skipped: d.skipped,
        unknown: 0, total: d.total,
        pass_rate_percent: d.total > 0 ? (d.passed / d.total) * 100 : 0,
        duration_ms: 0,
      } as AllureHistorySnapshot))
  }, [historyProjects])
  ```

  **C — Chart direction: oldest left, newest right**

  In `TestResultsProjectChart.tsx`, the `chartData` useMemo has `.reverse()` at the end which flips the order. Remove it so all charts render oldest→newest (left→right):
  ```typescript
  // Remove: .reverse()
  ```
  The aggregated snapshots are already sorted ascending, so this yields left=oldest, right=newest.

  **D — Coverage overlay line on all project charts**

  Add a reference line or secondary Area to `TestResultsProjectChart` showing coverage scaled to the test count axis. When `latestCoverage` is null, skip the line entirely.

  **Approach** — add a `coverage` field to each `ChartDataPoint` only for the latest snapshot (the most recent run's coverage is the best proxy):
  ```typescript
  // In the chart, add a ReferenceLine at y = (latestCoverage / 100) * maxTotal
  // maxTotal = max of all snapshots' .total values
  ```
  Use a `ReferenceLine` from recharts:
  ```tsx
  {latestCoverage != null && maxTotal > 0 && (
    <ReferenceLine
      y={Math.round((latestCoverage / 100) * maxTotal)}
      stroke="#06b6d4"
      strokeDasharray="4 3"
      strokeWidth={1.5}
      label={{
        value: `${latestCoverage.toFixed(0)}% cov`,
        fill: '#06b6d4',
        fontSize: 8,
        position: 'insideTopRight'
      }}
    />
  )}
  ```
  Import `ReferenceLine` from recharts. Compute `maxTotal = Math.max(0, ...snapshots.map(s => s.total))`.
  When no coverage: no line rendered.

  **E — Adaptive projects (already working)**
  The per-project charts already map over `projects` from Allure API response — new projects auto-appear. No change needed here. Document this in code comments.

- **Context files to read**:
  - `src/features/dashboard/pages/TestResultsPage.tsx` — full current implementation
  - `src/features/dashboard/components/TestResultsProjectChart.tsx` — chart component

- **Acceptance criteria**:
  - [ ] Coverage stat card shows adoption % (e.g. 3/6 projects = 50%), appears first in stat row
  - [ ] "All Projects" aggregation uses latest run per project per date
  - [ ] All project charts render left=oldest, right=newest (`.reverse()` removed)
  - [ ] Coverage reference line visible on per-project charts when `latestCoverage != null`
  - [ ] Coverage line absent when coverage is null/unavailable
  - [ ] New Allure projects appear automatically on page load (no code changes required)
  - [ ] `TestResultsPage.test.tsx` updated for the new aggregation logic
  - [ ] No TypeScript errors

---

### Step 7: GitHub Actions Page — Commit Activity Panel (HomeUI)

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 4, 5, 6, 8, 9 (after Step 3)
- **Description**:
  Replace the two inaccurate "Commits / Month" and "Commits / Year" stat cards with a single **Commit Activity** chart panel that shows daily commit counts for the currently selected time range. The panel respects the existing `range` and `repoFilter` state on the page.

  **A — New API client function** in `src/api/monitoring.ts`:
  ```typescript
  export function githubCommitsOptions(params: {
    username: string
    date_from: string
    date_to: string
  }) {
    return queryOptions({ ... })
  }
  ```
  Define Zod schema for the response (see endpoint docs in the prompt).

  **B — New hook** `src/features/dashboard/hooks/useGithubCommits.ts`:
  ```typescript
  export function useGithubCommits(params: { username: string; date_from: string; date_to: string }) { ... }
  ```

  **C — Update `GitHubActionsPage.tsx`**:
  - Remove the two `analyticsMonth` / `analyticsYear` hook calls and their stat cards ("Commits / Month", "Commits / Year")
  - Derive `date_from` / `date_to` from the existing page `range` state:
    - `'7d'` → last 7 days
    - `'30d'` → last 30 days
    - `'90d'` → last 90 days
  - Call `useGithubCommits({ username: 'gregor', date_from, date_to })`
  - When `repoFilter` is set: use `by_repository` data filtered to that repo's contributions; otherwise use the top-level `days` array
  - Render a **`ChartPanel` titled "Commit Activity"** with a bar chart (`BarChart` from recharts):
    - X axis: date labels
    - Y axis: commit count
    - Bar fill: `#10b981`
    - Panel header right side: `{total_commits} commits` total count for the range
  - While loading: show `<PanelLoader />` inside the chart area (uses Step 3 component)
  - Place the panel alongside the existing "Success Rate Trend" / "Runs per Workflow" charts (2-column grid)

- **Context files to read**:
  - `src/features/dashboard/pages/GitHubActionsPage.tsx` — full file (range state, chartBackground style, ChartPanel usage pattern)
  - `src/api/monitoring.ts` — queryOptions factory pattern
  - `src/features/dashboard/hooks/useGithubAnalytics.ts` — hook pattern to replicate
  - `src/features/dashboard/components/ChartPanel.tsx` — ChartPanel props
  - HomeCollector `app/routers/github.py` — `/github/commits` endpoint signature and response shape

- **Acceptance criteria**:
  - [ ] "Commits / Month" and "Commits / Year" stat cards removed
  - [ ] "Commit Activity" chart panel added, shows daily bar chart for selected time range
  - [ ] Chart updates when `range` selector changes (7d / 30d / 90d)
  - [ ] Chart filters to selected repo when `repoFilter` is set
  - [ ] Total commit count shown in panel header
  - [ ] `<PanelLoader />` shown while data loads
  - [ ] `useGithubCommits` hook with unit test created
  - [ ] TypeScript types match API response schema

---

### Step 8: Usage Page — Network TX/RX Totals (HomeUI)

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 4, 5, 6, 7, 9 (after Step 3)
- **Description**:
  Remove the "Net ↓" (RX) and "Net ↑" (TX) stat cards from the top of `UsagePage`. Replace with two new cards showing total transferred bytes for the selected time range.

  **Remove**:
  ```tsx
  <StatCard label="Net ↓" value={...} />
  <StatCard label="Net ↑" value={...} />
  ```

  **Compute totals from the filtered `networkData` array** (cumulative counters → range total = last - first):
  ```typescript
  const filteredNetwork = history ? filterByRange(history.network_transfer, range) : []
  const netRxTotal = filteredNetwork.length >= 2
    ? filteredNetwork[filteredNetwork.length - 1].rx_bytes - filteredNetwork[0].rx_bytes
    : 0
  const netTxTotal = filteredNetwork.length >= 2
    ? filteredNetwork[filteredNetwork.length - 1].tx_bytes - filteredNetwork[0].tx_bytes
    : 0
  ```
  Note: If `rx_bytes`/`tx_bytes` are cumulative OS counters from Node Exporter (typical), `last - first` gives total transferred. If they are per-interval snapshots, use `sum(rx_bytes)` instead. Read the Prometheus metric type from `app/services/prometheus_service.py` to confirm — use the correct approach.

  **Add**:
  ```tsx
  <StatCard label="Net RX" value={history ? formatBytes(netRxTotal) : '—'} unit="total" />
  <StatCard label="Net TX" value={history ? formatBytes(netTxTotal) : '—'} unit="total" />
  ```

- **Context files to read**:
  - `src/features/dashboard/pages/UsagePage.tsx` — stat cards section (lines ~219-254)
  - HomeCollector `app/services/prometheus_service.py` — how `network_transfer` data is fetched and whether `rx_bytes`/`tx_bytes` are counters or gauges

- **Acceptance criteria**:
  - [ ] "Net ↓" and "Net ↑" stat cards removed
  - [ ] "Net RX" and "Net TX" stat cards added showing total for selected time range
  - [ ] Values update when time range is changed (e.g. switching from 1h to 7d shows different totals)
  - [ ] `UsagePage.test.tsx` updated
  - [ ] No TypeScript errors

---

### Step 9: Uptime Page — Full Width, Adaptive Timeline & Group Headers (HomeUI)

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 4, 5, 6, 7, 8 (after Step 3)
- **Description**:

  **A — Remove maxWidth constraint**

  In `UptimePage.tsx`, remove `maxWidth: 1200` from the outer div's style. The page should stretch to fill the available container width.

  **B — Adaptive heartbeat bar segments (range-driven)**

  `ServiceRow` always passes `segments` as the default (90) to `HeartbeatBar`. With 7d selected but 4 days of data, 86 empty slots appear on the left — visually the bar "goes left". Fix by passing a `segments` count derived from the selected time range:

  In `ServiceRow.tsx`, add a helper:
  ```typescript
  function rangeToSegments(range: string): number {
    const map: Record<string, number> = {
      '7d': 7, '14d': 14, '30d': 30, '60d': 60, '90d': 90,
    }
    return map[range] ?? 90
  }
  ```
  Pass `segments={rangeToSegments(range)}` to `<HeartbeatBar>`.

  Also update the footer label in `ServiceRow`:
  ```tsx
  // Before: {range} ago
  // After: use a readable label
  {range === '7d' ? '7 days ago' : range === '30d' ? '30 days ago' : `${range} ago`}
  ```

  **C — Group headers in uptime service list**

  Currently `UptimePage.tsx` flattens all groups and renders services without group labels. Update to show group section headers.

  Replace the flat render with a grouped render:
  ```tsx
  {groups.map((group) => (
    <div key={group.group} style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
      {/* Group header */}
      <div style={{ padding: '8px 0 4px 0' }}>
        <span style={{ fontSize: 11, fontWeight: 600, color: 'var(--muted-foreground)', textTransform: 'uppercase', letterSpacing: '0.08em' }}>
          {group.group}
        </span>
      </div>
      {/* Services in this group */}
      {group.services.map((service) => (
        <div key={service.service_name} style={{ backgroundColor: 'var(--card)', border: '1px solid var(--border)', borderRadius: 8, marginBottom: 8 }}>
          <ServiceRow service={service} heartbeatData={historyMap[service.service_name] ?? []} range={range} />
        </div>
      ))}
    </div>
  ))}
  ```
  The groups returned by the API are already correct after Step 2 (Pages, Services, Infrastructure).

  **D — HeartbeatBar segments test update**

  Update `HeartbeatBar.test.tsx` and `ServiceRow.test.tsx` to pass a `range` prop and verify segment count reflects the range.

- **Context files to read**:
  - `src/features/dashboard/pages/UptimePage.tsx` — full component
  - `src/features/dashboard/components/ServiceRow.tsx` — HeartbeatBar usage
  - `src/features/dashboard/components/HeartbeatBar.tsx` — segments prop behavior

- **Acceptance criteria**:
  - [ ] `maxWidth: 1200` removed — uptime page uses full available width
  - [ ] With range=7d and 4 days of data: bar shows 7 segments, 3 empty on left, 4 filled on right
  - [ ] Group headers visible: "Pages", "Services", "Infrastructure"
  - [ ] Services appear under correct group after Step 2 migration
  - [ ] `HeartbeatBar.test.tsx` and `ServiceRow.test.tsx` updated
  - [ ] No TypeScript errors

---

### Step 10: Commit, Push & Monitor (Both Projects)

- **Project**: HomeCollector + HomeUI
- **Parallel with**: —
- **Description**:
  After all steps complete and tests pass locally, commit and push both projects.

  **HomeCollector**:
  ```bash
  cd ~/HomeCollector
  PYTHONPATH=. pytest tests/ -v --cov=app --cov-fail-under=70
  git add -p   # stage selectively
  git commit -m "feat(github): dynamic org repo discovery; refactor(uptime): update service groups"
  git push origin main
  ```

  **HomeUI**:
  ```bash
  cd ~/HomeUI
  npm run test:ci   # verify ≥70% coverage
  git add -p
  git commit -m "feat(dashboard): monitoring improvements — panel layout, coverage tracking, loading UX, uptime grouping, network totals"
  git push origin main
  ```

  Monitor CI/CD pipelines on Discord and GitHub Actions for both projects.

  **For HomeCollector**: After deploy, run the Alembic migration on the server:
  ```bash
  ssh lab
  cd ~/HomeCollector
  docker compose exec api alembic upgrade head
  ```

- **Context files to read**:
  - `projects/homecollector.md` — pipeline and deployment steps
  - `projects/homeui.md` — pipeline and deployment steps

- **Acceptance criteria**:
  - [ ] HomeCollector tests pass (≥70% coverage)
  - [ ] HomeUI tests pass (≥70% coverage)
  - [ ] Both pipelines green (check Discord notifications)
  - [ ] Alembic migration applied on server
  - [ ] Live dashboard: service groups correct, coverage stats visible, Network panel full-width

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Dynamic GitHub repo discovery          → HomeCollector @ /Users/gregor/dev/922/HomeCollector
  Step 2: Update service groups + migration       → HomeCollector @ /Users/gregor/dev/922/HomeCollector

Wave 2 (sequential):
  Step 3: PanelLoader component                  → HomeUI @ /Users/gregor/dev/922/HomeUI
  (PanelLoader must exist before steps 4-9 import it)

Wave 3 (parallel, all after Step 3):
  Step 4: NetworkChart/DiskChart layout + container sort → HomeUI
  Step 5: SystemMetricsPanel coverage stat              → HomeUI
  Step 6: Test Results page full overhaul               → HomeUI
  Step 7: GitHub Actions commits endpoint               → HomeUI
  Step 8: Usage page network totals                     → HomeUI
  Step 9: Uptime page full-width + groups + segments    → HomeUI

Wave 4 (after all of Wave 3):
  Step 10: Commit, push, monitor pipelines, apply migration
```

---

## Post-Execution Checklist

- [ ] All HomeCollector tests pass (`pytest --cov-fail-under=70`)
- [ ] All HomeUI tests pass (`npm run test:ci`, ≥70% coverage)
- [ ] HomeCollector pipeline green (Discord notification)
- [ ] HomeUI pipeline green (Discord notification)
- [ ] `alembic upgrade head` run on server after HomeCollector deploy
- [ ] Uptime page shows groups: Pages / Services / Infrastructure
- [ ] Test Results page shows correct adoption-based coverage %
- [ ] All Projects chart shows oldest left, newest right
- [ ] Network I/O panel title is inside the card border
- [ ] GitHub commits stat cards use the new `/github/commits` endpoint
- [ ] No hardcoded `MONITORED_REPOS` in HomeCollector codebase
