# Plan: Management UI — Bug Fixes + Delete Functionality

- **Date**: 2026-03-22
- **Project(s)**: HomeUI
- **Goal**: Fix 4 bugs (duplicate admin badge, 2-letter avatar, broken org creation, missing org requirement) and add delete functionality for users and organisations with confirmation dialogs.

## Context

Read these files before proceeding:
- `projects/homeui.md` — project mapping and best practices
- `projects/homeauth.md` — backend auth service (delete endpoints already exist)

## Mockups (approved)

All mockups are in `/Users/gregor/dev/922/HomeUI/pencil/overview.pen`:
- **`7ud2Q`** — Delete User Confirmation dialog
- **`MI3YM`** — Delete Organisation Confirmation dialog
- **`hIHCK`** — New Organisation Form dialog

Design system: dark theme `#12121a`, JetBrains Mono, indigo `#6366f1` primary, red `#dc2626` destructive, borders `#1e1e2e`, muted text `#555577`/`#8888aa`, bright text `#e8e8ed`/`#f1f5f9`.

## Bugs to Fix

### Bug 1: "admin admin" duplicate role badge
- **File**: `src/features/users/pages/UsersPage.tsx` lines 191-226
- **Root cause**: `is_admin` renders an "admin" badge, AND `user.roles[]` also contains an "admin" role → shows "admin" twice
- **Fix**: Filter out roles named "admin" from the `user.roles.map()` when `user.is_admin` is true

### Bug 2: "New Organisation" button does nothing
- **File**: `src/features/organisations/pages/OrganisationsPage.tsx` line 158
- **Root cause**: Button has no `onClick` handler, no form dialog exists
- **Fix**: Create `OrgFormDialog` component (see mockup `hIHCK`), wire to button via `useCreateOrg` hook

### Bug 3: User avatar shows 2 letters instead of 1
- **File**: `src/features/users/pages/UsersPage.tsx` line 29
- **Root cause**: `initials()` function uses `.slice(0, 2)` — should be `.slice(0, 1)`
- **Fix**: Change to `.slice(0, 1).toUpperCase()`

### Bug 4: Users can be created without an organisation
- **File**: `src/features/users/components/UserFormDialog.tsx`
- **Root cause**: OrgSelector only shown for org managers, and has a "No organisation" option
- **Fix**: Always show OrgSelector, remove "No organisation" default option, make selection required

## Steps

### Step 1: Mockups ✅ DONE (2026-03-22)
- Pencil mockups created and approved.

### Step 2: Bug fixes (all 4)
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: —
- **Description**: Fix the 4 bugs listed above. Create `OrgFormDialog` component matching mockup `hIHCK`.
- **Context files to read**:
  - `src/features/users/pages/UsersPage.tsx` — admin badge dedup + avatar fix
  - `src/features/users/components/UserFormDialog.tsx` — org requirement
  - `src/features/organisations/pages/OrganisationsPage.tsx` — new org button
  - `src/hooks/useOrganizations.ts` — `useCreateOrg()` hook (already exists)
  - `src/api/organizations.ts` — `createOrg()` function (already exists)
- **Implementation details**:
  - **Bug 1**: In `UserRow`, filter `user.roles` to exclude name `"admin"` when `user.is_admin === true`
  - **Bug 2**: New file `src/features/organisations/components/OrgFormDialog.tsx`:
    - Dialog with name + slug fields (slug auto-generated from name via `slugify`)
    - Submit via `useCreateOrg` mutation
    - Dark theme matching mockup `hIHCK`
    - Import and wire in `OrganisationsPage.tsx` with state `[dialogOpen, setDialogOpen]`
  - **Bug 3**: Change `initials()` from `.slice(0, 2)` to `.slice(0, 1)`
  - **Bug 4**: In `UserFormDialog`:
    - Always render `<OrgSelector>` (remove `isOrgManager` guard)
    - Remove `<option value="">— No organisation —</option>`
    - Add form validation: block submit if no org selected
- **Acceptance criteria**:
  - [ ] "admin" badge shows only once per user
  - [ ] User avatar shows single letter
  - [ ] "New Organisation" opens form dialog, creates org on submit
  - [ ] Organisation selection required for all user creation/editing
  - [ ] Slug auto-generates from name in org form

### Step 3: Delete User — confirmation in edit dialog
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 4
- **Description**: Add delete user flow matching mockup `7ud2Q`.
- **Context files to read**:
  - `src/features/users/components/UserFormDialog.tsx` — add delete button + confirmation
  - `src/hooks/useUsers.ts` — `useDeleteUser()` hook (already exists, line 33-40)
  - `src/features/auth/AuthContext.tsx` — `hasRole('admin')` for admin gate
- **Implementation details**:
  - New component `ConfirmDeleteDialog` (reusable for both user and org deletion):
    - Props: `open`, `onOpenChange`, `title`, `description`, `warningText`, `confirmLabel`, `onConfirm`, `isPending`, `children` (slot for entity card)
    - Dark theme matching mockup: red trash icon, warning banner with `triangle-alert` icon, Cancel + red confirm button
  - In `UserFormDialog`:
    - Import `useDeleteUser` and `useAuth`
    - Add `hasRole('admin')` check from auth context
    - When editing AND admin: show red "Delete" button in bottom-left of actions row (opposite side from Cancel/Save)
    - On click: open `ConfirmDeleteDialog` with user card (avatar letter + name + email)
    - On confirm: call `deleteMutation.mutate(user.id)`, close both dialogs
  - Actions row layout: `justifyContent: "space-between"` — delete button left, cancel+save right
- **Acceptance criteria**:
  - [ ] Delete button visible only when editing AND `hasRole('admin')`
  - [ ] Confirmation shows user avatar, name, email (matching mockup `7ud2Q`)
  - [ ] Warning: "All data associated with this user will be permanently deleted."
  - [ ] On confirm: deletes user, closes dialog, refreshes list
  - [ ] Red `#dc2626` styling on confirm button

### Step 4: Delete Organisation — button on detail page
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 3
- **Description**: Add delete org flow matching mockup `MI3YM`.
- **Context files to read**:
  - `src/features/organisations/pages/OrganisationDetailPage.tsx` — add button to header
  - `src/hooks/useOrganizations.ts` — `useDeleteOrg()` hook (already exists, line 37-44)
  - `src/hooks/useUsers.ts` — `useRemoveUserFromOrg()` hook
- **Backend constraint**: HomeAuth returns HTTP 400 "Cannot delete organization with assigned users". Must remove all members first via `DELETE /admin/users/{user_id}/organization` for each member, then delete the org.
- **Implementation details**:
  - Reuse `ConfirmDeleteDialog` from Step 3
  - In `OrganisationDetailPage`:
    - Import `useDeleteOrg`, `useRemoveUserFromOrg`, `useAuth`, `useNavigate`
    - Add `hasRole('admin')` check
    - Add red "Delete Organisation" button (with trash-2 icon) in top-right of org header card, next to the org info
    - On click: open `ConfirmDeleteDialog` with org card (building icon + name + slug + member count)
    - On confirm handler (`handleDeleteOrg`):
      1. For each member in `members`: `await removeUserFromOrg(member.user_id)`
      2. Then: `await deleteOrg(org.id)`
      3. Navigate to `/management/organisations`
    - Warning text: "All {N} members will be removed from this organisation before deletion."
    - Admin-only: button hidden if not `hasRole('admin')`
- **Acceptance criteria**:
  - [ ] Delete button in top-right of org header (matching mockup `MI3YM`)
  - [ ] Confirmation shows org icon, name, slug, member count
  - [ ] Warning about member removal with actual count
  - [ ] On confirm: removes all members sequentially, then deletes org, navigates back
  - [ ] Red `#dc2626` styling, admin-only visibility

### Step 5: Update tests + push + monitor pipeline
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: —
- **Description**: Update MSW handlers, E2E tests, and unit tests for all changes. Push and monitor pipeline.
- **Implementation details**:
  - **MSW handlers** (`src/test/msw/handlers.ts`):
    - Add `DELETE */admin/users/:id` handler (204)
    - Add `DELETE */admin/organizations/:id` handler (204)
    - Add `DELETE */admin/users/:id/organization` handler (204)
    - Update org handlers: add `POST */admin/organizations` (201)
  - **E2E test data** (`e2e/fixtures/test-data.ts`): no changes needed (factories already correct)
  - **E2E tests**:
    - `e2e/management/organisations.spec.ts` — add test for org creation dialog, add test for delete org button + confirmation
    - `e2e/users/users.spec.ts` — add test for delete user button visibility (admin-only), add test for required org selection
  - **Unit tests**: Verify existing tests still pass after bug fixes
- **Acceptance criteria**:
  - [ ] MSW handlers cover all new endpoints
  - [ ] E2E tests for: org creation, org deletion, user deletion, required org field
  - [ ] All existing tests still pass
  - [ ] Pipeline green after push

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1: ✅ DONE
  Step 1: Pencil mockups — approved

Wave 2:
  Step 2: Bug fixes (admin dedup, avatar, org creation, org requirement)
    → HomeUI @ /Users/gregor/dev/922/HomeUI
    → Creates: src/features/organisations/components/OrgFormDialog.tsx
    → Modifies: UsersPage.tsx, UserFormDialog.tsx, OrganisationsPage.tsx

Wave 3 (parallel):
  Step 3: Delete User UI
    → HomeUI @ /Users/gregor/dev/922/HomeUI
    → Creates: src/components/ConfirmDeleteDialog.tsx (shared)
    → Modifies: UserFormDialog.tsx
  Step 4: Delete Organisation UI
    → HomeUI @ /Users/gregor/dev/922/HomeUI
    → Modifies: OrganisationDetailPage.tsx
    → Reuses: ConfirmDeleteDialog from Step 3

Wave 4:
  Step 5: Tests + push + pipeline
    → HomeUI @ /Users/gregor/dev/922/HomeUI
    → Modifies: MSW handlers, E2E specs
```

## Post-Execution Checklist
- [x] Mockups reviewed and approved (2026-03-22)
- [x] All tests pass — 146 files, 1159 tests (2026-03-22)
- [x] Pipeline green — run 23399326569 (2026-03-22)
- [ ] Delete flows tested end-to-end (manual UAT)
