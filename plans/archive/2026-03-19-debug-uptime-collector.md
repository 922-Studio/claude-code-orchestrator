# Plan: Debug Uptime Collector — Page Not Working

- **Date**: 2026-03-19
- **Status**: DONE (2026-03-19)
- **Project(s)**: HomeCollector, HomeUI
- **Goal**: Diagnose and fix why the uptime page is not showing data, despite all code being structurally correct after the overhaul plan.

## Investigation Findings

Both codebases were reviewed thoroughly. **No code bugs found.** The issue is runtime/deployment:

### Likely Root Causes (in order of probability)

1. **Container name mismatch**: `DEFAULT_MONITORED_SERVICES` in `config.py` uses names like `home_api_api`, `homeauth-api`, `shared_redis` etc. If the actual Docker container names on the server differ (e.g. `homeapi-api-1` vs `home_api_api`), the Docker monitor collects data under wrong names, and the `GET /api/uptime/status` endpoint can't match them to ServiceConfigs.

2. **Alembic migration not applied**: If the second migration (`b2c3d4e5f6a7_add_http_health_check_fields`) wasn't run, the DB is missing `health_url`, `monitor_type`, `expected_status_code` columns. The app would crash on startup when trying to seed configs with those fields.

3. **Celery worker/beat not running or crashing**: If the beat scheduler isn't triggering `poll_docker_services` every 60s, no data gets collected. Worker might be crashing due to missing dependencies, DB connection issues, or Docker socket permissions.

4. **Network isolation**: HomeCollector worker is on `infra` network only. HTTP health checks to services on other networks (e.g. Prometheus on `monitor-net`) would fail silently.

5. **Frontend silent error swallowing**: `src/api/uptime.ts` wraps calls in try-catch returning empty arrays. If HomeCollector is unreachable or returns errors, the page shows empty state instead of error messages.

6. **Traefik routing**: If `lab-collector.922-studio.com` isn't properly routed through Traefik to HomeCollector, frontend API calls fail silently.

## Steps

### Step 1: Server-Side Diagnosis

- **Project**: HomeCollector (on server)
- **Description**: Run diagnostic commands on the server to determine the exact runtime state.
- **Commands to run (via `ssh lab`)**:

```bash
# 1. Check all HomeCollector containers are running
docker ps | grep home_collector

# 2. Check container logs for errors
docker logs home_collector_api --tail 100 2>&1 | head -80
docker logs home_collector_worker --tail 100 2>&1 | head -80
docker logs home_collector_beat --tail 100 2>&1 | head -80

# 3. Check if Alembic migration is current
docker exec home_collector_api alembic current

# 4. Check seeded service configs in DB
docker exec -it home_collector_db psql -U postgres -d home_collector -c "SELECT service_name, display_name, monitor_type, health_url, enabled FROM service_configs ORDER BY \"group\", service_name;"

# 5. Check if uptime data is being collected
docker exec -it home_collector_db psql -U postgres -d home_collector -c "SELECT service_name, status, checked_at FROM uptime_checks ORDER BY checked_at DESC LIMIT 30;"

# 6. Check total uptime checks count
docker exec -it home_collector_db psql -U postgres -d home_collector -c "SELECT service_name, COUNT(*) as checks, MAX(checked_at) as last_check FROM uptime_checks GROUP BY service_name ORDER BY last_check DESC;"

# 7. Compare config service names vs actual Docker container names
docker ps --format '{{.Names}}' | sort

# 8. Test API endpoints directly
curl -s http://localhost:8011/health/ready
curl -s -H "X-User-ID: test" http://localhost:8011/api/uptime/status | python3 -m json.tool | head -50
curl -s http://localhost:8011/status | python3 -m json.tool | head -50

# 9. Check Celery beat is scheduling tasks
docker logs home_collector_beat --tail 30 2>&1 | grep -i "poll\|schedule\|error"

# 10. Check Celery worker is processing tasks
docker logs home_collector_worker --tail 30 2>&1 | grep -i "poll\|succeed\|error\|fail"

# 11. Check Traefik routing for collector
curl -s -o /dev/null -w "%{http_code}" https://lab-collector.922-studio.com/health/ready
```

### Step 2: Fix Based on Diagnosis

Based on what Step 1 reveals:

**If container names don't match:**
- Update `DEFAULT_MONITORED_SERVICES` in `config.py` to use the actual container names from `docker ps`
- Delete existing wrong service_configs from DB or update them
- Redeploy

**If migration not applied:**
- Run: `docker exec home_collector_api alembic upgrade head`
- Restart API container to trigger seeding

**If Celery not running:**
- Check logs for crash reason
- Fix dependencies/config
- Restart: `docker compose restart worker beat`

**If network issue:**
- Add `monitor-net` to HomeCollector services in `docker-compose.yaml`
- Redeploy

**If frontend can't reach collector:**
- Check Traefik labels on HomeCollector container
- Check CORS config in HomeCollector
- Check `VITE_COLLECTOR_URL` in HomeUI production env

**If API returns data but frontend shows empty:**
- The try-catch in `src/api/uptime.ts` silently swallows errors
- Add console.error logging before returning fallback
- Check browser console for network errors

### Step 3: Fix Frontend Error Swallowing

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Description**: Regardless of the backend fix, the frontend should NOT silently swallow errors. Update `src/api/uptime.ts` to let errors propagate to React Query so `isError` states work properly.
- **Context files to read**:
  - `src/api/uptime.ts` — the try-catch blocks returning empty arrays
  - `src/features/dashboard/pages/UptimePage.tsx` — error display logic
