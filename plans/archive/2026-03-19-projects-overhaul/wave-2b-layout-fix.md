# Wave 2B — Project Detail Full Width Fix

## Role
You are an Executor Agent. Follow `/Users/gregor/dev/922/Planner/prompts/executor.md`.

## Task
Remove the `maxWidth: 960px` constraint from the project detail page so it fills the available width.

## Context Files — Read These First
1. `/Users/gregor/dev/922/HomeUI/CLAUDE.md`
2. `/Users/gregor/dev/922/HomeUI/src/features/projects/pages/ProjectDetailPage.tsx`

## The Fix
In `ProjectDetailPage.tsx` line 26, remove `maxWidth: '960px'`:

```
Before: <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem', maxWidth: '960px' }}>
After:  <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
```

The parent layout (`ProjectsLayout.tsx`) already has `flex-1` with padding — the content should fill the available space naturally.

## Working Directory
All commands must run from `/Users/gregor/dev/922/HomeUI`. Run `cd /Users/gregor/dev/922/HomeUI` before any bash command.

## Verification
1. Run `cd /Users/gregor/dev/922/HomeUI && npm run test -- src/features/projects/pages/ProjectDetailPage` — the "no maxWidth" test from Wave 1E should now pass
2. Run `cd /Users/gregor/dev/922/HomeUI && npm run build`
