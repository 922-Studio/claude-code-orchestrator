# Project: HomeAPI

## Overview
- **Type**: fullstack (backend)
- **Path**: /Users/gregor/dev/922/HomeAPI
- **Status**: active
- **Description**: Scalable, multipurpose home-lab REST API backend. Serves as the central backend for the ecosystem supporting debt/finance tracking, task management, idea management, wellbeing metrics, email/calendar integration, AI prompts (Gemini), worklogs, memory/knowledge base, Discord bot integration, and Google Sheets sync. All monitoring and data collection (GitHub, Allure, Prometheus, system checks) has moved to HomeCollector.

## Tech Stack
- **Language(s)**: Python 3.13
- **Framework(s)**: FastAPI 0.123.9, SQLAlchemy 2.0.44 (async), Pydantic V2, Celery 5.6.0
- **Database**: PostgreSQL 16 (asyncpg), Redis 7.1.0
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
- **Pipeline**: cancel-previous → version → lint → tests → smoke-test → deploy → notify
- **Deploy**: Zero-downtime Docker Compose via `deploy.sh`
- **Monitor after push**: Check Discord notification, verify `/health/ready`, check Prometheus metrics

## Dependencies on Other Projects
- **HomeAuth**: Shares JWT_SECRET for token validation
- **HomeUI**: Frontend consumer of all API endpoints
- **discord**: Discord bot calls HomeAPI for debts, ideas, wellbeing
- **HomeCollector**: Shares PostgreSQL and Redis infrastructure
- **workflows**: Uses reusable CI/CD workflows

## Notes
- 17 database models across 12+ domains
- 21 router modules (core domain only — no monitoring)
- Celery for core background tasks: GSheets sync, DB-driven scheduled tasks and cron jobs
- Google Gemini 2.5 Flash for AI/NLP features
- All monitoring endpoints (GitHub, Allure, Prometheus, system metrics) live in HomeCollector
- `system_check_tasks.py` remains in HomeAPI: used directly by `openclaw.py` router for health checks via `asyncio.to_thread()`
