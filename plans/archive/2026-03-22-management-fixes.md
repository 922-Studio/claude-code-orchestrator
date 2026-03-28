# Plan: Management System Fixes

**Date**: 2026-03-22
**Status**: executed (2026-03-22)
**Projects**: HomeAuth, HomeUI, HomeAPI

---

## Issues & Root Cause Analysis

### Issue 1: Delete user → 500 Internal Server Error (only admin deleting admin)

**Reproduction**: Admin tries to delete another admin user.

**Root cause**: In HomeAuth `app/routes/admin.py:216-225`, the last-admin guard counts `other_admins`. If there are exactly 2 admins total and the acting admin tries to delete the other admin, `other_admins` = 1 (the acting admin themselves), so the guard passes and deletion proceeds. The deletion itself works fine at the DB level (cascade deletes roles, tokens, org membership).

**However**: The 500 error likely comes from the frontend's `handleOrgAssignment` flow. When the user update form submits, it calls `updateUser` then `handleOrgAssignment`. If something in that chain fails (e.g. the user being deleted is also the current session user, or there's a token/auth issue after deletion), the 500 propagates.

**More likely root cause**: The frontend `UserFormDialog.tsx:181-189` calls `DELETE /admin/users/{id}` via HomeAuth. But the HomeAuth admin routes require `require_admin` dependency, which validates the current user's JWT. If the acting admin's JWT was issued before they were admin, or if there's a session validation issue, it could 500.

**Need to verify**: Check the actual server logs on HomeAuth for the 500 traceback. The code looks correct for the delete endpoint itself — it has proper guards and cascade. The 500 might come from a middleware or auth dependency, not the delete logic.

**Action**: Add proper error logging and check server logs. Also: the frontend should show the error message from the API response, not just "500".

### Issue 2: User edit panel UX — delete popup hides edit panel

**Current behavior**: User clicks "Delete" → `ConfirmDeleteDialog` opens on TOP of the `UserFormDialog` (both visible, layered). If cancelled, the confirm dialog closes and edit panel is still there.

**Requested behavior**: When delete popup appears, the edit panel should vanish. If cancelled/X pressed, delete popup disappears and edit panel comes back. On successful delete, both close.

**Root cause**: Both dialogs are rendered as siblings (`<>` fragment in `UserFormDialog.tsx:210-418`). The `Dialog` component uses `open` prop, and both can be open simultaneously.

**Fix**: When `confirmDeleteOpen` becomes true, set the main dialog's open to false. When confirm dialog is closed without deletion, reopen the main dialog.

### Issue 3: 922-studio can't see coming_soon modules in sidebar

**Root cause**: Two-layer problem from our recent changes:

1. **Backend** (HomeAPI `app/crud/module.py:116-125`): For `org-management` orgs, returns ALL modules with `status: module.global_status`. So `content` returns with `status: "under_development"` and `memory` with `status: "coming_soon"`.

2. **Frontend** (HomeUI `AppSidebar.tsx:116`): Filters `.filter((m) => m.status === 'active')` — this filters OUT the non-active modules even for the admin org.

**Fix**: Two options:
- **Option A (backend)**: For `org-management` orgs, override all statuses to `"active"` so the frontend filter passes them through.
- **Option B (frontend)**: Don't filter by status in the sidebar. Instead, use the API response as-is — if the backend returns a module, show it. The backend already handles visibility (hidden modules aren't returned). Add visual indicator for coming_soon/under_development.

**Chosen**: Option A — backend overrides status to `active` for org-management orgs. This is the simplest fix and keeps the sidebar logic clean. The org-management org is the admin org that should see everything as if it's active.

### Issue 4: Organisation page shows wrong roles

**Root cause**: The org detail page at `OrganisationDetailPage.tsx` displays `org_role` from `OrgUserOut` schema, which is the **organisation role** (admin/member), NOT the **system role** (admin/user/social).

The endpoint `GET /admin/organizations/{org_id}/users` in HomeAuth (`admin_orgs.py:130-153`) returns `org_role` from `UserOrganization.org_role` — this is the role within the org (e.g., "admin" or "member"), assigned when the user was added to the org.

**The issue**: All users might have been added to the org with default `org_role = "admin"` (which is the seeding default), or the assignment endpoint defaults to "admin". The roles shown on the org page are ORG roles, not system roles. If the user expects to see system-level roles here, that's a display mismatch.

**Fix**: The org detail page should show the user's **system roles** (from `User.roles`) in addition to or instead of `org_role`. Alternatively, clarify in the UI that these are org-level roles, not system roles. Also need to ensure the `org_role` was set correctly during user assignment.

### Issue 5: Deleting an org does not delete users within it

**Current behavior**: HomeAuth `admin_orgs.py:99-124` BLOCKS deletion if org has members. Returns 400: "Cannot delete organization with assigned users". The frontend `OrganisationDetailPage.tsx:272-285` handles this by removing all members FIRST (loop of `removeUserFromOrg` calls), then deleting the org.

**The issue**: Removing a user from an org (`DELETE /admin/users/{id}/organization`) only removes the `UserOrganization` record — the user still exists. Users are NOT deleted when removed from an org.

**Expected behavior**: The user wants deleting an org to cascade-delete all users that belong to it. Currently: org delete → first removes all memberships → then deletes empty org. Users become "unassigned" but still exist.

**Fix**: Change the org deletion flow to delete users entirely (not just remove memberships). Add a new step in the frontend flow: for each member, call `DELETE /admin/users/{id}` (full user deletion), then delete the org.

### Issue 6: Removing admin access from a user not working

**Root cause**: The frontend `UserFormDialog.tsx` uses `RolesPicker` to toggle roles. When an admin untogles the "admin" role and submits, `handleSubmit` calls `PUT /admin/users/{id}` with `roles: ["user"]` (without "admin").

The HomeAuth `update_user` endpoint (lines 162-175) has a **last-admin guard**: if the user currently has admin AND the new roles don't include admin, it checks if there are other admins. If this is the last admin, it returns 400.

**But**: If there are multiple admins, this should work. The issue might be:
1. The frontend is sending `roles: []` (empty) instead of `roles: ["user"]`
2. The role names don't match between frontend and backend
3. The PUT request isn't including the `roles` field at all (the diff check on line 199-201 might not detect the change)

**Also**: The `isOrgManager` vs `isAdmin` check might be interfering — the frontend shows the delete button only if `isAdmin`, but role editing is available to all admins.

### Issue 7: Permission system explanation + system admin role

**Current architecture**:

```
System Level (HomeAuth):
├── User.roles[] — system-wide roles: "admin", "user", "social"
│   └── "admin" role = can access /admin/* endpoints
│   └── is_admin is COMPUTED: any(r.name == "admin" for r in roles)
│
├── Organization.permissions[] — JSONB array on org: ["org-management"]
│   └── Set during seeding for 922-studio
│   └── Flows into JWT → X-Org-Permissions header
│
└── UserOrganization.org_role — role within org: "admin" or "member"
    └── Controls org-level access (separate from system admin)

Service Level (HomeAPI, HomeCollector, etc.):
├── X-User-Roles header → system roles (from JWT)
├── X-Org-Role header → org role (from JWT)
├── X-Org-Permissions header → org permissions (from JWT)
└── Each service checks these headers independently
```

**For 922-studio org**:
- Org has `permissions: ["org-management"]`
- This flows into every request as `X-Org-Permissions: org-management`
- HomeAPI module endpoint checks this to return all modules
- But there's no "super admin" concept that bypasses everything

**Recommendation**: The "admin" system role + the "org-management" org permission already serve as the super-admin concept. The combination of `is_admin: true` (system) + org with `org-management` permission = full access. No new role needed — just need to ensure the UI respects this combination.

---

## Steps

### Step 1: Fix sidebar — admin org sees all modules (HomeAPI)
**Project**: HomeAPI
**Directory**: `/Users/gregor/dev/922/HomeAPI`
**Parallel**: yes, with Steps 2-4

**Change**: In `app/crud/module.py`, `get_modules_for_org()` line 122: when `is_org_admin` is true, set `status` to `"active"` instead of `module.global_status`. This makes the admin org see all modules as active in the sidebar.

```python
# Current:
"status": module.global_status,
# Change to:
"status": "active",
```

**Context files for agent**:
- Read `CLAUDE.md`
- Read `app/crud/module.py`

---

### Step 2: Fix user edit/delete panel UX (HomeUI)
**Project**: HomeUI
**Directory**: `/Users/gregor/dev/922/HomeUI`
**Parallel**: yes, with Steps 1, 3, 4

**Change**: In `src/features/users/components/UserFormDialog.tsx`:

1. When "Delete" is clicked (line 329): also close the main dialog (`onOpenChange(false)`)
2. When confirm dialog is cancelled (closed without confirming): reopen the main dialog (`onOpenChange(true)`)
3. On successful deletion: both stay closed (already works — line 186 closes main dialog)

Modify `ConfirmDeleteDialog` `onOpenChange` to detect cancel vs confirm:
```
setConfirmDeleteOpen(true) → also call onOpenChange(false)
ConfirmDeleteDialog onOpenChange → if closing without delete, call onOpenChange(true)
```

**Context files for agent**:
- Read `CLAUDE.md`
- Read `src/features/users/components/UserFormDialog.tsx`
- Read `src/components/ConfirmDeleteDialog.tsx`

---

### Step 3: Fix org detail page — show correct roles (HomeUI + HomeAuth)
**Project**: HomeUI, HomeAuth
**Directory**: `/Users/gregor/dev/922/HomeUI`, `/Users/gregor/dev/922/HomeAuth`
**Parallel**: yes, with Steps 1, 2, 4

**Problem**: Org detail page shows `org_role` (admin/member within org) but user expects to see system roles.

**Changes**:

**HomeAuth** — `app/routes/admin_orgs.py`, `app/schemas/organization.py`:
- Add `roles: list[str]` (system role names) to `OrgUserOut` schema
- In `list_org_users()`: eagerly load `User.roles` and include role names in response

**HomeUI** — `src/features/organisations/pages/OrganisationDetailPage.tsx`:
- Display system roles (admin/user/social badges) alongside or instead of org_role
- Update `OrgUser` type in `src/types/api/organizations.ts` to include `roles: string[]`

**Context files for agent**:
- Read HomeAuth `app/routes/admin_orgs.py` (list_org_users function)
- Read HomeAuth `app/schemas/organization.py` (OrgUserOut)
- Read HomeUI `src/features/organisations/pages/OrganisationDetailPage.tsx`
- Read HomeUI `src/types/api/organizations.ts`

---

### Step 4: Fix org deletion — cascade delete users (HomeUI)
**Project**: HomeUI
**Directory**: `/Users/gregor/dev/922/HomeUI`
**Parallel**: yes, with Steps 1, 2, 3

**Change**: In `src/features/organisations/pages/OrganisationDetailPage.tsx`, `handleDeleteOrg()`:

Currently:
```typescript
for (const member of members) {
  await removeUserMutation.mutateAsync(member.user_id)  // removes from org only
}
await deleteMutation.mutateAsync(id)  // deletes empty org
```

Change to:
```typescript
for (const member of members) {
  await deleteUserMutation.mutateAsync(member.user_id)  // fully deletes user
}
await deleteMutation.mutateAsync(id)  // deletes empty org
```

Need to import `useDeleteUser` and use it instead of `useRemoveUserFromOrg` for the org deletion flow.

**Warning**: This is destructive! Add a stronger warning in the confirm dialog: "This will permanently delete all users in this organisation."

**Context files for agent**:
- Read `CLAUDE.md`
- Read `src/features/organisations/pages/OrganisationDetailPage.tsx`
- Read `src/hooks/useUsers.ts` (useDeleteUser)

---

### Step 5: Investigate and fix admin deletion 500 error (HomeAuth)
**Project**: HomeAuth
**Directory**: `/Users/gregor/dev/922/HomeAuth`
**Parallel**: after Steps 1-4 (needs server log investigation)

**Action**:
1. Check server logs: `ssh lab` → check HomeAuth container logs for 500 traceback
2. If the 500 is from `delete_user` endpoint: fix the specific error
3. If the 500 is from a different endpoint called during the flow: trace the full request chain
4. Add better error handling/logging if needed

**Likely fix**: The delete endpoint itself looks correct. The 500 might come from:
- Deleting a user who is the current `require_admin` authenticated user (self-delete guard should catch this but maybe UUID comparison is wrong)
- Token validation failing after a related user operation
- Database constraint violation not caught by the guards

**Context files for agent**:
- Read `CLAUDE.md`
- Read `app/routes/admin.py` (delete_user endpoint)
- Read `app/dependencies/admin.py` (require_admin)
- Check server logs

---

### Step 6: Fix admin role removal (HomeUI)
**Project**: HomeUI
**Directory**: `/Users/gregor/dev/922/HomeUI`
**Parallel**: after Step 5

**Debug**: In `UserFormDialog.tsx`, the role change detection (lines 199-201) compares sorted role names. Trace through:
1. What `user.roles` looks like (array of `{ id, name, description }`)
2. What `selectedRoles` looks like after untoggling "admin"
3. Whether `payload.roles` actually gets set
4. Whether the PUT request includes the roles field

**Likely fix**: The issue might be that `body.roles` in the PUT request is only sent when roles actually change (diff check). But if the comparison is wrong (e.g., stringification differs), roles might not be included in the payload.

Also check: can the last-admin guard be triggered incorrectly? If there are 2 admins and one tries to remove admin from the other, it should work. But if the count query has a bug...

**Context files for agent**:
- Read `CLAUDE.md` in HomeUI
- Read `src/features/users/components/UserFormDialog.tsx`
- Read `src/features/users/pages/UsersPage.tsx` (handleSubmit)
- Read HomeAuth `app/routes/admin.py` (update_user endpoint, lines 162-175)

---

### Step 7: Tests
**Project**: HomeUI, HomeAuth, HomeAPI
**Parallel**: yes (one agent per project, after Steps 1-6)

**HomeAPI tests**: Update module tests for admin org status override
**HomeAuth tests**: Add test for admin deleting admin, role removal edge cases
**HomeUI tests**: Update sidebar/dialog tests

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Step 1: Fix sidebar admin org modules (HomeAPI)
  - Project: HomeAPI — app/crud/module.py
  - Parallel: yes, with Steps 2-4

Step 2: Fix user edit/delete panel UX (HomeUI)
  - Project: HomeUI — UserFormDialog.tsx
  - Parallel: yes, with Steps 1, 3, 4

Step 3: Fix org detail page roles (HomeAuth + HomeUI)
  - Project: HomeAuth + HomeUI
  - Parallel: yes, with Steps 1, 2, 4

Step 4: Fix org deletion cascade (HomeUI)
  - Project: HomeUI — OrganisationDetailPage.tsx
  - Parallel: yes, with Steps 1, 2, 3

Step 5: Investigate admin deletion 500 (HomeAuth)
  - Project: HomeAuth — server logs + admin.py
  - Parallel: after Steps 1-4

Step 6: Fix admin role removal (HomeUI)
  - Project: HomeUI — UserFormDialog.tsx
  - Parallel: after Step 5

Step 7: Tests (all projects)
  - Parallel: yes, after Steps 1-6
```

```
Timeline:

  Step 1 (HomeAPI: sidebar fix) ──────┐
  Step 2 (HomeUI: edit/delete UX) ────┤
  Step 3 (HomeAuth+UI: roles) ────────┤  parallel
  Step 4 (HomeUI: org delete) ────────┤
                                      ▼
  Step 5 (HomeAuth: 500 error) ───────┐
                                      ▼
  Step 6 (HomeUI: role removal) ──────┐
                                      ▼
  Step 7 (Tests: all projects) ───────┐
                                      ▼
                                    Done
```

---

## Permission Architecture Summary (for Gregor)

```
┌─────────────────────────────────────────────────┐
│                  SYSTEM LEVEL                     │
│  User.roles = ["admin", "user", "social"]        │
│  • "admin" → access to /admin/* endpoints        │
│  • is_admin = computed from roles                │
│  • Stored in: HomeAuth users + roles tables      │
│  • Flows via: JWT → X-User-Roles header          │
├─────────────────────────────────────────────────┤
│               ORGANISATION LEVEL                  │
│  Organization.permissions = ["org-management"]   │
│  • Set once during seeding for 922-studio        │
│  • Not editable via UI (hardcoded in DB)         │
│  • Flows via: JWT → X-Org-Permissions header     │
│  • HomeAPI checks this for "see all modules"     │
├─────────────────────────────────────────────────┤
│            ORG MEMBERSHIP LEVEL                   │
│  UserOrganization.org_role = "admin" | "member"  │
│  • Per-user role within an org                   │
│  • Currently: 1 user = 1 org (unique constraint) │
│  • Not the same as system admin!                 │
└─────────────────────────────────────────────────┘

922-studio org:
  • Has permissions: ["org-management"]
  • All users in this org → X-Org-Permissions: org-management
  • Combined with is_admin: true → full super-admin access
  • No additional role needed
```
