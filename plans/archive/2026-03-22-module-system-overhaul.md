# Plan: Module System Overhaul

**Date**: 2026-03-22
**Status**: ready
**Projects**: HomeAPI, HomeUI

---

## Context & Problem Analysis

### Current DB Module State (seeded in migration n001 + n002)

| # | Slug | Name | Status | Sort Order |
|---|------|------|--------|------------|
| 1 | `finance` | Finance & Debt Tracking | active | 1 |
| 2 | `health` | Health & Wellbeing | active | 2 |
| 3 | `monitoring` | System Monitoring | active | 3 |
| 4 | `tasks` | Task Management | active | 4 |
| 5 | `ideas` | Idea Board | active | 5 |
| 6 | `social` | Social Media Manager | coming_soon | 6 |
| 7 | `memory` | Knowledge Base | active | 7 |
| 8 | `worklogs` | Work Logs | active | 8 |
| 9 | `projects` | Projects | active | 9 |

### Current UI Sidebar Order (hardcoded in AppSidebar.tsx)

1. Overview (always visible)
2. Monitoring (`monitoring`)
3. Finance (`finance`)
4. Projects (`projects`)
5. Health (`health`)
6. Content (`content`) — but DB slug is still `social`
7. Management (always visible, no module slug)
8. Settings (bottom, always visible)

### Current Landing Page Order (hardcoded in pages.tsx MODULE_REGISTRY)

Row 1: Monitoring, Finance, Projects
Row 2: Health, Content (coming soon), Management (coming soon)

### Existing Permission System (HomeAuth)

- **922-studio** org has permission `"org-management"` (seeded in migration + `app/core/seeding.py`)
- Traefik forward-auth sets headers: `X-Org-ID`, `X-Org-Slug`, `X-Org-Role`, `X-Org-Permissions`
- HomeAPI receives these headers via `app/deps.py`
- No env var needed — just check `X-Org-Permissions` for `org-management`

---

## Issues Found

### Bug: Toggle fires 3 times
**Root cause**: Race condition in `OrganisationDetailPage.tsx` (line 256-286).

Flow on single click:
1. **Click** → optimistic state set via `setLocalModules(next)` → UI shows new value
2. **Mutation succeeds** → `onSuccess` calls `setLocalModules(null)` → `displayModules` falls back to `modules` from query cache, which still has the **OLD** stale data → UI flips back
3. **Query invalidation** (from `onSettled` in `useBulkUpsertOrgModules`) → refetch completes → query cache updated → UI shows new value again

User sees: OFF → ON → OFF → ON (3 visual toggles).

**Fix**: Remove `onSuccess`/`onError` callbacks from `handleToggle`. Keep optimistic state, only clear it when query data actually changes (via useEffect on `modules`).

### Module name/slug mismatches
| Current DB | Target | Reason |
|------------|--------|--------|
| `finance` / "Finance & Debt Tracking" | `finance` / "Debt Tracking" | Finance is the section, Debt Tracking is the module |
| `health` / "Health & Wellbeing" | `health` / "Sleep Tracking" | Health is the section, Sleep Tracking is the feature |
| `social` / "Social Media Manager" | `content` / "Content Manager" | Project renamed to HomeContent |

### Orphan/misplaced modules in DB
| Module | Decision |
|--------|----------|
| `tasks` | **Delete** — always active with projects, not independently toggleable |
| `ideas` | **Keep** — sub-feature of Projects, toggleable later |
| `worklogs` | **Keep** — sub-feature of Projects, toggleable later |
| `memory` / "Knowledge Base" | **Keep, set to `coming_soon`** — has backend, no frontend yet |

### No centralized ordering
- Sidebar + landing page use hardcoded arrays
- DB has `sort_order` field but frontend never consumes it

### Missing behaviors
- `coming_soon` / `under_development` modules show on sidebar (should NOT)
- No admin org logic (922-studio should see everything)
- Management is not a module (always visible = correct, but not toggleable per org)

---

## Target State

### Revised Module List (new DB state)

| # | Slug | Name | Status | Sort Order | Notes |
|---|------|------|--------|------------|-------|
| 1 | `monitoring` | Monitoring | active | 1 | Unchanged |
| 2 | `finance` | Debt Tracking | active | 2 | Renamed |
| 3 | `projects` | Projects | active | 3 | Reordered |
| 4 | `health` | Sleep Tracking | active | 4 | Renamed |
| 5 | `ideas` | Idea Board | active | 5 | Kept, sub-feature of projects (future toggle) |
| 6 | `worklogs` | Work Logs | active | 6 | Kept, sub-feature of projects (future toggle) |
| 7 | `content` | Content Manager | under_development | 7 | Renamed from `social`, new slug |
| 8 | `memory` | Knowledge Base | coming_soon | 8 | Status changed from active → coming_soon |

**Deleted modules**: `tasks` (merged into `projects`), `social` (replaced by `content`)

**Management**: stays always-visible, NOT a module — no DB entry needed.

### Ordering system
- API returns modules with `sort_order` field
- Frontend uses `sort_order` from API response for sidebar, landing page, and admin panel
- Single source of truth: the `modules` DB table

### Sidebar behavior
- `active` modules: shown in sidebar
- `coming_soon` / `under_development` modules: **hidden from sidebar** (only on landing page as locked cards)
- `hidden` modules: hidden everywhere

### Admin org (922-studio)
- Use existing `X-Org-Permissions` header from Traefik forward-auth
- If permissions include `org-management`: `GET /api/modules` returns ALL modules as visible+active
- No new env var, no new DB field — leverages existing HomeAuth permission system

---

## Steps

### Step 1: Fix toggle bug (HomeUI)
**Project**: HomeUI
**Directory**: `/Users/gregor/dev/922/HomeUI`
**Parallel**: yes, with Step 2

**Changes**:
1. `src/features/organisations/pages/OrganisationDetailPage.tsx`:
   - Remove `onSuccess` and `onError` callbacks from the `bulkUpsert()` call inside `handleToggle`
   - Keep optimistic `setLocalModules(next)` before the mutation
   - Add `useEffect` that syncs: when `modules` (from query) changes, clear `localModules` to `null`
   - This way: optimistic state persists until the refetch actually completes

**Context files for agent**:
- Read `CLAUDE.md`
- Read `src/features/organisations/pages/OrganisationDetailPage.tsx`
- Read `src/features/organisations/components/ModuleToggle.tsx`
- Read `src/hooks/useAdminModules.ts`

---

### Step 2: DB migration — clean up modules (HomeAPI)
**Project**: HomeAPI
**Directory**: `/Users/gregor/dev/922/HomeAPI`
**Parallel**: yes, with Step 1

Create new Alembic migration (next revision after latest):
1. **Rename** `finance`: name → "Debt Tracking", description → "Track debts and payments"
2. **Rename** `health`: name → "Sleep Tracking", description → "Track sleep patterns and trends"
3. **Delete** `social` module (CASCADE deletes org_module overrides)
4. **Insert** `content` module: slug "content", name "Content Manager", description "Schedule and manage content across platforms", status `under_development`, sort_order 7
5. **Delete** `tasks` module (CASCADE deletes org_module overrides)
6. **Update** `memory`: global_status → "coming_soon"
7. **Reorder** all modules:
   - `monitoring`: sort_order 1
   - `finance`: sort_order 2
   - `projects`: sort_order 3
   - `health`: sort_order 4
   - `ideas`: sort_order 5
   - `worklogs`: sort_order 6
   - `content`: sort_order 7
   - `memory`: sort_order 8

**Context files for agent**:
- Read `CLAUDE.md`
- Read `alembic/versions/n001_create_modules_and_org_modules.py`
- Read `alembic/versions/n002_seed_projects_module.py`
- Read `app/models/module.py`
- Read `app/models/org_module.py`

---

### Step 3: API — add sort_order to responses + admin org logic (HomeAPI)
**Project**: HomeAPI
**Directory**: `/Users/gregor/dev/922/HomeAPI`
**Parallel**: after Step 2

**Changes**:
1. `app/schemas/module.py`:
   - Add `sort_order: int` to `ModuleUserResponse`
   - Add `sort_order: int` to `OrgModuleMergedResponse`

2. `app/routers/modules.py` — `list_modules_for_user()`:
   - Accept `X-Org-Permissions` header (add dependency in `app/deps.py` if not present)
   - Pass permissions to CRUD function

3. `app/crud/module.py` — `list_modules_for_user()`:
   - Add `permissions: str | None` parameter
   - If permissions contain `org-management`: return ALL modules with `visible=True`, status from global_status, ordered by sort_order
   - Otherwise: existing behavior (filter by org_module visibility)

4. Update tests for new schema fields and admin org logic

**Context files for agent**:
- Read `CLAUDE.md`
- Read `app/schemas/module.py`
- Read `app/crud/module.py`
- Read `app/routers/modules.py`
- Read `app/deps.py`

---

### Step 4: Frontend — dynamic ordering from API (HomeUI)
**Project**: HomeUI
**Directory**: `/Users/gregor/dev/922/HomeUI`
**Parallel**: after Steps 1, 2, 3

**Changes**:

1. `src/types/api/modules.ts`:
   - Add `sort_order: number` to `ModuleUser` type

2. `src/types/api/admin-modules.ts`:
   - Add `sort_order: number` to `OrgModuleMerged` type

3. `src/components/layout/AppSidebar.tsx`:
   - Replace hardcoded `navItems` array with dynamic construction from `useModules()` data
   - Keep a static map `MODULE_META: Record<string, { Icon, url }>` for icon/route lookup per slug
   - Build nav items from modules sorted by `sort_order`
   - **Filter out** modules where status is `coming_soon` or `under_development`
   - Keep static items: Overview (top), Management, Settings, Logout (bottom)
   - Unknown slugs (no entry in MODULE_META) are silently skipped

4. `src/pages.tsx`:
   - Replace hardcoded `MODULE_REGISTRY` with dynamic construction from `useModules()` data
   - Keep a static map `MODULE_DISPLAY: Record<string, { Icon, description, hint }>` for display data
   - Build module cards from modules sorted by `sort_order`
   - `coming_soon` / `under_development` modules shown as locked cards (existing behavior)
   - Add Management card as static always-visible entry (not module-controlled)

5. Admin panel (`OrganisationDetailPage.tsx`):
   - Modules already come ordered from API — just ensure no client-side sort overrides it

**Context files for agent**:
- Read `CLAUDE.md`
- Read `src/components/layout/AppSidebar.tsx`
- Read `src/pages.tsx`
- Read `src/types/api/modules.ts`
- Read `src/types/api/admin-modules.ts`
- Read `src/features/modules/hooks/useModules.ts`
- Read `src/features/modules/components/ModuleGuard.tsx`

---

### Step 5: Tests (HomeUI + HomeAPI)
**Project**: HomeUI, HomeAPI
**Parallel**: yes (one agent per project, after Steps 1-4)

**HomeAPI tests**:
- Update existing module tests for new module names/slugs/sort_orders
- Add test: admin org with `org-management` permission gets all modules as active
- Add test: `sort_order` present in `ModuleUserResponse` and `OrgModuleMergedResponse`
- Add test: `content` module exists with status `under_development`
- Add test: `memory` module exists with status `coming_soon`
- Add test: `tasks` module no longer exists

**HomeUI tests**:
- Update sidebar tests for dynamic module rendering from API
- Update landing page tests for dynamic module rendering
- Test: `coming_soon` modules hidden from sidebar but visible on landing page
- Test: toggle bug fixed (mutation doesn't cause triple state flip)
- Test: modules render in sort_order

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Step 1: Fix toggle bug
  - Project: HomeUI
  - Directory: /Users/gregor/dev/922/HomeUI
  - Parallel: yes, with Step 2
  - Context: OrganisationDetailPage.tsx, ModuleToggle.tsx, useAdminModules.ts

Step 2: DB migration — clean up modules
  - Project: HomeAPI
  - Directory: /Users/gregor/dev/922/HomeAPI
  - Parallel: yes, with Step 1
  - Context: n001/n002 migrations, module models

Step 3: API — sort_order + admin org logic
  - Project: HomeAPI
  - Directory: /Users/gregor/dev/922/HomeAPI
  - Parallel: after Step 2
  - Context: schemas, crud, routers, deps

Step 4: Frontend — dynamic ordering
  - Project: HomeUI
  - Directory: /Users/gregor/dev/922/HomeUI
  - Parallel: after Steps 1+3
  - Context: AppSidebar.tsx, pages.tsx, module types/hooks

Step 5: Tests
  - Project: HomeUI + HomeAPI
  - Parallel: yes (after Steps 1-4)
```

```
Timeline:

  Step 1 (HomeUI: toggle fix) ──────┐
  Step 2 (HomeAPI: migration) ──────┤
                                    ▼
  Step 3 (HomeAPI: API changes) ────┐
                                    ▼
  Step 4 (HomeUI: dynamic order) ───┐
                                    ▼
  Step 5 (Tests: both projects) ────┐
                                    ▼
                                  Done
```

---

## Decisions Log

| # | Question | Decision | Date |
|---|----------|----------|------|
| 1 | Knowledge Base module | Keep as `coming_soon` | 2026-03-22 |
| 2 | tasks/ideas/worklogs | Delete `tasks` (always with projects). Keep `ideas` + `worklogs` for future toggle | 2026-03-22 |
| 3 | Admin org identification | Use existing `X-Org-Permissions: org-management` from HomeAuth | 2026-03-22 |
| 4 | Management as module | Always visible, NOT a module | 2026-03-22 |
