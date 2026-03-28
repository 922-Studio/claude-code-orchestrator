# Plan: Management Frontend — Users, Organisations & Module Toggles

- **Date**: 2026-03-21
- **Project(s)**: HomeAuth, HomeUI, (HomeAPI — already done, verify only)
- **Goal**: Build full management UI for users (with org filter, clickable edit) and organisations (with working module toggles), restricted by 922-studio org-management permission.

## Context

Read these files before proceeding:
- `projects/homeauth.md` — HomeAuth project mapping
- `projects/homeui.md` — HomeUI project mapping
- `projects/homeapi.md` — HomeAPI project mapping (modules already exist)

### What Already Exists

**HomeAuth (backend)**:
- Full user CRUD: `GET/POST/PUT/DELETE /admin/users`, pagination, role assignment
- Full org CRUD: `GET/POST/PATCH/DELETE /admin/organizations`, org user listing
- User-org assignment: `POST/PATCH/DELETE /admin/users/{id}/organization`
- JWT contains: `org_id`, `org_role` — but `/auth/me` does NOT return org info
- `require_admin` dependency checks global `admin` role
- No concept of "org-management" permission

**HomeAPI (backend)**:
- Module model + OrgModule model fully implemented
- Module CRUD: `GET/POST/PATCH /admin/modules`
- Org-module config: `GET/PUT /admin/org-modules/{org_id}`
- User-facing: `GET /api/modules` returns visible modules for user's org
- 8 modules seeded: finance, health, monitoring, tasks, ideas, social, memory, worklogs
- Missing from seed: `projects` (used in UI sidebar)

**HomeUI (frontend)**:
- Users page exists at `/management/users` (old shadcn styling — needs redesign)
- Overview page at `/management` (target styling — dark, inline, JetBrains Mono)
- Auth context: `user.roles`, `hasRole()` — no org info
- Module API: `src/api/modules.ts` (user-facing only)
- No org API integration at all
- No admin module endpoints in frontend
- Sidebar nav: Overview, Users (no Organisations)

## Steps

### Step 1: HomeAuth — Add org info to /auth/me and org-management permission

- **Project**: HomeAuth
- **Directory**: /Users/gregor/dev/922/HomeAuth
- **Parallel with**: Step 2
- **Description**:
  1. Extend `UserOutWithRoles` schema to include org info (`org_id`, `org_slug`, `org_role`)
  2. Update `/auth/me` endpoint to eager-load user's org and return it
  3. Add `has_permission` field to org model OR use slug-based check:
     - Add `permissions` JSON column to `organizations` table (e.g. `["org-management"]`)
     - OR simpler: add `has_org_management: bool` computed field to `/auth/me` based on org slug = `922-studio`
     - **Recommended**: Add a `permissions` list[str] column to `Organization` model for future extensibility. Seed `922-studio` with `["org-management"]`. Return `org_permissions` in `/auth/me`.
  4. Update forward-auth `/auth/verify` to also return `X-Org-Slug` and `X-Org-Permissions` headers
  5. Write comprehensive tests for all changes
- **Context files to read**:
  - `CLAUDE.md` — architecture rules
  - `.claude/HOW-TO-PYTEST-TEST.md` — testing patterns
  - `app/schemas/auth.py` — UserOutWithRoles schema (line 94-108)
  - `app/routes/auth.py` — /auth/me endpoint (line 519-522), /auth/verify (line ~480-516)
  - `app/models/organization.py` — Organization, UserOrganization models
  - `app/dependencies/auth.py` — get_current_user dependency
- **Acceptance criteria**:
  - [ ] `/auth/me` returns `org_id`, `org_slug`, `org_role`, `org_permissions` (or null if no org)
  - [ ] `Organization` model has `permissions` column (list of strings, default empty)
  - [ ] Alembic migration adds `permissions` column to `organizations` table
  - [ ] Seed/update `922-studio` org with `permissions: ["org-management"]`
  - [ ] `/auth/verify` returns `X-Org-Slug` and `X-Org-Permissions` headers
  - [ ] All existing tests still pass
  - [ ] New tests cover: /auth/me with org, /auth/me without org, org permissions in response, verify headers

### Step 2: HomeAPI — Verify module system & seed missing module

- **Project**: HomeAPI
- **Directory**: /Users/gregor/dev/922/HomeAPI
- **Parallel with**: Step 1
- **Description**:
  1. Verify existing module system works end-to-end (all endpoints functional)
  2. Add `projects` module to seed migration (or create a new migration to insert it) — it's used in the UI sidebar but missing from DB seed
  3. Ensure `GET /admin/org-modules/{org_id}` returns ALL modules with their org-specific overrides (not just configured ones) — agent should check if current response includes unconfigured modules or only explicitly set ones
  4. If needed: update `GET /admin/org-modules/{org_id}` to return merged view (all modules + org overrides) so the frontend toggle list shows all modules with their enabled/disabled state
  5. Write/verify tests for module endpoints
- **Context files to read**:
  - `CLAUDE.md` — architecture rules
  - `app/routers/modules.py` — module endpoints
  - `app/crud/module.py` — CRUD logic (especially `get_modules_for_org` and `get_org_modules`)
  - `app/models/module.py` — Module model
  - `app/models/org_module.py` — OrgModule model
  - `app/schemas/module.py` — schemas
  - `alembic/versions/n001_create_modules_and_org_modules.py` — seed data
- **Acceptance criteria**:
  - [ ] `projects` module exists in DB seed
  - [ ] `GET /admin/org-modules/{org_id}` returns a merged list: ALL modules with org-specific `visible` and `status` overrides (default: visible=true, status=global_status for unconfigured modules)
  - [ ] `PUT /admin/org-modules/{org_id}` correctly toggles module visibility
  - [ ] Tests verify: list all modules, bulk upsert, toggle visible off/on, merged response includes unconfigured modules

### Step 3: HomeUI — Auth context + org API layer + admin module API

- **Project**: HomeUI
- **Directory**: /Users/gregor/dev/922/HomeUI
- **Parallel with**: — (depends on Step 1 & 2)
- **Description**:
  1. Update auth types to include org info from `/auth/me` response:
     - `src/types/api/auth.ts` — add `org_id`, `org_slug`, `org_role`, `org_permissions` to `GetMeResponse`
  2. Update `AuthContext.tsx`:
     - Parse and expose `orgId`, `orgSlug`, `orgRole`, `orgPermissions`
     - Add `hasPermission(perm: string)` helper (checks `org_permissions` array)
     - Convenience: `isOrgManager` = `hasPermission('org-management')`
  3. Create organization API layer:
     - `src/types/api/organizations.ts` — Zod schemas for Org, OrgUser
     - `src/api/organizations.ts` — CRUD functions + queryOptions factories
     - `src/hooks/useOrganizations.ts` — React Query hooks (list, detail, create, update, delete, listUsers)
  4. Create admin module API layer (for org-module management):
     - `src/types/api/admin-modules.ts` — Zod schemas for admin module + org-module responses
     - `src/api/admin-modules.ts` — listAllModules, getOrgModules, bulkUpsertOrgModules + queryOptions
     - `src/hooks/useAdminModules.ts` — React Query hooks
  5. Write tests for all new API functions, hooks, and auth context changes
- **Context files to read**:
  - `CLAUDE.md` — architecture rules, naming, patterns
  - `.claude/HOW-TO-UNIT-TEST.md` — testing patterns
  - `tech_docs/api_integration.md` — HTTP client, React Query patterns
  - `src/features/auth/AuthContext.tsx` — current auth context
  - `src/types/api/auth.ts` — current auth types
  - `src/api/users.ts` — reference pattern for API layer
  - `src/hooks/useUsers.ts` — reference pattern for hooks
  - `src/api/modules.ts` — existing user-facing module API
  - `src/types/api/modules.ts` — existing module types
- **Acceptance criteria**:
  - [ ] Auth context exposes `orgId`, `orgSlug`, `orgRole`, `orgPermissions`, `hasPermission()`, `isOrgManager`
  - [ ] Organization API layer with Zod-validated CRUD functions
  - [ ] Admin module API layer with list/get/upsert functions
  - [ ] React Query hooks with proper staleTime, invalidation on mutations
  - [ ] Tests: auth context with/without org, API functions mock correctly, hooks render correctly

### Step 4: HomeUI — Users page redesign

- **Project**: HomeUI
- **Directory**: /Users/gregor/dev/922/HomeUI
- **Parallel with**: Step 5
- **Description**:
  1. Redesign `src/features/users/pages/UsersPage.tsx` to match overview page styling:
     - Dark inline styles (#12121a cards, #1e1e2e borders, JetBrains Mono)
     - Table with columns: Username (avatar+name), Email, Org (badge), Roles (badges), Joined
     - Rows are clickable → opens edit dialog
  2. Add org filter toggle (My Org / All Users):
     - Only visible when user `isOrgManager` (922-studio)
     - Default: shows only own org users
     - "All Users" shows all users across orgs
     - Other orgs: no toggle, only see own org users (uses `GET /admin/organizations/{org_id}/users` from HomeAuth)
  3. Add search bar: filters by username and email (client-side filter on loaded data)
  4. Update `UserFormDialog.tsx`:
     - Restyle to match dark theme
     - Add organisation dropdown (only visible/editable for `isOrgManager`)
     - For non-922-studio: org auto-selected to current user's org
     - Role checkboxes: admin, user
  5. Write comprehensive tests
- **Context files to read**:
  - `CLAUDE.md` — architecture, patterns
  - `.claude/HOW-TO-UNIT-TEST.md` — testing patterns
  - `src/features/management/pages/ManagementOverviewPage.tsx` — target styling reference
  - `src/features/users/pages/UsersPage.tsx` — current implementation
  - `src/features/users/components/UserFormDialog.tsx` — current dialog
  - `src/hooks/useUsers.ts` — existing hooks
  - `src/api/users.ts` — existing API layer
- **Acceptance criteria**:
  - [ ] Users page matches overview page dark styling (inline styles, JetBrains Mono, role badges)
  - [ ] Org column with colored org badges
  - [ ] Search bar filters by username and email
  - [ ] Org filter toggle visible only for 922-studio users, defaults to "My Org"
  - [ ] Clicking a row opens edit dialog
  - [ ] Edit dialog: org selector only for 922-studio, auto-selected otherwise
  - [ ] Role checkboxes: admin, user
  - [ ] Tests: rendering, search filtering, org filter toggle visibility, edit dialog, role assignment

### Step 5: HomeUI — Organisations page + detail with module toggles

- **Project**: HomeUI
- **Directory**: /Users/gregor/dev/922/HomeUI
- **Parallel with**: Step 4
- **Description**:
  1. Create organisations feature:
     - `src/features/organisations/pages/OrganisationsPage.tsx` — list all orgs
     - `src/features/organisations/pages/OrganisationDetailPage.tsx` — detail with module toggles + members
     - `src/features/organisations/components/ModuleToggle.tsx` — toggle switch component
  2. Organisations list page:
     - Table: Name (icon), Slug, Members count, Modules enabled/total, Created date
     - "New Organisation" button
     - Clickable rows → navigate to detail
  3. Organisation detail page:
     - Back link to org list
     - Org header with metadata (name, slug, members, created)
     - Modules section: list ALL modules from `GET /admin/org-modules/{org_id}`, each with toggle
     - Toggle calls `PUT /admin/org-modules/{org_id}` with updated visible/status
     - **Toggles must work 100%**: optimistic update with rollback on error
     - Members section: table with avatar, username, email, org role badge
  4. Update sidebar nav (`ManagementNav.tsx`):
     - Add "Organisations" item with building-2 icon
     - Only visible when user `isOrgManager`
  5. Update routes in `App.tsx`:
     - `/management/organisations` → OrganisationsPage
     - `/management/organisations/:orgId` → OrganisationDetailPage
     - Wrap with permission check (redirect if not isOrgManager)
  6. All pages follow overview page styling (dark inline, JetBrains Mono, role badges)
  7. Write comprehensive tests
- **Context files to read**:
  - `CLAUDE.md` — architecture, patterns
  - `.claude/HOW-TO-UNIT-TEST.md` — testing patterns
  - `src/features/management/pages/ManagementOverviewPage.tsx` — target styling reference
  - `src/features/management/components/ManagementNav.tsx` — sidebar nav
  - `src/App.tsx` — route definitions (lines 193-212)
  - `src/api/organizations.ts` — org API (from Step 3)
  - `src/api/admin-modules.ts` — admin module API (from Step 3)
  - `src/hooks/useOrganizations.ts` — org hooks (from Step 3)
  - `src/hooks/useAdminModules.ts` — admin module hooks (from Step 3)
- **Acceptance criteria**:
  - [ ] Organisations page: table with all orgs, correct columns, clickable rows
  - [ ] Organisation detail: header with metadata, back navigation
  - [ ] Module toggles: show ALL modules, toggle ON/OFF works correctly via API
  - [ ] Optimistic updates on toggle: immediate visual feedback, rollback on error
  - [ ] Members section: shows org users with roles
  - [ ] "Organisations" nav item only visible for 922-studio org users
  - [ ] Routes protected: non-922-studio users redirected
  - [ ] Styling matches overview page design language
  - [ ] Tests: org list rendering, org detail rendering, module toggle interactions, nav visibility, route protection

### Step 6: Integration testing & polish

- **Project**: HomeUI
- **Directory**: /Users/gregor/dev/922/HomeUI
- **Parallel with**: —
- **Description**:
  1. E2E test scenarios (Playwright):
     - 922-studio admin: sees all nav items, can filter all users, can manage orgs, can toggle modules
     - Non-922-studio admin: sees only Users nav, no org filter, cannot access /management/organisations
     - Module toggle: enable/disable a module and verify it persists
     - User edit: change role, change org assignment
  2. Verify existing tests still pass after all changes
  3. Update overview page if needed: ensure it uses the same org-aware data loading
  4. Final visual polish: verify all pages match the mockup
- **Context files to read**:
  - `.claude/skills/e2e.md` — E2E patterns
  - All new page/component files from steps 4-5
- **Acceptance criteria**:
  - [ ] E2E tests cover the 4 core flows above
  - [ ] All unit tests pass (no regressions)
  - [ ] `npm run test:ci` passes with ≥70% coverage
  - [ ] Visual match with mockup screenshots

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel — backend changes):
  Step 1: HomeAuth — org info in /auth/me + org permissions → HomeAuth @ /Users/gregor/dev/922/HomeAuth
  Step 2: HomeAPI — verify modules + seed projects module → HomeAPI @ /Users/gregor/dev/922/HomeAPI

Wave 2 (after wave 1 — API layer):
  Step 3: HomeUI — auth context + org API + admin module API → HomeUI @ /Users/gregor/dev/922/HomeUI

Wave 3 (after wave 2 — parallel UI pages):
  Step 4: HomeUI — users page redesign → HomeUI @ /Users/gregor/dev/922/HomeUI
  Step 5: HomeUI — organisations page + module toggles → HomeUI @ /Users/gregor/dev/922/HomeUI

Wave 4 (after wave 3 — integration):
  Step 6: HomeUI — E2E tests + polish → HomeUI @ /Users/gregor/dev/922/HomeUI
```

## Post-Execution Checklist
- [x] All HomeAuth tests pass — 269 tests, 98% coverage (2026-03-21)
- [x] All HomeAPI tests pass — 1156 tests (2026-03-21)
- [x] All HomeUI unit tests pass — 1144 tests (2026-03-21)
- [x] HomeUI E2E tests pass — 24 new scenarios (2026-03-21)
- [x] All 3 projects pushed (2026-03-21)
- [ ] Pipeline green on all 3 projects after push
- [ ] Documentation updated:
  - [ ] HomeAuth: update `docs/HOMEUI_INTEGRATION.md` with new /auth/me fields
  - [ ] HomeUI: update relevant tech_docs if architecture patterns changed
- [ ] Mockup verified: all 4 screens match the Pencil designs
