# Plan: Registry-Based CI/CD + Watchtower Rollout for All Services

- **Date**: 2026-03-27
- **Status**: In Progress (Wave 1)
- **Project(s)**: HomeAPI, HomeAuth, HomeCollector, HomeUI, Anime-API, Anime-APP, Portfolio, Studio, Discord Bot, Sweatvalley Bingo
- **Goal**: Migrate all remaining services from local-build SSH deployment to registry-based CI/CD with Watchtower auto-deployment — matching the pattern established by Drafter.

### Known Issues
- **`environment` + `uses` incompatible**: GitHub Actions rejects `environment:` block on jobs that use reusable workflows (`uses:`) on some repos. Removed `environment` from `push-prod` jobs. Deployment tracking via Discord notifications instead.

## Context

Read these files before proceeding:
- `plans/generic-registry-cicd-rollout.md` — step-by-step migration checklist per project
- `plans/2026-03-25-watchtower-auto-deployment.md` — Watchtower setup and Drafter pilot
- `plans/2026-03-25-registry-cicd-drafter-pilot.md` — Drafter as reference implementation
- `server.md` — full infrastructure reference
- `projects/<name>.md` — per-project mapping for each service being migrated

## Strategy

### Dev/Prod Environment Map

Not all services have a dev/prod split. The core Home Lab services have full separation (see `plans/2026-03-24-dev-prod-environment-split.md`). Other services are prod-only.

| Service | Dev/Prod Split | Dev Branch | Prod Branch | Dev Subdomain | Prod Subdomain |
|---------|---------------|------------|-------------|---------------|----------------|
| **HomeAPI** | Yes | `dev` | `prod` | `lab-api-dev.922-studio.com` | `lab-api.922-studio.com` |
| **HomeAuth** | Yes | `dev` | `prod` | `auth-dev.922-studio.com` | `auth.922-studio.com` |
| **HomeUI** | Yes | `dev` | `prod` | `lab-dev.922-studio.com` | `lab.922-studio.com` |
| **HomeCollector** | Yes | `dev` | `prod` | `lab-collector-dev.922-studio.com` | `lab-collector.922-studio.com` |
| **Drafter** | Yes (done) | `dev` | manual dispatch | `drafter-dev.922-studio.com` | `drafter.922-studio.com` |
| Portfolio | No | `main` | — | — | `gregor.922-studio.com` |
| Studio | No | `main` | — | — | `studio.922-studio.com` |
| Anime-API | No | `main` | — | — | `anime-api.922-studio.com` |
| Anime-APP | No | `main` | — | — | `anime.922-studio.com` |
| Discord Bot | No | `main` | — | — | (no subdomain) |
| Sweatvalley Bingo | No | `main` | — | — | `sweatvalley-bingo.922-studio.com` |

### Deployment Pattern: Dev/Prod Services (HomeAPI, HomeAuth, HomeUI, HomeCollector)

These services follow the Drafter pilot pattern with full dev/prod separation:

```
Push to dev branch → GitHub Actions:
  1. Semantic versioning
  2. Docker build (no push)
  3. Smoke test (isolated DB + built image) ← parallel with tests
  4. Unit/integration tests                 ← parallel with smoke
  5. Push to registry: :dev (mutable) + :dev-vX.Y.Z (immutable)
  6. Discord notification
→ Watchtower detects new :dev digest → pulls + restarts dev container(s)
→ Dev container entrypoint runs migrations against dev_postgres:5433

Push to prod branch (or manual dispatch with "production") → GitHub Actions:
  Same pipeline, but:
  5. Push to registry: :prod (mutable) + :prod-vX.Y.Z (immutable)
  Environment protection: approval from Gregor required
→ Watchtower detects new :prod digest → pulls + restarts prod container(s)
→ Prod container entrypoint runs migrations against shared_postgres:5432
```

**Server layout per dev/prod service:**
- Prod: `~/SERVICE/docker-compose.deploy.yaml` + `.env` (IMAGE_TAG=prod, prod ports, shared_postgres)
- Dev: `~/dev/SERVICE/docker-compose.deploy.yaml` + `.env` (IMAGE_TAG=dev, dev ports, dev_postgres)

**Docker compose is parameterized** — same `docker-compose.deploy.yaml`, different `.env` drives:
- `IMAGE_TAG` → `:dev` or `:prod`
- `CONTAINER_PREFIX` → `dev_` or (empty)
- `COMPOSE_PROJECT_NAME` → `service-dev` or `service`
- `DB_HOST` → `dev_postgres` or `shared_postgres`
- `DB_PORT` → `5433` or `5432`
- `DB_NAME` → `dev_service` or `service`
- `REDIS_HOST` → `dev_redis` or `shared_redis` (if applicable)
- `TRAEFIK_HOST` → dev subdomain or prod subdomain
- `API_PORT`, `FLOWER_PORT` → dev ports or prod ports

### Deployment Pattern: Prod-Only Services (Portfolio, Studio, Anime-*, Discord, Sweatvalley)

Simpler flow — single environment, no dev/prod split:

```
Push to main → GitHub Actions:
  1. Semantic versioning
  2. Docker build (no push)
  3. Smoke test ← parallel with tests
  4. Unit/integration tests ← parallel with smoke
  5. Push to registry: :prod (mutable) + :prod-vX.Y.Z (immutable)
  6. Discord notification
→ Watchtower detects new :prod digest → pulls + restarts container

Manual dispatch not needed (no approval gate for these services).
```

**Server layout per prod-only service:**
- Single directory: `~/SERVICE/docker-compose.deploy.yaml` + `.env` (IMAGE_TAG=prod)

### Image Tagging Summary

| Service type | CI trigger | Tags pushed | Watchtower watches |
|-------------|-----------|-------------|-------------------|
| Dev/prod services — dev push | push to `dev` | `:dev`, `:dev-vX.Y.Z` | `:dev` on dev container |
| Dev/prod services — prod push | push to `prod` or manual dispatch | `:prod`, `:prod-vX.Y.Z` | `:prod` on prod container |
| Prod-only services | push to `main` | `:prod`, `:prod-vX.Y.Z` | `:prod` on single container |

### `.env` File Strategy

Each service maintains environment files in **two places**: the repo (committed templates) and the server (full config with secrets).

**In the repo (committed, no secrets):**

| File | Purpose | Contains |
|------|---------|----------|
| `.env.dev` | Dev environment template | IMAGE_TAG=dev, dev ports, dev DB host/name, dev subdomain, container prefix |
| `.env.prod` | Prod environment template | IMAGE_TAG=prod, prod ports, prod DB host/name, prod subdomain |

For prod-only services, only `.env.prod` exists.

These files contain **no secrets** (no passwords, tokens, API keys). They are safe to commit and serve as the source of truth for environment-specific configuration.

**On the server (not committed, contains secrets):**

| Location | Source | Contains |
|----------|--------|----------|
| `~/SERVICE/.env` (prod) | `.env.prod` + secrets | Full prod config: template values + DB_PASSWORD, JWT_SECRET, API keys |
| `~/dev/SERVICE/.env` (dev) | `.env.dev` + secrets | Full dev config: template values + DB_PASSWORD, JWT_SECRET, API keys |

Server `.env` is created by copying the repo template and appending server-only secrets. When template values change (e.g., a new env var is added), the server `.env` must be updated manually or via deploy script.

**Secrets that go ONLY on the server:**
- `DB_PASSWORD` / `DB_USER`
- `JWT_SECRET` / `SECRET_KEY`
- `DISCORD_BOT_TOKEN`
- `REGISTRY_USERNAME` / `REGISTRY_PASSWORD` (for deploy.sh, if kept)
- Any third-party API keys (GEMINI_API_KEY, etc.)

### Migration Waves

Services are grouped by complexity and dependency. Each wave completes before the next starts — this limits blast radius and lets us catch issues early.

| Wave | Services | Complexity | Dev/Prod | Why this order |
|------|----------|-----------|----------|----------------|
| 1 | Portfolio, Studio | Low | Prod only | Static sites, no DB, no workers — simplest possible migration |
| 2 | HomeAuth | Low | **Dev + Prod** | Simple FastAPI, single container, no workers — first Python dev/prod service |
| 3 | HomeUI, Anime-APP | Low | **HomeUI: Dev+Prod**, Anime-APP: Prod only | Frontend SPAs, no DB — validates frontend pattern |
| 4 | Anime-API | Low | Prod only | Simple FastAPI, no workers — straightforward backend |
| 5 | HomeAPI, HomeCollector | Medium | **Dev + Prod** | FastAPI + Alembic + Celery workers — most complex, multiple containers |
| 6 | Discord Bot | Medium | Prod only | Python async, SQLAlchemy — unique stack, isolated |
| 7 | Sweatvalley Bingo | Low | Prod only | Express + React + Socket.io — isolated, low priority |

## Steps

---

### Step 1: Portfolio — Registry Migration (prod only)

- **Project**: Portfolio
- **Directory**: `/Users/gregor/dev/922/portfolio`
- **Parallel with**: Step 2 (Studio)
- **Context files to read**:
  - `projects/portfolio.md` — project mapping
  - `plans/generic-registry-cicd-rollout.md` — migration checklist
  - Current `Dockerfile`, `docker-compose.yaml`, `.github/workflows/` in Portfolio repo
  - `/Users/gregor/dev/922/Drafter/docker-compose.deploy.yaml` — reference for deploy compose
  - `/Users/gregor/dev/922/Drafter/.github/workflows/deploy.yml` — reference pipeline
- **Changes**:
  1. Review existing Dockerfile — ensure multi-stage build is clean (no entrypoint needed, no DB)
  2. Create `docker-compose.deploy.yaml` with registry image (`${IMAGE_TAG:-prod}`), Watchtower label, Traefik labels
  3. Create `.env.prod` in repo with prod values:
     ```env
     IMAGE_TAG=prod
     CONTAINER_NAME=portfolio
     TRAEFIK_HOST=gregor.922-studio.com
     ```
  4. Add `.env.prod` to `.gitignore` if it contains secrets; otherwise commit it as a template. Actual server `.env` is managed on server only.
  5. Refactor `.github/workflows/deploy.yml` to new pattern: version → build → smoke-test → tests → push-prod → notify
     - Push to `main` → pushes `:prod` + `:prod-vX.Y.Z` (no dev environment for this service)
  6. Add GitHub secrets: `REGISTRY_USERNAME`, `REGISTRY_PASSWORD` (if not already set)
  7. Create GitHub environment: `production`
  8. Push changes, verify CI runs successfully
- **Acceptance criteria**:
  - [ ] `docker-compose.deploy.yaml` exists with Watchtower label
  - [ ] `.env.prod` committed in repo (template, no secrets)
  - [ ] CI pipeline builds, tests, and pushes `registry.922-studio.com/portfolio:prod`
  - [ ] No SSH deploy step in pipeline

### Step 2: Studio — Registry Migration (prod only)

- **Project**: Studio
- **Directory**: `/Users/gregor/dev/922/studio`
- **Parallel with**: Step 1 (Portfolio)
- **Context files to read**:
  - `projects/studio.md` — project mapping
  - `plans/generic-registry-cicd-rollout.md` — migration checklist
  - Current `Dockerfile`, `docker-compose.yaml`, `.github/workflows/` in Studio repo
- **Changes**: Same as Portfolio — static Next.js site, no DB, no workers, prod only.
  1. Review Dockerfile
  2. Create `docker-compose.deploy.yaml` with `${IMAGE_TAG:-prod}`, Watchtower label
  3. Create `.env.prod` in repo:
     ```env
     IMAGE_TAG=prod
     CONTAINER_NAME=studio
     TRAEFIK_HOST=studio.922-studio.com
     ```
  4. Refactor CI workflow: push to `main` → push `:prod` + `:prod-vX.Y.Z`
  5. Add secrets + environment on GitHub
  6. Push and verify
- **Acceptance criteria**:
  - [ ] `docker-compose.deploy.yaml` exists with Watchtower label
  - [ ] `.env.prod` committed in repo
  - [ ] CI pipeline builds, tests, and pushes `registry.922-studio.com/studio:prod`

### Step 3: Server Deployment — Wave 1 (Portfolio + Studio, prod only)

- **Project**: HomeStructure (server-side)
- **Directory**: Server via `ssh lab`
- **Depends on**: Steps 1 + 2
- **Context files to read**:
  - `server.md` — service ports, container names, networks
  - `HomeStructure/docs/services/watchtower.md` — Watchtower config
- **Changes**:
  1. On server: `~/Portfolio/docker-compose.deploy.yaml` + `~/Portfolio/.env` (copy from `.env.prod`, add any server-only secrets)
  2. On server: `~/Studio/docker-compose.deploy.yaml` + `~/Studio/.env` (same pattern)
  3. Pull images: `docker compose -f docker-compose.deploy.yaml pull`
  4. Stop old containers, start new ones from registry images
  5. Verify Watchtower picks up both containers (`docker logs watchtower --tail 50`)
  6. Verify sites respond: `curl -I https://gregor.922-studio.com` and `curl -I https://studio.922-studio.com`
  7. Verify Watchtower auto-update: push a trivial change, wait 30s, confirm new image deployed
- **Note**: No dev environment for these services — single prod deployment per service.
- **Acceptance criteria**:
  - [ ] Both containers running from registry images (`:prod` tag)
  - [ ] Watchtower monitoring both containers
  - [ ] Health checks pass
  - [ ] Sites accessible via their domains
  - [ ] Auto-update verified on at least one service

### Step 4: HomeAuth — Registry Migration (dev + prod)

- **Project**: HomeAuth
- **Directory**: `/Users/gregor/dev/922/HomeAuth`
- **Depends on**: Step 3 (validate pattern works)
- **Context files to read**:
  - `projects/homeauth.md` — project mapping
  - `plans/generic-registry-cicd-rollout.md` — migration checklist (Python/Alembic variant)
  - `plans/2026-03-24-dev-prod-environment-split.md` — existing dev/prod setup
  - Current `Dockerfile`, `docker-compose.yaml`, `.github/workflows/` in HomeAuth repo
- **Changes**:
  1. Create `entrypoint.sh` with Alembic migration: `alembic upgrade head` before app start
  2. Update Dockerfile: copy `alembic/` dir + `alembic.ini`, set ENTRYPOINT to entrypoint.sh
  3. Create `docker-compose.deploy.yaml` — parameterized via env vars, single file for both environments:
     ```yaml
     services:
       homeauth:
         image: registry.922-studio.com/homeauth:${IMAGE_TAG:-dev}
         container_name: ${CONTAINER_PREFIX:-}homeauth
         labels:
           - "com.centurylinklabs.watchtower.enable=true"
           - "traefik.http.routers.${ROUTER_NAME:-homeauth}.rule=Host(`${TRAEFIK_HOST}`)"
     ```
  4. Create `.env.dev` in repo (committed, no secrets):
     ```env
     IMAGE_TAG=dev
     CONTAINER_PREFIX=dev_
     COMPOSE_PROJECT_NAME=homeauth-dev
     TRAEFIK_HOST=auth-dev.922-studio.com
     ROUTER_NAME=homeauth-dev
     API_PORT=8200
     DB_HOST=dev_postgres
     DB_PORT=5433
     DB_NAME=dev_home_auth
     ```
  5. Create `.env.prod` in repo (committed, no secrets):
     ```env
     IMAGE_TAG=prod
     CONTAINER_PREFIX=
     COMPOSE_PROJECT_NAME=homeauth
     TRAEFIK_HOST=auth.922-studio.com
     ROUTER_NAME=homeauth
     API_PORT=8100
     DB_HOST=shared_postgres
     DB_PORT=5432
     DB_NAME=home_auth
     ```
  6. **Note**: Secrets (DB_PASSWORD, JWT_SECRET, etc.) are NOT in these files — they go in the server-side `.env` only, or are appended to the server copy.
  7. Refactor CI workflow to registry pattern:
     - Push to `dev` branch → build → test → push `:dev` + `:dev-vX.Y.Z`
     - Push to `prod` branch (or manual dispatch with `production`) → build → test → push `:prod` + `:prod-vX.Y.Z` (with approval gate)
  8. Add GitHub secrets: `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`
  9. Create GitHub environments: `development`, `production` (with approval gate)
  10. Push to `dev`, verify CI pushes `:dev` image
- **Acceptance criteria**:
  - [ ] `entrypoint.sh` runs Alembic migrations on startup
  - [ ] `docker-compose.deploy.yaml` parameterized for both environments
  - [ ] `.env.dev` and `.env.prod` committed in repo (templates, no secrets)
  - [ ] CI: push to `dev` → pushes `registry.922-studio.com/homeauth:dev`
  - [ ] CI: push to `prod` → pushes `registry.922-studio.com/homeauth:prod` (with approval)
  - [ ] Smoke test validates migrations run in CI

### Step 5: Server Deployment — HomeAuth (dev first, then prod)

- **Project**: HomeStructure (server-side)
- **Directory**: Server via `ssh lab`
- **Depends on**: Step 4
- **Changes**:
  **Dev environment first:**
  1. Copy `docker-compose.deploy.yaml` to `~/dev/HomeAuth/`
  2. Create `~/dev/HomeAuth/.env` by combining `.env.dev` template + server-only secrets:
     ```env
     # From .env.dev template
     IMAGE_TAG=dev
     CONTAINER_PREFIX=dev_
     COMPOSE_PROJECT_NAME=homeauth-dev
     TRAEFIK_HOST=auth-dev.922-studio.com
     ROUTER_NAME=homeauth-dev
     API_PORT=8200
     DB_HOST=dev_postgres
     DB_PORT=5433
     DB_NAME=dev_home_auth
     # Server-only secrets (not in repo)
     DB_PASSWORD=<from existing .env>
     JWT_SECRET=<from existing .env>
     ```
  3. Pull and start: `docker compose -f docker-compose.deploy.yaml pull && docker compose -f docker-compose.deploy.yaml up -d`
  4. Verify dev: container logs show "Running database migrations", `curl https://auth-dev.922-studio.com/health`
  5. Verify Watchtower picks up `dev_homeauth`

  **Prod environment after dev is verified:**
  6. Copy `docker-compose.deploy.yaml` to `~/HomeAuth/`
  7. Create `~/HomeAuth/.env` by combining `.env.prod` template + server-only secrets
  8. Pull and start prod
  9. Verify prod: migrations ran, `curl https://auth.922-studio.com/health`
  10. Verify Watchtower picks up `homeauth`
  11. Test auth flow end-to-end: login via browser on both dev and prod domains
  12. Push trivial change to `dev` → confirm Watchtower auto-deploys dev container within 30s
- **Acceptance criteria**:
  - [ ] Dev container `dev_homeauth` running from `registry.922-studio.com/homeauth:dev`
  - [ ] Prod container `homeauth` running from `registry.922-studio.com/homeauth:prod`
  - [ ] Alembic migrations ran on both environments (against different databases)
  - [ ] Both `auth-dev.922-studio.com` and `auth.922-studio.com` respond
  - [ ] Watchtower monitoring both containers
  - [ ] Auto-deploy verified on dev

### Step 6: HomeUI (dev + prod) + Anime-APP (prod only) — Registry Migration

- **Project**: HomeUI, Anime-APP
- **Directory**: `/Users/gregor/dev/922/HomeUI`, `/Users/gregor/dev/922/Anime-APP`
- **Parallel with**: Both can be done in parallel (independent frontends)
- **Depends on**: Step 5 (HomeAuth verified — HomeUI depends on auth)
- **Context files to read**:
  - `projects/homeui.md`, `projects/anime-app.md` — project mappings
  - `plans/generic-registry-cicd-rollout.md` — migration checklist
  - `plans/2026-03-24-dev-prod-environment-split.md` — HomeUI dev/prod setup
  - Current Dockerfiles, compose files, workflows in each repo

- **HomeUI changes (dev + prod)**:
  1. Review Dockerfile (no entrypoint needed — frontend, no DB)
  2. Create `docker-compose.deploy.yaml` parameterized via env vars (same pattern as HomeAuth Step 4)
  3. Create `.env.dev` in repo:
     ```env
     IMAGE_TAG=dev
     CONTAINER_PREFIX=dev_
     COMPOSE_PROJECT_NAME=homeui-dev
     TRAEFIK_HOST=lab-dev.922-studio.com
     ROUTER_NAME=homeui-dev
     PORT=8001
     ```
  4. Create `.env.prod` in repo:
     ```env
     IMAGE_TAG=prod
     CONTAINER_PREFIX=
     COMPOSE_PROJECT_NAME=homeui
     TRAEFIK_HOST=lab.922-studio.com
     ROUTER_NAME=homeui
     PORT=8000
     ```
  5. Refactor CI: push to `dev` → `:dev` tag, push to `prod` → `:prod` tag (with approval)
  6. Add secrets + environments on GitHub

- **Anime-APP changes (prod only)**:
  1. Review Dockerfile
  2. Create `docker-compose.deploy.yaml` with `${IMAGE_TAG:-prod}`, Watchtower label
  3. Create `.env.prod` in repo:
     ```env
     IMAGE_TAG=prod
     CONTAINER_NAME=anime_app
     TRAEFIK_HOST=anime.922-studio.com
     ```
  4. Refactor CI: push to `main` → `:prod` + `:prod-vX.Y.Z`
  5. Add secrets + environment on GitHub

- **Acceptance criteria**:
  - [ ] HomeUI: `.env.dev` + `.env.prod` committed, CI pushes `:dev` and `:prod` separately
  - [ ] Anime-APP: `.env.prod` committed, CI pushes `:prod`
  - [ ] Both have `docker-compose.deploy.yaml` with Watchtower labels

### Step 7: Server Deployment — HomeUI (dev + prod) + Anime-APP (prod only)

- **Project**: HomeStructure (server-side)
- **Directory**: Server via `ssh lab`
- **Depends on**: Step 6
- **Changes**:
  **HomeUI (dev first, then prod):**
  1. `~/dev/HomeUI/.env` — merge `.env.dev` template + server-only secrets (API URLs, etc.)
  2. `~/dev/HomeUI/docker-compose.deploy.yaml` — copy from repo
  3. Pull + start dev container → verify `lab-dev.922-studio.com`
  4. `~/HomeUI/.env` — merge `.env.prod` template + server-only secrets
  5. `~/HomeUI/docker-compose.deploy.yaml` — copy from repo
  6. Pull + start prod container → verify `lab.922-studio.com`
  7. Verify both HomeUI environments can call HomeAPI and HomeCollector

  **Anime-APP (prod only):**
  8. `~/Anime-APP/.env` — from `.env.prod` template + any server secrets
  9. `~/Anime-APP/docker-compose.deploy.yaml` — copy from repo
  10. Pull + start → verify `anime.922-studio.com`

  **All:**
  11. Verify Watchtower picks up all new containers (3 total: `dev_homeui`, `homeui`, `anime_app`)
  12. Push trivial change to HomeUI `dev` → confirm auto-deploy on dev container
- **Acceptance criteria**:
  - [ ] HomeUI dev (`dev_homeui`) running from `:dev` tag, prod (`homeui`) from `:prod` tag
  - [ ] Anime-APP (`anime_app`) running from `:prod` tag
  - [ ] `lab.922-studio.com`, `lab-dev.922-studio.com`, `anime.922-studio.com` all responding
  - [ ] Watchtower monitoring all 3 containers
  - [ ] HomeUI → HomeAPI/HomeCollector integration verified on both dev and prod

### Step 8: Anime-API — Registry Migration (prod only)

- **Project**: Anime-API
- **Directory**: `/Users/gregor/dev/922/Anime-API`
- **Depends on**: Step 7 (Anime-APP deployed, validates API consumers work)
- **Context files to read**:
  - `projects/anime-api.md` — project mapping
  - `plans/generic-registry-cicd-rollout.md`
  - Current Dockerfile, compose, workflows
- **Changes**:
  1. Review Dockerfile — check if DB migrations needed (add entrypoint if so)
  2. Create `docker-compose.deploy.yaml` with `${IMAGE_TAG:-prod}`, Watchtower label
  3. Create `.env.prod` in repo:
     ```env
     IMAGE_TAG=prod
     CONTAINER_NAME=anime_api
     TRAEFIK_HOST=anime-api.922-studio.com
     API_PORT=8020
     DB_HOST=shared_postgres
     DB_NAME=anime_api
     ```
  4. Refactor CI: push to `main` → `:prod` + `:prod-vX.Y.Z`
  5. Add secrets + environment on GitHub
  6. Push and verify
- **Acceptance criteria**:
  - [ ] `.env.prod` committed in repo
  - [ ] CI pushes `registry.922-studio.com/anime-api:prod`
  - [ ] `docker-compose.deploy.yaml` with Watchtower label

### Step 9: Server Deployment — Anime-API (prod only)

- **Project**: HomeStructure (server-side)
- **Directory**: Server via `ssh lab`
- **Depends on**: Step 8
- **Changes**:
  1. `~/Anime-API/.env` — from `.env.prod` template + server-only secrets (DB_PASSWORD, etc.)
  2. `~/Anime-API/docker-compose.deploy.yaml` — copy from repo
  3. Pull + start → verify `anime-api.922-studio.com` responds
  4. Verify Watchtower picks it up
  5. Verify Anime-APP → Anime-API integration still works
- **Acceptance criteria**:
  - [ ] Container running from `registry.922-studio.com/anime-api:prod`
  - [ ] API endpoints respond
  - [ ] Watchtower monitoring

### Step 10: HomeAPI — Registry Migration (dev + prod)

- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: Step 11 (HomeCollector)
- **Depends on**: Step 9 (simpler services validated first)
- **Context files to read**:
  - `projects/homeapi.md` — project mapping
  - `plans/generic-registry-cicd-rollout.md` — Python/Alembic variant
  - `plans/2026-03-24-dev-prod-environment-split.md` — existing dev/prod setup
  - Current Dockerfile, compose, workflows
- **Changes**:
  1. Create `entrypoint.sh` with Alembic migration
  2. Update Dockerfile: copy `alembic/` + `alembic.ini`, set ENTRYPOINT
  3. Create `docker-compose.deploy.yaml` — **must include all containers**: api, worker (Celery), beat (Celery scheduler), flower (optional monitoring). All parameterized via env vars:
     ```yaml
     services:
       api:
         image: registry.922-studio.com/homeapi:${IMAGE_TAG:-dev}
         container_name: ${CONTAINER_PREFIX:-}home_api_api
         labels: ["com.centurylinklabs.watchtower.enable=true"]
       worker:
         image: registry.922-studio.com/homeapi:${IMAGE_TAG:-dev}
         container_name: ${CONTAINER_PREFIX:-}home_api_worker
         command: celery -A app.worker worker
         labels: ["com.centurylinklabs.watchtower.enable=true"]
       beat:
         image: registry.922-studio.com/homeapi:${IMAGE_TAG:-dev}
         container_name: ${CONTAINER_PREFIX:-}home_api_beat
         command: celery -A app.worker beat
         labels: ["com.centurylinklabs.watchtower.enable=true"]
       flower:
         image: registry.922-studio.com/homeapi:${IMAGE_TAG:-dev}
         container_name: ${CONTAINER_PREFIX:-}home_api_flower
         command: celery -A app.worker flower
         labels: ["com.centurylinklabs.watchtower.enable=true"]
     ```
  4. Handle multi-container complexity: only the `api` container runs migrations in entrypoint; worker/beat/flower use same image but different CMD
  5. Create `.env.dev` in repo:
     ```env
     IMAGE_TAG=dev
     CONTAINER_PREFIX=dev_
     COMPOSE_PROJECT_NAME=homeapi-dev
     TRAEFIK_HOST=lab-api-dev.922-studio.com
     ROUTER_NAME=homeapi-dev
     API_PORT=8180
     FLOWER_PORT=5655
     DB_HOST=dev_postgres
     DB_PORT=5433
     DB_NAME=dev_home_api
     REDIS_HOST=dev_redis
     REDIS_PORT=6380
     CELERY_BROKER_DB=0
     ```
  6. Create `.env.prod` in repo:
     ```env
     IMAGE_TAG=prod
     CONTAINER_PREFIX=
     COMPOSE_PROJECT_NAME=homeapi
     TRAEFIK_HOST=lab-api.922-studio.com
     ROUTER_NAME=homeapi
     API_PORT=8080
     FLOWER_PORT=5555
     DB_HOST=shared_postgres
     DB_PORT=5432
     DB_NAME=home_api
     REDIS_HOST=shared_redis
     REDIS_PORT=6379
     CELERY_BROKER_DB=0
     ```
  7. Refactor CI workflow:
     - Push to `dev` → build → test → push `:dev` + `:dev-vX.Y.Z`
     - Push to `prod` (or manual dispatch) → build → test → push `:prod` + `:prod-vX.Y.Z` (approval gate)
  8. Add GitHub secrets + environments
  9. Push to `dev`, verify CI pushes `:dev` image
- **Acceptance criteria**:
  - [ ] `entrypoint.sh` runs Alembic on API container only
  - [ ] `docker-compose.deploy.yaml` includes api + worker + beat + flower, all parameterized
  - [ ] `.env.dev` and `.env.prod` committed in repo (templates, no secrets)
  - [ ] All containers have Watchtower labels
  - [ ] CI: push to `dev` → `:dev`, push to `prod` → `:prod` (with approval)
  - [ ] Smoke test validates migration + health check

### Step 11: HomeCollector — Registry Migration (dev + prod)

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: Step 10 (HomeAPI)
- **Depends on**: Step 9
- **Context files to read**:
  - `projects/homecollector.md` — project mapping
  - `plans/generic-registry-cicd-rollout.md`
  - `plans/2026-03-24-dev-prod-environment-split.md`
  - Current Dockerfile, compose, workflows
- **Changes**: Same pattern as HomeAPI — Alembic + Celery workers, dev + prod.
  1. Create `entrypoint.sh` with Alembic migration
  2. Update Dockerfile
  3. Create `docker-compose.deploy.yaml` with api + worker + beat + flower (all parameterized)
  4. Create `.env.dev` in repo:
     ```env
     IMAGE_TAG=dev
     CONTAINER_PREFIX=dev_
     COMPOSE_PROJECT_NAME=homecollector-dev
     TRAEFIK_HOST=lab-collector-dev.922-studio.com
     ROUTER_NAME=homecollector-dev
     API_PORT=8110
     FLOWER_PORT=5656
     DB_HOST=dev_postgres
     DB_PORT=5433
     DB_NAME=dev_home_collector
     REDIS_HOST=dev_redis
     REDIS_PORT=6380
     CELERY_BROKER_DB=1
     ```
  5. Create `.env.prod` in repo:
     ```env
     IMAGE_TAG=prod
     CONTAINER_PREFIX=
     COMPOSE_PROJECT_NAME=homecollector
     TRAEFIK_HOST=lab-collector.922-studio.com
     ROUTER_NAME=homecollector
     API_PORT=8010
     FLOWER_PORT=5556
     DB_HOST=shared_postgres
     DB_PORT=5432
     DB_NAME=home_collector
     REDIS_HOST=shared_redis
     REDIS_PORT=6379
     CELERY_BROKER_DB=1
     ```
  6. Refactor CI: same dev/prod branch pattern as HomeAPI
  7. Push and verify
- **Acceptance criteria**:
  - [ ] Same as HomeAPI criteria
  - [ ] `.env.dev` + `.env.prod` committed
  - [ ] CI pushes `registry.922-studio.com/homecollector:dev` and `:prod`

### Step 12: Server Deployment — HomeAPI + HomeCollector (dev first, then prod)

- **Project**: HomeStructure (server-side)
- **Directory**: Server via `ssh lab`
- **Depends on**: Steps 10 + 11
- **Critical**: These are core services. Strict dev-first, prod-second rollout.
- **Changes**:

  **Phase A — Dev environments first:**
  1. HomeAPI dev: `~/dev/HomeAPI/.env` = `.env.dev` template + server secrets (DB_PASSWORD, SECRET_KEY, etc.)
  2. HomeAPI dev: copy `docker-compose.deploy.yaml`, pull + start all 4 containers (api, worker, beat, flower)
  3. Verify: migrations ran, `lab-api-dev.922-studio.com` responds, Celery worker processing, beat scheduling
  4. HomeCollector dev: same pattern at `~/dev/HomeCollector/`
  5. Verify: `lab-collector-dev.922-studio.com` responds, uptime polling working, beat scheduling
  6. Verify HomeUI dev → HomeAPI dev integration works

  **Phase B — Prod environments (only after dev is fully verified):**
  7. HomeAPI prod: `~/HomeAPI/.env` = `.env.prod` template + server secrets
  8. HomeAPI prod: copy `docker-compose.deploy.yaml`, pull + start all 4 containers
  9. Verify: migrations ran, `lab-api.922-studio.com` responds, Celery working
  10. HomeCollector prod: same pattern at `~/HomeCollector/`
  11. Verify: `lab-collector.922-studio.com` responds, `status.922-studio.com` returning data
  12. Verify HomeUI prod → HomeAPI prod integration works

  **Phase C — Watchtower + end-to-end:**
  13. Verify Watchtower monitors all containers (8 total: 4 per service × 2 environments)
  14. Push trivial change to HomeAPI `dev` → confirm auto-deploy on dev containers within 30s
  15. Keep old deployment directories available for 48h as rollback safety net
- **Acceptance criteria**:
  - [ ] Dev: 4 HomeAPI + 4 HomeCollector containers from `:dev` images, hitting `dev_postgres:5433`
  - [ ] Prod: 4 HomeAPI + 4 HomeCollector containers from `:prod` images, hitting `shared_postgres:5432`
  - [ ] Migrations ran on all 4 databases (dev_home_api, dev_home_collector, home_api, home_collector)
  - [ ] Celery workers processing on both environments
  - [ ] Celery beat scheduling on both environments
  - [ ] HomeUI (dev) → HomeAPI (dev) integration verified
  - [ ] HomeUI (prod) → HomeAPI (prod) integration verified
  - [ ] `status.922-studio.com` returning monitoring data
  - [ ] Watchtower monitoring all 8 containers
  - [ ] Auto-deploy verified on dev

### Step 13: Discord Bot — Registry Migration (prod only)

- **Project**: Discord Bot
- **Directory**: `/Users/gregor/dev/922/discord`
- **Depends on**: Step 12 (core services stable)
- **Context files to read**:
  - `projects/discord.md` — project mapping
  - `plans/generic-registry-cicd-rollout.md`
  - Current Dockerfile, compose, workflows
- **Changes**:
  1. Review if DB migrations needed (async SQLAlchemy) — add entrypoint if so
  2. Create `docker-compose.deploy.yaml` with `${IMAGE_TAG:-prod}`, Watchtower label
  3. Create `.env.prod` in repo:
     ```env
     IMAGE_TAG=prod
     CONTAINER_NAME=discord_bot
     DB_HOST=shared_postgres
     DB_NAME=discord_bot
     ```
  4. Note: Discord Bot connects to HomeAPI — include `homeapi_default` network in deploy compose
  5. Refactor CI: push to `main` → `:prod` + `:prod-vX.Y.Z`
  6. Add secrets + environment on GitHub
  7. Push and verify
- **Acceptance criteria**:
  - [ ] `.env.prod` committed in repo
  - [ ] CI pushes `registry.922-studio.com/discord-bot:prod`
  - [ ] Bot container has correct network access to HomeAPI

### Step 14: Server Deployment — Discord Bot (prod only)

- **Project**: HomeStructure (server-side)
- **Depends on**: Step 13
- **Changes**:
  1. `~/Discord/.env` — from `.env.prod` template + server secrets (DISCORD_BOT_TOKEN, DB_PASSWORD, etc.)
  2. `~/Discord/docker-compose.deploy.yaml` — copy from repo
  3. Pull + start
  4. Verify bot comes online in Discord
  5. Test bot commands that call HomeAPI (debts, ideas, etc.)
  6. Verify Watchtower monitors the container
- **Acceptance criteria**:
  - [ ] Container running from `registry.922-studio.com/discord-bot:prod`
  - [ ] Bot online and responding
  - [ ] HomeAPI integration working
  - [ ] Watchtower monitoring

### Step 15: Sweatvalley Bingo — Registry Migration (prod only)

- **Project**: Sweatvalley Bingo
- **Directory**: `/Users/gregor/dev/922/sweatvalley_bingo`
- **Depends on**: Step 14 (all higher-priority services done)
- **Context files to read**:
  - `projects/sweatvalley-bingo.md` — project mapping
  - Current Dockerfile, compose, workflows
- **Changes**:
  1. Review Dockerfile — Express + React + Socket.io, no DB
  2. Create `docker-compose.deploy.yaml` with `${IMAGE_TAG:-prod}`, Watchtower label
  3. Create `.env.prod` in repo:
     ```env
     IMAGE_TAG=prod
     CONTAINER_NAME=sweatvalley-bingo
     TRAEFIK_HOST=sweatvalley-bingo.922-studio.com
     PORT=3923
     ```
  4. Refactor CI: push to `main` → `:prod` + `:prod-vX.Y.Z`
  5. Add secrets + environment on GitHub
  6. Push and verify
- **Acceptance criteria**:
  - [ ] `.env.prod` committed in repo
  - [ ] CI pushes `registry.922-studio.com/sweatvalley-bingo:prod`
  - [ ] Watchtower label set

### Step 16: Server Deployment — Sweatvalley Bingo (prod only)

- **Project**: HomeStructure (server-side)
- **Depends on**: Step 15
- **Changes**:
  1. `~/Sweatvalley/.env` — from `.env.prod` template + any server secrets
  2. `~/Sweatvalley/docker-compose.deploy.yaml` — copy from repo
  3. Pull + start
  4. Verify `sweatvalley-bingo.922-studio.com` responds
  5. Verify WebSocket (Socket.io) still works
  6. Verify Watchtower monitors
- **Acceptance criteria**:
  - [ ] Container running from `registry.922-studio.com/sweatvalley-bingo:prod`
  - [ ] Site accessible and functional
  - [ ] Socket.io connections work
  - [ ] Watchtower monitoring

### Step 17: Full Ecosystem Verification

- **Project**: All
- **Directory**: Server via `ssh lab`
- **Depends on**: All previous steps
- **Changes**: None — verification only.
- **Checks**:
  1. Run `docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"` — all containers should show `registry.922-studio.com/*` images with correct `:dev` or `:prod` tags
  2. Run `docker logs watchtower --tail 100` — verify all labeled containers are being watched
  3. Check Watchtower container count matches expected (count all `com.centurylinklabs.watchtower.enable=true` labels)
  4. **Verify all prod domains respond:**
     ```bash
     for domain in gregor.922-studio.com studio.922-studio.com auth.922-studio.com lab.922-studio.com anime.922-studio.com anime-api.922-studio.com lab-api.922-studio.com lab-collector.922-studio.com status.922-studio.com drafter.922-studio.com sweatvalley-bingo.922-studio.com; do
       echo "PROD $domain: $(curl -s -o /dev/null -w '%{http_code}' https://$domain)"
     done
     ```
  5. **Verify all dev domains respond:**
     ```bash
     for domain in auth-dev.922-studio.com lab-dev.922-studio.com lab-api-dev.922-studio.com lab-collector-dev.922-studio.com drafter-dev.922-studio.com; do
       echo "DEV  $domain: $(curl -s -o /dev/null -w '%{http_code}' https://$domain)"
     done
     ```
  6. **Verify dev containers use dev infrastructure:**
     - Dev containers connect to `dev_postgres:5433` (not `shared_postgres:5432`)
     - Dev containers connect to `dev_redis:6380` (not `shared_redis:6379`)
     - Check via container env: `docker inspect dev_home_api_api --format '{{range .Config.Env}}{{println .}}{{end}}' | grep DB_`
  7. **Verify prod containers use prod infrastructure:**
     - Same check for prod containers against `shared_postgres:5432` and `shared_redis:6379`
  8. Verify HomeCollector uptime checks report all services as UP
  9. Verify Grafana dashboards show healthy metrics for both environments
  10. **Auto-deploy test (dev):** push trivial change to HomeAPI `dev` → confirm Watchtower deploys dev containers within 30s, prod containers untouched
  11. **Auto-deploy test (prod-only service):** push trivial change to Portfolio `main` → confirm Watchtower deploys within 30s
- **Acceptance criteria**:
  - [ ] All containers using registry images with correct tags (`:dev` for dev, `:prod` for prod)
  - [ ] All 11 prod domains responding (2xx or 3xx)
  - [ ] All 5 dev domains responding (2xx or 3xx)
  - [ ] Dev containers isolated to dev_postgres + dev_redis
  - [ ] Prod containers isolated to shared_postgres + shared_redis
  - [ ] Watchtower monitoring all services (both dev and prod containers)
  - [ ] HomeCollector reports all UP
  - [ ] Auto-deploy verified: dev push only updates dev, prod push only updates prod

### Step 18: Cleanup Old Deployment Artifacts

- **Project**: All projects + HomeStructure (server-side)
- **Depends on**: Step 17 (everything verified working)
- **Changes**:
  1. Remove old `deploy.sh` scripts that used SSH + git pull pattern (or update them to use registry pull)
  2. Remove old deploy workflows that SSH into the server
  3. Remove git repos from server that are no longer needed (services now pull from registry, not git)
     - **Keep**: HomeStructure (still managed via git on server)
     - **Remove**: `~/HomeAPI`, `~/HomeAuth`, `~/HomeCollector`, `~/HomeUI`, `~/Portfolio`, etc. (after confirming deploy compose + .env are in place)
  4. Update `homelab-ctl.sh` if any paths or compose file references changed
  5. Update HomeCollector uptime checks if endpoints changed
  6. Add `REGISTRY_USERNAME` + `REGISTRY_PASSWORD` secrets to any repos that are missing them
  7. Prune unused Docker images on server: `docker image prune -a --filter "until=24h"`
- **Acceptance criteria**:
  - [ ] No services depend on git pull for deployment
  - [ ] Server disk space recovered from old git repos
  - [ ] `homelab-ctl.sh` works with new layout

### Step 19: Update Documentation

- **Project**: HomeStructure, Planner
- **Depends on**: Step 18
- **Changes**:
  1. Update `HomeStructure/docs/services/watchtower.md` — list all monitored containers
  2. Update each project's `projects/<name>.md` in Planner — change Pipeline & Deployment section to reflect registry-based pattern
  3. Update `server.md` if any ports, containers, or paths changed
  4. Update `registry.md` if dependencies changed
  5. Commit and push HomeStructure docs (triggers MkDocs rebuild)
- **Acceptance criteria**:
  - [ ] All project mappings reflect new deployment pattern
  - [ ] Watchtower docs list all monitored services
  - [ ] Server reference accurate

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 — Static Sites (parallel):
  Step 1: Portfolio registry migration     → Portfolio @ /Users/gregor/dev/922/portfolio
  Step 2: Studio registry migration        → Studio @ /Users/gregor/dev/922/studio

Wave 2 — Server Deploy + Verify Wave 1:
  Step 3: Deploy Portfolio + Studio        → Server via ssh lab

Wave 3 — First Python Service:
  Step 4: HomeAuth registry migration      → HomeAuth @ /Users/gregor/dev/922/HomeAuth

Wave 4 — Server Deploy HomeAuth:
  Step 5: Deploy HomeAuth                  → Server via ssh lab

Wave 5 — Frontend SPAs (parallel):
  Step 6: HomeUI + Anime-APP migration     → HomeUI + Anime-APP

Wave 6 — Server Deploy Frontends:
  Step 7: Deploy HomeUI + Anime-APP        → Server via ssh lab

Wave 7 — Simple Backend:
  Step 8: Anime-API registry migration     → Anime-API @ /Users/gregor/dev/922/Anime-API

Wave 8 — Server Deploy Anime-API:
  Step 9: Deploy Anime-API                 → Server via ssh lab

Wave 9 — Core Services (parallel):
  Step 10: HomeAPI registry migration      → HomeAPI @ /Users/gregor/dev/922/HomeAPI
  Step 11: HomeCollector migration         → HomeCollector @ /Users/gregor/dev/922/HomeCollector

Wave 10 — Server Deploy Core Services:
  Step 12: Deploy HomeAPI + HomeCollector  → Server via ssh lab (dev first, then prod)

Wave 11 — Discord Bot:
  Step 13: Discord Bot migration           → Discord @ /Users/gregor/dev/922/discord
  Step 14: Deploy Discord Bot              → Server via ssh lab

Wave 12 — Sweatvalley Bingo:
  Step 15: Sweatvalley Bingo migration     → Sweatvalley @ /Users/gregor/dev/922/sweatvalley_bingo
  Step 16: Deploy Sweatvalley Bingo        → Server via ssh lab

Wave 13 — Verify + Cleanup:
  Step 17: Full ecosystem verification     → Server via ssh lab
  Step 18: Cleanup old artifacts           → All projects + server
  Step 19: Update documentation            → HomeStructure + Planner
```

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Service downtime during migration | Deploy dev environment first, verify, then prod. Keep old deployment ready for instant rollback. |
| Watchtower updates during migration | Watchtower only watches labeled containers — new containers are labeled, old ones are not. Clean cutover. |
| Celery workers miss image update | All containers (api + worker + beat) use same image and Watchtower label → updated atomically. If timing issues occur, `docker compose restart` to realign. |
| Database migrations fail on startup | Smoke tests in CI catch migration issues before push. Entrypoint logs migration output for debugging. |
| Registry unavailable | Watchtower retries on next poll. Existing containers keep running with last image. |
| Multi-container services restart order | Watchtower restarts containers individually. API container runs migrations; workers reconnect automatically. |

## Rollback

Per service:
```bash
# Stop Watchtower from updating
docker stop watchtower

# Pin to last known good version
docker tag registry.922-studio.com/SERVICE:dev-vX.Y.Z registry.922-studio.com/SERVICE:dev
docker push registry.922-studio.com/SERVICE:dev

# Or revert to old deployment
cd ~/SERVICE && git pull && docker compose up -d --build

# Restart Watchtower
docker start watchtower
```

## Post-Execution Checklist

- [ ] All 10 services migrated to registry-based deployment
- [ ] All containers running from `registry.922-studio.com/*` images with correct `:dev`/`:prod` tags
- [ ] Watchtower monitoring all service containers (dev and prod)
- [ ] All 11 prod domains responding
- [ ] All 5 dev domains responding
- [ ] Dev containers isolated to dev_postgres + dev_redis
- [ ] Prod containers isolated to shared_postgres + shared_redis
- [ ] `.env.dev` and `.env.prod` committed in all repos with dev/prod split (no secrets)
- [ ] `.env.prod` committed in all prod-only repos (no secrets)
- [ ] Server `.env` files contain full config (template values + secrets)
- [ ] CI/CD pipelines green on all repos
- [ ] Dev branch push → `:dev` image only (for dev/prod services)
- [ ] Prod branch push → `:prod` image only (for dev/prod services, with approval gate)
- [ ] Main branch push → `:prod` image (for prod-only services)
- [ ] HomeCollector reports all services UP
- [ ] Auto-deploy verified: dev push updates dev only, prod push updates prod only
- [ ] Old deployment artifacts cleaned up
- [ ] Documentation updated across all project mappings
- [ ] No SSH deploy steps remain in any pipeline
