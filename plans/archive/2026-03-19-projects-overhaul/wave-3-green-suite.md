# Wave 3 — Green Suite Pass

## Role
You are an Executor Agent. Follow `/Users/gregor/dev/922/Planner/prompts/executor.md`.

## Task
Run the full test suite for the projects module and fix any remaining failures. All tests from Wave 1 should now pass after Wave 2 code fixes.

## Context Files — Read These First
1. `/Users/gregor/dev/922/HomeUI/CLAUDE.md`
2. The plan: `/Users/gregor/dev/922/Planner/plans/2026-03-19-projects-module-overhaul.md`

## Steps

## Working Directory
All commands must run from `/Users/gregor/dev/922/HomeUI`. Run `cd /Users/gregor/dev/922/HomeUI` before any bash command.

### 1. Run Full Project Test Suite
```bash
cd /Users/gregor/dev/922/HomeUI && npm run test:ci -- --reporter=verbose 2>&1 | head -200
```

### 2. If Any Tests Fail
For each failure:
1. Read the failing test file
2. Read the corresponding source file
3. Determine: is the **test** wrong or is the **code** wrong?
   - Test-first tests that assert future behavior (hover edit, scrollability, full width, tasks page) → code should have been fixed in Wave 2. If still failing, the Wave 2 fix was incomplete — fix the code.
   - Tests that assert existing behavior → if they broke due to Wave 2 changes, update the test.
4. Fix and re-run

### 3. Run Lint
```bash
cd /Users/gregor/dev/922/HomeUI && npm run lint
```
Fix any lint errors introduced by new code.

### 4. Run Build
```bash
cd /Users/gregor/dev/922/HomeUI && npm run build
```
Fix any type errors.

### 5. Final Report
List:
- Total tests: X passed, Y failed
- Any remaining issues
- Files modified in this wave

## E2E Scaffold (if time permits)
After unit tests are green, scaffold E2E tests for the projects feature:
```bash
npx tsx scripts/new-e2e.ts projects
```
Then write basic E2E scenarios:
- Navigate to projects page
- Open a project detail
- Create a task
- Create an idea
- Add a goal

Follow: `/Users/gregor/dev/922/HomeUI/.claude/skills/e2e.md`
