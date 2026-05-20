# 03 — Orchestrator Workflow

**Prev**: [02 — Launching](02-launching.md) | **Next**: [04 — Worktree & PR Flow](04-worktree-pr-flow.md)

## When to Engage the Orchestrator

Use the orchestrator when:
- A task touches **more than one project** (e.g. HomeAPI schema change + HomeUI consumer update).
- A task needs a **written, sequenced plan** with dependencies and parallelizable steps.
- You need **per-project context** before acting — read `orchestrator/projects/<name>.md`.

For a single-file fix inside one repo, skip the orchestrator and just work in that repo.

## The Planning Loop

```
1. Read context
   └── orchestrator/registry.md          (project landscape)
   └── orchestrator/projects/<name>.md   (target project conventions)
   └── orchestrator/server.md            (infra, if relevant)

2. Write plan
   └── orchestrator/plans/YYYY-MM-DD-<slug>.md
       ├── numbered steps with dependencies
       ├── acceptance criteria per step
       ├── worktree + branch name per step
       └── execution overview (waves)

3. Execute waves
   └── Wave 1: parallelizable steps → each gets a worktree + feature branch
   └── Wave 2: depends on Wave 1 output
   └── ...

4. PR per step
   └── gh pr create against main
   └── URL reported back to Gregor

5. Archive plan (after all PRs merged)
   └── move to orchestrator/plans/archive/
```

## Key Files

| File | Purpose |
|------|---------|
| `orchestrator/registry.md` | Every project: path, type, status, dependencies |
| `orchestrator/projects/<name>.md` | Per-project: tech stack, key files, conventions, CI/CD |
| `orchestrator/plans/` | All active plans |
| `orchestrator/plans/archive/` | Completed/superseded plans |
| `orchestrator/plans/_template.md` | Plan file template |
| `orchestrator/prompts/planner.md` | System prompt for planning role |
| `orchestrator/prompts/executor.md` | System prompt for execution role |
| `orchestrator/prompts/reviewer.md` | System prompt for review/QA role |

## Agent Roles

Claude can operate in three roles in this system:

- **Planner** — reads project context, produces a plan file with sequenced steps. Does NOT touch code.
- **Executor** — receives one step from a plan, creates worktree, implements, tests, commits, pushes, opens PR.
- **Reviewer** — reads plan intent + diff, verifies acceptance criteria, reports `approved / changes-requested / blocked`.

The prompts in `orchestrator/prompts/` are the system instructions for each role. When spawning a sub-agent for a step, pass the relevant prompt as the agent's context.

## Example: End-to-End Plan Walk-Through

A real example is this doc set itself. See `orchestrator/plans/2026-05-19-agent-setup-handover-docs.md`:

1. Plan file defines 5 steps across 5 sequential waves.
2. Wave 1 (Step 1): outline audience/scope → confirm with Gregor.
3. Wave 2 (Step 2): draft 8 topic files — within the wave they can be written in parallel.
4. Wave 3 (Step 3): write `README.md` as the entry point.
5. Wave 4 (Step 4): newcomer test + one revision pass.
6. Wave 5 (Step 5): add links in root + orchestrator `CLAUDE.md`.

Each step has explicit acceptance criteria. No step is reported complete until those criteria are met.

## Naming Conventions

- Plan files: `YYYY-MM-DD-<slug>.md` (e.g. `2026-05-19-agent-setup-handover-docs.md`)
- Feature branches: `feat/<plan-slug>` or `feat/<plan-slug>-step-<N>` for parallel work on the same repo
- Worktree paths: `<repo>/.worktrees/<branch-name>`
