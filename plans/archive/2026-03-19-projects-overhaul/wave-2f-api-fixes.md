# Wave 2F — API & Payload Fixes

## Role
You are an Executor Agent. Follow `/Users/gregor/dev/922/Planner/prompts/executor.md`.

## Task
Fix API payload issues discovered during test-first analysis. Two potential bugs need investigation and fixing.

## Context Files — Read These First
1. `/Users/gregor/dev/922/HomeUI/CLAUDE.md`
2. `/Users/gregor/dev/922/HomeUI/src/features/projects/components/EditProjectDialog.tsx` — sends `status` on line 94
3. `/Users/gregor/dev/922/HomeUI/src/types/api/projects.ts` — `ProjectUpdateSchema` definition
4. `/Users/gregor/dev/922/HomeUI/src/api/projects.ts` — `updateProject` and `patchProjectContext` functions
5. `/Users/gregor/dev/922/HomeUI/src/hooks/useProjects.ts` — mutation hooks

## Issue 1: `status` vs `project_status` in EditProjectDialog

### Investigation
Read `src/types/api/projects.ts` and look at `ProjectUpdateSchema`. Check what field name the backend expects for the project status:
- If the schema has `project_status` → the dialog sending `status` is a bug
- If the schema has `status` → it's correct, but the `Project` type uses `project_status` for the GET response, which would be unusual

### Fix (if needed)
In `EditProjectDialog.tsx`, line 88-109, the mutation payload includes:
```ts
{ slug, name, company, type, status, priority, ... }
```
If the backend expects `project_status`, change to:
```ts
{ slug, name, company, type, project_status: status, priority, ... }
```

## Issue 2: `patchProjectContext` Payload Shape

### Investigation
In `src/api/projects.ts` line 94-96:
```ts
export async function patchProjectContext(slug: string, updates: Record<string, unknown>) {
  const { data } = await http.patch<unknown>(`/api/projects/${slug}/context`, { updates })
  return ProjectSchema.parse(data)
}
```

The function wraps `updates` in `{ updates }`. So the actual HTTP body is:
```json
{ "updates": { "goals": [...] } }
```

Check the backend (HomeAPI) to confirm if this is the expected shape. Two ways:
1. Check if there's a backend schema/route definition referenced anywhere
2. Look at the API tests from Wave 1A — if they pass with this shape, it's correct
3. Check the test file `src/api/projects.test.ts` for assertions on the payload

If the backend expects flat `{ "goals": [...] }` instead of wrapped, fix the function.

## Issue 3: updateProject `status` field naming

### Investigation
In `src/api/projects.ts` line 45:
```ts
export async function updateProject({ slug, ...payload }: ProjectUpdate & { slug: string }) {
```
The `...payload` spread passes whatever the caller sends. If the caller sends `status`, that's what goes to the API. If the backend expects `project_status`, we need to transform.

Check `ProjectUpdateSchema` in `src/types/api/projects.ts` for the correct field names.

## Working Directory
All commands must run from `/Users/gregor/dev/922/HomeUI`. Run `cd /Users/gregor/dev/922/HomeUI` before any bash command.

## Verification
1. Run `cd /Users/gregor/dev/922/HomeUI && npm run test -- src/api/projects.test.ts` — API tests should verify correct payloads
2. Run `cd /Users/gregor/dev/922/HomeUI && npm run test -- src/features/projects/components/EditProjectDialog.test.tsx`
3. Run `cd /Users/gregor/dev/922/HomeUI && npm run build`

## Rules
- If you need to check the backend, SSH to lab and read the relevant API route handler
- Document any findings as code comments if the mapping is non-obvious
- If you cannot confirm the backend expectation, add a TODO comment and report it
