# Plan: Fix Uptime Collection — Container Names, HTTP Checks, Event Loop

- **Date**: 2026-03-19
- **Status**: DONE (2026-03-19)
- **Project(s)**: HomeCollector
- **Goal**: Fix broken uptime monitoring caused by container name mismatches, unreachable HTTP health URLs, and Celery event loop conflicts.
- **Parent plan**: `2026-03-19-uptime-collector-overhaul.md`

## Root Cause Analysis

### Issue 1: Container Name Mismatches in DEFAULT_MONITORED_SERVICES
The `config.py` references container names that don't exist or have changed:
- `homeauth-api` → actual container is `homeauth`
- `caddy` → Caddy was removed, reverse proxy is `traefik`
- `home_api_db`, `discord_bot_db`, `home_collector_db` → all consolidated into `shared_postgres`

### Issue 2: HTTP Health Checks Unreachable from Worker
The Celery worker runs on `infra` network only. HTTP health checks fail for:
- Services on `proxy` network (homeui, homeauth, portfolio)
- Services on `monitor-net` (grafana, prometheus)
- `localhost:8010` → resolves to the worker container, not the API
- `home-lab:3922` → hostname doesn't resolve inside Docker

When `monitor_type="both"`, the merge logic prefers HTTP status over Docker status. Failed HTTP = "down", even though Docker reports the container as running.

### Issue 3: Celery Event Loop Conflicts
Task takes ~61s to complete (Docker stats collection is slow for 33 containers). Beat fires every 60s, so tasks overlap. New tasks in same worker process get a different event loop, causing:
```
RuntimeError: Event loop is closed
Task got Future attached to a different loop
```

## Steps

### Step 1: Fix Container Names & Health URLs in config.py

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Context files to read**:
  - `config.py` — `DEFAULT_MONITORED_SERVICES` list
  - `/Users/gregor/dev/922/Planner/server.md` — updated container names

**Changes to `DEFAULT_MONITORED_SERVICES`**:

| Old service_name | New service_name | Reason |
|---|---|---|
| `homeauth-api` | `homeauth` | Actual container name |
| `caddy` | `traefik` | Caddy replaced by Traefik |
| `home_api_db` | REMOVE | No longer exists — DB is `shared_postgres` |
| `discord_bot_db` | REMOVE | No longer exists — DB is `shared_postgres` |
| `home_collector_db` | REMOVE | No longer exists — DB is `shared_postgres` |
| — | ADD `shared_postgres` | Shared database for all services |

Also update health URLs:
| Service | Old health_url | New health_url |
|---|---|---|
| `homeauth` | `http://homeauth-api:8100/health/ready` | `http://homeauth:8100/health/ready` |
| `traefik` (was caddy) | `http://caddy:80/` | `http://traefik:80/` or Docker-only |
| `home_collector_api` | `http://localhost:8010/health/ready` | `http://home_collector_api:8010/health/ready` |
| `portfolio` | `http://home-lab:3922/` | `http://portfolio:3000/` (internal port from server.md) |

Also update display names and groups accordingly.

### Step 2: Fix HTTP Health Check Network Access

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Context files to read**:
  - `docker-compose.yaml` — current network config
  - `/Users/gregor/dev/922/Planner/server.md` — Docker networks reference

The worker needs to be on the same networks as the services it checks:
- Add `proxy` network to worker service (for homeui, homeauth, portfolio, sweatvalley-bingo)
- Add `monitor-net` network to worker service (for grafana, prometheus)

**Changes to `docker-compose.yaml`**:
- Worker service: add `proxy` and `monitor-net` to networks
- API service: verify it's on `proxy` and `monitor-net` too (for self-check)
- Declare `proxy` and `monitor-net` as external networks at bottom of file

### Step 3: Fix Celery Event Loop Issue

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Context files to read**:
  - `app/tasks/uptime_tasks.py` — the poll task
  - `app/celery_app.py` — beat schedule config
  - `app/services/docker_monitor.py` — understand why polling takes 61s

**The core issue**: `asyncio.run()` creates a new event loop per task. When tasks overlap (61s task + 60s schedule), SQLAlchemy's async connection pool gets confused between event loops.

**Fixes**:
1. Increase `CHECK_INTERVAL` or beat schedule to 120s (double the task duration) to prevent overlap
2. OR add a lock so the task skips if a previous execution is still running (Celery `reject_on_worker_lost=True` or a Redis-based lock)
3. Fix the slow Docker stats: `container.stats(stream=False)` with 5s timeout per container × 33 containers = potentially 165s if slow. Consider collecting stats only for ServiceConfig-registered containers instead of ALL containers.
4. Use a shared event loop in the worker instead of `asyncio.run()` per task — use `asgiref.sync.async_to_sync` or manage the loop explicitly.

**Recommended approach**:
- Option A (quick): Filter Docker polling to only ServiceConfig-registered containers. This reduces from 33 to ~14 containers, halving task time.
- Option B (robust): Add a Redis lock to prevent overlapping executions.
- Do both.

### Step 4: Clean Up Stale Data in DB

- **Project**: HomeCollector (server)
- **Description**: After deploying the config fixes, clean up the DB:
  1. Delete old `service_configs` for removed services (`home_api_db`, `discord_bot_db`, `home_collector_db`, `caddy`, `homeauth-api`)
  2. The seeding logic will auto-create the corrected configs on restart (`traefik`, `homeauth`, `shared_postgres`)
  3. Optionally: prune stale `uptime_checks` rows for old container names

**SQL to run after deploy**:
```sql
-- Remove stale service configs (will be recreated with correct names on restart)
DELETE FROM service_configs WHERE service_name IN ('homeauth-api', 'caddy', 'home_api_db', 'discord_bot_db', 'home_collector_db');

-- Clean up old uptime data for non-existent containers (optional, saves DB space)
DELETE FROM uptime_checks WHERE service_name IN ('homeauth-api', 'caddy', 'home_api_db', 'discord_bot_db', 'home_collector_db', 'home_collector_redis', 'home_api_redis', 'homeauth_db', 'homeapi-flower-1', 'homecollector-flower-1', 'landingpage', 'uptime-kuma');
```

### Step 5: Verify End-to-End

After deploy:
```bash
# Wait 2 minutes for first poll cycle
docker logs home_collector_worker --tail 20 2>&1 | grep -i "stored\|error\|succeed"

# Check API returns all services as "up"
curl -s -H "X-User-ID: test" http://localhost:8010/api/uptime/status | python3 -m json.tool

# Verify no event loop errors
docker logs home_collector_worker --tail 50 2>&1 | grep -i "event loop\|attached to a different"
```

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Step 1: Fix container names + health URLs in config.py    → HomeCollector @ /Users/gregor/dev/922/HomeCollector
Step 2: Fix network access in docker-compose.yaml         → HomeCollector @ /Users/gregor/dev/922/HomeCollector
Step 3: Fix Celery event loop + optimize Docker polling   → HomeCollector @ /Users/gregor/dev/922/HomeCollector
Step 4: Clean up stale DB data (manual on server)         → ssh lab
Step 5: Verify end-to-end                                 → ssh lab

Steps 1-3: Single agent, sequential (all in same project)
Step 4-5: Manual by Gregor after deploy
```

## Post-Execution Checklist
- [ ] All 14 services show correct status in `GET /api/uptime/status`
- [ ] No event loop errors in worker logs
- [ ] Poll task completes in <30s (not 61s)
- [ ] `services_up` count matches reality
- [ ] Pipeline green after push
