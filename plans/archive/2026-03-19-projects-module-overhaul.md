# Projects Module Overhaul

**Date**: 2026-03-19
**Status**: DONE (2026-03-19)
**Project**: HomeUI
**Directory**: `/Users/gregor/dev/922/HomeUI`
**Scope**: UI fixes, API fixes, full test coverage (test-first approach)

---

## Issues Identified

### Layout & UI
1. **Project detail page has `maxWidth: 960px`** — leaves a gap on the right (`ProjectDetailPage.tsx:26`)
2. **Dialog component not scrollable** — `DialogContent` has no `overflow-y: auto` or `max-height` (`dialog.tsx:97`), will clip on small screens
3. **"+ Add Goal" button is plain text** — needs to match the style of `+ Add Task`, `+ Add Idea` etc. (emerald pill style from `ProjectTasks.tsx:46-48`)
4. **Goals have no edit button** — need hover-only edit icon per goal row (`ProjectGoals.tsx:73-101`)
5. **"+ Add Task/Idea/Note/Log Work" buttons inconsistent** — Tasks, Ideas, Notes, Worklogs all use the same emerald pill, but Notes uses it in `SectionHeader.action` while Goals uses plain text. All should match the "Edit Project" button style (`ProjectHeader.tsx:112-119`: zinc-800 bg, zinc-400 text, rounded pill)
6. **Tasks page shows nothing** — `ProjectsTasksPage.tsx` only lists project names with task counts, doesn't actually show/load individual tasks

### API Issues (test-first discovery)
7. **`updateProject` sends `status` field** — but the backend API field is `project_status` (`EditProjectDialog.tsx:94` sends `status`)
8. **`patchProjectContext` wraps in `{ updates }` object** — needs verification if backend expects `{ updates: { goals: [...] } }` or flat `{ goals: [...] }`
9. **`ProjectsTasksPage` doesn't fetch tasks** — only fetches project list, never calls task endpoints

---

## Strategy: Test-First (Upside-Down)

Write tests first for the **expected behavior**, then fix code or tests as needed.

---

## Step 1: API Layer Tests
**Files**: `src/api/projects.test.ts` (new)
**Parallel**: Yes — independent of all other steps
**Context files agent must read**: `src/api/projects.ts`, `src/api/tasks.test.ts` (pattern reference)

Tests to write:
- `listProjects` — correct endpoint, params forwarding
- `getProject` — correct endpoint with slug
- `createProject` — POST with payload
- `updateProject` — PATCH with slug extracted, payload forwarded
- `deleteProject` — DELETE with slug
- `getProjectDashboard` — correct endpoint + params
- `getProjectFull` — correct endpoint with slug
- `getProjectTasks` — correct endpoint with slug + params
- `getProjectIdeas` — correct endpoint with slug + params
- `getProjectWorklogs` — correct endpoint with slug + params
- `getProjectMemory` — correct endpoint with slug + params
- `getProjectActivity` — correct endpoint with slug + params
- `patchProjectContext` — PATCH with slug, verify payload shape
- `projectQueries` — each factory returns correct queryKey and invokes correct fn

---

## Step 2: Hook Tests
**Files**: Verify/extend `src/hooks/useProjects.test.tsx`, add `src/hooks/useProjectNotes.test.tsx` extension
**Parallel**: Yes — independent of Step 1
**Context files**: `src/hooks/useProjects.ts`, `src/hooks/useProjectNotes.ts`, `src/hooks/useProjects.test.tsx`

Existing hook tests cover: `useCreateProject`, `useUpdateProject`, `useDeleteProject`, `usePatchProjectContext`
Extend with:
- `usePatchProjectContext` — verify payload shape matches what backend expects
- `useCreateProjectNote` — create + invalidation
- `useUpdateProjectNote` — update + invalidation
- `useDeleteProjectNote` — delete + invalidation

---

## Step 3: Component Unit Tests — Sections
**Files**: New test files colocated in `src/features/projects/sections/`
**Parallel**: Yes — all section tests are independent

### 3a: `ProjectGoals.test.tsx`
- Renders goal list with completed/uncompleted state
- Toggle goal calls `patchProjectContext` with correct payload
- "Add Goal" button opens input
- Submit adds goal
- Escape/cancel closes input
- **NEW: hover edit button appears only on hover**
- **NEW: edit mode allows inline title editing**

### 3b: `ProjectTasks.test.tsx`
- Renders task list
- Filter buttons work (filter by status)
- Status change mutation fires
- "Add Task" opens dialog
- Empty state when no tasks

### 3c: `ProjectIdeas.test.tsx`
- Renders idea grid
- Shows priority badge, status badge, tags
- "Add Idea" opens dialog
- Empty state

### 3d: `ProjectNotes.test.tsx`
- Renders note cards
- Add note inline flow
- Edit note flow
- Delete with confirmation

### 3e: `ProjectWorklogs.test.tsx`
- Renders worklog entries
- Duration summaries (week/month/total)
- "Log Work" opens dialog
- Empty state

### 3f: `ProjectHeader.test.tsx`
- Renders project name, status, tags, progress
- Edit button opens dialog
- Delete flow with confirmation
- **Verify "Edit Project" button style** (zinc-800 pill)

### 3g: `ProjectStats.test.tsx`
- Renders stats cards correctly
- Handles zero/null values

### 3h: `ProjectDescription.test.tsx`
- Renders description text
- Handles empty/null

---

## Step 4: Component Unit Tests — Dialogs
**Files**: New test files in `src/features/projects/components/`
**Parallel**: Yes — all dialog tests are independent

### 4a: `EditProjectDialog.test.tsx`
- Opens with pre-filled values
- Submits with correct payload
- **Verify field name: should send `project_status`, not `status`**
- Validates required fields
- Cancel closes
- **Dialog scrollable on small viewports**

### 4b: `TaskCreateDialog.test.tsx`
- AI mode toggle
- Manual mode: all fields
- Submit payload shape
- Validation
- **Dialog scrollable**

### 4c: `IdeaCreateDialog.test.tsx`
- All fields render
- Submit payload shape
- Validation
- **Dialog scrollable**

### 4d: `WorklogCreateDialog.test.tsx`
- Duration calculation (hours + minutes)
- Task linking dropdown
- Submit payload shape
- Validation (>0 minutes)
- **Dialog scrollable**

### 4e: `ProjectCreateDialog.test.tsx`
- Auto-slugify
- All fields
- Submit payload

---

## Step 5: Page-Level Tests
**Files**: New test files in `src/features/projects/pages/`
**Parallel**: Yes

### 5a: `ProjectDetailPage.test.tsx`
- Renders all sections
- **Layout: no maxWidth constraint (full width)**
- Loads full data, ideas, worklogs

### 5b: `ProjectsPage.test.tsx`
- Dashboard stats render
- Project grid renders
- Filters work (status, company, type, priority)
- Search works
- Pagination

### 5c: `ProjectsTasksPage.test.tsx`
- **Renders actual open tasks across projects** (not just project links)
- Fetches tasks data
- Groups by project or shows flat list

### 5d: `ProjectsLayout.test.tsx`
- Renders nav + outlet
- Full height layout

---

## Step 6: Fix — Dialog Scrollability
**File**: `src/components/ui/dialog.tsx`
**Change**: Add `max-h-[85vh] overflow-y-auto` to `DialogContentImpl` inner div (line 97)

```
Before: <div className="relative box-border px-10 py-7">
After:  <div className="relative box-border px-10 py-7 max-h-[85vh] overflow-y-auto">
```

---

## Step 7: Fix — Project Detail Full Width
**File**: `src/features/projects/pages/ProjectDetailPage.tsx`
**Change**: Remove `maxWidth: '960px'` from line 26

```
Before: <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem', maxWidth: '960px' }}>
After:  <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
```

---

## Step 8: Fix — Goal "Add" Button Style + Hover Edit
**File**: `src/features/projects/sections/ProjectGoals.tsx`

Changes:
1. Replace the plain text "+" Add Goal" button (line 131-137) with emerald pill matching other sections → then change **all add buttons** to match "Edit Project" zinc-800 style (see Step 10)
2. Add a small edit (pencil) icon to each goal row, visible only on hover via `group/goal` + `opacity-0 group-hover/goal:opacity-100` Tailwind classes
3. Add inline edit state: clicking edit replaces goal text with input + save/cancel

---

## Step 9: Fix — Tasks Page Shows Actual Tasks
**File**: `src/features/projects/pages/ProjectsTasksPage.tsx`

**Change**: Rewrite to fetch open tasks across all projects and display them with `TaskRow` components, grouped by project.

- Use `listTasks({ status: 'TODO' })` + `listTasks({ status: 'IN_PROGRESS' })` or a combined endpoint
- Or iterate active projects and fetch their tasks
- Show tasks using `TaskRow` component with status change support
- Keep project grouping for context

---

## Step 10: Fix — Unified Button Styles
**Files**: All section files that have "add" buttons

The "Edit Project" button style is the reference:
```
className="font-mono text-[11px] text-zinc-400 hover:text-zinc-200 bg-zinc-800 hover:bg-zinc-700 transition-colors cursor-pointer border-none"
style={{ padding: '0.375rem 0.75rem', borderRadius: 6 }}
```

Apply this style to:
- `ProjectTasks.tsx` — "+ Add Task" button (currently emerald)
- `ProjectIdeas.tsx` — "+ Add Idea" button (currently emerald)
- `ProjectNotes.tsx` — "+ Add Note" button (currently emerald)
- `ProjectWorklogs.tsx` — "+ Log Work" button (currently emerald)
- `ProjectGoals.tsx` — "+ Add Goal" button (currently plain text)

---

## Step 11: Fix — EditProjectDialog Field Name Bug
**File**: `src/features/projects/components/EditProjectDialog.tsx`

**Verify**: Line 94 sends `status` in the mutation payload. The API type `ProjectUpdate` and the backend may expect `project_status`. Check `src/types/api/projects.ts` for the `ProjectUpdateSchema` to confirm the correct field name, then fix if needed.

---

## Step 12: Fix — API Payload Verification
**File**: `src/api/projects.ts`

**Verify**: `patchProjectContext` (line 95) sends `{ updates }` wrapper — confirm backend expects this shape. If backend expects flat `{ goals: [...] }`, remove the wrapper.

Run tests from Steps 1-2 against live API (or check backend route handler) to confirm.

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Step 1: API layer tests (projects.test.ts)
  - Project: HomeUI
  - Directory: /Users/gregor/dev/922/HomeUI
  - Parallel: with Steps 2, 3, 4, 5
  - Context files: src/api/projects.ts, src/api/tasks.test.ts

Step 2: Hook tests extension
  - Project: HomeUI
  - Parallel: with Steps 1, 3, 4, 5
  - Context files: src/hooks/useProjects.ts, src/hooks/useProjectNotes.ts

Step 3a-3h: Section component tests (8 files)
  - Project: HomeUI
  - Parallel: all 8 sub-steps parallel with each other and Steps 1-2
  - Context files: respective section file + shared components

Step 4a-4e: Dialog component tests (5 files)
  - Project: HomeUI
  - Parallel: all 5 sub-steps parallel
  - Context files: respective dialog file

Step 5a-5d: Page tests (4 files)
  - Project: HomeUI
  - Parallel: all 4 parallel
  - Context files: respective page file

Step 6: Dialog scrollability fix
  - Project: HomeUI
  - Parallel: No — after Step 4 tests written (they assert scrollability)
  - Context files: src/components/ui/dialog.tsx

Step 7: Full width layout fix
  - Project: HomeUI
  - Parallel: with Step 6
  - Context files: src/features/projects/pages/ProjectDetailPage.tsx

Step 8: Goal button + hover edit
  - Project: HomeUI
  - Parallel: with Steps 6-7
  - Context files: src/features/projects/sections/ProjectGoals.tsx

Step 9: Tasks page rewrite
  - Project: HomeUI
  - Parallel: with Steps 6-8
  - Context files: src/features/projects/pages/ProjectsTasksPage.tsx, src/api/tasks.ts

Step 10: Unified button styles
  - Project: HomeUI
  - Parallel: with Steps 6-9
  - Context files: All section files listed

Step 11: EditProjectDialog field name fix
  - Project: HomeUI
  - Parallel: with Steps 6-10
  - Context files: src/features/projects/components/EditProjectDialog.tsx, src/types/api/projects.ts

Step 12: API payload verification
  - Project: HomeUI
  - Parallel: No — needs running tests or backend check
  - Context files: src/api/projects.ts, backend route handler
```

### Execution Waves

| Wave | Steps | Description |
|------|-------|-------------|
| **Wave 1** | 1, 2, 3a-h, 4a-e, 5a-d | All tests (test-first) — ~20 files, fully parallel |
| **Wave 2** | 6, 7, 8, 9, 10, 11 | All code fixes — fully parallel |
| **Wave 3** | 12 | API verification — requires test results from Wave 1 |
| **Wave 4** | — | Run full test suite, fix any remaining red tests |

### Quality Gates
- [ ] All new tests pass
- [ ] Existing tests still pass
- [ ] No lint errors
- [ ] Dialogs scroll on small screens
- [ ] Project detail fills full width
- [ ] Goals have hover edit
- [ ] Tasks page shows actual tasks
- [ ] All "add" buttons match "Edit Project" style
- [ ] API payloads match backend expectations
