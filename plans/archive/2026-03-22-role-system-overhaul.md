# Plan: Role System Overhaul

**Date**: 2026-03-22
**Status**: ready
**Projects**: HomeAuth, HomeUI

---

## Goal

Restructure both role systems:
1. **System roles**: Seed "user" as default, auto-assign on user creation
2. **Org roles**: Replace hardcoded enum with a table-based system where each org defines its own roles with custom permissions

---

## Architecture

### Current State

```
System Roles (global):
  roles table → user_roles junction → User.roles
  Only "admin" seeded. No default on user creation.

Org Roles (per-org):
  user_organizations.org_role = Enum("admin", "member")
  Hardcoded. Same 2 roles for every org. No permissions attached.
```

### Target State

```
System Roles (global) — minimal change:
  roles table → user_roles junction → User.roles
  Seed: "admin", "user" (default), "social"
  Auto-assign "user" role on creation if no roles specified

Org Roles (per-org) — new table-based system:
  org_roles table (per-org role definitions with permissions)
  ├── id (UUID, PK)
  ├── org_id (FK → organizations)
  ├── name (string, e.g. "owner", "editor", "viewer")
  ├── permissions (JSONB array, e.g. ["manage_users", "edit_content"])
  ├── is_default (bool — assigned to new members automatically)
  ├── sort_order (int — display ordering)
  └── created_at

  user_organizations table change:
  ├── org_role (Enum) → REMOVED
  └── org_role_id (FK → org_roles) → NEW

  Each org gets seeded with default roles:
  ├── "admin" — permissions: ["*"] (wildcard = everything)
  └── "member" — permissions: [] (base access)
  Orgs can add custom roles (e.g. "editor", "viewer") with specific permissions.
```

### Permission Strings (initial set)

```
manage_users     — add/remove/edit users in the org
manage_roles     — create/edit/delete org roles
manage_modules   — toggle module visibility for the org
edit_content     — create/edit content in content modules
view_analytics   — access analytics/reporting
*                — wildcard, all permissions (for org admin)
```

New permissions can be added without migrations — they're just strings checked in code.

### JWT / Header Flow (unchanged pattern)

```
Current:  JWT.org_role = "admin" → X-Org-Role: admin
New:      JWT.org_role = "admin" → X-Org-Role: admin (role name from org_roles)
          JWT.org_permissions = ["*"] → X-Org-Permissions: * (from org_roles.permissions)

The forward-auth header flow stays the same. The difference is that
org_role now comes from org_roles.name (via FK) instead of a hardcoded enum,
and org_permissions are the UNION of org.permissions + org_role.permissions.
```

---

## Steps

### Step 1: Seed system roles + auto-assign "user" default (HomeAuth)
**Project**: HomeAuth
**Directory**: `/Users/gregor/dev/922/HomeAuth`
**Parallel**: yes, with Step 2

**Changes**:

**`app/core/seeding.py`**:
- Rename `seed_admin_role()` → `seed_roles()`
- Seed all three roles: "admin", "user" (description: "Default user role"), "social"
- Return the admin role (for admin user assignment)

**`app/routes/admin.py`** — `create_user` endpoint:
- When `body.roles` is empty, auto-assign the "user" role
- Look up "user" role by name, assign it

**`app/schemas/auth.py`** — `UserCreate`:
- Keep `roles: list[str] = []` — empty means "assign default"
- Document this behavior

**Tests**: Update seeding tests, add test for default role assignment on user creation

---

### Step 2: Create org_roles table + migration (HomeAuth)
**Project**: HomeAuth
**Directory**: `/Users/gregor/dev/922/HomeAuth`
**Parallel**: yes, with Step 1

**Migration** (`alembic/versions/q001_org_roles_table.py`):

1. Create `org_roles` table:
   ```sql
   CREATE TABLE org_roles (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
     name VARCHAR(100) NOT NULL,
     permissions JSONB NOT NULL DEFAULT '[]',
     is_default BOOLEAN NOT NULL DEFAULT false,
     sort_order INTEGER NOT NULL DEFAULT 0,
     created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
     UNIQUE(org_id, name)
   );
   ```

2. For each existing org, seed default roles:
   ```sql
   INSERT INTO org_roles (id, org_id, name, permissions, is_default, sort_order)
   SELECT gen_random_uuid(), id, 'admin', '["*"]', false, 1 FROM organizations;

   INSERT INTO org_roles (id, org_id, name, permissions, is_default, sort_order)
   SELECT gen_random_uuid(), id, 'member', '[]', true, 2 FROM organizations;
   ```

3. Add `org_role_id` column to `user_organizations`:
   ```sql
   ALTER TABLE user_organizations ADD COLUMN org_role_id UUID REFERENCES org_roles(id);
   ```

4. Backfill `org_role_id` from existing `org_role` enum:
   ```sql
   UPDATE user_organizations uo
   SET org_role_id = (
     SELECT or2.id FROM org_roles or2
     WHERE or2.org_id = uo.org_id AND or2.name = uo.org_role
   );
   ```

5. Make `org_role_id` NOT NULL, drop `org_role` enum column:
   ```sql
   ALTER TABLE user_organizations ALTER COLUMN org_role_id SET NOT NULL;
   ALTER TABLE user_organizations DROP COLUMN org_role;
   DROP TYPE IF EXISTS org_role_enum;
   ```

**Model** (`app/models/organization.py`):
- Add `OrgRole` model
- Update `UserOrganization`: replace `org_role` with `org_role_id` FK + `role` relationship

**Context files for agent**:
- Read `CLAUDE.md`
- Read `app/models/organization.py`
- Read `alembic/versions/` (check latest revision for `down_revision`)

---

### Step 3: Update HomeAuth API for org roles (HomeAuth)
**Project**: HomeAuth
**Directory**: `/Users/gregor/dev/922/HomeAuth`
**Parallel**: no, depends on Steps 1-2

**Changes**:

**New endpoints** (`app/routes/admin_orgs.py`):
- `GET /admin/organizations/{org_id}/roles` — list org roles with permissions
- `POST /admin/organizations/{org_id}/roles` — create new org role
- `PATCH /admin/organizations/{org_id}/roles/{role_id}` — update role name/permissions
- `DELETE /admin/organizations/{org_id}/roles/{role_id}` — delete role (guard: can't delete if users assigned, can't delete last role)

**Updated endpoints** (`app/routes/admin_orgs.py`):
- `POST /admin/users/{user_id}/organization` — `org_role` param becomes `org_role_id` or `org_role_name` (look up by name within the org, fallback to default role)
- `PATCH /admin/users/{user_id}/organization` — same: accept role name or ID
- `GET /admin/organizations/{org_id}/users` — return role name + permissions instead of just "admin"/"member"

**Updated schemas** (`app/schemas/organization.py`):
- `OrgRoleOut`: id, name, permissions, is_default, sort_order
- `OrgRoleCreate`: name, permissions (list[str]), is_default (bool)
- `OrgRoleUpdate`: name?, permissions?, is_default?
- `UserOrganizationAssign`: change `org_role` to `role_name: str = None` (None = assign default role)
- `OrgUserOut`: change `org_role: str` to `org_role: OrgRoleOut` (full role with permissions)

**Updated JWT flow** (`app/routes/auth.py`):
- `_get_user_org()`: load `UserOrganization.role` (the OrgRole), return role.name as org_role and merge role.permissions with org.permissions
- JWT now carries org_role (name) + org_permissions (org.permissions UNION role.permissions)

**Seeding** (`app/core/seeding.py`):
- After creating an org, seed its default roles ("admin" with `["*"]`, "member" with `[]`)
- When assigning admin user to org, look up the "admin" org role by name

**Tests**: CRUD tests for org roles, updated org user tests, JWT content tests

---

### Step 4: Update HomeUI for org role management (HomeUI)
**Project**: HomeUI
**Directory**: `/Users/gregor/dev/922/HomeUI`
**Parallel**: no, depends on Step 3

**Changes**:

**Types** (`src/types/api/organizations.ts`):
- Add `OrgRole` type: `{ id, name, permissions, is_default, sort_order }`
- Update `OrgUser.org_role` from `string` to `OrgRole` (or keep string + add `org_role_permissions`)

**API** (`src/api/organizations.ts`):
- Add `listOrgRoles(orgId)`, `createOrgRole(orgId, data)`, `updateOrgRole(orgId, roleId, data)`, `deleteOrgRole(orgId, roleId)`

**Hooks** (`src/hooks/useOrganizations.ts`):
- Add `useOrgRoles(orgId)`, `useCreateOrgRole()`, `useUpdateOrgRole()`, `useDeleteOrgRole()`
- Update `useAssignUserToOrg()` to use role_name instead of org_role enum

**OrganisationDetailPage** (`src/features/organisations/pages/OrganisationDetailPage.tsx`):
- **Roles section**: New section showing org's roles with permissions, editable
  - List roles with name, permissions badges, is_default indicator
  - Add/edit/delete roles (dialog or inline)
- **Members table**: Org role column becomes a dropdown (select from org's roles)
  - On change → calls `PATCH /admin/users/{user_id}/organization` with new role

**UserFormDialog** (`src/features/users/components/UserFormDialog.tsx`):
- When assigning user to org, show org role picker (dropdown of org's roles instead of hardcoded admin/member)
- Default to the org's default role

---

### Step 5: Tests (HomeAuth + HomeUI)
**Project**: HomeAuth, HomeUI
**Parallel**: yes (one per project, after Step 4)

**HomeAuth tests**:
- Seeding: all 3 system roles created, default "user" role assigned on user creation
- Org roles CRUD: create, list, update, delete with guards
- Migration: existing data correctly migrated (org_role_id populated from enum)
- JWT: org_permissions includes role permissions
- User assignment: default role assigned when no role specified

**HomeUI tests**:
- Org role management: list, create, edit, delete
- Member role assignment: dropdown, change role
- User creation: default system role

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Step 1: Seed system roles + auto-assign default (HomeAuth)
  - Project: HomeAuth — seeding.py, admin.py
  - Parallel: yes, with Step 2
  - Context files: CLAUDE.md, app/core/seeding.py, app/routes/admin.py, app/schemas/auth.py

Step 2: Create org_roles table + migration (HomeAuth)
  - Project: HomeAuth — migration, models
  - Parallel: yes, with Step 1
  - Context files: CLAUDE.md, app/models/organization.py, latest alembic revision

Step 3: Update HomeAuth API for org roles (HomeAuth)
  - Project: HomeAuth — routes, schemas, auth flow
  - Depends on: Steps 1, 2
  - Context files: CLAUDE.md, app/routes/admin_orgs.py, app/routes/auth.py, app/schemas/organization.py

Step 4: Update HomeUI for org role management (HomeUI)
  - Project: HomeUI — types, API, hooks, pages
  - Depends on: Step 3
  - Context files: CLAUDE.md, src/types/api/organizations.ts, src/features/organisations/

Step 5: Tests (HomeAuth + HomeUI)
  - Parallel: yes (one agent per project)
  - Depends on: Step 4
```

```
Timeline:

  Step 1 (HomeAuth: seed + default) ─────┐
  Step 2 (HomeAuth: migration + model) ──┤  parallel
                                         ▼
  Step 3 (HomeAuth: API + JWT) ──────────┐
                                         ▼
  Step 4 (HomeUI: frontend) ─────────────┐
                                         ▼
  Step 5 (Tests: both projects) ─────────┐
                                         ▼
                                       Done
```

---

## Design Decisions

**Why JSONB for permissions instead of a separate table?**
- Permissions are simple string labels, not entities with their own metadata
- JSONB is simpler to query, easier to seed, and matches the existing `Organization.permissions` pattern
- Adding new permission strings never requires a migration
- If we ever need permission metadata (description, categories), we can add a `permission_definitions` reference table later

**Why role_name in API instead of role_id?**
- Human-readable API: `POST /users/{id}/organization { role_name: "editor" }` is clearer than `{ org_role_id: "uuid" }`
- Backend resolves name → ID within the org context
- IDs still used internally and for the update endpoint path param

**Why wildcard `["*"]` for admin instead of listing all permissions?**
- Admin should always have all permissions, even new ones added later
- Backend checks: `"*" in permissions or "specific_perm" in permissions`
- Avoids needing to update admin role every time a new permission is added

**Why keep the 1-user-1-org constraint?**
- No current use case for multi-org users
- Simplifies JWT (one org context per token)
- Can lift the constraint later if needed (remove `UniqueConstraint("user_id")`)
