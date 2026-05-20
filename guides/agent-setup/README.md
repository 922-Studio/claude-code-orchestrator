# Agent Setup & Handover Guide

This guide explains how Gregor's Claude Code + orchestrator + Zed setup works. Target audience: a competent dev who has used Claude Code casually but has never seen this workspace. It covers the *system*, not the individual projects — those document themselves via their own `CLAUDE.md` files.

## TL;DR for the Impatient

1. **Launch from the root.** Open Zed (or `cd`) at `~/dev/922`. This loads the universal `CLAUDE.md`, workspace permissions, global settings, and the memory index in one shot.
2. **The orchestrator is the hub.** `orchestrator/` holds all plans, project mappings, and agent prompts. For any task touching more than one project — or needing a written, sequenced plan — start there.
3. **Every code change lives in a worktree.** Branch off `main`, work inside `<repo>/.worktrees/<branch>`, push, open a PR, capture the URL, then remove the worktree. Never commit to `main` directly.
4. **Memory persists across sessions.** Facts Claude learns (your role, preferences, project decisions) are written to `~/.claude/projects/-Users-gregor-dev-922/memory/` and reloaded next session.
5. **Skills extend Claude's behavior.** Invoke with `/skill-name`. Available skills are listed in `<system-reminder>` at session start.

## Topics

| # | File | What it covers |
|---|------|---------------|
| 1 | [01-overview.md](01-overview.md) | Big picture: workspace root, CLAUDE.md hierarchy, orchestrator role, memory, Zed launch model |
| 2 | [02-launching.md](02-launching.md) | How to start a session (Zed + CLI), what loads automatically, settings layering |
| 3 | [03-orchestrator-workflow.md](03-orchestrator-workflow.md) | When/how to engage the orchestrator, planning loop, agent roles, example plan walk-through |
| 4 | [04-worktree-pr-flow.md](04-worktree-pr-flow.md) | Mandatory worktree+PR workflow, exact commands, when to remove vs. leave the worktree |
| 5 | [05-settings-and-permissions.md](05-settings-and-permissions.md) | Global vs workspace settings, permission allowlist, statusline, plugins, model selection |
| 6 | [06-memory.md](06-memory.md) | Auto-memory: location, when Claude writes/reads, the four memory types, pruning |
| 7 | [07-skills-and-commands.md](07-skills-and-commands.md) | Available skills, how to invoke, built-in commands, discovering skills at session start |
| 8 | [08-handover-checklist.md](08-handover-checklist.md) | Day-1 steps: clone, symlinks, settings, open Zed, smoke test, SSH verify |

## Where to Go Next

- **Project list**: `orchestrator/registry.md`
- **Server infrastructure**: `orchestrator/server.md`
- **Per-project context**: `orchestrator/projects/<name>.md`
- **Active plans**: `orchestrator/plans/`
- **Universal rules**: `/Users/gregor/dev/922/CLAUDE.md`
