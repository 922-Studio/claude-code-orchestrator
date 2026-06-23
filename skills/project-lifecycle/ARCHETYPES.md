# Project Archetypes

The proven patterns in the 922-Studio ecosystem. When bootstrapping a new project,
pick the archetype whose reference project is closest, then **clone its structure**
(not its git history) and adapt. Never invent a new shape unless none of these fit —
in which case propose a new archetype rather than improvising.

Each archetype names a **reference project**, the **files that define its shape**
(copy these as scaffold), and the infra footprint the ADD playbook must provision.

---

## `python-fastapi-backend`

**Reference**: `Anime-API` (simplest, public) · `HomeCollector` (Celery + auth, fuller)

| Trait | Value |
|-------|-------|
| Language | Python 3.13, FastAPI, SQLAlchemy, Pydantic V2, Alembic |
| Deployed | yes — own container, Traefik-routed |
| Database | yes — `shared_postgres` (DB + user via `homelab-ctl.sh db:create`) |
| Redis | only if Celery — reserve next free DB number (see preflight) |
| Auth | optional — `auth-verify@file` middleware if protected |
| Domain | `<name>.922-studio.com` |
| Lint/test | ruff + mypy, pytest, Allure project `<name>` (kebab-case) |
| Port band | 80xx (8020, 8021 taken — pick next free) |

**Scaffold files** (from reference): `main.py` (or `app/`), `requirements.txt`,
`requirements-test.txt`, `Dockerfile`, `docker-compose.yaml`, `docker-compose.ci.yaml`,
`deploy.sh`, `alembic/` + `alembic.ini`, `tests/conftest.py`, `.github/workflows/`,
`pyproject.toml`, `README.md`, `CLAUDE.md`, `.gitignore`, `.env.example`.

**Mandatory endpoints**: `/health`, `/version` (public via Traefik priority router).

**Cross-service registration**: HomeCollector `DEFAULT_MONITORED_SERVICES` + HomeAPI
versioning registry (both required for APIs).

**Test-infra hardening** (known CI hangers — see `guides/new-service-setup.md` §11):
Celery → `memory://`, asyncpg `NullPool`, grpcio `os._exit`, `pytest-timeout` 30s,
workflow `timeout-minutes: 10`, Allure project-id kebab-case.

---

## `frontend-spa`

**Reference**: `Anime-APP` (Vite/React, plain JSX) · `HomeUI` (larger, TS)

| Trait | Value |
|-------|-------|
| Language | JS/JSX or TS, React 19, Vite, Tailwind 4 |
| Deployed | yes — Node build → Nginx static serve |
| Database | no |
| Redis | no |
| Auth | no (public) — auth handled by the APIs it consumes |
| Domain | `<name>.922-studio.com` |
| Lint/test | ESLint, Vitest, Allure project `<name>` |
| Port band | 80xx host → container port 80 (Nginx) |

**Scaffold files**: `src/`, `package.json`, `vite.config.*`, `Dockerfile`
(Node build → `nginx:1.27-alpine` + `apk add --no-cache curl`), `docker-compose.yaml`,
`deploy.sh`, `.github/workflows/`, `README.md`, `.env.example` (`APP_PORT` for host bind).

**Healthcheck**: `curl -f http://localhost:80/` (nginx-alpine lacks reliable wget).

**Cross-service registration**: HomeCollector monitoring as `group: Pages`, `monitor_type: both`.

---

## `nextjs-app`

**Reference**: `Studio` (i18n + MDX) · `Portfolio` (simpler) · `Drafter` (DB + internal auth)

| Trait | Value |
|-------|-------|
| Language | TypeScript, Next.js 16, React 19, Tailwind 4 |
| Deployed | yes — standalone output, multi-stage Docker |
| Database | only if app-stateful (Drafter uses `shared_postgres` + MinIO) |
| Redis | no |
| Auth | none (Studio/Portfolio) or internal jose JWT (Drafter) — never HomeAuth |
| Domain | `<name>.922-studio.com` |
| Lint/test | Vitest (unit) + Playwright (e2e), Allure `<name>-unit` / `<name>-e2e` |
| Port band | container 3000 (internal, Traefik-mapped) |

**Scaffold files**: `src/app/`, `package.json`, `next.config.ts` (standalone output),
`Dockerfile` (multi-stage), `docker-compose.yaml`, `deploy.sh`, `.github/workflows/`,
`README.md`, `CLAUDE.md`. If i18n: `messages/`, `src/i18n/`.

**Cross-service registration**: HomeCollector monitoring as `group: Pages`.

---

## `standalone-worker`

**Reference**: `Discord` bot (EggVault)

| Trait | Value |
|-------|-------|
| Language | Python 3.13 (or Node), long-running process, no HTTP server |
| Deployed | yes — `infra` network only, **no exposed ports, no Traefik** |
| Database | optional — `shared_postgres` if it owns state |
| Redis | optional |
| Auth | n/a (no inbound) |
| Domain | none |
| Lint/test | pytest + ruff + mypy, Allure project `<name>` |

**Scaffold files**: entry script (`bot.py`), `config.py`, `database.py` (if DB),
pure-logic package kept free of framework imports, `Dockerfile`, `docker-compose.yaml`
(`networks: [infra]` only), `deploy.sh`, `tests/`, `.github/workflows/`, `README.md`, `CLAUDE.md`.

**Cross-service registration**: HomeCollector monitoring as `monitor_type: docker`
(container-only — no health URL since there's no HTTP server).

---

## Universal conventions (all archetypes)

- Org: `922-Studio`. Default branch: `dev`. Branch off `dev`, PR into `dev`.
- CI/CD: reusable workflows from `922-Studio/workflows`. Discord notify on deploy.
- `deploy.sh`: zero-downtime build-first — **never** `docker compose down`. `SKIP_PULL`
  support, pre-build cache prune, `--no-cache` retry, `--wait --wait-timeout 120`.
- Networks: web+db → `proxy`+`infra`; db/redis only → `infra`; static web → `proxy`.
- No `Co-Authored-By` trailers. Docs/code/PRs in English.
- Full server procedure: `guides/new-service-setup.md` (canonical, 11 steps).
- Current port/redis usage: `server.md` + `guides/new-service-setup.md` reference table.
  Always run `scripts/project-lifecycle.sh preflight <name>` before claiming a port/domain.
