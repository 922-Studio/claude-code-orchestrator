# Wave 1B — Hook Tests Extension

## Role
You are an Executor Agent. Follow `/Users/gregor/dev/922/Planner/prompts/executor.md`.

## Task
Extend hook test coverage for project-related hooks. The existing `useProjects.test.tsx` covers basic CRUD mutations. Add missing tests and create note hook tests.

## Context Files — Read These First
1. `/Users/gregor/dev/922/HomeUI/CLAUDE.md` — project conventions
2. `/Users/gregor/dev/922/HomeUI/.claude/HOW-TO-UNIT-TEST.md` — testing guide
3. `/Users/gregor/dev/922/HomeUI/src/hooks/useProjects.ts` — hooks under test
4. `/Users/gregor/dev/922/HomeUI/src/hooks/useProjects.test.tsx` — existing tests (extend this)
5. `/Users/gregor/dev/922/HomeUI/src/hooks/useProjectNotes.ts` — note hooks under test
6. `/Users/gregor/dev/922/HomeUI/src/hooks/useProjectNotes.test.tsx` — existing note tests (extend if exists, create if not)
7. `/Users/gregor/dev/922/HomeUI/src/api/projects.ts` — API module
8. `/Users/gregor/dev/922/HomeUI/src/api/project-notes.ts` — notes API module

## Output Files
- `/Users/gregor/dev/922/HomeUI/src/hooks/useProjects.test.tsx` (extend)
- `/Users/gregor/dev/922/HomeUI/src/hooks/useProjectNotes.test.tsx` (extend or create)

## Tests to Add/Verify

### useProjects.test.tsx — Add
1. `usePatchProjectContext` — verify it calls `patchProjectContext` with correct slug and updates shape
2. `usePatchProjectContext` — verify it invalidates `['projects']` queries on settled
3. `useUpdateProject` — verify the payload shape (especially check if `status` vs `project_status` matters)

### useProjectNotes.test.tsx
4. `useCreateProjectNote` — calls `createProjectNote`, invalidates `['projects', 'full', slug]`
5. `useUpdateProjectNote` — calls `updateProjectNote`, invalidates correctly
6. `useDeleteProjectNote` — calls `deleteProjectNote`, invalidates correctly
7. Error handling — mutation error state is accessible

### Pattern
Follow the existing pattern in `useProjects.test.tsx`:
```ts
vi.mock('@/api/projects')
// or
vi.mock('@/api/project-notes')

function createWrapper() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return { queryClient, wrapper: ... }
}
```

## Working Directory
All commands must run from `/Users/gregor/dev/922/HomeUI`. Run `cd /Users/gregor/dev/922/HomeUI` before any bash command.

## Validation
Run `cd /Users/gregor/dev/922/HomeUI && npm run test -- src/hooks/useProjects.test.tsx src/hooks/useProjectNotes.test.tsx` and report results.
