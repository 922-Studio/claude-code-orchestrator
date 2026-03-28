# Wave 2D — Tasks Page Rewrite

## Role
You are an Executor Agent. Follow `/Users/gregor/dev/922/Planner/prompts/executor.md`.

## Task
Rewrite `ProjectsTasksPage` to actually show open tasks across all active projects instead of just listing project names.

## Context Files — Read These First
1. `/Users/gregor/dev/922/HomeUI/CLAUDE.md`
2. `/Users/gregor/dev/922/HomeUI/src/features/projects/pages/ProjectsTasksPage.tsx` — current (broken) implementation
3. `/Users/gregor/dev/922/HomeUI/src/features/projects/pages/ProjectsTasksPage.test.tsx` — tests to satisfy (from Wave 1E)
4. `/Users/gregor/dev/922/HomeUI/src/api/projects.ts` — `projectQueries.list`, `getProjectTasks`
5. `/Users/gregor/dev/922/HomeUI/src/api/tasks.ts` — `listTasks`, `updateTask`, `taskQueries`
6. `/Users/gregor/dev/922/HomeUI/src/components/TaskRow.tsx` — reusable task row component
7. `/Users/gregor/dev/922/HomeUI/src/components/EmptyState.tsx`
8. `/Users/gregor/dev/922/HomeUI/src/types/api/tasks.ts` — Task type, statuses

## Current Problem
The page fetches the project list but never fetches any tasks. It only renders project names as clickable links.

## New Implementation

### Approach
Fetch open tasks across all projects using the tasks API. Two viable approaches:

**Option A (preferred)**: Use `listTasks` with status filters
```ts
const { data: todoTasks } = useSuspenseQuery(taskQueries.list({ status: 'TODO', limit: 200 }))
const { data: inProgressTasks } = useSuspenseQuery(taskQueries.list({ status: 'IN_PROGRESS', limit: 200 }))
const { data: plannedTasks } = useSuspenseQuery(taskQueries.list({ status: 'PLANNED', limit: 200 }))
```

**Option B**: Fetch per-project tasks for each active project (more API calls, less ideal)

### UI Structure
```
Tasks (page heading)
open tasks across all active projects

[Filter buttons: All | PLANNED | TODO | IN_PROGRESS | IN_REVIEW]

--- Project Name A ---
  TaskRow (title, status, priority, due date)
  TaskRow
--- Project Name B ---
  TaskRow
  TaskRow

Empty state: "No open tasks across any project"
```

### Requirements
1. Group tasks by `project_id` — show project name as group header
2. Use `TaskRow` component for each task
3. Status change per task (same mutation pattern as `ProjectTasks.tsx`)
4. Filter by status (PLANNED, TODO, IN_PROGRESS, IN_REVIEW, All)
5. Keep the project list query for mapping `project_id` → `project.name`
6. Match existing page styling (dark theme, font-mono)

### Status change mutation
```ts
const statusChange = useMutation({
  mutationFn: ({ id, status }: { id: string; status: TaskStatus }) => updateTask({ id, status }),
  onSettled: () => {
    void queryClient.invalidateQueries({ queryKey: ['tasks'] })
    void queryClient.invalidateQueries({ queryKey: ['projects'] })
  },
})
```

## Working Directory
All commands must run from `/Users/gregor/dev/922/HomeUI`. Run `cd /Users/gregor/dev/922/HomeUI` before any bash command.

## Verification
1. Run `cd /Users/gregor/dev/922/HomeUI && npm run test -- src/features/projects/pages/ProjectsTasksPage` — all tests should pass
2. Run `cd /Users/gregor/dev/922/HomeUI && npm run build`
