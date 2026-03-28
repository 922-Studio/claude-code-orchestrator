# Plan: Multi-Tenant Organizations + Module System

- **Date**: 2026-03-20
- **Project(s)**: HomeAuth, HomeAPI, HomeContent, HomeUI
- **Goal**: Introduce organizations as the multi-tenancy layer, add a module access system with coming-soon support, and scope all existing data to orgs.

## Context

Read these files before proceeding:
- `projects/homeauth.md` — HomeAuth architecture, JWT structure, admin routes
- `projects/homeapi.md` — HomeAPI architecture, 17 models, 21 routers
- `projects/homecontent.md` — HomeContent models and auth pattern
- `projects/homeui.md` — HomeUI feature structure and API integration patterns

## Design Decisions

### Data Model

**HomeAuth** (identity layer):
```
organizations
  id          UUID PK
  name        VARCHAR unique
  slug        VARCHAR unique
  created_at  TIMESTAMP

user_organizations
  id          UUID PK
  user_id     UUID FK → users.id (unique — 1 user = 1 org)
  org_id      UUID FK → organizations.id
  org_role    ENUM("admin", "member")
  created_at  TIMESTAMP
```

**HomeAPI** (module catalog + org config):
```
modules
  id             UUID PK
  slug           VARCHAR unique   ("finance", "health", "monitoring", ...)
  name           VARCHAR          ("Finance", "Health", ...)
  description    TEXT
  global_status  ENUM("active", "coming_soon")
  sort_order     INTEGER
  created_at     TIMESTAMP

org_modules
  id           UUID PK
  org_id       VARCHAR(36)        (from HomeAuth — no FK, cross-service ref)
  module_slug  VARCHAR FK → modules.slug
  visible      BOOLEAN
  status       ENUM("active", "coming_soon")   (per-org override)
  UNIQUE(org_id, module_slug)
```

### JWT Claims (after Step 1)
```json
{
  "sub": "user-uuid",
  "org_id": "org-uuid",
  "org_role": "admin",
  "roles": ["user"],
  "pwd_ver": 1,
  "jti": "...",
  "exp": "...",
  "iat": "...",
  "type": "access"
}
```

### Traefik Forward-Auth Headers (after Step 1)
```
X-User-ID:    <uuid>
X-User-Email: <email>
X-User-Roles: <comma-sep roles>
X-Org-ID:     <org-uuid>
X-Org-Role:   <admin|member>
```

### Module Visibility Rules
| Org-Module config              | What the user sees         |
|-------------------------------|----------------------------|
| visible=true, status=active    | Module visible and active  |
| visible=true, status=coming_soon | Module with "Coming Soon" badge |
| visible=false                 | Module not shown at all    |

### Initial Module Seed Data
Seed these modules in HomeAPI on migration (all `global_status=active` unless noted):
- `finance` — Finance & Debt Tracking
- `health` — Health & Wellbeing
- `monitoring` — System Monitoring
- `tasks` — Task Management
- `ideas` — Idea Board
- `social` — Social Media Manager (`global_status=coming_soon` until HomeContent is org-ready)
- `memory` — Knowledge Base
- `worklogs` — Work Logs

---

## Steps

### Step 1: HomeAuth — Organizations + JWT Update

- **Project**: HomeAuth
- **Directory**: /Users/gregor/dev/922/HomeAuth
- **Parallel with**: —
- **Description**:
  Add the organization layer to HomeAuth. This is the foundation everything else depends on.

  1. Create `Organization` and `UserOrganization` SQLAlchemy models (async, UUID PKs, same patterns as existing `User` model)
  2. Create Alembic migration
  3. Update `create_access_token()` in `app/core/security.py` to accept and embed `org_id: str` and `org_role: str` in the JWT payload
  4. Update `validate_access_token()` to return `org_id` and `org_role` from decoded payload
  5. Update `GET /auth/verify` to return two new headers: `X-Org-ID` and `X-Org-Role`
  6. Add admin endpoints under `/admin/organizations`:
     - `GET /admin/organizations` — list all orgs
     - `POST /admin/organizations` — create org
     - `PATCH /admin/organizations/{org_id}` — update org name/slug
     - `DELETE /admin/organizations/{org_id}` — delete (guard: no users assigned)
     - `GET /admin/organizations/{org_id}/users` — list users in org
     - `POST /admin/users/{user_id}/organization` — assign user to org with role
     - `PATCH /admin/users/{user_id}/organization` — change role (admin/member)
     - `DELETE /admin/users/{user_id}/organization` — remove user from org
  7. Update user registration: no org assigned by default (admin assigns separately)
  8. Update login flow: if user has no org assigned, include `org_id: null`, `org_role: null` in JWT (handle gracefully)
  9. Seed Gregor's org on startup via environment variable `OWNER_ORG_NAME` (similar to existing admin seeding), auto-assign `ADMIN_EMAIL` user to that org as `admin`
  10. Write/update tests for all new endpoints and JWT changes

- **Context files to read**:
  - `app/models/user.py` — existing User model patterns
  - `app/core/security.py` — JWT creation/decoding
  - `app/routes/auth.py` — verify endpoint
  - `app/routes/admin.py` — existing admin patterns
  - `CLAUDE.md` — architecture and testing rules
  - `.claude/HOW-TO-PYTEST-TEST.md` — testing patterns

- **Acceptance criteria**:
  - [ ] `organizations` and `user_organizations` tables created via migration
  - [ ] JWT access token contains `org_id` and `org_role`
  - [ ] `/auth/verify` returns `X-Org-ID` and `X-Org-Role` headers
  - [ ] Admin org management endpoints work (CRUD + user assignment)
  - [ ] Owner org seeded on startup
  - [ ] Existing tests still pass
  - [ ] New tests cover all org endpoints + JWT changes
  - [ ] 85% coverage maintained
  - [ ] Pipeline green

---

### Step 2: HomeAPI — Module Catalog + Org-Module Config

- **Project**: HomeAPI
- **Directory**: /Users/gregor/dev/922/HomeAPI
- **Parallel with**: Step 3 (HomeContent)
- **Description**:
  Add the module system to HomeAPI. Does NOT touch existing models (that's Step 4).

  1. Create `Module` and `OrgModule` SQLAlchemy models (see Design Decisions above)
  2. Create Alembic migration with seed data for initial 8 modules (see Initial Module Seed Data above)
  3. Update `app/main.py` (or equivalent auth dependency) to extract `X-Org-ID` and `X-Org-Role` from headers (passed by Traefik after Step 1) and make available in request context. Add to the existing user context alongside `X-User-ID`, `X-User-Email`, `X-User-Roles`.
  4. Create `app/routers/modules.py` with:
     - `GET /api/modules` — returns modules for current user's org (filters by org_id from JWT context, returns only visible=true modules with their status). If `org_id` is null, return empty list.
     - `GET /api/admin/modules` — super-admin: returns all modules with full config
     - `POST /api/admin/modules` — create new module
     - `PATCH /api/admin/modules/{slug}` — update module (name, description, global_status, sort_order)
     - `GET /api/admin/org-modules/{org_id}` — get module config for a specific org
     - `PUT /api/admin/org-modules/{org_id}` — bulk upsert module config for an org (set visible + status per module)
  5. Protect admin endpoints with role check: `org_role == "admin"` OR `roles` contains `"admin"` (super-admin)
  6. Write tests for all new endpoints

- **Context files to read**:
  - `app/main.py` — auth middleware and header extraction
  - `app/auth.py` — current JWT/header validation patterns
  - `CLAUDE.md` — layer separation, naming conventions
  - `.claude/HOW-TO-PYTEST-TEST.md` — testing patterns

- **Acceptance criteria**:
  - [ ] `modules` and `org_modules` tables created via migration with seed data
  - [ ] `GET /api/modules` returns correct modules for org, respecting visibility and status
  - [ ] Admin endpoints for module + org-module management work
  - [ ] `org_id` and `org_role` available in HomeAPI request context
  - [ ] Tests cover all new endpoints
  - [ ] 70% coverage maintained
  - [ ] Pipeline green

---

### Step 3: HomeContent — Add org_id to Models

- **Project**: HomeContent
- **Directory**: /Users/gregor/dev/922/HomeContent
- **Parallel with**: Step 2 (HomeAPI module catalog)
- **Description**:
  Add org scoping to HomeContent's data layer. Same cross-service pattern as HomeAPI.

  1. Add `org_id VARCHAR(36) NOT NULL` to `Post` and `MediaAsset` models
  2. Create Alembic migration: add column nullable first, backfill with owner org UUID (hardcode as env var `OWNER_ORG_ID`), then make NOT NULL
  3. Update `app/auth.py` to extract `X-Org-ID` and `X-Org-Role` from Traefik headers and include in user context
  4. Update all CRUD operations to:
     - Filter all queries by `org_id` from request context
     - Set `org_id` on create
  5. Update all route handlers to pass `org_id` from user context to CRUD layer
  6. Update tests to include org context in all fixtures

- **Context files to read**:
  - `app/auth.py` — current role/header auth pattern
  - `app/models/post.py` — Post model
  - `app/models/media_asset.py` — MediaAsset model
  - `CLAUDE.md` — architecture patterns

- **Acceptance criteria**:
  - [ ] `org_id` added to `Post` and `MediaAsset` tables via migration
  - [ ] All existing data backfilled with owner org ID
  - [ ] All queries filtered by org_id
  - [ ] `X-Org-ID` and `X-Org-Role` extracted in auth layer
  - [ ] Tests updated and passing
  - [ ] 70% coverage maintained
  - [ ] Pipeline green

---

### Step 4: HomeAPI — Add org_id to All Existing Models

- **Project**: HomeAPI
- **Directory**: /Users/gregor/dev/922/HomeAPI
- **Parallel with**: — (after Steps 2 + 3)
- **Description**:
  Scope all 17 existing HomeAPI models to organizations. This is the largest step.

  1. Read all models in `app/models/` to identify every table
  2. Add `org_id VARCHAR(36) NOT NULL` to every model that holds user/org data (skip pure lookup/config tables)
  3. Create a single Alembic migration that:
     a. Adds `org_id` as nullable to all affected tables
     b. Backfills all rows with owner org UUID (from env var `OWNER_ORG_ID`)
     c. Makes `org_id` NOT NULL
     d. Adds index on `org_id` for every table
  4. Update every CRUD module (`app/crud/*.py`) to:
     - Add `org_id: str` parameter to all `get`, `get_all`, `create`, `update`, `delete` functions
     - Filter all SELECT queries with `WHERE org_id = :org_id`
     - Set `org_id` on all INSERT operations
  5. Update every router (`app/routers/*.py`) to:
     - Extract `org_id` from the request context (already available after Step 2)
     - Pass `org_id` to CRUD functions
  6. Add `user_id` to models where individual user ownership makes sense (e.g., worklogs, ideas — models that are personal even within an org). Use same backfill approach with `X-User-ID`.
  7. Update all tests to include `org_id` in fixtures and verify org isolation

- **Context files to read**:
  - `app/models/` — all model files
  - `app/crud/` — all CRUD files
  - `app/routers/` — all router files
  - `app/main.py` — request context with org_id (added in Step 2)
  - `CLAUDE.md` — layer separation rules
  - `.claude/HOW-TO-PYTEST-TEST.md` — async patterns

- **Acceptance criteria**:
  - [ ] All data models have `org_id` column
  - [ ] All queries filtered by `org_id` — no cross-org data leakage possible
  - [ ] Single migration handles backfill cleanly
  - [ ] All 21 router modules updated
  - [ ] Tests verify org isolation (one org cannot see another org's data)
  - [ ] 70% coverage maintained
  - [ ] Pipeline green

---

### Step 5: HomeUI — Module-Aware UI

- **Project**: HomeUI
- **Directory**: /Users/gregor/dev/922/HomeUI
- **Parallel with**: — (after Step 2)
- **Description**:
  Make the HomeUI module-system-aware: load modules from API, show/hide navigation items based on visibility, show Coming Soon badges.

  1. Create `src/api/modules.ts` with `GET /api/modules` query using Zod schema:
     ```
     Module { slug, name, description, status: "active" | "coming_soon" }
     ```
  2. Create `src/features/modules/hooks/useModules.ts` — React Query hook wrapping the modules API
  3. Create `src/features/modules/hooks/useModule.ts` — helper to check if a specific module is active/coming_soon/hidden
  4. Update navigation/sidebar to use `useModules()`:
     - Active modules: shown normally
     - Coming Soon modules: shown with a "Coming Soon" badge (greyed out, non-clickable)
     - Hidden modules: not rendered
  5. Add a `<ComingSoon />` wrapper component for module pages not yet accessible
  6. Add route guards: if user navigates directly to a module route that is not active (hidden or coming_soon), redirect to home or show a not-available state
  7. Create Settings page section (read-only for now): shows which modules are active for the org. Toggle functionality is a future step.
  8. Write tests for `useModules`, `useModule`, and the ComingSoon component

- **Context files to read**:
  - `src/App.tsx` — route definitions
  - `src/api/` — existing API client patterns
  - `tech_docs/api_integration.md` — React Query patterns
  - `CLAUDE.md` — feature module structure, testing rules
  - `.claude/HOW-TO-UNIT-TEST.md` — testing patterns

- **Acceptance criteria**:
  - [ ] `GET /api/modules` called on app load, result cached via React Query
  - [ ] Navigation shows only visible modules
  - [ ] Coming Soon modules visible but non-navigable, with badge
  - [ ] Route guard prevents direct URL access to inactive modules
  - [ ] Settings section shows module status (read-only)
  - [ ] Tests pass for new hooks and components
  - [ ] 70% coverage maintained
  - [ ] Pipeline green

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1:
  Step 1: HomeAuth — Orgs + JWT update
    → HomeAuth @ /Users/gregor/dev/922/HomeAuth
    → All other steps depend on this

Wave 2 (parallel, after Wave 1):
  Step 2: HomeAPI — Module catalog + org-module config
    → HomeAPI @ /Users/gregor/dev/922/HomeAPI
  Step 3: HomeContent — Add org_id to models
    → HomeContent @ /Users/gregor/dev/922/HomeContent

Wave 3 (after Wave 2):
  Step 4: HomeAPI — Add org_id to all existing models
    → HomeAPI @ /Users/gregor/dev/922/HomeAPI

Wave 4 (after Step 2, can start after Wave 2):
  Step 5: HomeUI — Module-aware UI
    → HomeUI @ /Users/gregor/dev/922/HomeUI
```

---

## Agent Prompts

### Prompt: Step 1 — HomeAuth

```
You are executing Step 1 of plan `plans/2026-03-20-multi-tenant-org-modules.md`.

Read these files first:
- plans/2026-03-20-multi-tenant-org-modules.md — full plan and design decisions
- projects/homeauth.md — architecture, patterns, testing strategy
- /Users/gregor/dev/922/HomeAuth/CLAUDE.md — must read always
- /Users/gregor/dev/922/HomeAuth/.claude/HOW-TO-PYTEST-TEST.md — testing patterns
- /Users/gregor/dev/922/HomeAuth/app/models/user.py — existing model patterns
- /Users/gregor/dev/922/HomeAuth/app/core/security.py — JWT structure
- /Users/gregor/dev/922/HomeAuth/app/routes/auth.py — verify endpoint
- /Users/gregor/dev/922/HomeAuth/app/routes/admin.py — admin patterns

Task: Add Organization model, UserOrganization model, Alembic migration, update JWT to include org_id/org_role, update /auth/verify to return X-Org-ID/X-Org-Role headers, add admin org management endpoints, seed owner org on startup.

Full details and acceptance criteria are in the plan file Step 1.
```

### Prompt: Step 2 — HomeAPI Module Catalog

```
You are executing Step 2 of plan `plans/2026-03-20-multi-tenant-org-modules.md`.

Read these files first:
- plans/2026-03-20-multi-tenant-org-modules.md — full plan and design decisions (especially Design Decisions section)
- projects/homeapi.md — architecture, patterns
- /Users/gregor/dev/922/HomeAPI/CLAUDE.md — must read always
- /Users/gregor/dev/922/HomeAPI/.claude/HOW-TO-PYTEST-TEST.md — testing patterns
- /Users/gregor/dev/922/HomeAPI/app/main.py — auth middleware
- /Users/gregor/dev/922/HomeAPI/app/auth.py — header extraction patterns

Task: Add Module and OrgModule models, migration with seed data, update request context to include org_id/org_role from X-Org-ID/X-Org-Role headers, add /api/modules and /api/admin/modules + /api/admin/org-modules endpoints.

Full details and acceptance criteria are in the plan file Step 2.
```

### Prompt: Step 3 — HomeContent org_id

```
You are executing Step 3 of plan `plans/2026-03-20-multi-tenant-org-modules.md`.

Read these files first:
- plans/2026-03-20-multi-tenant-org-modules.md — full plan and design decisions
- projects/homecontent.md — architecture, patterns
- /Users/gregor/dev/922/HomeContent/CLAUDE.md — must read always
- /Users/gregor/dev/922/HomeContent/app/auth.py — current auth/header pattern
- /Users/gregor/dev/922/HomeContent/app/models/post.py
- /Users/gregor/dev/922/HomeContent/app/models/media_asset.py

Task: Add org_id to Post and MediaAsset models, create backfill migration, update auth layer to extract X-Org-ID/X-Org-Role, filter all queries by org_id.

Full details and acceptance criteria are in the plan file Step 3.
```

### Prompt: Step 4 — HomeAPI Data Migration

```
You are executing Step 4 of plan `plans/2026-03-20-multi-tenant-org-modules.md`.

Read these files first:
- plans/2026-03-20-multi-tenant-org-modules.md — full plan and design decisions
- projects/homeapi.md — architecture, 17 models, 21 routers
- /Users/gregor/dev/922/HomeAPI/CLAUDE.md — must read always
- /Users/gregor/dev/922/HomeAPI/.claude/HOW-TO-PYTEST-TEST.md — testing patterns
- /Users/gregor/dev/922/HomeAPI/app/models/ — read ALL model files
- /Users/gregor/dev/922/HomeAPI/app/crud/ — read ALL crud files
- /Users/gregor/dev/922/HomeAPI/app/routers/ — read ALL router files
- /Users/gregor/dev/922/HomeAPI/app/main.py — org_id now in request context (from Step 2)

Task: Add org_id to all 17 models, single backfill migration, update all CRUD to filter by org_id, update all routers to pass org_id from context, add user_id where personal ownership matters.

Full details and acceptance criteria are in the plan file Step 4.
```

### Prompt: Step 5 — HomeUI Module Awareness

```
You are executing Step 5 of plan `plans/2026-03-20-multi-tenant-org-modules.md`.

Read these files first:
- plans/2026-03-20-multi-tenant-org-modules.md — full plan and design decisions
- projects/homeui.md — architecture, patterns
- /Users/gregor/dev/922/HomeUI/CLAUDE.md — must read always
- /Users/gregor/dev/922/HomeUI/.claude/HOW-TO-UNIT-TEST.md — testing patterns
- /Users/gregor/dev/922/HomeUI/src/App.tsx — route definitions
- /Users/gregor/dev/922/HomeUI/src/api/ — existing API client patterns
- /Users/gregor/dev/922/HomeUI/tech_docs/api_integration.md — React Query patterns

Task: Create modules API client, useModules/useModule hooks, update navigation to show/hide/badge modules based on visibility and status, add route guards, add read-only Settings module section.

Full details and acceptance criteria are in the plan file Step 5.
```

---

## Post-Execution Checklist
- [ ] All tests pass across all 4 projects
- [ ] Documentation updated (HomeAuth: docs/HOMEAPI_INTEGRATION.md + README; HomeAPI: QUICK_REFERENCE; HomeUI: tech_docs)
- [ ] Pipeline green on all 4 repos
- [ ] Owner org seeded and JWT contains org_id/org_role in production
- [ ] Gregor's user assigned to owner org with role=admin
- [ ] All existing data backfilled to owner org
- [ ] No cross-org data leakage (verify in tests)
