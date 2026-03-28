# Project: Anime-API

## Overview
- **Type**: fullstack (backend)
- **Path**: /Users/gregor/dev/922/Anime-API
- **Status**: active
- **Description**: FastAPI backend for anime collection management. Provides REST endpoints for users, collections, and anime entries. Proxies the Jikan (MyAnimeList) API for anime search. Public API — no authentication middleware.

## Tech Stack
- **Language(s)**: Python 3.13
- **Framework(s)**: FastAPI, SQLAlchemy (sync), Pydantic V2, Alembic, gunicorn
- **Auth**: passlib + jose
- **AI**: google-generativeai >=0.8.0
- **Database**: PostgreSQL 16 via psycopg2-binary (own container: `anime_api_db`, port 5435)
- **Infrastructure**: Docker Compose, Traefik
- **CI/CD**: GitHub Actions (922-Studio/workflows), ruff + mypy linting

## Key Files to Read

| File | Purpose | When to read |
|------|---------|--------------|
| `main.py` | All routes, models, schemas, app setup | Always |
| `requirements.txt` | Python dependencies | When planning changes |
| `docker-compose.yaml` | Service + DB setup | When touching infra |
| `docker-compose.ci.yaml` | Smoke test override | When touching CI |
| `.github/workflows/deploy.yml` | CI/CD pipeline | When pushing changes |
| `deploy.sh` | Deployment script | When touching deployment |

## Best Practices
- Single `main.py` architecture — keep flat unless complexity requires splitting
- Sync SQLAlchemy (not async) — do not refactor to async without a dedicated plan
- `psycopg2-binary` for sync PostgreSQL driver
- POST → 201, GET → 200, PATCH → 200, DELETE → 204
- No `Co-Authored-By` trailers in commits

## Testing Strategy
- **Unit tests**: `tests/test_*.py` — `PYTHONPATH=. pytest tests/ -x -q`
- **Coverage**: 0% minimum initially (to be raised in a separate plan)
- **Reporting**: Allure at `http://home-lab:5050` (project: `anime-api`)

## Documentation
- **Where**: `README.md`
- **Update rule**: Update when API surface changes

## Pipeline & Deployment
- **CI trigger**: Push to main
- **Pipeline**: cancel-previous → version → lint → tests + smoke-test → deploy → notify
- **Deploy**: Zero-downtime Docker Compose via `deploy.sh` on server at `~/Anime-API`
- **Monitor after push**: Check Discord notification, verify `/health` endpoint

## Public Routes
- **API**: `anime-api.922-studio.com` → Traefik :80 → container port 8020
- No auth middleware — all endpoints public

## Port & Container Reference
| Resource | Value |
|---|---|
| App port (host) | 8020 |
| PostgreSQL port (host) | 5435 (127.0.0.1) |
| App container | `anime_api` |
| DB container | `anime_api_db` |
| Internal network | `anime_api_net` |

## Dependencies on Other Projects
- **workflows**: Uses reusable CI/CD workflows
- **HomeStructure**: Traefik routing, Cloudflare Tunnel

## Notes
- Database migrated from SQLite (`anime.db`) to PostgreSQL in infrastructure setup
- `bot.py` and Discord-related dependencies are legacy artifacts — not active
- `package.json` / `package-lock.json` at root are stale artifacts from earlier development
