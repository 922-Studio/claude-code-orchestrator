# Plan: Orchestrator Repository Cleanup

- **Date**: 2026-05-11
- **Project(s)**: Orchestrator (this repo)
- **Goal**: Identify and remove deprecated, obsolete, and stale files; archive completed plans; commit all pending changes cleanly.
- **Status**: Done (2026-05-11)

## Context

Read these files before proceeding:
- `registry.md` — master project list
- `plans/` — all active and completed plans
- `.gitignore` — current exclusions

Current untracked/modified state (from `git status`):
- **Deleted (unstaged)**: `plans/2026-03-20-multi-tenant-org-modules.md`, `plans/2026-03-21-anime-infra.md`, `plans/2026-03-22-remove-coverage-from-e2e-and-prometheus.md`
- **Modified**: `plans/2026-03-27-full-documentation-overhaul.md`
- **Untracked**: `execution/` (25 doc-audit .txt files), `plans/2026-03-27-fix-health-page-visibility.md`, `plans/2026-03-27-multi-server-performance-dashboard.md`, `plans/2026-04-02-drafter-v1-requirements.md`, `studio/`

---

## Steps

---

### Step 1: Verify Plan Statuses

- **Directory**: `/Users/gregor/dev/922/orchestrator/plans/`
- **Parallel with**: —
- **Description**: Read all plans without an explicit status field to determine if they are complete, pending, or abandoned. Plans from 2026-03-24 and 2026-03-25 have no `Status` metadata — verify against git history and current ecosystem state.

Plans to verify (no status field found):
| Plan | Date | Likely State |
|------|------|-------------|
| `2026-03-24-container-grouping-and-domain-monitoring.md` | Mar 24 | Unknown |
| `2026-03-24-dev-prod-environment-split.md` | Mar 24 | Unknown |
| `2026-03-24-drafter-workflows-deployment.md` | Mar 24 | Unknown |
| `2026-03-24-shared-postgres-migration.md` | Mar 24 | Unknown |
| `2026-03-24-studio-landing-page.md` | Mar 24 | Unknown |
| `2026-03-25-dev-database-mirroring.md` | Mar 25 | Unknown |
| `2026-03-25-docker-registry-and-traefik-docs.md` | Mar 25 | Unknown |
| `2026-03-25-drafter-mvp-backend.md` | Mar 25 | Unknown |
| `2026-03-25-homestructure-docs-overhaul.md` | Mar 25 | Unknown |
| `2026-03-25-registry-cicd-drafter-pilot.md` | Mar 25 | Unknown |
| `2026-03-27-drafter-bugfixes-and-testing.md` | Mar 27 | Unknown |
| `2026-03-27-minio-deployment-and-drafter-integration.md` | Mar 27 | Unknown |
| `2026-03-27-multi-server-cluster-setup.md` | Mar 27 | Unknown |

- **Acceptance criteria**:
  - [ ] Each plan has a determined status (Done / Active / Abandoned)
  - [ ] Decision documented for each

---

### Step 2: Archive Completed Plans

- **Directory**: `/Users/gregor/dev/922/orchestrator/plans/`
- **Parallel with**: —
- **Depends on**: Step 1
- **Description**: Move all confirmed-done plans to `plans/archive/`. The following are confirmed done by their status field and can be moved immediately:

**Confirmed Done (archive immediately):**
- `plans/2026-03-25-watchtower-auto-deployment.md` — Status: Done
- `plans/2026-03-27-full-documentation-overhaul.md` — Status: Done (modified, untracked but confirmed done)
- `plans/2026-03-27-fix-health-page-visibility.md` — Status: DONE (untracked)
- `plans/2026-03-27-multi-server-performance-dashboard.md` — Status: Done (untracked)
- `plans/2026-03-28-fix-uptime-dashboard-granularity.md` — Status: DONE

**Plus all plans verified as Done in Step 1.**

**Keep active (not archive):**
- `plans/2026-03-27-per-repo-documentation-update.md` — Status: Ready (not started)
- `plans/2026-03-27-registry-cicd-rollout-all-services.md` — Status: In Progress (Wave 1)
- `plans/2026-04-02-drafter-v1-requirements.md` — Requirements spec, keep as reference
- `plans/critical-zero-downtime-migrations.md` — Reference doc, keep
- `plans/generic-registry-cicd-rollout.md` — Reference doc, keep

- **Acceptance criteria**:
  - [ ] All done plans moved to `plans/archive/`
  - [ ] Active/pending plans remain in `plans/`
  - [ ] No plans lost (all moved, not deleted)

---

### Step 3: Remove Deprecated Scripts

- **Directory**: `/Users/gregor/dev/922/orchestrator/scripts/`
- **Parallel with**: Step 2
- **Description**: The `scripts/` directory contains two files:
  - `scripts/patch_api_methods.py` — Written for the archived plan `2026-03-20-homeapi-mcp-generation.md`. Targets `/home/lab/openclaw/mcp-servers/homeapi/` which no longer exists in the ecosystem. **Delete it.**
  - `scripts/audit-homeui.sh` — Useful utility for HomeUI best practices audit. **Keep it.**

- **Acceptance criteria**:
  - [ ] `scripts/patch_api_methods.py` deleted
  - [ ] `scripts/audit-homeui.sh` remains intact

---

### Step 4: Handle the `execution/` Directory

- **Directory**: `/Users/gregor/dev/922/orchestrator/execution/`
- **Parallel with**: Step 3
- **Description**: The `execution/` directory contains 25 `doc-audit-*.txt` files — server scan snapshots from 2026-03-27 produced during the full documentation overhaul (now complete). These are 45+ days old and have been superseded by the updated docs. They should be cleaned up.
  - Delete all `doc-audit-*.txt` files (stale, single-use audit artifacts)
  - If the directory becomes empty, remove it entirely OR keep it as the orchestration state dir per CLAUDE.md design
  - Update `.gitignore` to exclude `execution/*.txt` so future audit snapshots aren't accidentally committed

- **Acceptance criteria**:
  - [ ] All `doc-audit-*.txt` files removed
  - [ ] `.gitignore` updated to exclude `execution/*.txt`

---

### Step 5: Handle the `studio/` Directory

- **Directory**: `/Users/gregor/dev/922/orchestrator/`
- **Parallel with**: Step 4
- **Description**: The `studio/` directory contains only a `.git` folder and `.gitignore` — it is a nested git repository (the Studio project), not part of the orchestrator repo. It shows as untracked (`??`) because git detects a nested `.git` but doesn't track it. **Add `studio/` to the orchestrator `.gitignore`** to prevent it from appearing in git status permanently.

- **Acceptance criteria**:
  - [ ] `studio/` added to `.gitignore`
  - [ ] No longer appears in `git status`

---

### Step 6: Stage Deleted Plans and Finalize

- **Directory**: `/Users/gregor/dev/922/orchestrator/`
- **Parallel with**: —
- **Depends on**: Steps 2–5
- **Description**: Stage all changes:
  1. Stage the 3 locally-deleted plan files (`git rm`)
  2. Stage all archived plans (moved files)
  3. Stage `.gitignore` changes
  4. Stage deletion of `scripts/patch_api_methods.py`
  5. Do NOT stage `execution/doc-audit-*.txt` (will be covered by .gitignore)

- **Acceptance criteria**:
  - [ ] `git status` shows only intentional changes
  - [ ] No untracked files remain (except `studio/` after .gitignore)

---

### Step 7: Commit

- **Directory**: `/Users/gregor/dev/922/orchestrator/`
- **Parallel with**: —
- **Depends on**: Step 6
- **Description**: Commit all changes with a descriptive message.

Commit message:
```
chore: orchestrator cleanup — archive completed plans, remove deprecated files

- Archive all done plans (Mar 24–28) to plans/archive/
- Remove deprecated scripts/patch_api_methods.py (OpenClaw MCP, archived plan)
- Remove stale doc-audit execution snapshots from 2026-03-27
- Add studio/ and execution/*.txt to .gitignore
- Stage deletions for 3 manually-deleted plans (Mar 20–22)
```

- **Acceptance criteria**:
  - [ ] Commit created successfully
  - [ ] `git status` is clean

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1:
  Step 1: Verify plan statuses (read each undated plan)
          → Orchestrator @ /Users/gregor/dev/922/orchestrator/plans/

Wave 2 (parallel, after Wave 1):
  Step 2: Archive completed plans → plans/archive/
  Step 3: Delete deprecated script → scripts/patch_api_methods.py
  Step 4: Clean execution/ dir + update .gitignore
  Step 5: Add studio/ to .gitignore

Wave 3 (after Wave 2):
  Step 6: Stage all changes
  Step 7: Commit
```

---

## Post-Execution Checklist
- [ ] All completed plans in `plans/archive/`
- [ ] Only active plans remain in `plans/`
- [ ] No deprecated scripts remain
- [ ] `.gitignore` updated for `execution/*.txt` and `studio/`
- [ ] `git status` is clean after commit
- [ ] No data loss (only stale artifacts removed)
