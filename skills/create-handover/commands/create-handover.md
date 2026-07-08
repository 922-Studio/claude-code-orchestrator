# Create Session Handover

Generate a thorough handover document for the next agent session.

Usage: `/create-handover [optional: next-session instructions]`

If instructions follow the command (e.g. `/create-handover finish kicker-v6 prod push then sync envs`),
those become the next session's tasks. If none are given, ask Gregor before writing:
"What should the next session tackle? I'll package it as ready-to-run prompts."

---

## Instructions

You are writing a handover for a future Claude Code agent with **zero context** about this session.
It must be able to open the file and start executing immediately — no research, no re-explaining.

### Step 1 — Gather session context
- `git log --oneline -5` and `git status` in each repo touched this session; `git branch` for active branches
- Any open worktrees (`git -C <repo> worktree list`)
- Open/in-progress tasks and relevant memory entries
- The relevant plan file(s) under `plans/` and their current step state

### Step 2 — Write the handover file
Write to `.planning/handover/HANDOVER-<TOPIC>.md` (absolute path, in the orchestrator repo).
Create `.planning/handover/` if missing. `<TOPIC>` = short slug (e.g. `KICKER-V6-PROD`, `LEDGER-E2E`).

The file MUST contain, in order:

```markdown
# Handover — <Topic>

> Generated: <date> · Branch(es): <repo → branch list>
> Next agent: load this file, execute "Next Session" in order, then delete this file.

## What Was Done This Session
- Files edited (paths + what changed), commits (SHA + repo), PRs opened/reviewed
- Bugs / root causes found (error messages, file:line), decisions made and why
- Anything half-finished and its exact current state

## Key Context
- Conventions/constraints, ordering dependencies, things NOT to do and why
- Env/credentials needed, reference implementations, blockers/unknowns
- Relevant plan file(s) under plans/ and which steps remain

## Next Session — Prompts to Execute
### Task 1 — <short title>
**Context:** <why this exists, what it depends on>
**Prompt to run:**
```
<exact paste-ready prompt for the next agent — written as if Gregor is speaking,
all context inline: files, repos, branches, errors, prior decisions>
```
### Task 2 — <short title>
...

## Repo / Worktree Locations
| Repo | Path | Branch |
|------|------|--------|
```

### Step 3 — Tell Gregor
Output exactly: (1) handover file absolute path, (2) active branch(es), (3) a one-paragraph summary
of what the next session will do. Then **stop** — do not start new tasks.
