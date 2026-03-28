# Executor Prompt — Step 3: Reusable PanelLoader Component

## Role
You are a Technical Executor Agent. Implement this step precisely, following all project conventions.

## Project
**HomeUI** — `/Users/gregor/dev/922/HomeUI`

## Mandatory reads before touching any code
1. `/Users/gregor/dev/922/Planner/projects/homeui.md` — stack, patterns, testing rules
2. `/Users/gregor/dev/922/HomeUI/CLAUDE.md` — project conventions and architecture
3. `/Users/gregor/dev/922/HomeUI/src/components/ui/LoadingScreen.tsx` — animation pattern to replicate
4. `/Users/gregor/dev/922/HomeUI/src/components/ui/LoadingScreen.test.tsx` — test pattern to follow
5. `/Users/gregor/dev/922/HomeUI/src/index.css` — confirm `loading-spinner` and `loading-dot` CSS animation classes exist
6. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/pages/UsagePage.tsx` — ChartPlaceholder to update
7. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/pages/GitHubActionsPage.tsx` — ChartPlaceholder to update
8. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/pages/TestResultsPage.tsx` — loading state to update
9. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/pages/UptimePage.tsx` — loading badge to update

---

## What to implement

### Goal
Create a compact inline loading animation component for dashboard panels. Steps 4–9 all import and use this component, so it must be created first.

### New file: `src/features/dashboard/components/PanelLoader.tsx`

The component must:
- Accept an optional `height` prop (default: `120`)
- Render a div centered at the given height
- Show the same arc + dots animation as `LoadingScreen` but at smaller scale (48px spinner instead of 80px)
- Use existing `loading-spinner` and `loading-dot` CSS classes from `index.css`
- No overlay, no backdrop — pure inline element

```tsx
interface PanelLoaderProps {
  height?: number
}

export function PanelLoader({ height = 120 }: PanelLoaderProps) {
  return (
    <div
      className="flex items-center justify-center"
      style={{ height }}
    >
      <div style={{ position: 'relative', width: 48, height: 48 }}>
        {/* Spinning gradient arc — same gradient as LoadingScreen, scaled to 48px */}
        <svg
          className="loading-spinner absolute inset-0"
          style={{ width: 48, height: 48 }}
          viewBox="0 0 80 80"
          fill="none"
          role="img"
          aria-label="Loading"
        >
          <defs>
            <linearGradient id="panel-loader-grad" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stopColor="#6366f1" />
              <stop offset="100%" stopColor="#06b6d4" />
            </linearGradient>
          </defs>
          <path
            d="M40 3 A37 37 0 0 1 77 40"
            stroke="url(#panel-loader-grad)"
            strokeWidth="3"
            strokeLinecap="round"
            fill="none"
          />
        </svg>
        {/* Pulsing dots */}
        <div className="absolute inset-0 flex items-center justify-center gap-1">
          <span className="loading-dot" style={{ width: 5, height: 5, borderRadius: '50%', backgroundColor: '#6366f1' }} />
          <span className="loading-dot" style={{ width: 5, height: 5, borderRadius: '50%', backgroundColor: '#6366f1', animationDelay: '0.2s' }} />
          <span className="loading-dot" style={{ width: 5, height: 5, borderRadius: '50%', backgroundColor: '#6366f1', animationDelay: '0.4s' }} />
        </div>
      </div>
    </div>
  )
}
```

**Important**: Verify that `loading-spinner` (spin animation) and `loading-dot` (pulse/opacity animation) CSS classes are defined in `src/index.css` before using them. If the class names differ, match what's actually in the CSS.

### New file: `src/features/dashboard/components/PanelLoader.test.tsx`

```tsx
import { describe, it, expect } from 'vitest'
import { screen } from '@testing-library/react'
import { renderWithProviders } from '@/test/test-utils'
import { PanelLoader } from './PanelLoader'

describe('PanelLoader', () => {
  it('renders the loading svg', () => {
    renderWithProviders(<PanelLoader />)
    expect(screen.getByRole('img', { name: 'Loading' })).toBeInTheDocument()
  })

  it('applies custom height', () => {
    const { container } = renderWithProviders(<PanelLoader height={60} />)
    const outer = container.firstChild as HTMLElement
    expect(outer).toHaveStyle({ height: '60px' })
  })
})
```

### Replace "Loading..." text across four files

**`UsagePage.tsx`** — find the `ChartPlaceholder` function at the bottom of the file:
```tsx
// Before:
function ChartPlaceholder({ loading }: { loading: boolean }) {
  return (
    <div className="flex items-center justify-center" style={{ height: '100%', fontSize: 11, color: 'var(--muted-foreground)' }}>
      {loading ? 'Loading...' : 'No data available'}
    </div>
  )
}

// After:
import { PanelLoader } from './PanelLoader'

function ChartPlaceholder({ loading }: { loading: boolean }) {
  if (loading) return <PanelLoader />
  return (
    <div className="flex items-center justify-center" style={{ height: '100%', fontSize: 11, color: 'var(--muted-foreground)' }}>
      No data available
    </div>
  )
}
```

**`GitHubActionsPage.tsx`** — same pattern, same `ChartPlaceholder` function at the bottom.

**`TestResultsPage.tsx`** — find the loading state div:
```tsx
// Before:
{isLoading && (
  <div className="flex items-center justify-center" style={{ padding: 40, fontSize: 12, color: 'var(--muted-foreground)' }}>
    Loading test results...
  </div>
)}

// After:
{isLoading && <PanelLoader height={80} />}
```

**`UptimePage.tsx`** — find the "Loading..." badge in the header section:
```tsx
// Before:
{isLoading && (
  <span style={{ fontSize: 10, color: 'var(--muted-foreground)', backgroundColor: 'var(--card)', border: '1px solid var(--border)', borderRadius: 4, padding: '2px 8px' }}>
    Loading...
  </span>
)}

// After:
{isLoading && <PanelLoader height={24} />}
```

---

## Run tests
```bash
cd /Users/gregor/dev/922/HomeUI
npm run test:ci
```
Fix any failures. Check coverage stays ≥70%.

## Commit & Push
```bash
git add src/features/dashboard/components/PanelLoader.tsx \
        src/features/dashboard/components/PanelLoader.test.tsx \
        src/features/dashboard/pages/UsagePage.tsx \
        src/features/dashboard/pages/GitHubActionsPage.tsx \
        src/features/dashboard/pages/TestResultsPage.tsx \
        src/features/dashboard/pages/UptimePage.tsx
git commit -m "feat(dashboard): reusable PanelLoader component; replace Loading... text"
git push origin main
```

## Report format
```
=== STEP 3 COMPLETE ===
Plan: plans/2026-03-19-monitoring-dashboard-improvements.md
Step: 3 - Reusable PanelLoader Component
Status: done / blocked / partial
Changes: [files modified]
Tests: pass / fail (details)
Notes: [CSS class names found, any issues]
```
