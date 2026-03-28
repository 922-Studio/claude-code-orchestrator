# Wave 1C — Section Component Tests

## Role
You are an Executor Agent. Follow `/Users/gregor/dev/922/Planner/prompts/executor.md`.

## Task
Write unit tests for all 8 section components in the projects feature. These are the building blocks of the project detail page.

## Context Files — Read These First
1. `/Users/gregor/dev/922/HomeUI/CLAUDE.md` — project conventions
2. `/Users/gregor/dev/922/HomeUI/.claude/HOW-TO-UNIT-TEST.md` — full testing guide (query priority, patterns, anti-patterns)
3. `/Users/gregor/dev/922/HomeUI/src/test/test-utils.tsx` — `renderWithProviders()` helper
4. Each section file listed below (read before writing its test)
5. `/Users/gregor/dev/922/HomeUI/src/types/api/projects.ts` — Project type definition
6. `/Users/gregor/dev/922/HomeUI/src/types/api/tasks.ts` — Task type definition
7. `/Users/gregor/dev/922/HomeUI/src/types/api/ideas.ts` — Idea type definition

## Output Files (8 test files)

### 1. `src/features/projects/sections/ProjectGoals.test.tsx`
Source: `src/features/projects/sections/ProjectGoals.tsx`
Mock: `vi.mock('@/hooks/useProjects')` for `usePatchProjectContext`

Tests:
- Renders list of goals with correct text
- Completed goals show line-through styling
- Shows completed count (e.g. "2/5")
- Clicking checkbox calls `patchProjectContext.mutate` with toggled goal
- "Add Goal" button click shows input field
- Typing + Enter submits new goal
- Escape cancels adding
- Empty state: "No goals defined."
- **TEST FOR FUTURE FIX**: Write a test that expects a hover-only edit button per goal row (use `group-hover` or similar). This test WILL fail initially — that's intentional (test-first).
- **TEST FOR FUTURE FIX**: Write a test that expects clicking edit enters inline edit mode

### 2. `src/features/projects/sections/ProjectTasks.test.tsx`
Source: `src/features/projects/sections/ProjectTasks.tsx`
Mock: `vi.mock('@/api/tasks')` for `updateTask`

Tests:
- Renders task rows with title, status, priority
- Shows total count in header
- Filter buttons render for each status
- Clicking filter shows only matching tasks
- "All" filter shows everything
- Status change calls `updateTask` mutation
- "+ Add Task" opens TaskCreateDialog
- Empty state for no tasks
- Empty state for filtered-out tasks

### 3. `src/features/projects/sections/ProjectIdeas.test.tsx`
Source: `src/features/projects/sections/ProjectIdeas.tsx`

Tests:
- Renders idea cards in grid
- Shows title, priority badge, status badge
- Description truncated at 100 chars
- Tags render
- "+ Add Idea" opens IdeaCreateDialog
- Empty state

### 4. `src/features/projects/sections/ProjectNotes.test.tsx`
Source: `src/features/projects/sections/ProjectNotes.tsx`
Mock: `vi.mock('@/hooks/useProjectNotes')`

Tests:
- Renders note cards
- "+ Add Note" shows inline textarea
- Typing + Save creates note
- Cancel hides textarea
- Edit button on note card enters edit mode
- Save edit calls update mutation
- Delete shows confirmation
- Confirming delete calls delete mutation
- Canceling delete hides confirmation
- Empty state

### 5. `src/features/projects/sections/ProjectWorklogs.test.tsx`
Source: `src/features/projects/sections/ProjectWorklogs.tsx`

Tests:
- Renders worklog entries (date, duration, description, category)
- Duration summaries: this week, this month, total
- `formatDuration` — "2h 30m", "45m", "1h"
- "+ Log Work" opens WorklogCreateDialog
- Empty state

### 6. `src/features/projects/sections/ProjectHeader.test.tsx`
Source: `src/features/projects/sections/ProjectHeader.tsx`
Mock: `vi.mock('@/hooks/useProjects')` for `useDeleteProject`

Tests:
- Renders project name as h1
- Shows StatusBadge, company MetaPill, type MetaPill
- Shows tags
- ProgressBar renders
- "Edit Project" button opens EditProjectDialog
- **Verify "Edit Project" button styling**: has `bg-zinc-800`, `text-zinc-400` classes
- "Delete" button shows confirmation
- Confirming delete calls mutation
- Cancel hides confirmation
- Summary text renders when present

### 7. `src/features/projects/sections/ProjectStats.test.tsx`
Source: `src/features/projects/sections/ProjectStats.tsx`

Tests:
- Renders progress, task count, idea count, worklog duration
- Handles zero values
- Handles null/undefined gracefully

### 8. `src/features/projects/sections/ProjectDescription.test.tsx`
Source: `src/features/projects/sections/ProjectDescription.tsx`

Tests:
- Renders description text
- Handles empty/null description
- Handles long description

## Mock Data Pattern
Create factory functions for test data:
```ts
function mockProject(overrides?: Partial<Project>): Project {
  return { id: '1', slug: 'test', name: 'Test Project', ... , ...overrides }
}
```

## Working Directory
All commands must run from `/Users/gregor/dev/922/HomeUI`. Run `cd /Users/gregor/dev/922/HomeUI` before any bash command.

## Validation
Run `cd /Users/gregor/dev/922/HomeUI && npm run test -- src/features/projects/sections/` and report results.

## Rules
- Do NOT add `Co-Authored-By` trailers
- Use `renderWithProviders` from `src/test/test-utils.tsx`
- Follow RTL query priority: `getByRole` > `getByLabelText` > `getByText` > `getByTestId`
- Use `userEvent.setup()` for interactions
- Mock API modules, not HTTP client
- Each test file is independent — mock what that component needs
