# Executor Prompt — Step 5: Overview — Coverage Stat in SystemMetricsPanel

## Role
You are a Technical Executor Agent. Implement this step precisely, following all project conventions.

## Project
**HomeUI** — `/Users/gregor/dev/922/HomeUI`

## Mandatory reads before touching any code
1. `/Users/gregor/dev/922/Planner/projects/homeui.md` — stack, patterns, testing rules
2. `/Users/gregor/dev/922/HomeUI/CLAUDE.md` — project conventions
3. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/components/SystemMetricsPanel.tsx` — full file
4. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/components/SystemMetricsPanel.test.tsx` — existing tests
5. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/pages/OverviewPage.tsx` — how allure data is destructured and passed to SystemMetricsPanel
6. `/Users/gregor/dev/922/HomeUI/src/types/api/monitoring.ts` (or wherever `AllureProjectResult` type is defined) — confirm the `coverage_percent` field name

---

## What to implement

### Goal
The "TEST HEALTH" pill in `SystemMetricsPanel` currently shows only the pass rate. Add coverage display below it when coverage data is available.

### Change 1: `SystemMetricsPanel.tsx` — add `allureCoverage` prop

**Add the prop to the interface**:
```typescript
interface SystemMetricsPanelProps {
  data: SystemMetrics | undefined
  activeRuns: number
  queuedRuns: number
  allurePassRate: number
  allureTotalTests: number
  allureCoverage?: number | null   // ← add this
}
```

**Update the function signature** to destructure `allureCoverage`.

**Update the TEST HEALTH pill**. Currently it renders:
```tsx
<span style={{ ...valueStyle, color: ... }}>
  {String(Math.round(allurePassRate))}%
</span>
<span style={subStyle}>{String(allureTotalTests)} tests passing</span>
```

Change it to:
```tsx
<span style={{ ...valueStyle, color: ... }}>
  {String(Math.round(allurePassRate))}%
</span>
<span style={subStyle}>
  {allureCoverage != null
    ? `${allureCoverage.toFixed(0)}% cov · ${String(allureTotalTests)} passing`
    : `${String(allureTotalTests)} tests passing`}
</span>
```

The coverage value in the sub-line uses this color logic:
```typescript
const covColor = allureCoverage == null
  ? 'var(--muted-foreground)'
  : allureCoverage >= 80 ? '#10b981'
  : allureCoverage >= 60 ? '#f59e0b'
  : '#f43f5e'
```

If `allureCoverage != null`, render the sub-line text in `covColor`. If null, use the default `subStyle` color (muted).

Check the current `pillStyle.height` (it is `110`). If adding the coverage sub-line causes overflow, increase it slightly (e.g. to `120`). Read the current value first and make a judgment.

### Change 2: `OverviewPage.tsx` — compute and pass coverage

Find where allure data is destructured:
```typescript
const allureProjects = allure.data?.projects ?? []
const allureTotalTests = allure.data?.total_passed ?? 0
const allurePassRate = allure.data?.overall_pass_rate_percent ?? 0
```

Add below:
```typescript
// Average coverage across projects that report it
const coverageProjects = allureProjects.filter((p) => p.coverage_percent != null)
const allureCoverage: number | null = coverageProjects.length > 0
  ? coverageProjects.reduce((s, p) => s + (p.coverage_percent ?? 0), 0) / coverageProjects.length
  : null
```

Then pass it to `SystemMetricsPanel`:
```tsx
<SystemMetricsPanel
  data={system.data}
  activeRuns={activeRuns}
  queuedRuns={queuedRuns}
  allurePassRate={allurePassRate}
  allureTotalTests={allureTotalTests}
  allureCoverage={allureCoverage}   // ← add this
/>
```

### Update tests: `SystemMetricsPanel.test.tsx`

Add test cases:
- When `allureCoverage` is a number (e.g. 85), verify coverage appears in the rendered output
- When `allureCoverage` is null/undefined, verify only the tests passing count appears (no coverage text)

Look at the existing tests to understand the render setup and follow the same pattern.

---

## Run tests
```bash
cd /Users/gregor/dev/922/HomeUI
npm run test:ci
```
Fix any failures. Ensure coverage ≥70%.

## Commit & Push
```bash
git add src/features/dashboard/components/SystemMetricsPanel.tsx \
        src/features/dashboard/components/SystemMetricsPanel.test.tsx \
        src/features/dashboard/pages/OverviewPage.tsx
git commit -m "feat(overview): add coverage % to TEST HEALTH stat pill"
git push origin main
```

## Report format
```
=== STEP 5 COMPLETE ===
Plan: plans/2026-03-19-monitoring-dashboard-improvements.md
Step: 5 - Overview Coverage Stat
Status: done / blocked / partial
Changes: [files modified]
Tests: pass / fail (details)
Notes: [coverage_percent field name confirmed, pill height adjustment if made]
```
