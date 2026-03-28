# Wave 2A — Dialog Scrollability Fix

## Role
You are an Executor Agent. Follow `/Users/gregor/dev/922/Planner/prompts/executor.md`.

## Task
Make all dialogs scrollable on small screens. Currently the dialog content can overflow the viewport with no scroll.

## Context Files — Read These First
1. `/Users/gregor/dev/922/HomeUI/CLAUDE.md`
2. `/Users/gregor/dev/922/HomeUI/src/components/ui/dialog.tsx` — the Dialog primitive

## The Fix
In `src/components/ui/dialog.tsx`, the `DialogContentImpl` function renders a dialog card. The inner `<div>` at line ~97 needs scroll capability.

Change the inner content div:
```
Before: <div className="relative box-border px-10 py-7">
After:  <div className="relative box-border px-10 py-7 max-h-[85vh] overflow-y-auto">
```

This ensures:
- Dialog never exceeds 85% viewport height
- Content scrolls when it overflows
- Padding and close button remain accessible

## Working Directory
All commands must run from `/Users/gregor/dev/922/HomeUI`. Run `cd /Users/gregor/dev/922/HomeUI` before any bash command.

## Verification
1. Run `cd /Users/gregor/dev/922/HomeUI && npm run test -- src/components/ui/` to ensure no existing dialog tests break
2. Run `cd /Users/gregor/dev/922/HomeUI && npm run test -- src/features/projects/components/` — the scrollability tests from Wave 1D should now pass
3. Run `cd /Users/gregor/dev/922/HomeUI && npm run build` to verify no type errors

## Rules
- Do NOT add `Co-Authored-By` trailers
- Minimal change — only add the two Tailwind classes
