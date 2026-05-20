# Plan: Docker Container Grouping & Domain Reachability Monitoring

- **Date**: 2026-03-24
- **Project(s)**: HomeCollector, HomeUI, HomeAPI, HomeAuth, HomeStructure, Anime-API, Anime-APP, Discord Bot, Portfolio, Studio, Sweatvalley Bingo
- **Goal**: Group Docker containers via custom labels and add a new "Domain Reachability" section to the Uptime page that verifies all public subdomains serve the correct content.

## Context

Read these files before proceeding:
- `projects/homeui.md` — HomeUI project mapping
- `projects/homeapi.md` — HomeAPI project mapping
- `server.md` — Server infrastructure, all services & public routes

## Part A: Docker Container Grouping via Labels

### Step 1: Add `922.group` Labels to All docker-compose.yaml Files

- **Project**: All projects (12 compose files)
- **Directory**: `/Users/gregor/dev/922/` (multiple subdirectories)
- **Parallel with**: Step 2
- **Description**: Add a `922.group` label to every service in every production docker-compose.yaml. This label defines the logical group a container belongs to in the monitoring dashboard.

**Label format**: `922.group=<GroupName>`

**Label mapping**:

| Compose File | Services | Label Value |
|---|---|---|
| `HomeAPI/docker-compose.yaml` | api, worker, beat, flower | `922.group=HomeAPI` |
| `HomeAuth/docker-compose.yaml` | api | `922.group=HomeAuth` |
| `HomeCollector/docker-compose.yaml` | api, worker, beat, flower | `922.group=HomeCollector` |
| `HomeUI/docker-compose.yaml` | homeui | `922.group=HomeUI` |
| `Anime-API/docker-compose.yaml` | api | `922.group=Anime` |
| `Anime-APP/docker-compose.yaml` | app | `922.group=Anime` |
| `discord/docker-compose.yaml` | bot | `922.group=Discord` |
| `portfolio/docker-compose.yaml` | portfolio | `922.group=Portfolio` |
| `studio/docker-compose.yaml` | studio | `922.group=Studio` |
| `HomeStructure/infra/docker-compose.yaml` | postgres, redis, postgres-exporter, redis-exporter | `922.group=Infrastructure` |
| `HomeStructure/traefik/docker-compose.yaml` | traefik | `922.group=Infrastructure` |
| `HomeStructure/core/docker-compose.yaml` | portainer | `922.group=Infrastructure` |
| `HomeStructure/monitoring/docker-compose.yaml` | prometheus, node-exporter, cadvisor, grafana, pushgateway | `922.group=Monitoring` |
| `HomeStructure/allure/docker-compose.yaml` | allure-api, allure-ui | `922.group=Testing` |
| `HomeAPI/docs-service/docker-compose.yaml` | homeapi-docs | `922.group=Docs` |
| `HomeCollector/docs-service/docker-compose.yaml` | home_collector_docs | `922.group=Docs` |
| `discord/docs-service/docker-compose.yaml` | discord_bot_docs | `922.group=Docs` |
| `HomeStructure/docs-service/docker-compose.yaml` | homelab-docs | `922.group=Docs` |
| `OpenClaw/docs-service/docker-compose.yaml` | openclaw-docs | `922.group=Docs` |

**Implementation**: For services that already have a `labels:` section (e.g. Traefik labels), append the new label. For services without labels, add a `labels:` section.

Example for a service WITHOUT existing labels:
```yaml
services:
  bot:
    ...
    labels:
      - "922.group=Discord"
```

Example for a service WITH existing labels:
```yaml
services:
  api:
    ...
    labels:
      - "traefik.enable=true"
      - ...existing traefik labels...
      - "922.group=HomeAPI"
```

- **Context files to read**:
  - Each project's `docker-compose.yaml` — to see existing label structure
- **Acceptance criteria**:
  - [ ] Every service in every production compose file has a `922.group` label
  - [ ] Existing labels (Traefik etc.) are preserved
  - [ ] CI compose files (`docker-compose.ci.yaml`) are NOT modified

### Step 2: Extend HomeCollector Docker Monitor to Read Group Labels

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: Step 1
- **Description**: Modify `docker_monitor.py` to read the `922.group` label from each container and include it in the returned data. Extend the `/api/monitoring/docker` endpoint to return the group field.

**Changes**:

1. **`app/services/docker_monitor.py`** — In `poll_docker_containers()`, read `info.get("Labels", {}).get("922.group", "Ungrouped")` and add `"group"` to each record dict.

2. **`app/routers/system.py`** (or wherever `/api/monitoring/docker` is defined) — Ensure the container response schema includes the `group` field. If the endpoint reads from Docker directly (not DB), the field flows through automatically.

3. **Response format change**:
```json
{
  "containers": [
    {
      "name": "home_api_api",
      "group": "HomeAPI",
      "status": "running",
      "cpu_percent": 2.5,
      "memory_bytes": 123456789,
      ...
    }
  ]
}
```

- **Context files to read**:
  - `app/services/docker_monitor.py` — current polling logic
  - `app/routers/system.py` — docker endpoint
  - `app/services/prometheus_service.py` — may also serve container data
- **Acceptance criteria**:
  - [ ] `poll_docker_containers()` returns `group` field per container
  - [ ] `/api/monitoring/docker` response includes `group` field
  - [ ] Containers without label get `group: "Other"`
  - [ ] Existing tests pass, new test covers group extraction

### Step 3: Update HomeUI ContainerGrid to Group by Label

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: —
- **Dependencies**: Step 2 (needs API to return group)
- **Description**: Update the `ContainerGrid` component to group containers by their `group` field instead of showing a flat sorted list.

**Changes**:

1. **`src/types/api/monitoring.ts`** — Add `group: string` to `ContainerMetricsSchema`.

2. **`src/features/dashboard/components/ContainerGrid.tsx`** — Group containers by `group` field. Render each group as a collapsible section with:
   - Group name as header
   - Container cards underneath in current card style
   - Groups sorted: project groups alphabetically, "Infrastructure" and "Monitoring" at the end, "Other" last

3. **Layout**: Each group shows its containers in the existing 4-column grid. Group header shows group name + count of running/total containers.

- **Context files to read**:
  - `src/features/dashboard/components/ContainerGrid.tsx` — current implementation
  - `src/features/dashboard/components/ContainerCard.tsx` — card component
  - `src/types/api/monitoring.ts` — types
- **Acceptance criteria**:
  - [ ] Containers are visually grouped by label
  - [ ] Group headers show name + running count
  - [ ] Groups are ordered logically (project groups first, infra/monitoring/other last)
  - [ ] Works on both OverviewPage and UptimePage

## Part B: Domain Reachability Monitoring

### Step 4: Add Domain Check Model & Config to HomeCollector

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: Step 1, Step 2
- **Description**: Create a new model for domain check configuration and results. Add domain check configs to the default seed data.

**New model `app/models/domain_check.py`**:
```python
class DomainConfig(Base):
    __tablename__ = "domain_configs"
    id: str (UUID, PK)
    domain: str (unique)          # "lab-api.922-studio.com"
    display_name: str             # "HomeAPI"
    check_path: str               # "/" or "/health"
    expected_status_code: int     # 200 (or 301 for redirects)
    content_match: str | None     # regex or substring to verify in response body
    follow_redirects: bool        # True for most, False for 922-studio.com redirect check
    enabled: bool
    check_interval_seconds: int   # default 300 (5 min)
    created_at: datetime

class DomainCheck(Base):
    __tablename__ = "domain_checks"
    id: str (UUID, PK)
    domain: str (indexed)
    status: str                   # "up" | "down" | "wrong_content"
    status_code: int | None
    response_time_ms: float | None
    content_matched: bool | None
    error_message: str | None     # for connection errors, SSL issues, etc.
    checked_at: datetime (indexed)
    created_at: datetime
```

**Default domain configs** (seeded on startup like `DEFAULT_MONITORED_SERVICES`):

| Domain | Path | Expected Status | Content Match | Follow Redirects |
|--------|------|-----------------|---------------|------------------|
| `922-studio.com` | `/` | 301 | — | `false` |
| `gregor.922-studio.com` | `/` | 200 | `Gregor` (or portfolio identifier) | `true` |
| `lab.922-studio.com` | `/` | 200 | `HomeUI` or `<title>` pattern | `true` |
| `auth.922-studio.com` | `/auth/health` | 200 | `"status"` | `true` |
| `lab-api.922-studio.com` | `/health` | 200 | `"status"` | `true` |
| `lab-collector.922-studio.com` | `/health` | 200 | `"status"` | `true` |
| `status.922-studio.com` | `/status` | 200 | `"status"` | `true` |
| `sweatvalley-bingo.922-studio.com` | `/` | 200 | `Sweatvalley` or app identifier | `true` |
| `anime-api.922-studio.com` | `/health` | 200 | `"status"` | `true` |
| `anime.922-studio.com` | `/` | 200 | `Anime` or app identifier | `true` |
| `studio.922-studio.com` | `/` | 200 | `922` or studio identifier | `true` |

> **Note for executor**: The exact `content_match` values need to be determined by hitting each URL and seeing what the response contains. Use strings that uniquely identify the correct service (e.g. a title tag, a JSON field, or a known text fragment).

- **Context files to read**:
  - `app/models/service_config.py` — existing model pattern
  - `app/models/uptime_check.py` — existing check pattern
  - `config.py` — `DEFAULT_MONITORED_SERVICES` pattern for seeding
  - `app/core/database.py` — Base class
- **Acceptance criteria**:
  - [ ] Alembic migration creates both tables
  - [ ] Default configs seeded on startup (upsert, no overwrite)
  - [ ] Model has all fields for domain, path, expected status, content match

### Step 5: Implement Domain Check Service & Celery Task

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: —
- **Dependencies**: Step 4
- **Description**: Create the service that performs domain checks and a Celery task that runs them on schedule.

**New service `app/services/domain_monitor.py`**:
```python
async def poll_domains(configs: list[DomainConfig]) -> list[dict]:
    """Hit each domain's public URL and verify status + content."""
```

Logic per domain:
1. Build URL: `https://{domain}{check_path}`
2. Make HTTP GET with `httpx.AsyncClient` (timeout 10s)
3. Set `follow_redirects` based on config
4. Check response status code matches `expected_status_code`
5. If `content_match` is set, check `content_match in response.text`
6. Determine status:
   - Connection error / timeout → `"down"`, store error message
   - Wrong status code → `"down"`
   - Status OK but content mismatch → `"wrong_content"`
   - All good → `"up"`
7. Record: `{ domain, status, status_code, response_time_ms, content_matched, error_message, checked_at }`

**New Celery task** in `app/tasks/domain_tasks.py`:
- Register as `poll-domain-checks` in beat schedule
- Schedule: every 300 seconds (5 min)
- Uses Redis lock to prevent overlap
- Loads enabled `DomainConfig` entries from DB
- Calls `poll_domains()`
- Bulk inserts results into `domain_checks` table
- Add pruning to existing prune task (same RETENTION_DAYS)

**CRUD** `app/crud/domain_check.py`:
- `bulk_create_domain_checks()` — batch insert
- `get_latest_domain_checks()` — latest check per domain
- `get_domain_check_history()` — history for heartbeat bars
- `prune_old_domain_checks()` — retention cleanup

- **Context files to read**:
  - `app/services/http_monitor.py` — existing HTTP check pattern
  - `app/tasks/uptime_tasks.py` — existing task pattern
  - `app/celery_app.py` — beat schedule registration
  - `app/crud/uptime_check.py` — existing CRUD pattern
- **Acceptance criteria**:
  - [ ] Domain checks hit actual `https://` URLs
  - [ ] Content verification works (substring match)
  - [ ] Status correctly set to `up`, `down`, or `wrong_content`
  - [ ] Error messages captured for debugging
  - [ ] Task runs every 5 minutes
  - [ ] Old checks pruned with existing retention policy
  - [ ] Tests cover: success case, wrong content, timeout, wrong status code

### Step 6: Add Domain Check API Endpoints

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: —
- **Dependencies**: Step 5
- **Description**: Expose domain check data through API endpoints for HomeUI consumption.

**New router `app/routers/domains.py`**:

1. **GET `/api/domains/status`** (auth required)
   - Returns latest check per domain, sorted by domain name
   - Response:
   ```json
   {
     "domains": [
       {
         "domain": "lab-api.922-studio.com",
         "display_name": "HomeAPI",
         "status": "up",
         "status_code": 200,
         "response_time_ms": 145.2,
         "content_matched": true,
         "last_checked": "2026-03-24T21:30:00"
       }
     ],
     "total": 11,
     "domains_up": 10,
     "domains_down": 1
   }
   ```

2. **GET `/api/domains/history/bulk?range=90d`** (auth required)
   - Returns per-day/per-hour uptime history per domain (same format as uptime history bulk)
   - Reuse the same aggregation logic as uptime history

3. **GET `/api/domains/configs`** (auth required)
   - List all domain configs (for admin/debug)

4. **POST `/api/domains/configs`** (auth required)
   - Add/update domain config

- **Context files to read**:
  - `app/routers/uptime.py` — existing endpoint patterns
  - `app/main.py` — router registration
- **Acceptance criteria**:
  - [ ] All endpoints require auth (JWT)
  - [ ] Status endpoint returns latest check per domain
  - [ ] History endpoint supports same range parameters as uptime
  - [ ] Router registered in `main.py`
  - [ ] Tests cover status and history endpoints

### Step 7: Add Domain Reachability Section to HomeUI Uptime Page

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: —
- **Dependencies**: Step 3, Step 6
- **Description**: Add a new "Domain Reachability" section on the Uptime page, positioned above the Docker container grid and below the existing service uptime section.

**Changes**:

1. **`src/api/domains.ts`** — New API client functions:
   - `getDomainStatus()` → `GET /api/domains/status`
   - `getDomainHistoryBulk(range)` → `GET /api/domains/history/bulk?range=`
   - Query options with 60s stale time, 120s refetch

2. **`src/types/api/domains.ts`** — New types:
   - `DomainStatusSchema` — single domain status
   - `DomainStatusResponseSchema` — response wrapper
   - `DomainHistorySchema` — history data

3. **`src/features/dashboard/components/DomainRow.tsx`** — New component:
   - Similar to `ServiceRow` but adapted for domains
   - Shows: domain URL, display name, status badge, HeartbeatBar
   - Status badges: "up" (green), "down" (red), "wrong content" (amber)
   - Reuses `HeartbeatBar` component for history visualization

4. **`src/features/dashboard/pages/UptimePage.tsx`** — Add new section:
   - Section header: "Domain Reachability" (same style as group headers)
   - Below existing service uptime groups
   - Above the container grid
   - Lists all domains with `DomainRow`
   - Shares the same time range filter as service uptime

**Page layout (top to bottom)**:
```
[Overall Status Banner]
[Time Range Filter: 1h | 7d | 30d | 90d]

── Pages ──
  ServiceRow: Portfolio
  ServiceRow: HomeUI
  ...

── Services ──
  ServiceRow: HomeAPI
  ...

── Infrastructure ──
  ServiceRow: PostgreSQL
  ...

── Domain Reachability ──        ← NEW
  DomainRow: 922-studio.com
  DomainRow: gregor.922-studio.com
  DomainRow: lab.922-studio.com
  ...

── Docker Containers ──
  [Grouped ContainerGrid]       ← UPDATED (from Step 3)
```

- **Context files to read**:
  - `src/features/dashboard/pages/UptimePage.tsx` — current page layout
  - `src/features/dashboard/components/ServiceRow.tsx` — row component to base DomainRow on
  - `src/features/dashboard/components/HeartbeatBar.tsx` — reusable visualization
  - `src/api/uptime.ts` — existing API pattern
- **Acceptance criteria**:
  - [ ] Domain Reachability section visible on Uptime page
  - [ ] Positioned above Docker containers, below service uptime
  - [ ] Each domain shows status, response time, heartbeat bar
  - [ ] "wrong_content" status clearly distinguishable from "down"
  - [ ] Shares time range filter with service uptime
  - [ ] Responsive layout

### Step 8: Deploy & Validate

- **Project**: All affected projects
- **Directory**: Server via `ssh lab`
- **Parallel with**: —
- **Dependencies**: All previous steps
- **Description**: Deploy all changes, redeploy containers to pick up new labels, verify everything works end-to-end.

**Deployment order**:
1. Push all projects with label changes (Step 1) — CI/CD deploys automatically
2. Push HomeCollector changes — migration runs on startup
3. Push HomeUI changes
4. Verify on server:
   - `docker inspect <container> | grep 922.group` — labels present
   - `curl http://localhost:8010/api/monitoring/docker` — group field in response
   - `curl http://localhost:8010/api/domains/status` — domain checks running
   - HomeUI Uptime page shows new sections

- **Context files to read**:
  - `server.md` — deployment commands
- **Acceptance criteria**:
  - [ ] All containers have `922.group` label after redeploy
  - [ ] Container grid on UI shows grouped containers
  - [ ] Domain checks running every 5 min
  - [ ] Domain Reachability section shows all 11 subdomains
  - [ ] All pipelines green

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Add 922.group labels to all docker-compose files → All projects
  Step 2: Extend docker monitor to read group labels → HomeCollector @ /Users/gregor/dev/922/HomeCollector
  Step 4: Add domain check models & seed config → HomeCollector @ /Users/gregor/dev/922/HomeCollector

Wave 2 (after wave 1):
  Step 3: Update ContainerGrid to group by label → HomeUI @ /Users/gregor/dev/922/HomeUI
  Step 5: Implement domain check service & Celery task → HomeCollector @ /Users/gregor/dev/922/HomeCollector

Wave 3 (after wave 2):
  Step 6: Add domain check API endpoints → HomeCollector @ /Users/gregor/dev/922/HomeCollector

Wave 4 (after wave 3):
  Step 7: Add Domain Reachability section to Uptime page → HomeUI @ /Users/gregor/dev/922/HomeUI

Wave 5 (after wave 4):
  Step 8: Deploy & validate all changes → Server (ssh lab)
```

## Post-Execution Checklist
- [ ] All tests pass (HomeCollector + HomeUI)
- [ ] Documentation updated (HomeCollector docs if endpoint docs exist)
- [ ] All pipelines green
- [ ] HomeCollector added to HomeAPI versioning endpoint (if new endpoints added)
- [ ] Changes reviewed against best practices in project mappings
