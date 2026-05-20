# Plan: Agent Setup Handover Documentation

- **Date**: 2026-05-19
- **Project(s)**: orchestrator
- **Goal**: Produce a self-contained set of docs (`orchestrator/guides/agent-setup/`) that someone else can read and fully understand how Gregor's Claude Code + orchestrator + Zed setup works, so the workflow can be handed off, demo'd, or onboarded onto.

## Background

The system has several moving pieces that aren't documented anywhere as a coherent whole:
- Workspace root at `/Users/gregor/dev/922` with two-layer `CLAUDE.md` (root + per-project)
- Symlinks (`registry.md`, `server.md`) pointing into `orchestrator/`
- `orchestrator/` as the planning+execution hub (registry, projects, plans, prompts)
- Auto-memory store at `~/.claude/projects/-Users-gregor-dev-922/memory/`
- Per-user global settings at `~/.claude/settings.json` (model, statusline, plugins)
- Workspace settings at `/Users/gregor/dev/922/.claude/settings.local.json` (permissions for Zed-launched sessions)
- Zed as the IDE host that launches Claude Code from `/Users/gregor/dev/922`
- Plugin: `warp@claude-code-warp`
- Statusline: custom `ctx_monitor.js`
- Skills available: orchestrator-cleanup, schedule, loop, review, security-review, etc.
- Worktree+PR workflow as a universal rule

Without a written explanation, anyone (or future Gregor in 6 months) has to reverse-engineer this from files.

## Context

Read these files before proceeding:
- `/Users/gregor/dev/922/CLAUDE.md` — root (universal rules, orchestrator pointer)
- `orchestrator/CLAUDE.md` — orchestrator-specific workflow
- `orchestrator/registry.md` — project list
- `orchestrator/server.md` — infra (referenced, not duplicated in handover)
- `orchestrator/prompts/{planner,executor,reviewer}.md` — agent prompts
- `orchestrator/plans/_template.md` — plan format
- `orchestrator/projects/_template.md` — project mapping format
- `~/.claude/settings.json` — global settings
- `/Users/gregor/dev/922/.claude/settings.local.json` — workspace permissions
- `~/.claude/projects/-Users-gregor-dev-922/memory/MEMORY.md` — memory index (do not copy contents into the handover doc)

## Steps

### Step 1: Outline & Audience
- **Project**: orchestrator
- **Directory**: `/Users/gregor/dev/922/orchestrator/guides/agent-setup/`
- **Parallel with**: —
- **Description**: Decide audience and scope. Target audience: a competent dev who has used Claude Code casually but has never seen this workspace. Scope boundary: explain the *system*, not every project (those have their own `CLAUDE.md`). Sketch the doc structure as a single `README.md` plus a small set of topic files. Confirm structure with Gregor before drafting prose.
- **Acceptance criteria**:
  - [ ] `README.md` outline drafted with section headings
  - [ ] List of topic files proposed (see Step 2 for the likely set)
  - [ ] Audience + scope written into the README intro

### Step 2: Draft Topic Files
- **Project**: orchestrator
- **Directory**: `/Users/gregor/dev/922/orchestrator/guides/agent-setup/`
- **Parallel with**: — (sequential after Step 1, but topic files within Step 2 can be written in parallel)
- **Description**: Write the following topic files. Each ≤ 150 lines. Concrete examples > abstract description.
  - `01-overview.md` — the big picture: workspace root, orchestrator as hub, per-project CLAUDE.md, memory, Zed launch model. Include a single ASCII diagram showing CLAUDE.md hierarchy + symlinks + orchestrator role.
  - `02-launching.md` — how to start a session (Zed: open `~/dev/922`; CLI fallback: `cd ~/dev/922 && claude`). What loads automatically (root CLAUDE.md, workspace settings, global settings, memory). What does NOT load until you navigate (per-project CLAUDE.md).
  - `03-orchestrator-workflow.md` — when to engage the orchestrator, the planning loop (plan → execution overview → executor agents → PRs), `plans/`, `prompts/`, `registry.md`, `projects/<name>.md`. Walk through one example plan end-to-end (cite an existing plan, don't fabricate).
  - `04-worktree-pr-flow.md` — the mandatory worktree+PR workflow, exact commands, when to remove the worktree, when to leave it, how PR URLs are surfaced.
  - `05-settings-and-permissions.md` — global vs workspace settings, what's in each, how to extend the permission allowlist (`/fewer-permission-prompts` skill), statusline, plugins, model selection.
  - `06-memory.md` — how auto-memory works, where it lives, when Claude writes/reads, the four memory types (user/feedback/project/reference), how to prune. Reference but don't copy actual memory contents.
  - `07-skills-and-commands.md` — what skills are available (list a few core ones: review, security-review, loop, schedule), how to invoke (`/skill-name`), and that they're listed in system-reminders per session.
  - `08-handover-checklist.md` — concrete steps a newcomer takes on day 1: clone what, set up SSH for `lab`, open Zed at `~/dev/922`, try a no-op plan, etc.
- **Acceptance criteria**:
  - [ ] All 8 topic files exist
  - [ ] Each links to the next/prev where appropriate
  - [ ] No section duplicates content from `CLAUDE.md` files — link instead
  - [ ] Diagrams kept ASCII (renders everywhere)

### Step 3: Write README & Index
- **Project**: orchestrator
- **Directory**: `/Users/gregor/dev/922/orchestrator/guides/agent-setup/`
- **Parallel with**: — (after Step 2)
- **Description**: Write `README.md` that frames the doc set, links to each topic in order, and includes a "TL;DR for the impatient" section (5-bullet summary of how the system works).
- **Acceptance criteria**:
  - [ ] `README.md` reads as a coherent entry point
  - [ ] TL;DR is genuinely sufficient to orient someone in 2 minutes

### Step 4: Newcomer Test
- **Project**: orchestrator
- **Directory**: `/Users/gregor/dev/922/orchestrator`
- **Parallel with**: — (after Step 3)
- **Description**: Pick a "newcomer surrogate" — either a fresh Claude session with no context except the guide, or a real person if available. Have them: (a) start a session from `~/dev/922`, (b) explain back what the orchestrator does, (c) follow Step 08-handover-checklist. Note every confusion point. Iterate on the docs once.
- **Acceptance criteria**:
  - [ ] Test executed
  - [ ] Confusion points captured as a punch list inside this plan file
  - [ ] One revision pass applied to the docs
  - [ ] Final docs committed

### Step 5: Link From Top-Level Files
- **Project**: orchestrator
- **Directory**: `/Users/gregor/dev/922/orchestrator`
- **Parallel with**: — (after Step 4)
- **Description**: Add a "Handover docs" link line to `orchestrator/CLAUDE.md`'s File Reference section and to the root `/Users/gregor/dev/922/CLAUDE.md` so future sessions discover the guide.
- **Acceptance criteria**:
  - [ ] One link added to each, pointing at `orchestrator/guides/agent-setup/README.md`

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1:
  Step 1: Outline & audience → orchestrator/guides/agent-setup

Wave 2 (after Wave 1, topic files in parallel within this wave):
  Step 2: Draft 8 topic files → orchestrator/guides/agent-setup

Wave 3 (after Wave 2):
  Step 3: Write README & index → orchestrator/guides/agent-setup

Wave 4 (after Wave 3):
  Step 4: Newcomer test + revision pass → orchestrator/guides/agent-setup

Wave 5 (after Wave 4):
  Step 5: Link from root CLAUDE.md and orchestrator CLAUDE.md → orchestrator
```

## Post-Execution Checklist
- [ ] `orchestrator/guides/agent-setup/` exists with README + 8 topic files
- [ ] Newcomer test produced fewer than ~3 confusion points after one revision
- [ ] Both root and orchestrator `CLAUDE.md` link to the handover docs
- [ ] No content duplication — handover docs cross-link rather than copy

## Open Questions for Gregor
- Should the handover docs live in `orchestrator/guides/agent-setup/` (loads as orchestrator context) or somewhere more neutral (e.g. a dedicated repo)? If the latter, where?
- Audience: only senior devs, or also less-technical collaborators? Affects how much we explain Claude Code basics.
- Should we include screenshots of Zed + Claude Code in action, or keep it text-only for portability?
