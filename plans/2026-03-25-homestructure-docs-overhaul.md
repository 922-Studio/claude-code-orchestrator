# Plan: HomeStructure Docs Overhaul — Align with Reality

- **Date**: 2026-03-25
- **Project(s)**: HomeStructure
- **Goal**: Update all HomeStructure documentation to reflect the actual server state, fix architecture graphics, and create a dedicated Traefik visualization page.

## Context

Read these files before proceeding:
- `projects/homestructure.md` — project mapping
- `server.md` — current server reference (Planner repo)
- `HomeStructure/docs/project-info/architecture.md` — current architecture page
- `HomeStructure/docs/services/traefik.md` — current Traefik docs
- `HomeStructure/docs/index.md` — docs homepage
- `HomeStructure/mkdocs.yml` — nav structure

## Audit Results (2026-03-25)

### Documented but NO LONGER running
| Service | Where documented | Status |
|---------|-----------------|--------|
| Obsidian CouchDB (:5984) | architecture.md, index.md | **REMOVED** — no container running |
| "Landing Page" (:8010) | architecture.md, server.md | **REMOVED** — replaced by Studio; port 8010 is HomeCollector |

### Running but NOT documented in architecture.md
| Service | Container(s) | Port(s) |
|---------|-------------|---------|
| HomeAuth | `homeauth`, `dev_homeauth` | 8100 (prod), 8200 (dev) |
| HomeCollector (full) | `home_collector_api/worker/beat`, `homecollector_flower` | 8010 (prod), 8110 (dev), 5556 (flower) |
| Drafter | `drafter`, `drafter_dev`, `drafter_pr_*` | 3000 (internal) |
| Anime-API | `anime_api` | 8020 |
| Anime-APP | `anime_app` | 8021 |
| Studio | `studio` | 3000 (internal) |
| Docker Registry | `docker_registry` | 5000 (internal) |
| Pushgateway | `pushgateway` | 9091 |
| Dev Postgres | `dev_postgres` | 5433 |
| Dev Redis | `dev_redis` | 6380 |
| HomeCollector Docs | `homecollector_docs` | 8013 |
| Flower (HomeAPI) | `home_api_flower` / `dev_home_api_flower` | 5555 / 5655 |
| Flower (Collector) | `homecollector_flower` / `dev_homecollector_flower` | 5556 / 5656 |

### Graphics issue
The ASCII art on `http://home-lab:8002/project-info/architecture/` has misaligned right-side box borders. The inner box widths are inconsistent — some close at different column positions. All boxes must be the same width with aligned right borders.

## Steps

### Step 1: Fix architecture.md — Rewrite with correct services and aligned graphics
- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure`
- **Parallel with**: Step 2
- **Description**:
  Rewrite `docs/project-info/architecture.md` completely:
  1. **Fix all ASCII art boxes** — ensure every box within the same nesting level has identical width, with right-side borders (`│` and `┘`) aligned in the same column. Count characters carefully.
  2. **Remove** Obsidian CouchDB and Landing Page from all diagrams and tables.
  3. **Add** all missing services: HomeAuth, HomeCollector (full stack), Drafter, Anime-API, Anime-APP, Studio, Docker Registry, Pushgateway, dev environment.
  4. **Update the Service Ports table** to reflect reality (see audit above).
  5. **Update Docker Networks** section — add `infra` network (missing), remove `discord_bot_network` (doesn't exist as a named network).
  6. **Restructure service groups** in the diagram:
     - **Infrastructure**: Traefik, PostgreSQL, Redis, Dev Postgres, Dev Redis
     - **Core App Stack**: HomeAuth, HomeAPI (+ worker/beat/flower), HomeUI, HomeCollector (+ worker/beat/flower), Drafter
     - **Web Projects**: Portfolio, Studio, Anime-API, Anime-APP, Sweatvalley Bingo
     - **Monitoring**: Prometheus, Grafana, Pushgateway, Node Exporter, cAdvisor
     - **Utilities**: Portainer, Allure, Docker Registry, 5× MkDocs docs sites
     - **Systemd**: OpenClaw Gateway, Cloudflared, Syncthing, 4× GitHub Runners
  7. **Update Deployment Flow** to mention dev/prod split.
- **Context files to read**:
  - `HomeStructure/docs/project-info/architecture.md` — current content to rewrite
  - This plan file — audit results section for exact services/ports
- **Acceptance criteria**:
  - [ ] All ASCII art boxes within the same level have identical width (right borders align)
  - [ ] No references to Obsidian CouchDB or Landing Page
  - [ ] All 51 running containers (grouped by service) are represented
  - [ ] All systemd services (OpenClaw, Cloudflared, Syncthing, 4× Runners) listed
  - [ ] Port table matches `docker ps` output
  - [ ] Dev/prod environment represented in the diagram

### Step 2: Update index.md — Remove dead services, add missing ones
- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure`
- **Parallel with**: Step 1
- **Description**:
  Update `docs/index.md`:
  1. Remove Obsidian Sync row from "Other Services" table.
  2. Add missing services to the tables:
     - Anime-API, Anime-APP, Studio, Drafter (to "Other Services" or a new "Application Services" section)
     - Docker Registry
     - Pushgateway
     - HomeCollector Docs (:8013)
  3. Remove `obsidian-sync/` from Repository Structure.
  4. Add `registry/` to Repository Structure.
  5. Update "Key Technologies" if needed.
- **Context files to read**:
  - `HomeStructure/docs/index.md` — current content
  - This plan file — audit results
- **Acceptance criteria**:
  - [ ] No references to Obsidian Sync/CouchDB
  - [ ] All running services appear in the tables
  - [ ] Repository structure matches actual directories

### Step 3: Create dedicated Traefik visualization page
- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure`
- **Parallel with**: Step 1, Step 2
- **Description**:
  The existing `docs/services/traefik.md` already has excellent content including architecture diagram, routing patterns, middlewares, etc. The task is to enhance the visualization:
  1. Verify the existing Traefik docs are up to date (all routers from running containers are listed).
  2. Add a **request flow diagram** showing the full path for each access type:
     - Public request: Internet → Cloudflare → cloudflared → Traefik → [middleware?] → Container
     - Tailscale request: VPN → ufw → Traefik / direct port
     - Dev request: Same flow but with dev subdomains
  3. Add a **complete router table** extracted from the actual running Traefik config:
     ```bash
     ssh lab 'curl -s http://127.0.0.1:8082/api/http/routers | jq'
     ```
  4. Verify all services in the "proxy network" box match reality.
  5. Add dev environment routing (dev subdomains → dev containers).
  6. Ensure the existing Traefik page is already linked in mkdocs.yml nav (it is — at Services > Traefik).
- **Context files to read**:
  - `HomeStructure/docs/services/traefik.md` — current Traefik docs
  - `HomeStructure/traefik/docker-compose.yaml` — Traefik compose
  - `HomeStructure/traefik/dynamic/middleware.yaml` — middleware config
- **Acceptance criteria**:
  - [ ] All Traefik routers (prod + dev) documented
  - [ ] Request flow visualization for public, Tailscale, and dev access
  - [ ] Dev environment routing documented
  - [ ] No references to removed services

### Step 4: Clean up other docs pages referencing dead services
- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure`
- **Parallel with**: —
- **Depends on**: Steps 1-3
- **Description**:
  Search all docs for references to removed services and update:
  1. `grep -r "obsidian\|couchdb\|5984\|landing.page\|landingpage" docs/` — find and remove/update all references.
  2. Check `docs/config/cloudflare.md` — ensure tunnel ingress rules match reality.
  3. Check `docs/services/` — remove `obsidian-sync.md` if it exists, remove `landingpage.md` if it exists.
  4. Update `mkdocs.yml` nav to remove dead pages and add any new ones.
  5. Check `docs/neue-services-einrichten.md` for outdated examples.
- **Context files to read**:
  - `HomeStructure/mkdocs.yml` — nav structure
  - All files found by grep
- **Acceptance criteria**:
  - [ ] Zero references to Obsidian/CouchDB/landing page in the entire docs/ tree
  - [ ] mkdocs.yml nav has no broken links
  - [ ] No orphan .md files that are no longer in the nav

### Step 5: Update Planner server.md to match
- **Project**: Planner
- **Directory**: `/Users/gregor/dev/922/Planner`
- **Parallel with**: Step 4
- **Depends on**: Steps 1-3
- **Description**:
  Update `server.md` in the Planner repo to match the updated HomeStructure docs:
  1. Fix HomeCollector port: 8011 → 8010.
  2. Remove Landing Page references.
  3. Remove Obsidian CouchDB references.
  4. Add Pushgateway to monitoring table.
  5. Add HomeCollector Docs (:8013) to docs table.
  6. Add Flower instances to background workers table.
  7. Verify all port numbers match reality.
- **Context files to read**:
  - `server.md` — current Planner server reference
  - This plan file — audit results
- **Acceptance criteria**:
  - [ ] All ports match `docker ps` output
  - [ ] No references to removed services
  - [ ] All running services listed

### Step 6: Verify and commit
- **Project**: HomeStructure, Planner
- **Directory**: Both repos
- **Parallel with**: —
- **Depends on**: Steps 4, 5
- **Description**:
  1. Build/preview MkDocs locally or check the rendered pages after push.
  2. Verify ASCII art alignment renders correctly in the browser.
  3. Commit and push HomeStructure changes.
  4. Commit and push Planner changes.
  5. Monitor CI/CD pipeline for HomeStructure docs deployment.
  6. Verify `http://home-lab:8002/project-info/architecture/` renders correctly.
- **Acceptance criteria**:
  - [ ] Architecture page graphics aligned (right borders in straight line)
  - [ ] All links in the docs work
  - [ ] Pipeline green
  - [ ] Changes deployed to server

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Rewrite architecture.md (fix graphics + add all services) → HomeStructure @ /Users/gregor/dev/922/HomeStructure
  Step 2: Update index.md (remove dead, add missing services) → HomeStructure @ /Users/gregor/dev/922/HomeStructure
  Step 3: Enhance Traefik docs with complete routing visualization → HomeStructure @ /Users/gregor/dev/922/HomeStructure

Wave 2 (after wave 1):
  Step 4: Clean up all other docs referencing dead services → HomeStructure @ /Users/gregor/dev/922/HomeStructure
  Step 5: Update Planner server.md to match → Planner @ /Users/gregor/dev/922/Planner

Wave 3 (after wave 2):
  Step 6: Verify rendering, commit, push, monitor pipeline → Both repos
```

## Agent Prompts

All agents use **Sonnet** model unless otherwise specified.

### Agent Prompt — Step 1 (Architecture Rewrite)

> Read the plan at `/Users/gregor/dev/922/Planner/plans/2026-03-25-homestructure-docs-overhaul.md` (the "Audit Results" section and Step 1).
> Read `/Users/gregor/dev/922/HomeStructure/docs/project-info/architecture.md` for current content.
>
> Rewrite `architecture.md` completely following the step instructions. CRITICAL: For ASCII art, ensure every box at the same nesting level has the exact same character width. Right-side borders (`│`, `┘`, `┐`) must all appear in the same column. Count characters manually. Test by checking that every line between a `┌` and `┐` (or `└` and `┘`) is the same length.
>
> Use the audit results from the plan for the complete list of services and ports. Do NOT include Obsidian CouchDB or Landing Page.

### Agent Prompt — Step 2 (Index Update)

> Read the plan at `/Users/gregor/dev/922/Planner/plans/2026-03-25-homestructure-docs-overhaul.md` (Step 2).
> Read `/Users/gregor/dev/922/HomeStructure/docs/index.md`.
>
> Update `index.md` following the step instructions. Remove Obsidian, add all missing services from the audit.

### Agent Prompt — Step 3 (Traefik Visualization)

> Read the plan at `/Users/gregor/dev/922/Planner/plans/2026-03-25-homestructure-docs-overhaul.md` (Step 3).
> Read `/Users/gregor/dev/922/HomeStructure/docs/services/traefik.md`.
> Run `ssh lab 'curl -s http://127.0.0.1:8082/api/http/routers | jq ".[].name"'` to get all actual Traefik routers.
>
> Enhance the Traefik page with request flow diagrams and a complete router table from the live config. Add dev environment routing.

### Agent Prompt — Step 4 (Cleanup)

> Read the plan at `/Users/gregor/dev/922/Planner/plans/2026-03-25-homestructure-docs-overhaul.md` (Step 4).
> Run `grep -r "obsidian\|couchdb\|5984\|landing.page\|landingpage" /Users/gregor/dev/922/HomeStructure/docs/`.
> Clean up all references to removed services. Check and update `mkdocs.yml` nav.

### Agent Prompt — Step 5 (Planner server.md)

> Read the plan at `/Users/gregor/dev/922/Planner/plans/2026-03-25-homestructure-docs-overhaul.md` (Step 5 and "Audit Results").
> Read `/Users/gregor/dev/922/Planner/server.md`.
>
> Update `server.md` following the step instructions. Fix ports, remove dead services, add missing services.

## Post-Execution Checklist
- [x] Architecture page ASCII art renders with aligned right borders — **Done 2026-03-25**
- [x] All 51 running containers represented in docs — **Done 2026-03-25**
- [x] All 7 systemd services documented (OpenClaw, Cloudflared, Syncthing, 4× Runners) — **Done 2026-03-25**
- [x] Zero references to Obsidian CouchDB or Landing Page across all docs (historical notes in MIGRATION-PLAN.md and syncthing.md kept intentionally) — **Done 2026-03-25**
- [x] Pipeline green for HomeStructure — **Pushed 2026-03-25** (commit 6556b1b)
- [ ] `http://home-lab:8002/project-info/architecture/` verified in browser — **Pending deploy**
