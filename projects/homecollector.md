# Project: HomeCollector

## Overview
- **Type**: fullstack (backend)
- **Path**: /Users/gregor/dev/922/HomeCollector
- **Status**: active
- **Description**: Data collection hub and uptime monitoring service for the 922-Studio home-lab. Owns all monitoring and external data collection responsibilities: Docker uptime monitoring via Docker socket + HTTP health checks, GitHub Actions monitoring, Allure test results, Prometheus system metrics, background notification tasks (disk alerts, email, Discord, OpenClaw), and a public status page at `/status`. Single source of truth for all monitoring data consumed by HomeUI dashboards.

## Tech Stack
- **Language(s)**: Python 3.13
- **Framework(s)**: FastAPI 0.123.9, SQLAlchemy 2.0.44 (async), Pydantic V2, Celery 5.6.0
- **Database**: PostgreSQL 16 via `shared_postgres` (database: `home_collector`), Redis via `shared_redis` DB 1
- **Infrastructure**: Docker, Alembic, aiodocker, Prometheus metrics, Traefik
- **CI/CD**: GitHub Actions (922-Studio/workflows), ruff + mypy, 70% coverage min

## Key Files to Read

| File | Purpose | When to read |
|------|---------|--------------|
| `CLAUDE.md` | Architecture, conventions, patterns, testing strategy | Always |
| `README.md` | Quick start, full API overview, architecture diagram | First time |
| `config.py` | Environment variables (Docker socket, GitHub, Allure, Prometheus, Redis, JWT) | When touching config |
| `app/main.py` | FastAPI app, middleware (auth, CORS, request ID), router registration | When touching app structure |
| `app/services/docker_monitor.py` | poll_docker_containers(), CPU calculation | When touching uptime monitoring |
| `app/services/http_monitor.py` | HTTP health check polling, response time measurement | When touching health checks |
| `app/services/github_service.py` | GitHub Actions: workflow runs, runners, stats, analytics | When touching GitHub data |
| `app/services/allure_service.py` | Allure test results, history, projects | When touching test result data |
| `app/services/prometheus_service.py` | System metrics, container metrics, usage, coverage history | When touching system metrics |
| `app/tasks/uptime_tasks.py` | Celery tasks: 60s Docker+HTTP poll, daily pruning | When touching background tasks |
| `app/tasks/system_check_tasks.py` | Disk usage, pending todos, system updates checks | When touching system checks |
| `app/tasks/openclaw_tasks.py` | OpenClaw daily briefing, usage overview, weekly overview | When touching OpenClaw tasks |
| `app/tasks/email_tasks.py` | Health alert emails, morning summary | When touching email tasks |
| `app/tasks/sleep_reminder_tasks.py` | Sleep logging reminder via Discord | When touching reminders |
| `app/routers/uptime.py` | Uptime status, history, bulk history, services CRUD | When touching uptime API |
| `app/routers/public_status.py` | GET /status — public status page (no auth) | When touching status page |
| `app/routers/github.py` | GitHub workflow runs, runners, stats, analytics | When touching GitHub API |
| `app/routers/allure.py` | Allure results, history, projects | When touching Allure API |
| `app/routers/system.py` | System metrics, container metrics, usage, coverage, overview | When touching system API |
| `app/models/uptime_check.py` | UptimeCheck model | When touching uptime data |
| `app/models/service_config.py` | ServiceConfig model, monitor_type (docker/http/both) | When touching service management |
| `app/celery_app.py` | Celery beat schedule for all background tasks | When touching task scheduling |
| `docker-compose.yaml` | Services (api, worker, beat, flower) | When touching infra |
| `.github/workflows/deploy.yml` | CI/CD pipeline | When pushing changes |

## Best Practices
- Strict layering: `routers/ → crud/ → models/` with `schemas/`, `services/`, `helpers/`, `tasks/`
- Two-layer auth: X-User-ID header (Traefik forward-auth) or Bearer JWT token
- `/status` is auth-exempt (public status page)
- Async throughout with AsyncSession
- Celery runs `asyncio.run()` to wrap async code from sync context
- UUID string PKs (36 chars), UTC timestamps
- No `Co-Authored-By` trailers in commits

## Testing Strategy
- **Unit tests**: `tests/unit/{models,schemas,crud,services,tasks}/test_*.py`
- **Integration tests**: `tests/integration/routers/test_*.py`
- **How to run**: `PYTHONPATH=. pytest tests/ -v --cov=app --cov-fail-under=70`
- **Coverage**: 70% minimum enforced in CI

## Documentation
- **Where**: `docs/` (MkDocs at http://home-lab:8013), `README.md`
- **Update rule**: Update docs when API or architecture changes

## Pipeline & Deployment
- **CI trigger**: Push to main (ignores .planning/**)
- **Pipeline**: cancel-previous → version → lint → tests → smoke-test → deploy → notify
- **Deploy**: Zero-downtime Docker Compose via `deploy.sh`
- **Monitor after push**: Check `/health`, Discord notification

## Dependencies on Other Projects
- **HomeAuth**: Shares JWT_SECRET for token validation
- **HomeUI**: Frontend dashboard consumes all monitoring APIs (uptime + github + allure + system + overview)
- **HomeStructure**: Shares PostgreSQL, Redis, Traefik; HomeCollector on `monitor-net` network for Prometheus access
- **workflows**: Uses reusable CI/CD workflows
- **GitHub API**: Workflow runs, runners, analytics (GITHUB_TOKEN)
- **Allure Docker Service**: Test results and history (ALLURE_URL)
- **Prometheus**: System and container metrics (PROMETHEUS_URL)
- **HomeAPI**: Read-only REST API call for pending todos count (HOME_API_URL)

## Notes
- Port 8010 internal / 8011 on host (HomeAPI uses 8080)
- Shared infrastructure: `shared_postgres` (database `home_collector`) + `shared_redis` DB 1
- HomeAPI has its own dedicated Postgres; HomeCollector uses the shared instance
- Configurable retention: `RETENTION_DAYS` (default 90)
- Configurable polling: `CHECK_INTERVAL` (default 60s)
- 14+ services monitored via ServiceConfig (auto-seeded on startup from `DEFAULT_MONITORED_SERVICES`)
- `status.922-studio.com` routes to this service's `/status` endpoint (no auth)
- Traefik labels: public routes (/health, /version, /docs, /status), protected routes (/api/*)
