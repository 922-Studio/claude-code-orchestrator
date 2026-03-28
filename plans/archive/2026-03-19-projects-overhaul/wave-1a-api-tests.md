# Wave 1A — Projects API Layer Tests

## Role
You are an Executor Agent. Follow `/Users/gregor/dev/922/Planner/prompts/executor.md`.

## Task
Write comprehensive unit tests for `src/api/projects.ts` — the projects API module.

## Context Files — Read These First
1. `/Users/gregor/dev/922/HomeUI/CLAUDE.md` — project conventions
2. `/Users/gregor/dev/922/HomeUI/.claude/HOW-TO-UNIT-TEST.md` — testing guide
3. `/Users/gregor/dev/922/HomeUI/src/api/projects.ts` — the module under test
4. `/Users/gregor/dev/922/HomeUI/src/api/tasks.test.ts` — reference pattern (mock `http`, test each fn)
5. `/Users/gregor/dev/922/HomeUI/src/types/api/projects.ts` — Zod schemas and types
6. `/Users/gregor/dev/922/HomeUI/src/lib/http.ts` — shared Axios instance

## Output File
`/Users/gregor/dev/922/HomeUI/src/api/projects.test.ts`

## Test Pattern
Follow the exact pattern from `tasks.test.ts`:
```ts
vi.mock('@/lib/http', () => ({
  http: { get: vi.fn(), post: vi.fn(), patch: vi.fn(), delete: vi.fn() },
}))
```

Create a `mockProject` object that satisfies the `ProjectSchema`, then test:

### Required Tests
1. `listProjects` — calls `GET /api/projects/` with params
2. `listProjects` with filter params — status, company, type, priority, etc.
3. `getProject` — calls `GET /api/projects/{slug}`
4. `createProject` — calls `POST /api/projects/` with payload
5. `updateProject` — calls `PATCH /api/projects/{slug}`, extracts slug from payload
6. `deleteProject` — calls `DELETE /api/projects/{slug}`
7. `getProjectDashboard` — calls `GET /api/projects/dashboard` with params
8. `getProjectFull` — calls `GET /api/projects/{slug}/full`
9. `getProjectTasks` — calls `GET /api/projects/{slug}/tasks` with params
10. `getProjectIdeas` — calls `GET /api/projects/{slug}/ideas` with params
11. `getProjectWorklogs` — calls `GET /api/projects/{slug}/worklogs` with params
12. `getProjectMemory` — calls `GET /api/projects/{slug}/memory` with params
13. `getProjectActivity` — calls `GET /api/projects/{slug}/activity` with params
14. `createProjectActivity` — calls `POST /api/projects/{slug}/activity`
15. `patchProjectContext` — calls `PATCH /api/projects/{slug}/context`, **verify payload shape** (does it send `{ updates: {...} }` or flat?)
16. `projectQueries.all()` — returns correct queryKey `['projects']`
17. `projectQueries.list(params)` — returns correct queryKey with params
18. `projectQueries.detail(slug)` — correct queryKey
19. `projectQueries.full(slug)` — correct queryKey
20. `projectQueries.dashboard(params)` — correct queryKey
21. `projectQueries.tasks(slug, params)` — correct queryKey
22. `projectQueries.ideas(slug, params)` — correct queryKey
23. `projectQueries.worklogs(slug, params)` — correct queryKey

Each test: verify the correct HTTP method, URL, payload, and that Zod parsing runs on the response.

## Working Directory
All commands must run from `/Users/gregor/dev/922/HomeUI`. Run `cd /Users/gregor/dev/922/HomeUI` before any bash command.

## Validation
Run `cd /Users/gregor/dev/922/HomeUI && npm run test -- src/api/projects.test.ts` and report results.

## Rules
- Do NOT add `Co-Authored-By` trailers to commits
- Mock `@/lib/http`, not the API module itself
- Use `vi.mocked()` for type-safe mock assertions
