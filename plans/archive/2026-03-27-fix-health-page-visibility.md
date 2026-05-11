# Plan: Fix /health page visibility on prod and dev

- **Date**: 2026-03-27
- **Status**: DONE (2026-03-27)
- **Project(s)**: HomeStructure, HomeAPI, HomeUI
- **Goal**: Restore the /health page so it is accessible and fully functional on both prod and dev environments.

## Root Cause Analysis

Investigation found **two issues** and one potential database-level cause:

### Issue 1: Missing Traefik `authResponseHeaders` (confirmed)
**File**: `HomeStructure/traefik/dynamic/middleware.yaml`

The forward-auth middleware only passes 5 headers but HomeAuth sets 7. Missing:
- `X-Org-Permissions` — needed by `/api/modules` admin bypass logic
- `X-Org-Slug` — needed for org context

### Issue 2: Potential database state (must verify on server)
The `/api/modules` endpoint returns the health module only if:
1. The `health` row exists in the `modules` table with `global_status = 'active'`
2. No `org_modules` row exists with `visible = false` for the user's org
3. The user has `X-Org-ID` set (i.e., is assigned to an organization)

If any of these fail, the ModuleGuard redirects `/health` to `/` and the sidebar hides the link.

### How the module system works (for executing agents)
```
HomeUI sidebar → GET /api/modules (via lab-api.922-studio.com)
  → Traefik forward-auth → HomeAuth /auth/verify → adds X-Org-ID header
  → HomeAPI get_modules_for_org(org_id)
    → if no org_id: return [] (ALL modules hidden)
    → merge modules table with org_modules overrides
    → filter visible=true, return with status
HomeUI ModuleGuard → if module not found or status='hidden' → redirect to /
HomeUI sidebar → only shows modules with status 'active' or 'under_development'
```

## Context

Read these files before proceeding:
- `projects/homeapi.md` — HomeAPI mapping
- `projects/homeui.md` — HomeUI mapping
- `server.md` — server access and infrastructure

## Steps

### Step 1: Diagnose database state on server
- **Project**: HomeAPI (database)
- **Directory**: Server via `ssh lab`
- **Parallel with**: —
- **Description**: Run diagnostic SQL queries on both prod and dev databases to identify the exact cause.
- **Commands to run**:

```bash
# === PROD DATABASE ===
ssh lab

# 1. Check if health module exists and its status
docker exec -it shared_postgres psql -U home_api -d home_api -c \
  "SELECT slug, name, global_status, sort_order FROM modules WHERE slug = 'health';"

# 2. Check ALL modules for comparison
docker exec -it shared_postgres psql -U home_api -d home_api -c \
  "SELECT slug, name, global_status, sort_order FROM modules ORDER BY sort_order;"

# 3. Check org_modules overrides (any org hiding health?)
docker exec -it shared_postgres psql -U home_api -d home_api -c \
  "SELECT om.org_id, om.module_slug, om.visible, om.status FROM org_modules om WHERE om.module_slug = 'health';"

# 4. Check all org_modules overrides
docker exec -it shared_postgres psql -U home_api -d home_api -c \
  "SELECT om.org_id, om.module_slug, om.visible, om.status FROM org_modules om ORDER BY om.org_id, om.module_slug;"

# 5. List organizations (to cross-reference org_id)
docker exec -it shared_postgres psql -U home_api -d home_api -c \
  "SELECT id, name, slug FROM organizations;" 2>/dev/null || echo "organizations table not in home_api DB"

# === DEV DATABASE ===
# 6. Same checks on dev
docker exec -it dev_postgres psql -U home_api -d dev_home_api -c \
  "SELECT slug, name, global_status, sort_order FROM modules WHERE slug = 'health';"

docker exec -it dev_postgres psql -U home_api -d dev_home_api -c \
  "SELECT om.org_id, om.module_slug, om.visible, om.status FROM org_modules om WHERE om.module_slug = 'health';"
```

- **Acceptance criteria**:
  - [ ] Know whether `health` module exists in both prod and dev databases
  - [ ] Know whether any org_modules override hides health
  - [ ] Root cause confirmed

### Step 2: Fix Traefik middleware — add missing headers
- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure`
- **Parallel with**: Step 1
- **Description**: Add `X-Org-Permissions` and `X-Org-Slug` to the Traefik forward-auth `authResponseHeaders`. This is a confirmed bug regardless of the health page issue.
- **Context files to read**:
  - `HomeStructure/traefik/dynamic/middleware.yaml` — current config
  - `HomeAuth/app/routes/auth.py` — verify endpoint sets all 7 headers

**Change** `HomeStructure/traefik/dynamic/middleware.yaml`:
```yaml
http:
  middlewares:
    auth-verify:
      forwardAuth:
        address: "http://homeauth:8000/auth/verify"
        authResponseHeaders:
          - "X-User-ID"
          - "X-User-Email"
          - "X-User-Roles"
          - "X-Org-ID"
          - "X-Org-Role"
          - "X-Org-Slug"
          - "X-Org-Permissions"
```

- **After change**: Commit, push, then on server:
```bash
ssh lab
cd ~/HomeStructure && git pull && docker compose restart traefik
```

- **Acceptance criteria**:
  - [ ] middleware.yaml includes all 7 headers
  - [ ] Traefik restarted on server
  - [ ] No Traefik errors in logs: `docker compose logs traefik --tail 20`

### Step 3: Fix database state (conditional — based on Step 1 results)
- **Project**: HomeAPI
- **Directory**: Server via `ssh lab`
- **Parallel with**: —
- **Description**: Apply the appropriate fix based on Step 1 diagnosis.

**If health module is MISSING from modules table:**
```bash
docker exec -it shared_postgres psql -U home_api -d home_api -c \
  "INSERT INTO modules (id, slug, name, description, global_status, sort_order, created_at)
   VALUES (gen_random_uuid()::text, 'health', 'Sleep Tracking', 'Track sleep patterns and trends', 'active', 4, NOW())
   ON CONFLICT (slug) DO UPDATE SET global_status = 'active', sort_order = 4;"

# Same for dev
docker exec -it dev_postgres psql -U home_api -d dev_home_api -c \
  "INSERT INTO modules (id, slug, name, description, global_status, sort_order, created_at)
   VALUES (gen_random_uuid()::text, 'health', 'Sleep Tracking', 'Track sleep patterns and trends', 'active', 4, NOW())
   ON CONFLICT (slug) DO UPDATE SET global_status = 'active', sort_order = 4;"
```

**If health module has wrong global_status:**
```bash
docker exec -it shared_postgres psql -U home_api -d home_api -c \
  "UPDATE modules SET global_status = 'active' WHERE slug = 'health';"

docker exec -it dev_postgres psql -U home_api -d dev_home_api -c \
  "UPDATE modules SET global_status = 'active' WHERE slug = 'health';"
```

**If org_modules override is hiding it:**
```bash
# Option A: Delete the override (falls back to global active)
docker exec -it shared_postgres psql -U home_api -d home_api -c \
  "DELETE FROM org_modules WHERE module_slug = 'health' AND visible = false;"

# Option B: Set it to visible + active
docker exec -it shared_postgres psql -U home_api -d home_api -c \
  "UPDATE org_modules SET visible = true, status = 'active' WHERE module_slug = 'health';"

# Same for dev
docker exec -it dev_postgres psql -U home_api -d dev_home_api -c \
  "DELETE FROM org_modules WHERE module_slug = 'health' AND visible = false;"
```

**If migrations haven't been applied (no modules table):**
```bash
# Run migrations on prod
docker exec -it home_api_api alembic upgrade head

# Run migrations on dev
docker exec -it dev_home_api_api alembic upgrade head
```

- **Acceptance criteria**:
  - [ ] `SELECT slug, global_status FROM modules WHERE slug = 'health';` returns `active` on both databases
  - [ ] No org_modules overrides hiding health on either database

### Step 4: Verify the fix end-to-end
- **Project**: All
- **Directory**: Server + browser
- **Parallel with**: —
- **Description**: Verify the /health page works on both prod and dev.

**API verification (from server):**
```bash
ssh lab

# Prod: Check modules endpoint returns health
# (needs auth token — use curl with a valid JWT or test via browser DevTools)
curl -s http://localhost:8080/api/modules -H "X-Org-ID: <ORG_ID_FROM_STEP_1>" | python3 -m json.tool | grep -A3 health

# Dev: Same check
curl -s http://localhost:8180/api/modules -H "X-Org-ID: <ORG_ID_FROM_STEP_1>" | python3 -m json.tool | grep -A3 health

# Also verify health endpoints respond
curl -s http://localhost:8080/health
curl -s http://localhost:8180/health
```

**Browser verification:**
1. Open `https://lab.922-studio.com` (prod HomeUI)
   - [ ] Health link visible in sidebar
   - [ ] Click Health → `/health` page loads
   - [ ] Health overview shows entries (or "No entries recorded")
2. Open `https://lab-dev.922-studio.com` (dev HomeUI) — if accessible
   - [ ] Same checks as above
3. Open browser DevTools → Network tab:
   - [ ] `GET /api/modules` returns 200 with health module in response
   - [ ] `GET /api/health/sleep/entries` returns 200

- **Acceptance criteria**:
  - [ ] /health page accessible on prod
  - [ ] /health page accessible on dev
  - [ ] Sidebar shows Health link on both environments
  - [ ] No console errors on health page

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Diagnose DB state           → Server @ ssh lab (manual)
  Step 2: Fix Traefik middleware       → HomeStructure @ /Users/gregor/dev/922/HomeStructure

Wave 2 (after wave 1 — Step 1 determines which fix):
  Step 3: Fix database state           → Server @ ssh lab (manual, conditional)

Wave 3 (after all fixes applied):
  Step 4: End-to-end verification      → Server + browser (manual)
```

## Agent Prompts

### Step 2 Agent Prompt (HomeStructure — Traefik middleware fix)

> **Project**: HomeStructure
> **Directory**: `/Users/gregor/dev/922/HomeStructure`
> **Model**: Sonnet
>
> Read these files first:
> - `traefik/dynamic/middleware.yaml` — current Traefik middleware config
>
> **Task**: Add missing `X-Org-Slug` and `X-Org-Permissions` headers to the forward-auth middleware in `traefik/dynamic/middleware.yaml`.
>
> The `authResponseHeaders` list must include all 7 headers that HomeAuth's `/auth/verify` endpoint returns:
> - X-User-ID
> - X-User-Email
> - X-User-Roles
> - X-Org-ID
> - X-Org-Role
> - X-Org-Slug (NEW)
> - X-Org-Permissions (NEW)
>
> After editing, commit with message: `fix: add missing X-Org-Slug and X-Org-Permissions to auth forward headers`
>
> Do NOT push — that will be done manually after review.

## Post-Execution Checklist
- [ ] Traefik middleware includes all 7 auth headers
- [ ] Health module exists and is active in prod database
- [ ] Health module exists and is active in dev database
- [ ] No org_modules overrides hiding health
- [ ] /health page loads on prod (lab.922-studio.com/health)
- [ ] /health page loads on dev
- [ ] Sidebar shows Health nav link
- [ ] Pipeline green after HomeStructure push
- [ ] Traefik logs clean (no errors)
