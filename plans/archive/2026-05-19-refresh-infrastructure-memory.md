# Plan: Refresh Infrastructure Memory

- **Date**: 2026-05-19
- **Project(s)**: orchestrator (memory store), HomeStructure (source of truth)
- **Goal**: Replace the stale `project_infrastructure.md` auto-memory with a current snapshot derived from live `server.md`, `HomeStructure/docs/`, and an actual server scan.

## Background

The auto-memory at `~/.claude/projects/-Users-gregor-dev-922/memory/project_infrastructure.md` is 60+ days old (as of 2026-05-19). It currently claims:

- Single-host setup (Ubuntu 24.x, Docker 29.3.0, ~31 containers, 14 Compose projects)
- 4 self-hosted runners
- Migration date 2026-03-19 from per-service Postgres/Redis/Caddy → shared infra + Traefik

But `orchestrator/server.md` (live, updated 2026-03-27) already shows a 3-node Docker Swarm cluster (home-lab + exec-0 + exec-1) — the memory is structurally wrong, not just dated.

This will increasingly mislead future sessions (already loaded as user auto-memory). Refresh from the ground up.

## Context

Read these files before proceeding:
- `~/.claude/projects/-Users-gregor-dev-922/memory/MEMORY.md` — current memory index
- `~/.claude/projects/-Users-gregor-dev-922/memory/project_infrastructure.md` — the stale memory
- `orchestrator/server.md` — current authoritative infra snapshot
- `orchestrator/registry.md` — current project list (some projects may have been added/removed since last memory write)
- `HomeStructure/docs/config/cluster.md` — cluster topology
- `HomeStructure/docs/config/storage.md` — storage layout
- `HomeStructure/docs/config/networking.md` — networking
- `/Users/gregor/dev/922/CLAUDE.md` — new ecosystem root

Then verify against the live server (next steps).

## Steps

### Step 1: Live Server Scan
- **Project**: home-lab (server)
- **Directory**: N/A (SSH)
- **Parallel with**: Step 2
- **Description**: SSH to `lab` (and `lab-exec-0`, `lab-exec-1` if reachable). Collect:
  - `docker info` (engine version, swarm role/status, node count)
  - `docker node ls` (cluster topology)
  - `docker service ls` and/or `docker stack ls` (services running on the swarm)
  - `docker ps --format` (containers per node, fallback if not swarm-managed)
  - `lsblk` / `df -h` (storage)
  - `ufw status` (firewall)
  - `ls ~/.cloudflared/config.yml`-ingress list (public routes)
  - Number of self-hosted runners (look in HomeStructure compose files or `gh api`)
- **Acceptance criteria**:
  - [ ] Raw scan output captured in a scratch file (not committed)
  - [ ] Discrepancies vs `server.md` and the stale memory noted

### Step 2: Project Inventory Cross-Check
- **Project**: orchestrator
- **Directory**: `/Users/gregor/dev/922/orchestrator`
- **Parallel with**: Step 1
- **Description**: Diff `registry.md` against actual `/Users/gregor/dev/922/` subdirectories. Flag any project added/removed since the last memory write. Confirm dependency graph in `registry.md` is still accurate (especially around shared infra and JWT sharing).
- **Acceptance criteria**:
  - [ ] List of registry vs filesystem deltas (if any)
  - [ ] List of dependency-graph corrections needed (if any)

### Step 3: Rewrite Memory File
- **Project**: orchestrator (memory store)
- **Directory**: `~/.claude/projects/-Users-gregor-dev-922/memory/`
- **Parallel with**: — (after Steps 1 & 2)
- **Description**: Replace `project_infrastructure.md` with a current snapshot. Structure:
  - Cluster topology (3-node Swarm, node roles, engine versions)
  - Shared infra (postgres, redis, exporters, networks)
  - Reverse proxy (Traefik) + Cloudflare Tunnel routes
  - Key services with current ports and domains
  - Management tooling (`homelab-ctl.sh`, `deploy-envs.sh`)
  - CI/CD (number of self-hosted runners, workflow conventions)
  - Last-verified date (today)
  - Why / How-to-apply lines, per memory-file convention
- **Acceptance criteria**:
  - [ ] File is concise (< ~80 lines) — memory should be load-bearing facts, not exhaustive
  - [ ] Cross-references `[[orchestrator-server-md]]` or similar where the long-form doc lives
  - [ ] Top of file has a fresh date stamp so future sessions see it's recent

### Step 4: Update MEMORY.md Index
- **Project**: orchestrator (memory store)
- **Directory**: `~/.claude/projects/-Users-gregor-dev-922/memory/`
- **Parallel with**: — (after Step 3)
- **Description**: Ensure `MEMORY.md` description line for `project_infrastructure.md` reflects the new content (Swarm-aware, not single-host). Verify other memories don't reference now-wrong infra facts.
- **Acceptance criteria**:
  - [ ] Index line updated
  - [ ] No other memory file contains contradicting infra claims

### Step 5: Validate from a Fresh Session
- **Project**: orchestrator
- **Directory**: `/Users/gregor/dev/922`
- **Parallel with**: — (after Step 4)
- **Description**: Start a new Claude session from `/Users/gregor/dev/922`. Ask: "summarize my home-lab infra" without pointing at any file. Verify the answer matches the refreshed memory and `server.md`.
- **Acceptance criteria**:
  - [ ] Session answer is accurate and current
  - [ ] No mention of removed/stale concepts (e.g. single-host, old container counts)

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Live server scan → home-lab via ssh
  Step 2: Project inventory cross-check → orchestrator

Wave 2 (after Wave 1):
  Step 3: Rewrite memory file → memory store

Wave 3 (after Wave 2):
  Step 4: Update MEMORY.md index → memory store

Wave 4 (after Wave 3):
  Step 5: Validate from fresh session → /Users/gregor/dev/922
```

## Post-Execution Checklist
- [ ] `project_infrastructure.md` reflects current Swarm cluster
- [ ] Date stamp at top of file is today's date
- [ ] `MEMORY.md` index line is accurate
- [ ] Fresh-session validation passed
- [ ] If `server.md` was out of date too, file a follow-up issue (or fix it in this same session)

## Open Questions for Gregor
- Should `server.md` itself be refreshed in this same plan, or kept as a separate concern?
- Any infra changes since 2026-03-27 (when `server.md` was last refreshed) that I should know about up front?
