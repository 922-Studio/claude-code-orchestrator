# Wave 1E — Page-Level Tests

## Role
You are an Executor Agent. Follow `/Users/gregor/dev/922/Planner/prompts/executor.md`.

## Task
Write unit tests for all 4 page-level components and the layout in the projects feature.

## Context Files — Read These First
1. `/Users/gregor/dev/922/HomeUI/CLAUDE.md` — project conventions
2. `/Users/gregor/dev/922/HomeUI/.claude/HOW-TO-UNIT-TEST.md` — testing guide
3. `/Users/gregor/dev/922/HomeUI/src/test/test-utils.tsx` — `renderWithProviders()`
4. Each page file listed below
5. `/Users/gregor/dev/922/HomeUI/src/api/projects.ts` — query factories
6. `/Users/gregor/dev/922/HomeUI/src/api/tasks.ts` — task query factories

## Output Files (4 test files)

### 1. `src/features/projects/pages/ProjectDetailPage.test.tsx`
Source: `src/features/projects/pages/ProjectDetailPage.tsx`
Mock: `vi.mock('@/api/projects')` — mock the query functions that `useSuspenseQuery` calls

Tests:
- Renders all section components (Header, Stats, Description, Goals, Tasks, Ideas, Notes, Worklogs, Activity)
- **TEST FOR FUTURE FIX**: Verify the outer container does NOT have `maxWidth: 960px` — test that it fills available width. Currently it has `maxWidth: '960px'` which is the bug. Write the test expecting NO maxWidth.
- Loads full data, ideas data, worklogs data via suspense queries
- Handles missing activity gracefully (falls back to `{ items: [], total: 0 }`)
- Route param `slug` is extracted correctly

### 2. `src/features/projects/pages/ProjectsPage.test.tsx`
Source: `src/features/projects/pages/ProjectsPage.tsx`
Read the source file first to understand its structure.

Tests:
- Dashboard stats render (active projects, total tasks, etc.)
- Project list/grid renders
- Filter controls render and work
- Search input filters projects
- Pagination works
- Empty state when no projects
- "New Project" action

### 3. `src/features/projects/pages/ProjectsTasksPage.test.tsx`
Source: `src/features/projects/pages/ProjectsTasksPage.tsx`

Tests:
- **TEST FOR FUTURE FIX**: Currently this page only shows project names with task counts. Write tests for what it SHOULD do:
  - Renders actual task rows (not just project links)
  - Shows open tasks across all active projects
  - Tasks are grouped by project name
  - Each task shows title, status, priority
  - Status change works per task
  - Empty state when no open tasks
- Also write a test documenting the CURRENT broken behavior (shows project names only, no tasks)

### 4. `src/features/projects/components/ProjectsLayout.test.tsx`
Source: `src/features/projects/components/ProjectsLayout.tsx`

Tests:
- Renders ProjectsNav
- Renders Outlet
- Layout is flex with full height
- Content area has overflow-y-auto

## Mocking Suspense Queries
Since pages use `useSuspenseQuery`, you need to mock at the API level and let React Query resolve:
```ts
vi.mock('@/api/projects')
vi.mocked(getProjectFull).mockResolvedValue({ project: mockProject, tasks: { items: [], total: 0 }, ... })
```
Or mock the query factories:
```ts
vi.mock('@/api/projects', () => ({
  projectQueries: {
    full: () => ({ queryKey: ['projects', 'full', 'test'], queryFn: () => Promise.resolve(mockFullData) }),
    ideas: () => ({ queryKey: [...], queryFn: () => Promise.resolve(mockIdeas) }),
    ...
  }
}))
```

Use `findBy*` queries to wait for async rendering.

## Working Directory
All commands must run from `/Users/gregor/dev/922/HomeUI`. Run `cd /Users/gregor/dev/922/HomeUI` before any bash command.

## Validation
Run `cd /Users/gregor/dev/922/HomeUI && npm run test -- src/features/projects/pages/ src/features/projects/components/ProjectsLayout.test.tsx` and report results.

## Rules
- Do NOT add `Co-Authored-By` trailers
- Use `renderWithProviders` with `route` param matching expected URL
- Mock API modules, not HTTP client
- Tests that assert future behavior (marked "TEST FOR FUTURE FIX") are expected to fail — that's correct
