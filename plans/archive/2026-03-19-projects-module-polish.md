# Plan: Projects Module Polish & Feature Additions

**Date**: 2026-03-19
**Project**: HomeUI — `src/features/projects/`
**Status**: IN PROGRESS

## Goal

Comprehensive UX/feature improvements to the projects module across 5 waves. All waves include test-first implementation.

## Requirements

| # | Requirement | Wave |
|---|-------------|------|
| 1 | Edit/New dialog 20% wider | 2 |
| 2 | Backdrop 40% darker when dialog open | 2 |
| 3 | Unsaved-changes confirmation popup | 2 |
| 4 | Project URL button in detail view | 3 |
| 5 | Fix tasks page (Zod errors) | 1 |
| 6 | Completed Projects box on overview | 4 |
| 7 | Completed Tasks box on project detail | 4 |
| 8 | Time Estimate box on project detail | 4 |
| 9 | Goal add input dark background | 5 |
| 10 | Goal editable inline | 5 |
| 11 | Goal appears immediately after add | 5 |
| 12 | Tasks/ideas appear immediately after add | 5 |
| 13 | Task status: BACKLOG | 1 |
| 14 | Fix task Zod error after add (nullable fields) | 1 |
| 15 | Activity add button matches other buttons (shared AddButton) | 2 |
| 16 | Project header: prominent status + company | 3 |
| 17 | Hosting tag first in tag list | 3 |

---

## Wave 1 — Schema & API Fixes

**Files**: `src/types/api/tasks.ts`

### Tasks
- [x] Add `'BACKLOG'` to `TASK_STATUSES`
- [x] Make `raw_content`, `description`, `completed_at`, `idea_id`, `updated_at` accept `undefined` via `.optional()`
- [x] Run and update tests

---

## Wave 2 — Shared Components & Dialog Improvements

**Files**:
- `src/components/AddButton.tsx` (new)
- `src/components/ui/dialog.tsx`
- `src/components/UnsavedChangesDialog.tsx` (new)
- `src/features/projects/sections/ProjectActivity.tsx`
- All section files using "+ Add X" buttons
- `src/features/projects/components/EditProjectDialog.tsx`
- `src/features/projects/components/ProjectCreateDialog.tsx`

### Tasks
- [ ] Create `AddButton` shared component (zinc-800 style)
- [ ] Dialog: `max-w-[504px]` (420 × 1.2)
- [ ] Dialog backdrop: `bg-black/80`
- [ ] Create `UnsavedChangesDialog` component
- [ ] Add `useUnsavedChanges` hook
- [ ] Integrate dirty-state + confirmation into `EditProjectDialog` and `ProjectCreateDialog`
- [ ] Replace all emerald "Add" buttons in sections with `AddButton`

---

## Wave 3 — Project Header Improvements

**Files**:
- `src/features/projects/sections/ProjectHeader.tsx`
- `src/features/projects/components/EditProjectDialog.tsx`

### Tasks
- [ ] URL button in ProjectHeader (only visible in detail view — already is)
- [ ] Prominent status badge + company label above title
- [ ] Add `hosting` input field to EditProjectDialog (stored in context)
- [ ] Show `hosting` as first tag in header tags row

---

## Wave 4 — New Sections

**Files**:
- `src/features/projects/sections/ProjectCompletedTasks.tsx` (new)
- `src/features/projects/sections/ProjectTimeEstimate.tsx` (new)
- `src/features/projects/pages/ProjectDetailPage.tsx`
- `src/features/projects/pages/ProjectsPage.tsx`
- `src/api/projects.ts`

### Tasks
- [ ] `ProjectCompletedTasks`: panel showing DONE/CANCELLED tasks
- [ ] `ProjectTimeEstimate`: panel showing time estimate (from context) + logged time from worklogs
- [ ] `CompletedProjectsSection` on ProjectsPage (query with `status: 'completed'`)
- [ ] Add sections to ProjectDetailPage layout
- [ ] Add completed section to ProjectsPage

---

## Wave 5 — UX & Optimistic Updates

**Files**:
- `src/features/projects/sections/ProjectGoals.tsx`
- `src/features/projects/sections/ProjectTasks.tsx`
- `src/features/projects/sections/ProjectIdeas.tsx`
- `src/features/projects/components/TaskCreateDialog.tsx`

### Tasks
- [ ] Goal input: dark background, proper styling
- [ ] Goals: local state for immediate render on add/toggle/edit
- [ ] Tasks: optimistic cache update on create
- [ ] Ideas: optimistic cache update on create
- [ ] BACKLOG in task filter UI + TaskCreateDialog status options
