# Wave 1D — Dialog Component Tests

## Role
You are an Executor Agent. Follow `/Users/gregor/dev/922/Planner/prompts/executor.md`.

## Task
Write unit tests for all 5 dialog components in the projects feature.

## Context Files — Read These First
1. `/Users/gregor/dev/922/HomeUI/CLAUDE.md` — project conventions
2. `/Users/gregor/dev/922/HomeUI/.claude/HOW-TO-UNIT-TEST.md` — testing guide
3. `/Users/gregor/dev/922/HomeUI/src/test/test-utils.tsx` — `renderWithProviders()`
4. `/Users/gregor/dev/922/HomeUI/src/components/ui/dialog.tsx` — Dialog primitive (understand open/close, scroll behavior)
5. Each dialog file listed below

## Output Files (5 test files)

### 1. `src/features/projects/components/EditProjectDialog.test.tsx`
Source: `src/features/projects/components/EditProjectDialog.tsx`
Mock: `vi.mock('@/hooks/useProjects')` for `useUpdateProject`

Tests:
- When open, renders all form fields pre-filled from project data
- Name field is required — empty submission shows error
- Submit calls `updateProject.mutate` with correct payload shape
- **CRITICAL TEST**: Verify the payload sends `project_status` (not `status`) for the status field — OR document what field name is actually sent. Currently line 94 sends `status` as the key. Write a test asserting the correct key name.
- Cancel button closes dialog
- Loading state shows spinner
- Error display on mutation failure
- All select fields render correct options (TYPE_OPTIONS, STATUS_OPTIONS, PRIORITY_OPTIONS)
- Tags field splits on comma
- **TEST FOR FUTURE FIX**: Test that dialog content is scrollable when content overflows viewport (check for `overflow-y-auto` or `max-h-*` class on the content wrapper)

### 2. `src/features/projects/components/TaskCreateDialog.test.tsx`
Source: `src/features/projects/components/TaskCreateDialog.tsx`
Mock: `vi.mock('@/api/tasks')` for `createTask`

Tests:
- AI mode toggle switches between textarea and manual fields
- Manual mode: all fields render (title, description, status, priority, due date, tags)
- Title is required in manual mode
- Raw content is required in AI mode
- Submit in manual mode: correct payload shape with `project_id`
- Submit in AI mode: sends `{ raw_content, project_id }` + `llm_parse: true` query param
- Cancel closes
- Form resets when dialog reopens
- Tags split on comma
- **Scrollability test** (same as EditProjectDialog)

### 3. `src/features/projects/components/IdeaCreateDialog.test.tsx`
Source: `src/features/projects/components/IdeaCreateDialog.tsx`
Mock: `vi.mock('@/api/ideas')` for `createIdea`

Tests:
- All fields render (title, description, priority, tags)
- Title is required
- Submit payload includes `project_id`
- Priority select has all IDEA_PRIORITIES options
- Cancel closes
- Form resets on reopen
- Error display
- **Scrollability test**

### 4. `src/features/projects/components/WorklogCreateDialog.test.tsx`
Source: `src/features/projects/components/WorklogCreateDialog.tsx`
Mock: `vi.mock('@/api/worklogs')` for `createWorklog`

Tests:
- All fields render (description, hours, minutes, category, date, linked task)
- Linked task dropdown only shows when tasks array is non-empty
- Duration validation: must be > 0 minutes
- Duration calculation: 2h + 30m = 150 minutes in payload
- `worked_at` defaults to today
- Submit payload includes `project_id`
- Task linking: `task_id` in payload when selected
- Cancel closes
- **Scrollability test**

### 5. `src/features/projects/components/ProjectCreateDialog.test.tsx`
Source: `src/features/projects/components/ProjectCreateDialog.tsx`
Mock: `vi.mock('@/hooks/useProjects')` for `useCreateProject`

Tests:
- Read the source file first to understand the form fields
- All fields render
- Name is required
- Auto-slugify from name
- Submit payload shape
- Cancel closes
- Form resets on reopen

## Mock Pattern
```ts
const mockMutate = vi.fn()
vi.mocked(useUpdateProject).mockReturnValue({
  mutate: mockMutate,
  isPending: false,
  error: null,
  reset: vi.fn(),
} as never)
```

## Working Directory
All commands must run from `/Users/gregor/dev/922/HomeUI`. Run `cd /Users/gregor/dev/922/HomeUI` before any bash command.

## Validation
Run `cd /Users/gregor/dev/922/HomeUI && npm run test -- src/features/projects/components/` and report results.

## Rules
- Do NOT add `Co-Authored-By` trailers
- Use `renderWithProviders` for all renders
- Use `userEvent.setup()` for interactions
- Follow RTL query priority
- Test what users see, not implementation
