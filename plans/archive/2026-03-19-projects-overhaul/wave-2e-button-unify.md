# Wave 2E — Unify All Add Button Styles

## Role
You are an Executor Agent. Follow `/Users/gregor/dev/922/Planner/prompts/executor.md`.

## Task
Make all "add" action buttons in the project sections consistent. The reference style is the "Edit Project" button from `ProjectHeader.tsx`.

## Context Files — Read These First
1. `/Users/gregor/dev/922/HomeUI/CLAUDE.md`
2. `/Users/gregor/dev/922/HomeUI/src/features/projects/sections/ProjectHeader.tsx` — reference style (lines 112-118)
3. `/Users/gregor/dev/922/HomeUI/src/features/projects/sections/ProjectTasks.tsx` — "+ Add Task" button
4. `/Users/gregor/dev/922/HomeUI/src/features/projects/sections/ProjectIdeas.tsx` — "+ Add Idea" button
5. `/Users/gregor/dev/922/HomeUI/src/features/projects/sections/ProjectNotes.tsx` — "+ Add Note" button
6. `/Users/gregor/dev/922/HomeUI/src/features/projects/sections/ProjectWorklogs.tsx` — "+ Log Work" button

## Reference Style (from "Edit Project" button)
```tsx
className="font-mono text-[11px] text-zinc-400 hover:text-zinc-200 bg-zinc-800 hover:bg-zinc-700 transition-colors cursor-pointer border-none"
style={{ padding: '0.375rem 0.75rem', borderRadius: 6 }}
```

## Current Style (emerald pill — all 4 section buttons)
```tsx
className="font-mono text-[10px] text-emerald-400 hover:text-emerald-300 bg-emerald-950/50 hover:bg-emerald-950 transition-colors cursor-pointer border-none"
style={{ padding: '0.25rem 0.625rem', borderRadius: 6 }}
```

## Changes (4 files, same change in each)

### 1. `ProjectTasks.tsx` — lines 43-50
Replace the `+ Add Task` button className and style with the reference style.

### 2. `ProjectIdeas.tsx` — lines 25-32
Replace the `+ Add Idea` button className and style.

### 3. `ProjectNotes.tsx` — lines 69-76
Replace the `+ Add Note` button className and style.

### 4. `ProjectWorklogs.tsx` — lines 57-64
Replace the `+ Log Work` button className and style.

**Note:** The `ProjectGoals.tsx` button is handled separately in Wave 2C.

## Working Directory
All commands must run from `/Users/gregor/dev/922/HomeUI`. Run `cd /Users/gregor/dev/922/HomeUI` before any bash command.

## Verification
1. Run `cd /Users/gregor/dev/922/HomeUI && npm run test -- src/features/projects/sections/` — verify button style tests pass
2. Run `cd /Users/gregor/dev/922/HomeUI && npm run build`
3. Quick visual check: all action buttons should now be zinc-800 with zinc-400 text
