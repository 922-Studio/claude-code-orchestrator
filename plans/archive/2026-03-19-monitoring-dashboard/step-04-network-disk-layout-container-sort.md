# Executor Prompt — Step 4: Network/Disk Panel Layout & Container Sort

## Role
You are a Technical Executor Agent. Implement this step precisely, following all project conventions.

## Project
**HomeUI** — `/Users/gregor/dev/922/HomeUI`

## Mandatory reads before touching any code
1. `/Users/gregor/dev/922/Planner/projects/homeui.md` — stack, patterns, testing rules
2. `/Users/gregor/dev/922/HomeUI/CLAUDE.md` — project conventions
3. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/components/NetworkChart.tsx` — full file
4. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/components/NetworkChart.test.tsx` — existing tests
5. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/components/DiskChart.tsx` — full file (find path, likely alongside NetworkChart)
6. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/components/DiskChart.test.tsx` — existing tests
7. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/pages/OverviewPage.tsx` — full file (container slice + NetworkChart/DiskChart usage)

---

## What to implement

### Change A: NetworkChart — title inside card border

**Current structure** (simplified):
```
<div style={{ gap: 12, padding: '0 20px 20px 20px' }}>    ← outer wrapper (NO border)
  <div>  ← title row ("Network I/O" + LIVE badge)
  <div style={{ backgroundColor: 'var(--card)', border: '1px solid var(--border)' }}>  ← chart card
    ...legend + chart + totals footer...
```

**Target structure** (title inside the card border, matching Docker panel style):
```
<div style={{ backgroundColor: 'var(--card)', border: '1px solid var(--border)', borderRadius: 8 }}>
  <div style={{ padding: '12px 16px', borderBottom: '1px solid var(--border)' }}>  ← title row inside card
    [green accent bar] "Network I/O" [dot] [LIVE badge]
  <div style={{ padding: '16px' }}>  ← chart content area (legend + chart + totals)
    ...
```

**Implementation**:
- The outer `<div>` on the component's return becomes the card container: add `backgroundColor: 'var(--card)', border: '1px solid var(--border)', borderRadius: 8`
- Remove `padding: '0 20px 20px 20px'` from the outer wrapper — the parent (`OverviewPage`) already provides horizontal padding via its section wrapper
- Move the title row INSIDE the outer card div; add a `borderBottom: '1px solid var(--border)'` divider between title and chart content
- The inner chart card div (which currently has its own border) should become a plain `padding: 16px` section — remove the inner border/card style (it's now redundant, the outer card provides the border)
- Keep the LIVE dot and badge in the title row exactly as-is

After this change the component's JSX wrapping should look like:
```tsx
return (
  <div style={{ backgroundColor: 'var(--card)', border: '1px solid var(--border)', borderRadius: 8, display: 'flex', flexDirection: 'column' }}>
    {/* Title row */}
    <div className="flex items-center justify-between" style={{ padding: '12px 16px', borderBottom: '1px solid var(--border)' }}>
      ... title content unchanged ...
    </div>
    {/* Chart content */}
    <div style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 12 }}>
      ... legend, chart area, totals footer all move here ...
    </div>
  </div>
)
```

### Change B: DiskChart — same pattern as NetworkChart

Read `DiskChart.tsx` and apply the identical structural change:
- Outer div becomes the card (with border)
- Title ("Disk Space" or whatever label it uses) moves inside the card with a `borderBottom` divider
- Remove any outer padding that duplicates the parent's padding
- Inner chart area becomes a plain padded section

### Change C: OverviewPage — sort containers by CPU

In `OverviewPage.tsx`, the container list is sliced without sorting. Find this section:
```typescript
const containerList = containers.data?.containers ?? []
const visibleContainers = containerList.slice(0, MAX_OVERVIEW_CONTAINERS)
```

Replace with:
```typescript
const containerList = [...(containers.data?.containers ?? [])].sort(
  (a, b) => (b.cpu_percent ?? 0) - (a.cpu_percent ?? 0)
)
const visibleContainers = containerList.slice(0, MAX_OVERVIEW_CONTAINERS)
```

Note: `ContainerGrid` (used in `UptimePage`) already sorts by CPU — do NOT change it.

### Update existing tests

`NetworkChart.test.tsx` and `DiskChart.test.tsx` test for the presence/absence of "Collecting data..." text. Verify they still pass after the structural refactor. If any snapshot or structure tests break, update them to match the new DOM structure.

---

## Run tests
```bash
cd /Users/gregor/dev/922/HomeUI
npm run test:ci
```
Fix any failures. Ensure coverage ≥70%.

## Commit & Push
```bash
git add src/features/dashboard/components/NetworkChart.tsx \
        src/features/dashboard/components/DiskChart.tsx \
        src/features/dashboard/pages/OverviewPage.tsx
git commit -m "fix(dashboard): title inside card border for Network/Disk panels; sort containers by CPU"
git push origin main
```

## Report format
```
=== STEP 4 COMPLETE ===
Plan: plans/2026-03-19-monitoring-dashboard-improvements.md
Step: 4 - Network/Disk Panel Layout & Container Sort
Status: done / blocked / partial
Changes: [files modified]
Tests: pass / fail (details)
Notes: [structural changes made, any visual concerns]
```
