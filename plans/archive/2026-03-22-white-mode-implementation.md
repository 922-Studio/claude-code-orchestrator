# Plan: Full White Mode Support for HomeUI

- **Date**: 2026-03-22
- **Project(s)**: HomeUI
- **Goal**: Implement full white/light mode across all pages, matching the approved Pencil mockup color scheme with a light sidebar, differentiated sub-navigation, and off-white cards.

## Context

Read these files before proceeding:
- `projects/homeui.md` — project mapping, tech stack, best practices
- `/Users/gregor/dev/922/HomeUI/CLAUDE.md` — architecture, naming, patterns
- `/Users/gregor/dev/922/HomeUI/src/index.css` — current CSS variable theme definitions
- `/Users/gregor/dev/922/HomeUI/pencil/overview.pen` — approved white mode mockups (frames: "White Mode — Landing", "White Mode — Management")

## Mockup Color Tokens

These values were extracted from the approved Pencil mockups and must be used exactly:

| Token | Light Mode Value | Purpose |
|-------|-----------------|---------|
| `--sidebar` | `#D5D4D1` | Sidebar background (was `#0D0D0D`) |
| `--sidebar-foreground` | `#111111` | Sidebar text |
| `--sidebar-border` | `#E0E0E0` | Sidebar dividers |
| `--sidebar-primary` | `var(--sidebar-color)` | Active accent (unchanged) |
| `--sidebar-primary-foreground` | `#FFFFFF` | Active accent text |
| `--sidebar-accent` | `#C8C7C4` | Active nav item bg |
| `--sidebar-accent-foreground` | `#555555` | Inactive nav text |
| `--section-nav` | `#E2E1DE` | Sub-navigation background (NEW) |
| `--section-nav-active` | `#D5D4D1` | Active section item bg (NEW) |
| `--background` | `#F2F1EF` | Page background (unchanged) |
| `--card` | `#F7F6F4` | Cards/tables (was `#FFFFFF`) |
| `--card-foreground` | `#111111` | Card text (unchanged) |
| `--border` | `#E0E0E0` | Borders (unchanged) |

## Steps

### Step 1: Update CSS Variables in index.css

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: —
- **Description**: Update `:root` (light mode) CSS variables to match the approved mockup colors. Add new `--section-nav` and `--section-nav-active` variables for both light and dark modes. The sidebar must be light-colored in light mode and dark in dark mode.
- **Context files to read**:
  - `src/index.css` — current variable definitions (lines 84-173)
  - `pencil/overview.pen` — approved mockups for reference
- **Changes**:
  - `:root` (light mode):
    - `--sidebar: #D5D4D1`
    - `--sidebar-foreground: #111111` (near-black text on light sidebar)
    - `--sidebar-border: #E0E0E0`
    - `--sidebar-accent: #C8C7C4`
    - `--sidebar-accent-foreground: #555555`
    - `--card: #F7F6F4` (off-white, not pure white)
    - Add `--section-nav: #E2E1DE`
    - Add `--section-nav-active: #D5D4D1`
  - `.dark` (dark mode):
    - Keep existing `--sidebar: #0D0D0D` (dark sidebar unchanged)
    - Keep all existing dark sidebar variables
    - Add `--section-nav: #111118` (match dark card)
    - Add `--section-nav-active: #1a1a24` (match dark secondary)
- **Acceptance criteria**:
  - [ ] Light mode sidebar renders with `#D5D4D1` background
  - [ ] Dark mode sidebar still renders with `#0D0D0D`
  - [ ] Cards render as `#F7F6F4` in light mode
  - [ ] New `--section-nav` variables exist in both modes

### Step 2: Update SectionLayout Sub-Navigation

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: —
- **Description**: Update SectionLayout component to use the new `--section-nav` CSS variable for the sub-navigation panel background, and `--section-nav-active` for the active item highlight. This ensures the sub-nav is visually distinct from both the sidebar and the page background.
- **Context files to read**:
  - `src/components/layout/SectionLayout.tsx` — current section layout
  - `src/features/monitoring/MonitoringLayout.tsx` — example usage
- **Changes**:
  - Replace background color class with `bg-[var(--section-nav)]` or equivalent Tailwind utility
  - Active section nav items use `bg-[var(--section-nav-active)]`
- **Acceptance criteria**:
  - [ ] Sub-nav background is `#E2E1DE` in light mode
  - [ ] Sub-nav background is `#111118` in dark mode
  - [ ] Active section item is distinguishable from inactive items
  - [ ] Three clear visual layers: sidebar → sub-nav → page background

### Step 3: Fix shadcn/ui Card Component

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 4, 5
- **Description**: Remove hardcoded `slate-*` Tailwind classes from card.tsx. Replace with CSS variable references (`bg-card`, `text-card-foreground`, `border-border`).
- **Context files to read**:
  - `src/components/ui/card.tsx` — current implementation with hardcoded `dark:border-slate-800`, `dark:bg-slate-950`, `dark:text-slate-50`
- **Acceptance criteria**:
  - [ ] No `slate-*` classes remain in card.tsx
  - [ ] Card uses `bg-card`, `text-card-foreground`, `border-border` only
  - [ ] Card renders correctly in both light and dark modes

### Step 4: Fix shadcn/ui NavigationMenu Component

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 3, 5
- **Description**: Remove hardcoded `slate-*` classes from navigation-menu.tsx. Replace with CSS variable-based classes.
- **Context files to read**:
  - `src/components/ui/navigation-menu.tsx` — hardcoded `dark:hover:bg-slate-800`, `dark:hover:text-slate-50`, etc.
- **Acceptance criteria**:
  - [ ] No `slate-*` classes remain
  - [ ] Uses theme-aware classes (`bg-accent`, `text-accent-foreground`, etc.)

### Step 5: Fix LoadingScreen and TerminalLogo

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 3, 4
- **Description**: Update LoadingScreen.tsx and TerminalLogo.tsx to respect theme. LoadingScreen gradient should use `var(--primary)`. TerminalLogo SVG colors should adapt to theme where appropriate (dark SVG background should become light in light mode).
- **Context files to read**:
  - `src/components/ui/LoadingScreen.tsx` — hardcoded `#6366f1`, `#06b6d4`, `dark:bg-white/20`
  - `src/components/ui/TerminalLogo.tsx` — fully hardcoded SVG with 10+ hex values
- **Changes**:
  - LoadingScreen: Use CSS variables for spinner/gradient colors
  - TerminalLogo: Make background and titlebar theme-aware (light bg in light mode, dark bg in dark mode). Traffic light dots and gradient colors can remain hardcoded (brand identity).
- **Acceptance criteria**:
  - [ ] Loading screen looks correct in both modes
  - [ ] Terminal logo background adapts to theme

### Step 6: Fix Feature Page Hardcoded Colors — HomePage & SystemHealthPage

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 7, 8, 9
- **Description**: Replace hardcoded `red-*`, `emerald-*`, `amber-*` Tailwind classes in pages.tsx with theme-compatible semantic classes. Status colors (success, warning, error) should work well on both light and dark backgrounds.
- **Context files to read**:
  - `src/pages.tsx` — lines 357-379, hardcoded status colors
- **Changes**:
  - Use light/dark compatible pairs: `bg-red-100 dark:bg-red-900/30` is actually OK as-is (already has both modes). Verify each usage renders correctly with the new light mode card color (`#F7F6F4`).
  - Fix any cases that ONLY have `dark:` without a light counterpart.
- **Acceptance criteria**:
  - [ ] Status badges (healthy/warning/error) visible in both modes
  - [ ] Module cards match mockup styling (off-white `#F7F6F4`)
  - [ ] No invisible or low-contrast text in light mode

### Step 7: Fix Finance Module Colors

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 6, 8, 9
- **Description**: Fix hardcoded colors in LedgerPage.tsx and DebtNLInput.tsx. Ensure financial positive/negative indicators work on both light and dark backgrounds.
- **Context files to read**:
  - `src/features/debts/pages/LedgerPage.tsx` — hardcoded `emerald-*`, `rose-*`
  - `src/features/debts/components/DebtNLInput.tsx` — mixed `slate/emerald/rose` hardcoding
- **Changes**:
  - Replace `dark:text-emerald-400` / `dark:text-rose-400` with proper light+dark pairs
  - Replace `dark:bg-slate-900`, `dark:border-slate-800`, `dark:text-slate-*` with CSS variable classes
- **Acceptance criteria**:
  - [ ] No `slate-*` classes remain
  - [ ] Positive amounts green, negative amounts red in both modes
  - [ ] Preview card uses `bg-card`, `border-border`

### Step 8: Fix Content Module Colors

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 6, 7, 9
- **Description**: Fix hardcoded `blue-*`, `emerald-*`, `rose-*` classes in StatusBadge.tsx and PostCard.tsx.
- **Context files to read**:
  - `src/features/content/components/StatusBadge.tsx` — hardcoded `dark:bg-blue-900/40`, etc.
  - `src/features/content/components/PostCard.tsx` — hardcoded `dark:text-blue-400`
- **Changes**:
  - Ensure each `dark:` class has a corresponding light mode class
  - Replace any that don't with proper light+dark pairs
- **Acceptance criteria**:
  - [ ] Status badges visible and properly colored in both modes
  - [ ] Post card links and buttons visible in both modes

### Step 9: Fix Projects Module Colors

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 6, 7, 8
- **Description**: Fix hardcoded `zinc-*` and hex colors in ProjectNotes.tsx. Replace with CSS variable classes.
- **Context files to read**:
  - `src/features/projects/sections/ProjectNotes.tsx` — hardcoded `zinc-*`, `#12121a`
- **Changes**:
  - `bg-[#12121a]` → `bg-card`
  - `text-zinc-400` → `text-muted-foreground`
  - `border-zinc-700` → `border-border`
  - `bg-zinc-800` → `bg-secondary`
- **Acceptance criteria**:
  - [ ] No `zinc-*` classes or hardcoded hex remain
  - [ ] Notes section renders correctly in both modes

### Step 10: Fix StatCard and ChartPanel Defaults

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 6-9
- **Description**: Update hardcoded status hex colors in StatCard.tsx and default accent in ChartPanel.tsx.
- **Context files to read**:
  - `src/components/ui/StatCard.tsx` — `#10b981`, `#f59e0b`, `#f43f5e`
  - `src/components/ui/ChartPanel.tsx` — `#10b981` default accent
- **Changes**:
  - Status colors in StatCard can remain as hardcoded hex (they are semantic status colors used for SVG indicators, not affected by theme). But verify they have sufficient contrast on the new off-white card background.
  - ChartPanel default accent should reference `var(--chart-2)` or similar CSS variable.
- **Acceptance criteria**:
  - [ ] Status indicators visible on `#F7F6F4` card background
  - [ ] Chart accent uses CSS variable

### Step 11: Fix Login Page Autofill Colors

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 6-10
- **Description**: Update hardcoded autofill colors in index.css (lines for `-webkit-autofill`). Currently hardcoded to dark theme values (`#141416`, `#a1a1aa`, `#2a2a2e`, `#27272a`). Add light mode variants.
- **Context files to read**:
  - `src/index.css` — autofill CSS rules
- **Changes**:
  - Scope dark autofill styles under `.dark` selector
  - Add light mode autofill styles with cream/light colors
- **Acceptance criteria**:
  - [ ] Login form autofill looks correct in light mode
  - [ ] Login form autofill looks correct in dark mode

### Step 12: Visual QA and E2E Smoke Test

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: —
- **Description**: Run through every page in both light and dark mode. Verify no invisible text, broken contrasts, or regressions. Run existing unit tests and E2E tests.
- **Context files to read**:
  - `src/App.tsx` — all routes
- **Pages to verify** (light AND dark):
  - [ ] Login (`/login`)
  - [ ] Home Overview (`/`)
  - [ ] Finance Overview (`/finance`)
  - [ ] Finance Ledger (`/finance/ledger`)
  - [ ] Monitoring Overview (`/monitoring`)
  - [ ] Monitoring Tests (`/monitoring/tests`)
  - [ ] Monitoring Actions (`/monitoring/actions`)
  - [ ] Monitoring Performance (`/monitoring/performance`)
  - [ ] Monitoring Usage (`/monitoring/usage`)
  - [ ] Monitoring Uptime (`/monitoring/uptime`)
  - [ ] Projects Dashboard (`/projects`)
  - [ ] Projects Tasks (`/projects/tasks`)
  - [ ] Project Detail (`/projects/:slug`)
  - [ ] Health Overview (`/health`)
  - [ ] Health Sleep (`/health/sleep`)
  - [ ] Content Overview (`/content`)
  - [ ] Content Timeline (`/content/timeline`)
  - [ ] Content Showcase (`/content/showcase`)
  - [ ] Management Overview (`/management`)
  - [ ] Management Users (`/management/users`)
  - [ ] Management Org Detail (`/management/organisations/:id`)
  - [ ] Settings (`/settings`)
- **Acceptance criteria**:
  - [ ] `npm run test:ci` passes
  - [ ] `npm run test:e2e` passes
  - [ ] All 22 pages visually verified in light mode
  - [ ] All 22 pages visually verified in dark mode
  - [ ] No WCAG AA contrast failures on any text

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (foundation):
  Step 1: Update CSS variables in index.css → HomeUI @ src/index.css
  Step 2: Update SectionLayout sub-nav → HomeUI @ src/components/layout/SectionLayout.tsx

Wave 2 (shadcn/ui fixes — parallel):
  Step 3: Fix Card component → HomeUI @ src/components/ui/card.tsx
  Step 4: Fix NavigationMenu → HomeUI @ src/components/ui/navigation-menu.tsx
  Step 5: Fix LoadingScreen + TerminalLogo → HomeUI @ src/components/ui/

Wave 3 (feature page fixes — parallel):
  Step 6: Fix HomePage/SystemHealth → HomeUI @ src/pages.tsx
  Step 7: Fix Finance module → HomeUI @ src/features/debts/
  Step 8: Fix Content module → HomeUI @ src/features/content/
  Step 9: Fix Projects module → HomeUI @ src/features/projects/
  Step 10: Fix StatCard/ChartPanel → HomeUI @ src/components/ui/
  Step 11: Fix Login autofill → HomeUI @ src/index.css

Wave 4 (validation):
  Step 12: Visual QA + test suite → HomeUI (all 22 pages, both modes)
```

## Post-Execution Checklist
- [ ] All tests pass (`npm run test:ci` + `npm run test:e2e`)
- [ ] Documentation updated (tech_docs if CSS variable schema changed)
- [ ] Pipeline green
- [ ] Changes reviewed against best practices in project mapping
- [ ] Mockups in Pencil match final implementation
