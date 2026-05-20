# Plan: Per-Project CLAUDE.md Review & Alignment

- **Date**: 2026-05-19
- **Project(s)**: All 17 projects in `registry.md` with an existing `CLAUDE.md`
- **Goal**: Audit every per-project `CLAUDE.md` so each one is lean, accurate, and complements the new root `/Users/gregor/dev/922/CLAUDE.md` without duplicating universal rules.

## Background

The workspace was just restructured to a two-layer CLAUDE.md model:
- **Root** (`/Users/gregor/dev/922/CLAUDE.md`): ecosystem identity, universal rules (worktrees, commits, quality gates), server pointer, orchestrator pointer.
- **Per-project** (`<project>/CLAUDE.md`): project-specific context only.

Per-project files were written at different times by different sessions. They likely contain:
- Duplicated universal rules (worktree workflow, no co-authored-by, English) — should be removed; root owns these now.
- Stale tech-stack info, removed services, renamed files.
- Inconsistent structure across projects.

This plan brings them into alignment without rewriting them from scratch.

## Context

Read these files before proceeding:
- `/Users/gregor/dev/922/CLAUDE.md` — the new root; defines what is now redundant in per-project files
- `orchestrator/CLAUDE.md` — orchestrator-scope conventions
- `orchestrator/registry.md` — full project list with current paths and status
- `orchestrator/projects/<name>.md` — authoritative per-project mapping; per-project `CLAUDE.md` should not contradict this

## Steps

### Step 1: Inventory & Diff
- **Project**: orchestrator
- **Directory**: `/Users/gregor/dev/922/orchestrator`
- **Parallel with**: —
- **Description**: Build a single inventory table listing every `<project>/CLAUDE.md`: file size, last modified, presence of universal-rule duplication (worktree, no co-authored-by, English clause, server pointer), and presence of stale references (compare against `orchestrator/projects/<name>.md`). Save as a working note inside this plan or in a scratch file under `orchestrator/plans/`.
- **Acceptance criteria**:
  - [ ] Table covers all projects in `registry.md` that have a `CLAUDE.md`
  - [ ] Each row flags: `has-duplicates: yes/no`, `has-stale: yes/no/unsure`, `needs-rewrite: yes/no/maybe`
  - [ ] Output is small enough to drive Step 2 decisions

### Step 2: Define the Per-Project CLAUDE.md Skeleton
- **Project**: orchestrator
- **Directory**: `/Users/gregor/dev/922/orchestrator`
- **Parallel with**: Step 1 (can start drafting in parallel; finalize after Step 1)
- **Description**: Write a short skeleton template that every per-project `CLAUDE.md` should follow. Place it at `orchestrator/projects/_claude-md-template.md`. Skeleton should include only project-specific concerns: tech stack one-liner, entrypoints, key directories, project-specific gotchas, testing commands, deploy command, links to docs. Explicitly NOT in the skeleton: worktree rules, commit conventions, server pointers, language preferences.
- **Acceptance criteria**:
  - [ ] Template exists at `orchestrator/projects/_claude-md-template.md`
  - [ ] Template is < 60 lines
  - [ ] Template explicitly notes which sections are forbidden (with reason: "owned by root CLAUDE.md")

### Step 3: Apply Skeleton — Wave A (Infrastructure / Backend)
- **Projects**: HomeStructure, HomeAPI, HomeAuth, HomeCollector, Anime-API, workflows
- **Directory**: each project root
- **Parallel with**: Step 4, Step 5 (one worktree per project; safe to parallelize across repos)
- **Description**: For each project, open a worktree on `feat/claude-md-cleanup`. Rewrite `CLAUDE.md` against the skeleton from Step 2. Cross-check against `orchestrator/projects/<name>.md` for accuracy. Commit, push, open PR, report URL.
- **Context files to read**:
  - `orchestrator/projects/<name>.md` — source of truth for project facts
  - `orchestrator/projects/_claude-md-template.md` — skeleton
- **Acceptance criteria**:
  - [ ] One PR per project, all linked back to this plan
  - [ ] No universal-rule duplication remains
  - [ ] No stale references remain (verified against `projects/<name>.md`)

### Step 4: Apply Skeleton — Wave B (Frontend / Apps)
- **Projects**: HomeUI, Anime-APP, Drafter, portfolio, sweatvalley_bingo, studio, smoking-counter
- **Directory**: each project root
- **Parallel with**: Step 3, Step 5
- **Description**: Same as Step 3, for frontend / app projects.
- **Acceptance criteria**:
  - [ ] One PR per project, all linked back to this plan

### Step 5: Apply Skeleton — Wave C (Standalone)
- **Projects**: discord
- **Directory**: each project root
- **Parallel with**: Step 3, Step 4
- **Description**: Same as Step 3, for standalone projects.
- **Acceptance criteria**:
  - [ ] CLAUDE.md trimmed to match the skeleton

### Deprecated (2026-05-19)
- OpenClaw, HomeSocial, landingpage moved to `/Users/gregor/dev/922/deprecated/`. They no longer participate in this plan.
- Integration code referencing OpenClaw still exists in HomeAPI (`app/routers/openclaw.py`, `app/services/openclaw_client.py`, schemas, tasks, tests) and HomeCollector (`app/tasks/openclaw_tasks.py`, `app/services/openclaw_client.py`, tests). Mappings (`projects/homeapi.md`, `projects/homecollector.md`, `projects/homestructure.md`) and `server.md` retain OpenClaw references until that code/service is also retired — separate plan needed.

### Step 6: Verify by Spot-Check
- **Project**: orchestrator
- **Directory**: `/Users/gregor/dev/922/orchestrator`
- **Parallel with**: — (after Steps 3–5 are merged)
- **Description**: Open a fresh Claude session from `/Users/gregor/dev/922`, `cd` into 3 random projects, ensure context loads cleanly and that universal rules from root are present without duplication. Note any remaining drift; add follow-up issues if needed.
- **Acceptance criteria**:
  - [ ] Spot-check report written to this plan as a closing note
  - [ ] No regressions: every project still has the project-specific context an agent needs to do work in it

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1:
  Step 1: Inventory & Diff → orchestrator
  Step 2: Define skeleton → orchestrator (can run alongside Step 1)

Wave 2 (after Wave 1, all parallel):
  Step 3: Wave A rewrites (6 projects, parallel PRs)
  Step 4: Wave B rewrites (7 projects, parallel PRs)
  Step 5: Wave C rewrites (4 projects, parallel PRs)

Wave 3 (after Wave 2 merged):
  Step 6: Verify by spot-check → orchestrator
```

## Post-Execution Checklist
- [ ] Every per-project `CLAUDE.md` follows the skeleton
- [ ] No universal-rule duplication anywhere
- [ ] No stale references to removed files/services
- [ ] `orchestrator/projects/_claude-md-template.md` is in place for future projects
- [ ] Spot-check session confirms clean context loading

## Open Questions for Gregor
- For inactive projects (OpenClaw, HomeSocial, landingpage): keep slim `CLAUDE.md` or remove entirely?
- Wave parallelism: comfortable opening ~17 PRs in one session, or stage waves across days?
