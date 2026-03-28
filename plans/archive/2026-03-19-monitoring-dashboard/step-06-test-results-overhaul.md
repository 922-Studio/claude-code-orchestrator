# Executor Prompt — Step 6: Test Results Page — Coverage Stat, Aggregation Fix & Coverage Overlay

## Role
You are a Technical Executor Agent. Implement this step precisely, following all project conventions.

## Project
**HomeUI** — `/Users/gregor/dev/922/HomeUI`

## Mandatory reads before touching any code
1. `/Users/gregor/dev/922/Planner/projects/homeui.md` — stack, patterns, testing rules
2. `/Users/gregor/dev/922/HomeUI/CLAUDE.md` — project conventions
3. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/pages/TestResultsPage.tsx` — full file (current implementation)
4. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/pages/TestResultsPage.test.tsx` — existing tests
5. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/components/TestResultsProjectChart.tsx` — chart component
6. `/Users/gregor/dev/922/HomeUI/src/types/api/monitoring.ts` — `AllureHistorySnapshot`, `AllureProjectResult` types

---

## What to implement

This step has four distinct sub-changes. Implement them all in this step.

---

### Sub-change A: Overall coverage — adoption-based formula

**Current formula** (in `TestResultsPage.tsx`):
Averages the `coverage_percent` values of projects that have them.

**New formula**: Percentage of total projects that have coverage reporting at all.
```typescript
// Replace the overallCoverage calculation:
const overallCoverage: number | null = projects.length > 0
  ? (projects.filter((p) => p.coverage_percent != null).length / projects.length) * 100
  : null
```
Example: 3 out of 6 projects report coverage → `overallCoverage = 50`.

**Move Coverage StatCard to first position** in the summary stats row:
```tsx
{/* Put Coverage first */}
{overallCoverage != null && (
  <StatCard
    label="Coverage"
    value={`${overallCoverage.toFixed(0)}%`}
    status={overallCoverage >= 80 ? 'ok' : overallCoverage >= 60 ? 'warn' : 'error'}
  />
)}
<StatCard label="Total Tests" value={String(totalTests)} status="ok" />
<StatCard label="Passed" ... />
...
```

---

### Sub-change B: Fix "All Projects" aggregation — one run per project per day

**The bug**: The current `aggregatedSnapshots` useMemo sums ALL runs across all projects for a given date. If one project runs CI 5 times on the same day, all 5 runs' test counts are summed. The correct logic is: for each date, take only the LATEST run per project, then sum across projects.

**Replace the entire `aggregatedSnapshots` useMemo** with:

```typescript
const aggregatedSnapshots = useMemo((): AllureHistorySnapshot[] => {
  // Step 1: For each (project, date), keep only the latest snapshot
  const latestPerProjectPerDate = new Map<string, AllureHistorySnapshot>()
  for (const proj of historyProjects) {
    for (const snap of proj.reports) {
      if (!snap.created_at) continue
      const dateKey = new Date(snap.created_at).toISOString().slice(0, 10)
      const mapKey = `${proj.project_id}::${dateKey}`
      const existing = latestPerProjectPerDate.get(mapKey)
      if (!existing || new Date(snap.created_at) > new Date(existing.created_at)) {
        latestPerProjectPerDate.set(mapKey, snap)
      }
    }
  }

  // Step 2: Group by date and aggregate across projects (one entry per project per date)
  const dateMap = new Map<string, {
    passed: number; failed: number; broken: number;
    skipped: number; total: number; created_at: string
  }>()
  for (const [mapKey, snap] of latestPerProjectPerDate) {
    const dateKey = mapKey.split('::')[1]
    const existing = dateMap.get(dateKey)
    if (existing) {
      existing.passed += snap.passed
      existing.failed += snap.failed
      existing.broken += snap.broken
      existing.skipped += snap.skipped
      existing.total += snap.total
    } else {
      dateMap.set(dateKey, {
        passed: snap.passed,
        failed: snap.failed,
        broken: snap.broken,
        skipped: snap.skipped,
        total: snap.total,
        created_at: snap.created_at,
      })
    }
  }

  // Step 3: Sort ascending (oldest left → newest right) and shape as AllureHistorySnapshot[]
  return Array.from(dateMap.values())
    .sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime())
    .map((d, i): AllureHistorySnapshot => ({
      report_id: `agg-${String(i)}`,
      created_at: d.created_at,
      passed: d.passed,
      failed: d.failed,
      broken: d.broken,
      skipped: d.skipped,
      unknown: 0,
      total: d.total,
      pass_rate_percent: d.total > 0 ? (d.passed / d.total) * 100 : 0,
      duration_ms: 0,
    }))
}, [historyProjects])
```

---

### Sub-change C: Chart direction — oldest left, newest right

In `TestResultsProjectChart.tsx`, the `chartData` useMemo ends with `.reverse()`. This flips the order so the chart shows newest on the left, oldest on the right.

**Remove `.reverse()`**:
```typescript
// Before:
const chartData = useMemo(() => {
  return snapshots
    .filter((s) => s.created_at != null)
    .map((s): ChartDataPoint => ({ ... }))
    .reverse()   // ← REMOVE THIS LINE
}, [snapshots])

// After:
const chartData = useMemo(() => {
  return snapshots
    .filter((s) => s.created_at != null)
    .map((s): ChartDataPoint => ({ ... }))
}, [snapshots])
```

The aggregated snapshots (Step B) are already sorted ascending, so all charts now render left=oldest, right=newest.

---

### Sub-change D: Coverage reference line on per-project charts

In `TestResultsProjectChart.tsx`, add a coverage reference line when `latestCoverage` is available.

**Add import**:
```typescript
import {
  Area, XAxis, YAxis, CartesianGrid, ResponsiveContainer, Tooltip, AreaChart,
  ReferenceLine,   // ← add this
} from 'recharts'
```

**Compute maxTotal inside the component** (before the return):
```typescript
const maxTotal = useMemo(
  () => Math.max(0, ...snapshots.map((s) => s.total)),
  [snapshots]
)
```

**Add `ReferenceLine` inside the `AreaChart`** (after the `<Area>` elements):
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
      position: 'insideTopRight',
    }}
  />
)}
```

**When `latestCoverage` is null**: No `ReferenceLine` rendered (the condition prevents it).

**For the "All Projects" chart**: It is called with `latestCoverage` not passed (undefined), so no coverage line appears there — correct behaviour.

---

### Update tests

In `TestResultsPage.test.tsx`, update or add tests:
- The new aggregation: given 2 projects with 2 runs each on the same date, only the latest run per project per date is counted
- The overall coverage stat uses adoption formula (e.g. 2/4 projects with coverage → 50%)
- Coverage stat card appears first in the row when available

---

## Run tests
```bash
cd /Users/gregor/dev/922/HomeUI
npm run test:ci
```
Fix any failures. Ensure coverage ≥70%.

## Commit & Push
```bash
git add src/features/dashboard/pages/TestResultsPage.tsx \
        src/features/dashboard/pages/TestResultsPage.test.tsx \
        src/features/dashboard/components/TestResultsProjectChart.tsx
git commit -m "fix(test-results): correct aggregation logic; adoption-based coverage; chart direction oldest→newest; coverage reference line"
git push origin main
```

## Report format
```
=== STEP 6 COMPLETE ===
Plan: plans/2026-03-19-monitoring-dashboard-improvements.md
Step: 6 - Test Results Page Overhaul
Status: done / blocked / partial
Changes: [files modified]
Tests: pass / fail (details)
Notes: [AllureHistorySnapshot type fields confirmed, any type adjustments]
```
