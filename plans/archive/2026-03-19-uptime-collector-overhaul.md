# Plan: Own Uptime Service & Data Collection Migration

- **Date**: 2026-03-19
- **Status**: DONE (2026-03-19)
- **Project(s)**: HomeCollector, HomeAPI, HomeUI, HomeStructure
- **Goal**: Replace Uptime Kuma with a fully self-owned uptime monitoring system, fix broken data collection in HomeCollector, monitor all critical services, and migrate all data-collection responsibilities from HomeAPI to HomeCollector.

## Investigation Findings

### Root Cause: Why Only HomeAPI Shows Up

The uptime page is empty/limited because of **two independent bugs**:

1. **No ServiceConfigs registered.** `poll_docker_containers()` polls ALL Docker containers every 60s and stores data in `uptime_checks`. But `GET /api/uptime/status` filters to only services registered in the `service_configs` table (where `enabled=true`). Only HomeAPI was ever manually registered via `POST /api/uptime/services`. All other container data exists in the DB but is invisible to the API.

2. **HeartbeatBar never receives data.** In `UptimePage.tsx` line 166, heartbeat data is hardcoded to `[]`:
   ```tsx
   <ServiceRow service={service} heartbeatData={[]} range={range} />
   ```
   The `useUptimeHistory` hook exists and works, but is never called or wired into the page. Every service shows an all-gray heartbeat bar.

### What HomeAPI Currently Does That Should Move

HomeAPI's `/api/monitoring/*` router contains **15+ endpoints** across 3 services that are pure data collection — not HomeAPI's core domain:

| Service | What it collects | Source |
|---------|-----------------|--------|
| `GitHubService` | Workflow runs, runners, stats, analytics across 7 repos | GitHub API |
| `AllureService` | Test results, coverage, history across 7 projects | Allure Docker Service API |
| `PrometheusService` | System metrics, container metrics, coverage history | Prometheus + Docker socket |
| System check tasks | Disk usage, pending todos, system updates | Local system + DB |
| OpenClaw tasks | Daily briefing, health check, usage overview | OpenClaw webhook |
| GSheets sync | All DB tables → Google Sheets | Google Sheets API |
| Email/Discord alerts | Health alerts, sleep reminders, morning emails | Gmail + Discord API |

### Services That Need Uptime Monitoring

| Service | Docker Container | Type |
|---------|-----------------|------|
| HomeAPI | `home_api_api` | Core |
| HomeAuth | HomeAuth container | Core |
| HomeUI | `homeui` | Core |
| HomeCollector | `home_collector_api` | Core |
| Discord Bot | `discord_bot` | App |
| Portfolio | host process (port 3922) | App |
| Sweatvalley Bingo | `sweatvalley-bingo` | App |
| PostgreSQL (HomeAPI) | `home_api_db` | Infrastructure |
| PostgreSQL (Discord) | `discord_bot_db` | Infrastructure |
| PostgreSQL (Collector) | `home_collector_db` | Infrastructure |
| Redis (shared) | `shared_redis` | Infrastructure |
| Caddy | `caddy` | Infrastructure |
| Prometheus | `prometheus` | Infrastructure |
| Grafana | `grafana` | Infrastructure |

---

## Steps

### Step 1: Seed ServiceConfigs for All Critical Services

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: Step 2
- **Description**: Create a seed script or Alembic data migration that populates `service_configs` with all critical services. Add a startup auto-sync mechanism: on app boot, read a `MONITORED_SERVICES` config (list of container names + display names + groups) and upsert into `service_configs`. This ensures new deployments always have the right services configured without manual POST calls.
- **Context files to read**:
  - `app/models/service_config.py` — ServiceConfig model
  - `app/crud/service_config.py` — existing CRUD operations
  - `config.py` — environment variables
  - `app/main.py` — lifespan events (startup hook)
- **Implementation details**:
  - Add `MONITORED_SERVICES` to `config.py` as a JSON env var or hardcoded default list
  - Add `upsert_service_configs()` to `app/crud/service_config.py`
  - Call it in FastAPI lifespan startup event
  - Services to seed (grouped):
    - **Core Services**: HomeAPI (`home_api_api`), HomeAuth, HomeUI (`homeui`), HomeCollector (`home_collector_api`)
    - **Apps**: Discord Bot (`discord_bot`), Portfolio (needs HTTP check — port 3922), Sweatvalley Bingo (`sweatvalley-bingo`)
    - **Infrastructure**: PostgreSQL HomeAPI (`home_api_db`), PostgreSQL Discord (`discord_bot_db`), PostgreSQL Collector (`home_collector_db`), Redis (`shared_redis`), Caddy (`caddy`), Prometheus (`prometheus`), Grafana (`grafana`)
- **Acceptance criteria**:
  - [ ] All 14+ services seeded on startup
  - [ ] Idempotent — running twice doesn't create duplicates
  - [ ] Existing manual configs preserved (upsert, not replace)
  - [ ] Tests cover the seeding logic

### Step 2: Wire HeartbeatBar Data in Frontend

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 1
- **Description**: Fix the hardcoded empty heartbeat data. For each service displayed, call `useUptimeHistory(range, service.service_name)` and pass the result to `ServiceRow`. The hook, component, and API endpoint all exist — they just need to be connected.
- **Context files to read**:
  - `src/features/dashboard/pages/UptimePage.tsx` — main page (the bug is here, line 166)
  - `src/features/dashboard/hooks/useUptimeHistory.ts` — the unused hook
  - `src/features/dashboard/components/ServiceRow.tsx` — receives heartbeatData prop
  - `src/features/dashboard/components/HeartbeatBar.tsx` — renders the visualization
  - `src/api/uptime.ts` — API client functions
  - `src/types/api/uptime.ts` — Zod schemas
- **Implementation details**:
  - Option A (simple): Fetch all histories in UptimePage, pass down. Risk: N+1 API calls.
  - Option B (better): Add a `GET /api/uptime/history/bulk` endpoint to HomeCollector that returns history for all enabled services in one call. Frontend fetches once.
  - Recommendation: Start with Option A (works immediately), add bulk endpoint in Step 5.
- **Acceptance criteria**:
  - [ ] HeartbeatBar shows green/amber/red segments based on real data
  - [ ] Range selector (7d/30d/90d) updates heartbeat display
  - [ ] Tests updated to pass real history data
  - [ ] Loading states handled gracefully

### Step 2b: Fix Dashboard Chart Max Capacities

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 2
- **Description**: The Performance and Usage dashboard pages show RAM, disk, and memory charts without proper Y-axis max values. Charts auto-scale to the data range instead of showing the full server capacity, making it misleading (e.g., RAM appears full when it's using 6/32 GB). Fix all three charts to use the actual server max as the Y-axis domain, and display the max capacity in the chart legend/label.
- **Context files to read**:
  - `src/features/dashboard/pages/SystemPerformancePage.tsx` — RAM chart (line ~274) and Disk chart (line ~321) both missing `domain` on YAxis
  - `src/features/dashboard/pages/UsagePage.tsx` — Memory chart (line ~275) missing `domain` on YAxis, legend missing total capacity
  - `src/features/dashboard/components/DiskChart.tsx` — reference implementation that correctly uses `domain={[0, totalGB || 'auto']}` (line 203)
- **Implementation details**:
  - **RAM chart** (SystemPerformancePage): The data already includes `total` (from `history.ram_total[i]?.value / 1e9`). Set `domain={[0, maxRamGB]}` on the YAxis where `maxRamGB` is derived from the first `ram_total` data point. Add a ReferenceLine or label showing "XX GB total".
  - **Disk chart** (SystemPerformancePage): Data includes `total` (from `p.total_bytes / 1e9`). Set `domain={[0, maxDiskGB]}`. Add total capacity to legend.
  - **Memory chart** (UsagePage): Set `domain={[0, maxRamGB]}` for the stacked RAM + Swap area chart. Show total RAM + total Swap in the legend.
  - Follow the pattern from `DiskChart.tsx` which already does this correctly.
- **Acceptance criteria**:
  - [ ] RAM chart Y-axis goes from 0 to actual server RAM (not auto-scaled)
  - [ ] Disk chart Y-axis goes from 0 to actual disk capacity
  - [ ] Memory chart Y-axis goes from 0 to actual RAM capacity
  - [ ] Max capacity shown in chart legend or as reference line
  - [ ] Tests updated

### Step 3: Add HTTP Health Check Monitoring (Beyond Docker Socket)

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: —
- **Depends on**: Step 1
- **Description**: Docker socket monitoring only tells you if a container is running, not if the service inside is healthy. Add HTTP health check polling alongside Docker monitoring. For each service with a `health_url` in its ServiceConfig, make an HTTP GET and record response time + status code. This enables monitoring Portfolio (host process, not Docker) and catching "container running but app crashed" scenarios.
- **Context files to read**:
  - `app/models/service_config.py` — add `health_url` and `expected_status_code` fields
  - `app/services/docker_monitor.py` — current Docker-only monitoring
  - `app/tasks/uptime_tasks.py` — Celery task that orchestrates polling
  - `app/schemas/uptime.py` — response schemas
- **Implementation details**:
  - Add to `ServiceConfig` model: `health_url` (nullable string), `expected_status_code` (int, default 200), `monitor_type` enum (`docker`, `http`, `both`)
  - Create `app/services/http_monitor.py` with `poll_http_services()`:
    - For each config with a health_url: `GET health_url`, measure response_time_ms
    - Status: "up" if status_code matches expected, "down" otherwise, "degraded" if slow (>5s)
  - Alembic migration to add new columns
  - Update Celery task to run both Docker + HTTP polling
  - Health URLs:
    - HomeAPI: `http://home_api_api:8080/health/ready`
    - HomeAuth: `http://homeauth-api:8100/health/ready`
    - HomeUI: `http://homeui:8000/` (or nginx health)
    - HomeCollector: `http://localhost:8010/health/ready` (self-check)
    - Portfolio: `http://home-lab:3922/` (host process)
    - Sweatvalley Bingo: `http://sweatvalley-bingo:3923/`
    - Discord Bot: Docker-only (no HTTP endpoint)
    - Databases/Redis: Docker-only
- **Acceptance criteria**:
  - [ ] HTTP health checks run alongside Docker checks
  - [ ] response_time_ms populated for HTTP-monitored services
  - [ ] Portfolio (host process) monitored via HTTP
  - [ ] "degraded" status when response > 5s
  - [ ] Alembic migration clean
  - [ ] Tests for HTTP monitor service

### Step 4: Add Bulk History Endpoint & Public Status Page API

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: —
- **Depends on**: Step 3
- **Description**: Add efficient bulk endpoints and a public (no-auth) status page API to replace Uptime Kuma's public status page.
- **Context files to read**:
  - `app/routers/uptime.py` — existing endpoints
  - `app/crud/uptime_check.py` — existing queries
  - `app/auth.py` — auth middleware (need to exempt status page routes)
- **Implementation details**:
  - `GET /api/uptime/history/bulk?range=90d` — returns history for ALL enabled services in one response. Eliminates N+1 from frontend.
  - `GET /status` (no auth) — public status page JSON:
    - Current status of all enabled services (up/down/degraded)
    - Overall uptime % (90d)
    - Per-service uptime % (90d)
    - Last incident timestamps
  - Add `/status` to auth exemption list in middleware
  - Update HomeUI to use bulk endpoint
- **Acceptance criteria**:
  - [ ] Bulk history returns all services in one call
  - [ ] `/status` accessible without authentication
  - [ ] Response matches what Uptime Kuma's status page provided
  - [ ] Tests for both endpoints

### Step 5: Migrate GitHub Data Collection to HomeCollector

- **Project**: HomeCollector, HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeCollector`, `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: Step 6
- **Depends on**: Step 4
- **Description**: Move GitHub Actions monitoring from HomeAPI to HomeCollector. This is the first data-collection migration.
- **Context files to read**:
  - HomeAPI `app/services/github_service.py` — full GitHub service (source)
  - HomeAPI `app/schemas/monitoring.py` — GitHub-related schemas (source)
  - HomeAPI `app/routers/monitoring.py` — GitHub endpoints (source)
  - HomeAPI `config.py` — GITHUB_TOKEN, GITHUB_ORG vars
  - HomeCollector `CLAUDE.md` — architecture conventions
- **Implementation details**:
  - Copy to HomeCollector:
    - `app/services/github_service.py`
    - GitHub-related schemas → `app/schemas/github.py`
    - GitHub endpoints → `app/routers/github.py`
  - Add env vars: `GITHUB_TOKEN`, `GITHUB_ORG` to HomeCollector config
  - Register router in `app/main.py`
  - Add optional Celery task for periodic GitHub data caching (avoid rate limits)
  - In HomeAPI: Keep endpoints temporarily as proxies to HomeCollector (backwards compat for any direct consumers), or remove if HomeUI is the only consumer
  - Update HomeUI API calls to point to HomeCollector base URL for GitHub endpoints
- **Acceptance criteria**:
  - [ ] All 6 GitHub endpoints functional on HomeCollector
  - [ ] GitHub data identical to what HomeAPI served
  - [ ] HomeAPI GitHub endpoints removed or proxied
  - [ ] HomeUI updated to call HomeCollector
  - [ ] Tests migrated and passing
  - [ ] Pipeline green on both projects

### Step 6: Migrate Allure Data Collection to HomeCollector

- **Project**: HomeCollector, HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeCollector`, `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: Step 5
- **Depends on**: Step 4
- **Description**: Move Allure test results collection from HomeAPI to HomeCollector.
- **Context files to read**:
  - HomeAPI `app/services/allure_service.py` — full Allure service (source)
  - HomeAPI `app/schemas/monitoring.py` — Allure-related schemas (source)
  - HomeAPI `app/routers/monitoring.py` — Allure endpoints (source)
  - HomeAPI `config.py` — ALLURE_URL var
- **Implementation details**:
  - Copy to HomeCollector:
    - `app/services/allure_service.py`
    - Allure-related schemas → `app/schemas/allure.py`
    - Allure endpoints → `app/routers/allure.py`
  - Add env var: `ALLURE_URL` to HomeCollector config
  - Register router in `app/main.py`
  - Remove from HomeAPI
  - Update HomeUI API calls
- **Acceptance criteria**:
  - [ ] All 3 Allure endpoints functional on HomeCollector
  - [ ] Data identical to HomeAPI's output
  - [ ] HomeAPI Allure endpoints removed
  - [ ] HomeUI updated
  - [ ] Tests migrated and passing

### Step 7: Migrate Prometheus/System Metrics to HomeCollector

- **Project**: HomeCollector, HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeCollector`, `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: —
- **Depends on**: Steps 5, 6
- **Description**: Move Prometheus system metrics, container metrics, and coverage history from HomeAPI to HomeCollector. This is the largest migration piece.
- **Context files to read**:
  - HomeAPI `app/services/prometheus_service.py` — full Prometheus service (source)
  - HomeAPI `app/schemas/monitoring.py` — system/container/coverage schemas (source)
  - HomeAPI `app/routers/monitoring.py` — system/docker/usage/coverage/overview endpoints (source)
  - HomeAPI `config.py` — PROMETHEUS_URL var
- **Implementation details**:
  - Copy to HomeCollector:
    - `app/services/prometheus_service.py`
    - All system/container/coverage schemas → `app/schemas/system.py`
    - System endpoints → `app/routers/system.py`
  - Add env var: `PROMETHEUS_URL` to HomeCollector config
  - Mount Docker socket in HomeCollector container (already done for uptime monitoring)
  - Migrate the `GET /api/monitoring/overview` aggregation endpoint (it combines all data sources — now all live in Collector)
  - Remove entire `monitoring.py` router from HomeAPI
  - Update HomeUI to point all monitoring API calls to HomeCollector
- **Acceptance criteria**:
  - [ ] All system/docker/usage/coverage endpoints functional
  - [ ] Dashboard overview endpoint returns combined data
  - [ ] HomeAPI `monitoring.py` router fully removed
  - [ ] HomeAPI `services/github_service.py`, `services/allure_service.py`, `services/prometheus_service.py` removed
  - [ ] HomeUI fully migrated to HomeCollector for all monitoring
  - [ ] Tests migrated and passing
  - [ ] Pipeline green on all three projects

### Step 8: Migrate Background Tasks to HomeCollector

- **Project**: HomeCollector, HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeCollector`, `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: —
- **Depends on**: Step 7
- **Description**: Move data-collection Celery tasks from HomeAPI to HomeCollector. These are background jobs that collect/push data but don't serve HomeAPI's core domain.
- **Context files to read**:
  - HomeAPI `app/tasks/system_check_tasks.py` — disk, todos, updates
  - HomeAPI `app/tasks/openclaw_tasks.py` — OpenClaw triggers
  - HomeAPI `app/tasks/email_tasks.py` — health alerts, morning emails
  - HomeAPI `app/tasks/sleep_reminder_tasks.py` — sleep reminder
  - HomeAPI `app/celery_app.py` — beat schedule
  - HomeCollector `app/celery_app.py` — existing beat schedule
- **Implementation details**:
  - Migrate tasks one by one, updating the Celery beat schedule in HomeCollector
  - Tasks that need HomeAPI DB access (e.g., `check_pending_todos`) should call HomeAPI's REST API instead of direct DB access
  - GSheets sync (`gsheets_tasks.py`) stays in HomeAPI — it syncs HomeAPI's own data
  - `scheduled_task_tasks.py` stays in HomeAPI — it processes HomeAPI's scheduled tasks table
  - Add required env vars: `DISCORD_*`, `GMAIL_*`, `OPENCLAW_*` to HomeCollector
- **Acceptance criteria**:
  - [ ] System check tasks running from HomeCollector
  - [ ] OpenClaw triggers running from HomeCollector
  - [ ] Email/Discord alert tasks running from HomeCollector
  - [ ] Sleep reminder running from HomeCollector
  - [ ] Removed tasks from HomeAPI beat schedule
  - [ ] HomeAPI slimmed down to only its core domain tasks (gsheets, scheduled_tasks)
  - [ ] Tests migrated

### Step 9: Remove Uptime Kuma

- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure`
- **Parallel with**: —
- **Depends on**: Steps 4, 8 (everything else working first)
- **Description**: Remove Uptime Kuma from the infrastructure. Update Cloudflare tunnel to point `status.922-studio.com` to the new public status page.
- **Context files to read**:
  - `HomeStructure/docs/services/uptime-kuma.md` (if exists)
  - `HomeStructure/docker-compose*.yaml` — find Uptime Kuma service
  - `HomeStructure/docs/config/cloudflare.md` — tunnel routes
  - `server.md` — port reference (3001)
- **Implementation details**:
  - Remove `uptime-kuma` service from Docker Compose
  - Update Cloudflare tunnel: `status.922-studio.com` → HomeCollector's `/status` endpoint (port 8011 via Caddy)
  - Remove from `monitor-net` network config
  - Update `server.md` in Planner repo
  - Update HomeStructure docs
  - Optional: Build a minimal static HTML status page served by HomeCollector at `/status` (rendered server-side) or redirect to HomeUI's uptime page
  - **Network fix (flagged in Step 7)**: HomeCollector is on `proxy` + `infra` networks but Prometheus is on `monitor-net`. To make `PROMETHEUS_URL=http://prometheus:9090` work, either add `monitor-net` to HomeCollector's service in `docker-compose.yaml`, or add the HomeCollector container to `monitor-net` in HomeStructure. Must be resolved here so `/api/monitoring/system` and related endpoints are functional post-migration.
- **Acceptance criteria**:
  - [ ] Uptime Kuma container stopped and removed
  - [ ] `status.922-studio.com` serves the new status page
  - [ ] No references to Uptime Kuma in infrastructure
  - [ ] `server.md` updated
  - [ ] Documentation updated

### Step 10: Final Cleanup & Documentation

- **Project**: All
- **Directory**: All project directories
- **Parallel with**: —
- **Depends on**: Step 9
- **Description**: Clean up dead code, update documentation, verify everything works end-to-end.
- **Context files to read**:
  - All project CLAUDE.md files
  - `projects/homecollector.md` — update mapping
  - `projects/homeapi.md` — update mapping
  - `registry.md` — update dependencies
- **Implementation details**:
  - HomeAPI: Remove dead imports, unused schemas, empty monitoring module
  - HomeCollector: Update CLAUDE.md, README, docs to reflect expanded scope
  - HomeUI: Clean up any dual-endpoint configs
  - Planner: Update `projects/homecollector.md` with new scope (data collection hub, not just uptime)
  - Planner: Update `projects/homeapi.md` to remove monitoring references
  - Planner: Update `registry.md` dependency graph
  - Planner: Update `server.md` to remove Uptime Kuma, update HomeCollector description
- **Acceptance criteria**:
  - [ ] No dead code in any project
  - [ ] All project mappings accurate
  - [ ] All pipelines green
  - [ ] End-to-end test: uptime page shows all services with heartbeat history
  - [ ] End-to-end test: monitoring dashboard shows GitHub, Allure, system metrics from HomeCollector
  - [ ] End-to-end test: `status.922-studio.com` shows public status page

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1:  Seed ServiceConfigs for all services     → HomeCollector @ /Users/gregor/dev/922/HomeCollector
  Step 2:  Wire HeartbeatBar data in frontend       → HomeUI @ /Users/gregor/dev/922/HomeUI
  Step 2b: Fix chart max capacities (RAM/disk/mem)  → HomeUI @ /Users/gregor/dev/922/HomeUI

Wave 2 (after wave 1):
  Step 3: Add HTTP health check monitoring          → HomeCollector @ /Users/gregor/dev/922/HomeCollector

Wave 3 (after wave 2):
  Step 4: Bulk history endpoint + public status API → HomeCollector @ /Users/gregor/dev/922/HomeCollector

Wave 4 (parallel):
  Step 5: Migrate GitHub data collection            → HomeCollector + HomeAPI
  Step 6: Migrate Allure data collection            → HomeCollector + HomeAPI

Wave 5 (after wave 4):
  Step 7: Migrate Prometheus/system metrics         → HomeCollector + HomeAPI

Wave 6 (after wave 5):
  Step 8: Migrate background tasks                  → HomeCollector + HomeAPI

Wave 7 (after wave 6):
  Step 9: Remove Uptime Kuma                        → HomeStructure

Wave 8 (after wave 7):
  Step 10: Final cleanup & documentation            → All projects
```

## Post-Execution Checklist
- [ ] All tests pass (HomeCollector, HomeAPI, HomeUI)
- [ ] Documentation updated (CLAUDE.md, README, project mappings, server.md)
- [ ] All pipelines green
- [ ] Changes reviewed against best practices in each project mapping
- [ ] Uptime Kuma fully decommissioned
- [ ] `status.922-studio.com` operational
- [ ] HomeCollector is the single source of truth for all monitoring & data collection
