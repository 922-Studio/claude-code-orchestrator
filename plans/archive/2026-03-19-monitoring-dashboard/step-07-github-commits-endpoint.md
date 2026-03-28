# Executor Prompt — Step 7: GitHub Actions Page — Commit Activity Panel

## Role
You are a Technical Executor Agent. Implement this step precisely, following all project conventions.

## Project
**HomeUI** — `/Users/gregor/dev/922/HomeUI`

## Mandatory reads before touching any code
1. `/Users/gregor/dev/922/Planner/projects/homeui.md` — stack, patterns, testing rules (especially API isolation and queryOptions pattern)
2. `/Users/gregor/dev/922/HomeUI/CLAUDE.md` — project conventions
3. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/pages/GitHubActionsPage.tsx` — full file
4. `/Users/gregor/dev/922/HomeUI/src/api/monitoring.ts` — queryOptions factory pattern and Zod schemas in use
5. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/hooks/useGithubAnalytics.ts` — hook pattern to replicate
6. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/components/ChartPanel.tsx` — ChartPanel props and usage
7. `/Users/gregor/dev/922/HomeUI/src/types/api/monitoring.ts` — type definitions to extend
8. `/Users/gregor/dev/922/HomeCollector/app/routers/github.py` — `/github/commits` endpoint signature

---

## Context: the commits endpoint

HomeCollector has a new endpoint already deployed:
```
GET /api/monitoring/github/commits
Query params:
  username:  string     (required)
  date_from: YYYY-MM-DD (optional, defaults to 30 days ago)
  date_to:   YYYY-MM-DD (optional, defaults to today)

Response:
{
  "total_commits": 42,
  "username": "gregor",
  "period_from": "2026-03-01",
  "period_to": "2026-03-19",
  "days": [
    { "date": "2026-03-01", "commit_count": 5 },
    { "date": "2026-03-02", "commit_count": 3 }
  ],
  "by_repository": [
    {
      "repo": "922-Studio/HomeAPI",
      "total_commits": 20,
      "contributions": [
        { "date": "2026-03-01", "commit_count": 3 }
      ]
    }
  ]
}
```

---

## What to implement

### Step 1: Add Zod schemas / types

Read `src/types/api/monitoring.ts` and add the response types for this endpoint. Follow whatever pattern already exists in the file (Zod schemas or plain TypeScript interfaces):

```typescript
// CommitContributionDay
{ date: string; commit_count: number }

// CommitContributionRepo
{ repo: string; total_commits: number; contributions: CommitContributionDay[] }

// CommitActivityResponse
{
  total_commits: number
  username: string
  period_from: string
  period_to: string
  days: CommitContributionDay[]
  by_repository: CommitContributionRepo[]
}
```

### Step 2: Add API query function to `src/api/monitoring.ts`

Follow the existing `queryOptions` factory pattern exactly. Add:
```typescript
export function githubCommitsOptions(params: {
  username: string
  date_from: string
  date_to: string
}) {
  return queryOptions({
    queryKey: ['github', 'commits', params],
    queryFn: async () => {
      const sp = new URLSearchParams({
        username: params.username,
        date_from: params.date_from,
        date_to: params.date_to,
      })
      const response = await http.get<CommitActivityResponse>(
        `/api/monitoring/github/commits?${sp.toString()}`
      )
      // parse with Zod if project uses it, otherwise return response.data
      return response.data
    },
    staleTime: 5 * 60 * 1000,
  })
}
```

Use the same HTTP client instance and error handling as the other queries in the file.

### Step 3: New hook `src/features/dashboard/hooks/useGithubCommits.ts`

```typescript
import { useQuery } from '@tanstack/react-query'
import { githubCommitsOptions } from '@/api/monitoring'

export function useGithubCommits(params: {
  username: string
  date_from: string
  date_to: string
}) {
  return useQuery(githubCommitsOptions(params))
}
```

### Step 4: New hook test `src/features/dashboard/hooks/useGithubCommits.test.ts`

Follow the pattern of the nearest existing hook test. At minimum:
- Test that the hook queries the correct endpoint
- Test that `total_commits` is accessible from the returned data

### Step 5: Update `GitHubActionsPage.tsx`

**A — Remove the two old commit-related hook calls**

Find and remove these lines (around lines 447–451):
```typescript
const analyticsMonth = useGithubAnalytics('30d', repoFilter || undefined)
const analyticsYear = useGithubAnalytics('365d', repoFilter || undefined)
const commitsMonth = analyticsMonth.data?.total_runs ?? 0
const commitsYear = analyticsYear.data?.total_runs ?? 0
```

**B — Remove the two stat cards**

Find and remove from the StatCards section:
```tsx
<StatCard label="Commits / Month" value={String(commitsMonth)} />
<StatCard label="Commits / Year" value={String(commitsYear)} />
```

**C — Add date range computation**

Add a helper (at the top of the component, before hooks) to derive `date_from` and `date_to` from the existing `range` state:
```typescript
function rangeToDates(range: TimeRange): { date_from: string; date_to: string } {
  const today = new Date()
  const daysMap: Record<string, number> = { '7d': 7, '30d': 30, '90d': 90 }
  const days = daysMap[range] ?? 30
  const from = new Date(today.getTime() - days * 24 * 60 * 60 * 1000)
  return {
    date_from: from.toISOString().slice(0, 10),
    date_to: today.toISOString().slice(0, 10),
  }
}
```

**D — Add the `useGithubCommits` hook call**

```typescript
const { date_from, date_to } = useMemo(() => rangeToDates(range), [range])
const commitsQuery = useGithubCommits({ username: 'gregor', date_from, date_to })
```

**E — Derive chart data from response**

When `repoFilter` is set, look up the repo's daily contributions from `by_repository`; otherwise use the top-level `days` array:
```typescript
const commitChartData = useMemo(() => {
  if (!commitsQuery.data) return []
  let days = commitsQuery.data.days

  if (repoFilter) {
    const repoData = commitsQuery.data.by_repository.find(
      (r) => r.repo === repoFilter || r.repo.endsWith(`/${repoFilter}`)
    )
    days = repoData?.contributions ?? []
  }

  return days.map((d) => ({
    date: new Date(d.date).toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit' }),
    commits: d.commit_count,
  }))
}, [commitsQuery.data, repoFilter])

const totalCommits = commitsQuery.data?.total_commits ?? 0
```

**F — Add the Commit Activity chart panel**

Place it in the **existing 2-column chart grid** alongside "Success Rate Trend" and "Runs per Workflow". Read `GitHubActionsPage.tsx` to find the grid div and insert the new panel there.

```tsx
<ChartPanel
  title="Commit Activity"
  subtitle={`${String(totalCommits)} commits`}
>
  <div style={{ ...chartBackground, height: 160 }}>
    {commitsQuery.isLoading ? (
      <PanelLoader />
    ) : commitChartData.length > 1 ? (
      <ResponsiveContainer width="100%" height={160}>
        <BarChart data={commitChartData} margin={{ top: 5, right: 10, left: 0, bottom: 0 }}>
          <CartesianGrid stroke="var(--border)" strokeOpacity={0.4} vertical={false} />
          <XAxis
            dataKey="date"
            tick={{ fill: '#6b7280', fontSize: 9 }}
            axisLine={false}
            tickLine={false}
            interval="preserveStartEnd"
          />
          <YAxis
            tick={{ fill: '#6b7280', fontSize: 9 }}
            axisLine={false}
            tickLine={false}
            width={25}
            allowDecimals={false}
          />
          <Tooltip
            contentStyle={chartTooltipStyle}
            labelStyle={{ color: 'var(--card-foreground)' }}
            formatter={(value) => [String(value), 'Commits']}
            cursor={{ fill: 'var(--border)', fillOpacity: 0.3 }}
          />
          <Bar dataKey="commits" fill="#10b981" fillOpacity={0.85} radius={[3, 3, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    ) : (
      <ChartPlaceholder loading={false} />
    )}
  </div>
</ChartPanel>
```

Make sure `Bar` and `BarChart` are already imported from recharts (they likely are — check the existing imports). Import `PanelLoader` from `../components/PanelLoader`.

Read `ChartPanel.tsx` to confirm the `subtitle` prop exists and how it renders. If `ChartPanel` doesn't support a `subtitle` prop, use a different approach for showing the total count (e.g. add it to the title string, or render a small span inside the panel).

**G — Update `isLoading`** if needed to avoid the page-level loading state masking the panel's own loading state. The panel uses `commitsQuery.isLoading` directly — the page-level `isLoading` does not need to include commits loading.

---

## Run tests
```bash
cd /Users/gregor/dev/922/HomeUI
npm run test:ci
```
Fix any failures. Ensure coverage ≥70%.

## Commit & Push
```bash
git add src/api/monitoring.ts \
        src/types/api/monitoring.ts \
        src/features/dashboard/hooks/useGithubCommits.ts \
        src/features/dashboard/hooks/useGithubCommits.test.ts \
        src/features/dashboard/pages/GitHubActionsPage.tsx
git commit -m "feat(github): Commit Activity panel with daily bar chart for selected time range

Replaces Commits/Month and Commits/Year stat cards with a Commit Activity
chart panel that shows daily commit counts for the active time range filter.
Respects repo filter. Uses /api/monitoring/github/commits endpoint."
git push origin main
```

## Report format
```
=== STEP 7 COMPLETE ===
Plan: plans/2026-03-19-monitoring-dashboard-improvements.md
Step: 7 - GitHub Commit Activity Panel
Status: done / blocked / partial
Changes: [files modified]
Tests: pass / fail (details)
Notes: [ChartPanel subtitle prop present/absent, repo filter matching logic used]
```
