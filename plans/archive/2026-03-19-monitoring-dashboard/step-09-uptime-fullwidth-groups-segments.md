# Executor Prompt — Step 9: Uptime Page — Full Width, Adaptive Segments & Group Headers

## Role
You are a Technical Executor Agent. Implement this step precisely, following all project conventions.

## Project
**HomeUI** — `/Users/gregor/dev/922/HomeUI`

## Mandatory reads before touching any code
1. `/Users/gregor/dev/922/Planner/projects/homeui.md` — stack, patterns, testing rules
2. `/Users/gregor/dev/922/HomeUI/CLAUDE.md` — project conventions
3. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/pages/UptimePage.tsx` — full file
4. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/pages/UptimePage.test.tsx` — existing tests
5. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/components/ServiceRow.tsx` — full file (HeartbeatBar usage)
6. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/components/ServiceRow.test.tsx` — existing tests
7. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/components/HeartbeatBar.tsx` — full file
8. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/components/HeartbeatBar.test.tsx` — existing tests

---

## What to implement

This step has three sub-changes.

---

### Sub-change A: Remove `maxWidth` constraint from UptimePage

In `UptimePage.tsx`, the outer wrapper div has `maxWidth: 1200`. Remove it so the page stretches to fill the full container width.

Find:
```tsx
<div
  className="flex flex-col"
  style={{ padding: 24, gap: 20, maxWidth: 1200 }}
>
```

Replace with:
```tsx
<div
  className="flex flex-col"
  style={{ padding: 24, gap: 20 }}
>
```

---

### Sub-change B: Adaptive heartbeat bar segments

**The problem**: `ServiceRow` always passes the default `segments={90}` to `HeartbeatBar`. When the user selects 7 days but only 4 days of data exist, the bar renders 90 slots — 86 empty (gray) on the left, 4 filled on the right. Visually the data "goes to the left". The bar should show only as many slots as the selected range, so 4 days of data fills most of the bar.

**How `HeartbeatBar` padding works** (from reading the component):
```
padded[i] = data[i - (segments - data.length)]
```
If `segments=7` and `data.length=4`:
- slots 0–2 → undefined (empty/gray)
- slots 3–6 → data[0..3] (filled, right side)

This is correct — data always anchors to the right (most recent = rightmost). The fix is just reducing `segments` to match the selected range.

**Changes to `ServiceRow.tsx`**:

Add a helper function at the top of the file (before the component):
```typescript
function rangeToSegments(range: string): number {
  const map: Record<string, number> = {
    '7d': 7,
    '14d': 14,
    '30d': 30,
    '60d': 60,
    '90d': 90,
  }
  return map[range] ?? 90
}
```

In the `ServiceRow` component, pass segments to `HeartbeatBar`:
```tsx
// Before:
<HeartbeatBar data={heartbeatData} />

// After:
<HeartbeatBar data={heartbeatData} segments={rangeToSegments(range)} />
```

Also update the footer label to be more readable. Find:
```tsx
<span style={{ fontSize: 11, color: 'var(--muted-foreground)' }}>
  {range} ago
</span>
```

This currently renders "90d ago" even when 7d is selected. Leave this as-is IF after the segments fix the label is already consistent (7d → "7d ago"). Only change the label format if it looks wrong after testing.

---

### Sub-change C: Group headers in uptime service list

**Current render** in `UptimePage.tsx` (find the groups mapping section):
```tsx
{groups.length > 0 ? (
  <div className="flex flex-col" style={{ gap: 0 }}>
    {groups.map((group) =>
      group.services.map((service) => (
        <div key={service.service_name} style={{ ... }}>
          <ServiceRow ... />
        </div>
      ))
    )}
  </div>
) : ...}
```

**Replace with grouped render that shows section headers**:
```tsx
{groups.length > 0 ? (
  <div className="flex flex-col" style={{ gap: 24 }}>
    {groups.map((group) => (
      <div key={group.group} className="flex flex-col" style={{ gap: 0 }}>
        {/* Group header */}
        <div style={{ paddingBottom: 8 }}>
          <span
            style={{
              fontSize: 11,
              fontWeight: 600,
              color: 'var(--muted-foreground)',
              textTransform: 'uppercase',
              letterSpacing: '0.08em',
            }}
          >
            {group.group}
          </span>
        </div>
        {/* Services */}
        {group.services.map((service) => (
          <div
            key={service.service_name}
            style={{
              backgroundColor: 'var(--card)',
              border: '1px solid var(--border)',
              borderRadius: 8,
              marginBottom: 8,
            }}
          >
            <ServiceRow
              service={service}
              heartbeatData={historyMap[service.service_name] ?? []}
              range={range}
            />
          </div>
        ))}
      </div>
    ))}
  </div>
) : ...}
```

The group names ("Pages", "Services", "Infrastructure") come from the API response after the HomeCollector Step 2 migration. The frontend renders whatever group names the API returns — it does not hardcode them.

---

### Update tests

**`ServiceRow.test.tsx`**: Add a test that with `range="7d"`, the `HeartbeatBar` receives `segments={7}`. You can test this indirectly via DOM (the rendered bar has 7 segment divs) or by checking the prop flow. Follow the existing HeartbeatBar test pattern using `container.firstChild`.

**`UptimePage.test.tsx`**: Add a test that when the API returns groups, the group names are rendered as headers. Look at the existing mock structure to understand how to mock `useUptimeStatus`.

**`HeartbeatBar.test.tsx`**: Existing tests should still pass — no changes to HeartbeatBar itself.

---

## Run tests
```bash
cd /Users/gregor/dev/922/HomeUI
npm run test:ci
```
Fix any failures. Ensure coverage ≥70%.

## Commit & Push
```bash
git add src/features/dashboard/pages/UptimePage.tsx \
        src/features/dashboard/pages/UptimePage.test.tsx \
        src/features/dashboard/components/ServiceRow.tsx \
        src/features/dashboard/components/ServiceRow.test.tsx
git commit -m "fix(uptime): full-width layout; adaptive heartbeat segments by range; group section headers"
git push origin main
```

## Report format
```
=== STEP 9 COMPLETE ===
Plan: plans/2026-03-19-monitoring-dashboard-improvements.md
Step: 9 - Uptime Full Width, Segments & Groups
Status: done / blocked / partial
Changes: [files modified]
Tests: pass / fail (details)
Notes: [range values supported, group rendering approach]
```
