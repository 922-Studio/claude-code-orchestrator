# Project: HomeContent

## Overview
- **Type**: fullstack (backend)
- **Path**: /Users/gregor/dev/922/HomeContent
- **Status**: active
- **Description**: Social media content management microservice. Provides REST API for creating, managing, previewing, and scheduling posts for Instagram and Facebook. Supports manual content creation, AI-assisted generation (Gemini), media upload, and scheduled posting with Discord notifications. Role-gated access ("social" role required).

## Tech Stack
- **Language(s)**: Python 3.13
- **Framework(s)**: FastAPI, SQLAlchemy 2.0 (async), Pydantic V2, Celery 5.x
- **Database**: PostgreSQL 16 (shared_postgres), Redis 7 (shared_redis, DB 3)
- **Infrastructure**: Docker, Alembic, Traefik forward-auth
- **CI/CD**: GitHub Actions (922-Studio/workflows), ruff + mypy, 70% coverage min

## Key Files to Read

| File | Purpose | When to read |
|------|---------|--------------|
| `CLAUDE.md` | Architecture, naming, patterns, testing strategy | Always |
| `config.py` | Environment variable management | When touching config |
| `app/main.py` | FastAPI app setup, middleware, lifespan | When touching app structure |
| `app/auth.py` | Role-based auth (X-User-Roles header + JWT fallback) | When touching auth |
| `app/models/post.py` | Post model | When touching posts |
| `app/models/media_asset.py` | MediaAsset model | When touching media |
| `app/services/ai_generator.py` | Gemini content generation | When touching AI features |
| `app/services/discord_notifier.py` | Discord webhook notifications | When touching notifications |
| `app/tasks/schedule_tasks.py` | Celery Beat scheduling tasks | When touching scheduling |
| `docker-compose.yaml` | Multi-service setup (api, worker, beat) | When touching infra |
| `.github/workflows/deploy.yml` | CI/CD pipeline | When pushing changes |

## Best Practices
- Strict layer separation: `routers → crud → models` with `schemas`, `services`, `tasks`
- Async throughout: `async def` for all DB and I/O operations
- UUID string PKs (36 chars)
- POST → 201, GET → 200, PATCH → 200, DELETE → 204
- Role-based auth: every endpoint requires "social" role
- Dual auth: Traefik forward-auth headers (primary) + JWT decode (fallback)
- AI features behind `AI_ENABLED` env flag (default: false)
- No `Co-Authored-By` trailers in commits

## Testing Strategy
- **Unit tests**: `tests/unit/{models,schemas,crud,services,tasks}/test_*.py`
- **Integration tests**: `tests/integration/routers/test_*.py`
- **How to run**: `PYTHONPATH=. pytest tests/ -v --cov=app --cov-fail-under=70`
- **Coverage**: 70% minimum enforced in CI

## Documentation
- **Where**: `README.md`, `CLAUDE.md`
- **Update rule**: Update docs when API or architecture changes

## Pipeline & Deployment
- **CI trigger**: Push to main
- **Pipeline**: cancel-previous → version → lint → tests → smoke-test → deploy → notify
- **Deploy**: Zero-downtime Docker Compose via `deploy.sh`
- **Monitor after push**: Check `/health`, Discord notification

## Dependencies on Other Projects
- **HomeAuth**: JWT_SECRET shared, role "social" required, forward-auth integration
- **HomeUI**: Frontend consumer of all API endpoints
- **Discord Bot**: Notification channel for scheduled posts (`;social` command)
- **HomeStructure**: Shared PostgreSQL, Redis, Traefik
- **workflows**: Uses reusable CI/CD workflows

## Notes
- Port 8012 behind Traefik (lab-content.922-studio.com)
- Redis DB 3 for Celery
- Media storage: /mnt/storage/homecontent/media/
- AI generation: Gemini via GEMINI_API_KEY, disabled by default
- Meta API integration (actual posting to Instagram/Facebook) is Phase 2 — not in initial scope
- Discord notifications use webhook URL directly (no bot dependency for sending)
