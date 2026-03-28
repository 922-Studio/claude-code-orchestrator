# Project: HomeAuth

## Overview
- **Type**: fullstack (backend)
- **Path**: /Users/gregor/dev/922/HomeAuth
- **Status**: active
- **Description**: Self-hosted JWT authentication server with forward-auth support for home lab services. Provides user registration, login, token refresh with rotation and reuse detection, role-based access control, account lockout, CSRF protection, and an HTML login form for browser-based auth. Integrates with Traefik via GET /auth/verify.

## Tech Stack
- **Language(s)**: Python 3.12
- **Framework(s)**: FastAPI >=0.133.1, SQLAlchemy[asyncio] >=2.0.47 (async), Pydantic V2, pwdlib[argon2] >=0.3.0, asyncpg >=0.31.0, Alembic >=1.18.4, uvicorn >=0.41.0
- **Auth**: PyJWT >=2.11.0, slowapi >=0.1.9
- **Database**: PostgreSQL (asyncpg)
- **Infrastructure**: Docker (non-root user), Alembic, slowapi rate limiting
- **CI/CD**: GitHub Actions (922-Studio/workflows), ruff + mypy, 85% coverage min

## Key Files to Read

| File | Purpose | When to read |
|------|---------|--------------|
| `CLAUDE.md` | Architecture, patterns, security rules, testing strategy | Always |
| `.claude/HOW-TO-PYTEST-TEST.md` | 1000+ line testing guide with patterns and anti-patterns | When writing tests |
| `README.md` | Quick start, architecture diagram, API endpoints, Traefik config | First time |
| `app/core/config.py` | Pydantic settings (DATABASE_URL, JWT_SECRET) | When touching config |
| `app/core/security.py` | JWT creation/decoding (HS256, 15min access, 7day refresh) | When touching auth |
| `app/core/password.py` | Argon2id hashing & verification | When touching passwords |
| `app/core/lockout.py` | Account lockout (5 failed attempts, 15min window) | When touching login |
| `app/routes/auth.py` | Auth endpoints (register, login, refresh, logout, verify) | When touching API |
| `app/routes/admin.py` | Admin CRUD (users, roles, role assignment) | When touching admin |
| `docs/HOMEUI_INTEGRATION.md` | React client integration | When touching frontend auth |
| `docs/HOMEAPI_INTEGRATION.md` | FastAPI service integration | When touching service auth |
| `.github/workflows/deploy.yml` | CI/CD pipeline | When pushing changes |

## Best Practices
- No CRUD layer — business logic directly in route functions
- Async/await throughout
- Timing attack prevention: always run `password_hash.verify()` even when user doesn't exist
- Identical error messages for "user not found" vs "wrong password"
- Token revocation via TokenBlacklist table, checked on every request
- Refresh rotation: reuse of revoked token → revoke ALL tokens for user
- Rate limiting per-IP (login ≤5/min, register ≤3/min, refresh ≤10/min)
- Security headers: HSTS, X-Content-Type-Options, X-Frame-Options, CSP
- No `Co-Authored-By` trailers in commits

## Testing Strategy
- **Unit tests**: `tests/unit/test_*.py` — 26+ test files covering all routes, core modules, models, schemas
- **How to run**: `PYTHONPATH=. pytest tests/ -x -q`
- **Coverage**: 85% minimum enforced in CI
- **Key patterns**: Every route tested for success + 401 (no token) + 401 (invalid token) + 422 (validation)

## Documentation
- **Where**: `README.md`, `docs/` (HOMEUI_INTEGRATION, HOMEAPI_INTEGRATION, USER_MANAGEMENT)
- **Update rule**: Update docs when auth flow or API changes

## Pipeline & Deployment
- **CI trigger**: Push to main (ignores .planning/*)
- **Pipeline**: cancel-previous → version → lint → tests (85%) → smoke-test → deploy → notify
- **Deploy**: Zero-downtime Docker Compose via `deploy.sh`
- **Monitor after push**: Check `/auth/health`, Discord notification

## Dependencies on Other Projects
- **HomeAPI**: Shares JWT_SECRET, HomeAPI validates tokens issued by HomeAuth
- **HomeUI**: Frontend login/register UI, token management
- **HomeStructure**: Traefik forward-auth integration (GET /auth/verify)

## Notes
- Forward-auth returns X-User-ID, X-User-Email, X-User-Roles headers for Traefik
- CSRF double-submit cookie pattern on HTML login form
- Admin seeding from environment variables on startup
