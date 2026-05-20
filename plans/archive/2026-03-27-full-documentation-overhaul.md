# Plan: Full Documentation Overhaul

- **Date**: 2026-03-27
- **Project(s)**: Planner, HomeStructure, all ecosystem projects
- **Goal**: Update every documentation file across the ecosystem to reflect current state, including live server scan for version accuracy.
- **Status**: Done (2026-03-27)

### Progress
- [x] Step 1: Live Server Scan (2026-03-27)
- [x] Step 2: Codebase Scan (2026-03-27)
- [x] Step 3: Update server.md (2026-03-27)
- [x] Step 4: Update HomeStructure Docs (2026-03-27) — 15 files updated
- [x] Step 5: Update Project Mappings (2026-03-27) — all 13 files updated
- [x] Step 6: Update registry.md + showcase.md (2026-03-27)
- [x] Step 7: Update Prompts + Templates + Guides (2026-03-27)
- [x] Step 8: Cross-Reference Validation (2026-03-27) — 11 issues found, 6 fixed
- [x] Step 9: Commit and Push (2026-03-27) — Planner committed, HomeStructure pushed to dev

## Context

Read these files before proceeding:
- `registry.md` — master project list and ecosystem graph
- `server.md` — current server infrastructure reference
- `projects/*.md` — all 13 project mappings
- `showcase.md` — marketing/overview doc

HomeStructure docs (43 files):
- `/Users/gregor/dev/922/HomeStructure/docs/` — full infrastructure documentation

---

## Steps

---

### Step 1: Live Server Scan — Collect Ground Truth

- **Project**: HomeStructure (server)
- **Directory**: Remote via `ssh lab`
- **Parallel with**: —
- **Description**: SSH into the server and collect current runtime state. This is the **single source of truth** that all other doc updates will reference.
- **Commands to run on server**:
  ```bash
  # 1. All running containers with images and versions
  docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" > /tmp/doc-audit-containers.txt

  # 2. Docker Swarm services (if any)
  docker service ls > /tmp/doc-audit-swarm-services.txt 2>/dev/null || echo "No swarm services"

  # 3. Docker networks
  docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" > /tmp/doc-audit-networks.txt

  # 4. Docker volumes
  docker volume ls > /tmp/doc-audit-volumes.txt

  # 5. Listening ports
  sudo ss -tlnp > /tmp/doc-audit-ports.txt

  # 6. Disk usage
  df -h > /tmp/doc-audit-disk.txt

  # 7. OS and kernel version
  cat /etc/os-release > /tmp/doc-audit-os.txt
  uname -r >> /tmp/doc-audit-os.txt

  # 8. Docker version
  docker version --format '{{.Server.Version}}' > /tmp/doc-audit-docker-version.txt

  # 9. Docker Compose version
  docker compose version > /tmp/doc-audit-compose-version.txt

  # 10. Traefik version (from container)
  docker exec traefik traefik version 2>/dev/null > /tmp/doc-audit-traefik-version.txt || echo "check image tag"

  # 11. PostgreSQL version
  docker exec shared_postgres psql -U postgres -c "SELECT version();" > /tmp/doc-audit-pg-version.txt 2>/dev/null

  # 12. Redis version
  docker exec shared_redis redis-server --version > /tmp/doc-audit-redis-version.txt 2>/dev/null

  # 13. All database names and users
  docker exec shared_postgres psql -U postgres -c "\l" > /tmp/doc-audit-databases.txt 2>/dev/null
  docker exec shared_postgres psql -U postgres -c "\du" > /tmp/doc-audit-db-users.txt 2>/dev/null

  # 14. Cloudflare tunnel config (if accessible)
  cat /home/lab/HomeStructure/cloudflared/config.yml > /tmp/doc-audit-cf-tunnel.txt 2>/dev/null

  # 15. UFW rules
  sudo ufw status verbose > /tmp/doc-audit-firewall.txt

  # 16. Tailscale status
  tailscale status > /tmp/doc-audit-tailscale.txt 2>/dev/null

  # 17. GitHub runners status
  ls /home/lab/actions-runner*/  > /tmp/doc-audit-runners.txt 2>/dev/null

  # 18. Crontabs
  crontab -l > /tmp/doc-audit-crontab.txt 2>/dev/null

  # 19. Systemd services (custom)
  systemctl list-units --type=service --state=running | grep -E "(docker|home|github|watchtower|syncthing|cloudflare)" > /tmp/doc-audit-systemd.txt

  # 20. Node info (swarm)
  docker node ls > /tmp/doc-audit-nodes.txt 2>/dev/null

  # 21. All docker-compose files in use
  find /home/lab -maxdepth 3 -name "docker-compose*.yml" -o -name "docker-compose*.yaml" 2>/dev/null > /tmp/doc-audit-compose-files.txt

  # 22. MinIO version
  docker exec minio minio --version > /tmp/doc-audit-minio-version.txt 2>/dev/null

  # Bundle everything
  tar czf /tmp/doc-audit-$(date +%Y%m%d).tar.gz /tmp/doc-audit-*.txt
  ```
- **Then copy to local**:
  ```bash
  scp lab:/tmp/doc-audit-$(date +%Y%m%d).tar.gz /Users/gregor/dev/922/Planner/execution/
  tar xzf /Users/gregor/dev/922/Planner/execution/doc-audit-*.tar.gz -C /Users/gregor/dev/922/Planner/execution/
  ```
- **Acceptance criteria**:
  - [ ] All 22 audit files collected
  - [ ] Data copied to local `execution/` directory
  - [ ] No errors in collection (missing containers noted)

---

### Step 2: Scan All Project Codebases — Collect Code-Level Truth

- **Project**: All 13 projects
- **Directory**: `/Users/gregor/dev/922/`
- **Parallel with**: Step 1
- **Description**: For each project, extract current state from code. This data feeds into project mapping updates (Step 5).

**Per-project scan — read these files in each project:**

| # | Project | Directory | Files to Read |
|---|---------|-----------|---------------|
| 1 | **HomeAPI** | `/Users/gregor/dev/922/HomeAPI` | `pyproject.toml` (deps, version), `app/models/` (count models), `app/routers/` (count routers), `docker-compose.yaml`, `.github/workflows/`, `README.md`, `alembic/` |
| 2 | **HomeAuth** | `/Users/gregor/dev/922/HomeAuth` | `pyproject.toml`, `app/routers/`, `app/models/`, `docker-compose.yaml`, `.github/workflows/`, `README.md` |
| 3 | **HomeCollector** | `/Users/gregor/dev/922/HomeCollector` | `pyproject.toml`, `app/tasks/` (celery tasks), `app/collectors/`, `docker-compose.yaml`, `.github/workflows/`, `README.md` |
| 4 | **HomeUI** | `/Users/gregor/dev/922/HomeUI` | `package.json` (deps, version), `src/pages/` (routes), `src/components/`, `vite.config.*`, `docker-compose.yaml`, `.github/workflows/` |
| 5 | **HomeStructure** | `/Users/gregor/dev/922/HomeStructure` | `docker-compose.yaml`, `scripts/homelab-ctl.sh`, `traefik/`, `prometheus/`, `grafana/`, `cloudflared/` |
| 6 | **Drafter** | `/Users/gregor/dev/922/Drafter` | `package.json`, `prisma/schema.prisma` (models), `src/app/` (routes), `docker-compose.yaml`, `.github/workflows/` |
| 7 | **Anime-API** | `/Users/gregor/dev/922/Anime-API` | `pyproject.toml`, `app/routers/`, `app/models/`, `docker-compose.yaml`, `.github/workflows/` |
| 8 | **Anime-APP** | `/Users/gregor/dev/922/Anime-APP` | `package.json`, `src/`, `docker-compose.yaml`, `.github/workflows/` |
| 9 | **Portfolio** | `/Users/gregor/dev/922/portfolio` | `package.json`, `src/`, `docker-compose.yaml`, `.github/workflows/` |
| 10 | **Studio** | `/Users/gregor/dev/922/studio` | `package.json`, `src/`, `docker-compose.yaml`, `.github/workflows/` |
| 11 | **Sweatvalley Bingo** | `/Users/gregor/dev/922/sweatvalley_bingo` | `package.json`, `src/`, `docker-compose.yaml`, `.github/workflows/` |
| 12 | **Discord Bot** | `/Users/gregor/dev/922/discord` | `pyproject.toml` or `package.json`, `src/` or `bot/`, `docker-compose.yaml`, `.github/workflows/` |
| 13 | **Workflows** | `/Users/gregor/dev/922/workflows` | `.github/workflows/` (all reusable workflow files), `README.md` |

**What to extract per project:**
- Current version / dependency versions
- Number of models, routers/routes, pages, components
- Tech stack (exact versions from lock files)
- CI/CD workflows (names, triggers, what they do)
- Docker setup (services, networks, labels)
- Any new features/endpoints not in current docs

- **Acceptance criteria**:
  - [ ] All 13 projects scanned
  - [ ] Extracted data saved as notes per project in `execution/`

---

### Step 3: Update `server.md` — Server Infrastructure Reference

- **Project**: Planner
- **Directory**: `/Users/gregor/dev/922/Planner`
- **Parallel with**: —
- **Depends on**: Step 1 (server scan data)
- **Context files to read**:
  - `server.md` — current state to diff against
  - `execution/doc-audit-*.txt` — ground truth from server
- **Description**: Update every section of `server.md` using scan data:
  1. **Cluster section**: Update node list, roles, IPs from `doc-audit-nodes.txt` and `doc-audit-tailscale.txt`
  2. **Storage section**: Update disk sizes/mounts from `doc-audit-disk.txt`
  3. **Networking section**: Update firewall rules from `doc-audit-firewall.txt`, Tailscale IPs
  4. **Public Routes**: Cross-reference with `doc-audit-cf-tunnel.txt`
  5. **All Services & Ports**: Rebuild from `doc-audit-containers.txt` and `doc-audit-ports.txt` — update every version number, add new services, remove decommissioned ones
  6. **Docker Networks**: Update from `doc-audit-networks.txt`
  7. **Key Commands**: Verify commands still work
  8. **Version numbers**: PostgreSQL from `doc-audit-pg-version.txt`, Redis from `doc-audit-redis-version.txt`, Traefik from `doc-audit-traefik-version.txt`, Docker from `doc-audit-docker-version.txt`
- **Acceptance criteria**:
  - [ ] Every service listed matches running containers
  - [ ] Every port number matches `ss -tlnp` output
  - [ ] Every version number matches actual running version
  - [ ] No phantom services (listed but not running)
  - [ ] No missing services (running but not listed)

---

### Step 4: Update HomeStructure Docs (43 files)

- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure/docs/`
- **Parallel with**: Step 3 (different files, same data source)
- **Depends on**: Step 1 (server scan data)
- **Context files to read**:
  - All files in `docs/` — current state
  - `execution/doc-audit-*.txt` — ground truth from server
  - Updated `server.md` from Step 3 (for consistency)

**Update each doc category:**

#### 4a. Project Info (2 files)
| File | What to Update | Data Source |
|------|---------------|-------------|
| `docs/project-info/about.md` | Tech stack versions, project description | `doc-audit-*-version.txt` |
| `docs/project-info/architecture.md` | Cluster layout, service ports table, networking diagram, deployment flow | `doc-audit-nodes.txt`, `doc-audit-ports.txt`, `doc-audit-networks.txt` |

#### 4b. Config (8 files)
| File | What to Update | Data Source |
|------|---------------|-------------|
| `docs/config/server.md` | OS version, kernel, packages | `doc-audit-os.txt` |
| `docs/config/networking.md` | Tailscale IPs, tunnel routes | `doc-audit-tailscale.txt`, `doc-audit-cf-tunnel.txt` |
| `docs/config/cluster.md` | Node table, overlay networks, swarm state | `doc-audit-nodes.txt`, `doc-audit-networks.txt` |
| `docs/config/dev-prod-environments.md` | Services table, subdomains, ports, DB/Redis split | `doc-audit-containers.txt`, `doc-audit-databases.txt` |
| `docs/config/storage.md` | Disk sizes, mount points, usage | `doc-audit-disk.txt` |
| `docs/config/security.md` | UFW rules, DOCKER-USER chain | `doc-audit-firewall.txt` |
| `docs/config/cloudflare.md` | Tunnel ingress rules, DNS entries | `doc-audit-cf-tunnel.txt` |
| `docs/config/notifications.md` | Notification services (verify still active) | `doc-audit-systemd.txt` |

#### 4c. Services (16 files)
| File | What to Update | Data Source |
|------|---------------|-------------|
| `docs/services/docker.md` | Docker version, compose locations | `doc-audit-docker-version.txt`, `doc-audit-compose-files.txt` |
| `docs/services/traefik.md` | Version, router table, middlewares, networks | `doc-audit-traefik-version.txt`, `doc-audit-containers.txt` |
| `docs/services/registry.md` | Registry version, users, storage | `doc-audit-containers.txt` |
| `docs/services/portainer.md` | Version, access URL | `doc-audit-containers.txt` |
| `docs/services/monitoring.md` | Prometheus/Grafana versions, scrape targets | `doc-audit-containers.txt` |
| `docs/services/github-runner.md` | Runner count, labels, versions | `doc-audit-runners.txt` |
| `docs/services/home-collector.md` | Monitored services list, health endpoints | `doc-audit-containers.txt` |
| `docs/services/openclaw.md` | Version, model config, endpoints | `doc-audit-containers.txt` |
| `docs/services/cloudflare-tunnel.md` | Ingress rules, services routing | `doc-audit-cf-tunnel.txt` |
| `docs/services/minio.md` | Version, buckets, policies | `doc-audit-minio-version.txt` |
| `docs/services/resend.md` | Integration status, templates | Verify via code |
| `docs/services/watchtower.md` | Version, monitored containers, schedule | `doc-audit-containers.txt` |
| `docs/services/syncthing.md` | Version, sync folders | `doc-audit-containers.txt` |
| `docs/services/email-routing.md` | Routing rules | Verify via Cloudflare |
| `docs/services/allure.md` | Version, access URL | `doc-audit-containers.txt` |
| `docs/services/portfolio.md` | Deployment status | `doc-audit-containers.txt` |

#### 4d. Actions (11 files)
| File | What to Update | Data Source |
|------|---------------|-------------|
| `docs/actions/index.md` | Workflow list (add new, remove old) | Read `/Users/gregor/dev/922/workflows/.github/workflows/` |
| `docs/actions/workflow-naming.md` | Naming examples | Cross-ref with actual workflow names |
| `docs/actions/*.md` (9 files) | Inputs, outputs, usage examples | Read each workflow `.yml` file in workflows repo |

#### 4e. Ops (3 files)
| File | What to Update | Data Source |
|------|---------------|-------------|
| `docs/ops/troubleshooting.md` | Common issues (add new ones from recent experience) | Review recent git logs |
| `docs/ops/maintenance.md` | Backup scripts, cleanup commands | `doc-audit-crontab.txt`, verify scripts |
| `docs/ops/auto-boot-shutdown.md` | Systemd services | `doc-audit-systemd.txt` |

#### 4f. Guides (2 files)
| File | What to Update | Data Source |
|------|---------------|-------------|
| `docs/guides/worker-node-setup.md` | Current Docker/OS versions, join command | `doc-audit-docker-version.txt`, `doc-audit-os.txt` |
| `docs/neue-services-einrichten.md` | Reference tables (existing services, ports, DB users) | `doc-audit-databases.txt`, `doc-audit-db-users.txt`, `doc-audit-ports.txt` |

#### 4g. Root Docs (3 files)
| File | What to Update | Data Source |
|------|---------------|-------------|
| `docs/index.md` | Services overview tables, quick links | All audit data |
| `docs/AI_CONTEXT.md` | Tech stack versions, key paths, quick reference | All audit data |
| `docs/MIGRATION-PLAN.md` | Mark as historical/completed (no update needed unless re-migration) | — |

- **Acceptance criteria**:
  - [ ] Every version number in every doc matches live server
  - [ ] Every service referenced actually exists
  - [ ] Every URL/port is correct
  - [ ] New services added since last update are documented
  - [ ] Removed services are cleaned out
  - [ ] Cross-references between docs are consistent

---

### Step 5: Update All 13 Project Mappings

- **Project**: Planner
- **Directory**: `/Users/gregor/dev/922/Planner/projects/`
- **Parallel with**: Step 4
- **Depends on**: Step 2 (codebase scan data)
- **Context files to read**:
  - `projects/_template.md` — required structure
  - `projects/*.md` — all 13 current mappings
  - Scan data from Step 2

**Per project, update these sections:**
1. **Overview**: Current description, any new features since last update
2. **Tech Stack**: Exact versions from `pyproject.toml` / `package.json`
3. **Key Files to Read**: Verify all paths still exist, add new important files
4. **Best Practices**: Review and update based on current code patterns
5. **Testing Strategy**: Update test counts, frameworks, coverage info
6. **Documentation**: Verify MkDocs/README status
7. **Pipeline & Deployment**: Update workflow names, deployment targets
8. **Dependencies**: Update inter-project dependencies

- **Acceptance criteria**:
  - [ ] All file paths in "Key Files to Read" sections are valid
  - [ ] Tech stack versions match actual `pyproject.toml` / `package.json`
  - [ ] Model/router/route counts are accurate
  - [ ] CI/CD workflow names match actual `.github/workflows/`
  - [ ] Dependencies reflect current reality

---

### Step 6: Update `registry.md` and `showcase.md`

- **Project**: Planner
- **Directory**: `/Users/gregor/dev/922/Planner`
- **Parallel with**: —
- **Depends on**: Steps 3, 4, 5
- **Context files to read**:
  - `registry.md` — current registry
  - `showcase.md` — current showcase
  - All updated `projects/*.md` from Step 5
  - Updated `server.md` from Step 3
- **Description**:
  1. **registry.md**: Update project statuses, add any new projects, update ecosystem graph, verify dependency matrix
  2. **showcase.md**: Update metrics, project descriptions, infrastructure stats, tech stack versions
- **Acceptance criteria**:
  - [ ] Every project in registry matches a `projects/<name>.md` file
  - [ ] Ecosystem graph reflects current dependencies
  - [ ] Showcase metrics are accurate (container count, endpoint count, etc.)

---

### Step 7: Update Planner Prompts and Templates

- **Project**: Planner
- **Directory**: `/Users/gregor/dev/922/Planner/prompts/`
- **Parallel with**: Step 6
- **Depends on**: Steps 3-5 (to know current ecosystem state)
- **Context files to read**:
  - `prompts/executor.md` — executor agent prompt
  - `prompts/planner.md` — planner agent prompt
  - `prompts/reviewer.md` — reviewer agent prompt
  - `plans/_template.md` — plan template
  - `projects/_template.md` — project template
  - `guides/new-service-setup.md` — new service guide
- **Description**: Review each prompt/template for outdated references, missing patterns, or new conventions that should be included. Update file references, tool names, and procedures.
- **Acceptance criteria**:
  - [ ] All file paths referenced in prompts are valid
  - [ ] Templates reflect current workflow
  - [ ] No references to removed tools or services

---

### Step 8: Cross-Reference Validation

- **Project**: Planner + HomeStructure
- **Directory**: Both repos
- **Parallel with**: —
- **Depends on**: Steps 3-7 (all updates complete)
- **Description**: Final validation pass across ALL updated docs:
  1. Every service mentioned in `server.md` has a matching entry in HomeStructure `docs/services/`
  2. Every project in `registry.md` has a `projects/<name>.md`
  3. Every public route in `server.md` matches `docs/config/cloudflare.md` and `docs/services/cloudflare-tunnel.md`
  4. Port numbers are consistent across all docs
  5. Version numbers are consistent across all docs
  6. No dead links between docs
  7. `docs/index.md` links to all current docs
- **Acceptance criteria**:
  - [ ] Zero inconsistencies between Planner docs and HomeStructure docs
  - [ ] Zero dead file references
  - [ ] All version numbers consistent across all 60+ files

---

### Step 9: Commit and Push All Changes

- **Project**: Planner, HomeStructure
- **Directory**: Both repos
- **Parallel with**: —
- **Depends on**: Step 8
- **Description**: Commit changes in both repos with descriptive messages.
  ```
  Planner:    "docs: full documentation overhaul — server scan 2026-03-27"
  HomeStructure: "docs: full documentation overhaul — live server data 2026-03-27"
  ```
- **Acceptance criteria**:
  - [ ] Both repos committed and pushed
  - [ ] Pipelines green (MkDocs rebuild for HomeStructure)

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Server scan via SSH             → Server @ ssh lab
  Step 2: Codebase scan (13 projects)     → All projects @ /Users/gregor/dev/922/

Wave 2 (parallel, after Wave 1):
  Step 3: Update server.md                → Planner @ /Users/gregor/dev/922/Planner
  Step 4: Update HomeStructure docs       → HomeStructure @ /Users/gregor/dev/922/HomeStructure/docs/
  Step 5: Update project mappings         → Planner @ /Users/gregor/dev/922/Planner/projects/

Wave 3 (parallel, after Wave 2):
  Step 6: Update registry + showcase      → Planner @ /Users/gregor/dev/922/Planner
  Step 7: Update prompts + templates      → Planner @ /Users/gregor/dev/922/Planner/prompts/

Wave 4 (after Wave 3):
  Step 8: Cross-reference validation      → Both repos

Wave 5 (after Wave 4):
  Step 9: Commit and push                 → Both repos
```

---

## Post-Execution Checklist
- [ ] All version numbers verified against live server
- [ ] All file paths verified against actual filesystem
- [ ] All cross-references consistent
- [ ] HomeStructure MkDocs pipeline green (docs rebuilt)
- [ ] No phantom services or dead references remain
- [ ] `execution/` audit files archived for future comparison

---

## Estimated Scope

| Category | Files to Update | Source |
|----------|-----------------|--------|
| Server reference | 1 | `server.md` |
| HomeStructure docs | ~43 | `docs/**/*.md` |
| Project mappings | 13 | `projects/*.md` |
| Registry + Showcase | 2 | `registry.md`, `showcase.md` |
| Prompts + Templates | 5 | `prompts/*.md`, `*/_template.md` |
| Guides | 2 | `guides/`, `neue-services-einrichten.md` |
| **Total** | **~66 files** | |
