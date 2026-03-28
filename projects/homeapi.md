# Project: HomeAPI

## Overview
- **Type**: fullstack (backend)
- **Path**: /Users/gregor/dev/922/HomeAPI
- **Status**: active
- **Description**: Scalable, multipurpose home-lab REST API backend. Serves as the central backend for the ecosystem supporting finance/ledger tracking, task management, idea management, health/sleep (wellbeing) metrics, email/calendar integration, AI prompts (Gemini), worklogs, memory/knowledge base, Discord bot integration, and Google Sheets sync. All monitoring and data collection (GitHub, Allure, Prometheus, system checks) has moved to HomeCollector.

## Tech Stack
- **Language(s)**: Python 3.13
- **Framework(s)**: FastAPI 0.123.9, SQLAlchemy 2.0.44 (async), Pydantic 2.12.5, Celery 5.6.0, asyncpg 0.31.0, Alembic 1.17.2, uvicorn 0.38.0
- **AI/Integrations**: google-genai 1.64.0, resend 2.7.0, discord.py 2.4.0, prometheus-fastapi-instrumentator 7.1.0
- **Database**: PostgreSQL 16 (asyncpg 0.31.0), Redis
- **Infrastructure**: Docker, Alembic migrations, Prometheus metrics, Traefik
- **CI/CD**: GitHub Actions (922-Studio/workflows), ruff + mypy linting, 70% coverage min

## Key Files to Read

| File | Purpose | When to read |
|------|---------|--------------|
| `CLAUDE.md` | Architecture, naming, patterns, testing guidelines | Always |
| `.claude/HOW-TO-PYTEST-TEST.md` | Complete testing patterns (AsyncMock, Allure, fixtures) | When writing tests |
| `.claude/BEST_PRACTICES.md` | Code quality audit, security, scalability | When planning improvements |
| `config.py` | Environment variable management | When touching config |
| `app/main.py` | FastAPI app setup, middleware, lifespan | When touching app structure |
| `app/core/database.py` | Async SQLAlchemy engine, session management | When touching DB |
| `app/auth.py` | JWT token validation (shared with HomeAuth) | When touching auth |
| `docker-compose.yaml` | Multi-service setup (api, worker, beat, flower) | When touching infra |
| `.github/workflows/deploy.yml` | CI/CD pipeline | When pushing changes |
| `PROJECT_SUMMARY.md` | Phase-by-phase implementation overview | For historical context |

## Best Practices
- Strict layer separation: `routers → crud → models` with `schemas`, `services`, `helpers`, `tasks`
- Async throughout: `async def` for all DB and I/O operations
- UUID string PKs (36 chars), Decimal for money (never float)
- POST → 201, GET → 200, PATCH → 200, DELETE → 204
- NLP endpoints: `POST /api/{resource}/parse`
- Pydantic V2: `ConfigDict(from_attributes=True)`, no legacy `class Config`
- No `Co-Authored-By` trailers in commits

## Testing Strategy
- **Unit tests**: `tests/unit/{models,schemas,crud,services,tasks,helpers}/test_*.py` — `PYTHONPATH=. pytest tests/ -x -q`
- **Integration tests**: `tests/integration/routers/test_*.py`
- **Coverage**: 70% minimum enforced in CI
- **Reporting**: Allure at `http://home-lab:5050`

## Documentation
- **Where**: `docs/` (MkDocs), `README.md`, `SETUP_GUIDE.md`, `QUICK_REFERENCE.md`
- **Update rule**: Update docs when public API or behavior changes

## Pipeline & Deployment
- **CI trigger**: Push to main
- **Pipeline**: cancel-previous → version → lint → smoke → tests (70%) → deploy → generate-mcp → notify
- **Deploy**: Zero-downtime Docker Compose via `deploy.sh`
- **Monitor after push**: Check Discord notification, verify `/health/ready`, check Prometheus metrics

## Dependencies on Other Projects
- **HomeAuth**: Shares JWT_SECRET for token validation
- **HomeUI**: Frontend consumer of all API endpoints
- **discord**: Discord bot calls HomeAPI for debts, ideas, wellbeing
- **HomeCollector**: Shares PostgreSQL and Redis infrastructure
- **workflows**: Uses reusable CI/CD workflows

## API URL Structure

Domain-grouped routing (reflects HomeUI section structure):

| Domain | URL Prefix | Router File | Old Prefix |
|--------|-----------|-------------|------------|
| Health / Sleep (wellbeing) | `/api/health/sleep/` | `app/routers/health/sleep.py` | `/api/wellbeing/` |
| Finance / Ledger (debts) | `/api/finance/ledger/` | `app/routers/finance/ledger.py` | `/api/debts/` |
| Other domains | `/api/{domain}/` | `app/routers/{domain}.py` | (unchanged) |

## Notes
- 19 database models (activity_log, cron_job, debt_transaction, idea, memory, module, org_module, project, project_note, prompt, quote, scheduled_task, settings, task, wellbeing_metric, wellbeing_metric_entry, wellbeing_metric_todo, worklog + __init__)
- 20+ router modules (activity_log, calendar, cron_job, finance/ledger, gmail, health/sleep, idea, memory, modules, openclaw, project, project_note, prompt, quote, scheduled_task, settings, sync, task, tasks, worklog)
- Celery for core background tasks: GSheets sync, DB-driven scheduled tasks and cron jobs
- Google Gemini 2.5 Flash for AI/NLP features
- All monitoring endpoints (GitHub, Allure, Prometheus, system metrics) live in HomeCollector
- `system_check_tasks.py` remains in HomeAPI: used directly by `openclaw.py` router for health checks via `asyncio.to_thread()`
- Routers grouped by UI domain: `app/routers/health/`, `app/routers/finance/` (sub-packages with `__init__.py`)
