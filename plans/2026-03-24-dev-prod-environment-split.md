# Plan: Dev/Prod Environment Split

- **Date**: 2026-03-24
- **Project(s)**: HomeAPI, HomeAuth, HomeUI, HomeCollector, HomeStructure, Workflows
- **Goal**: Split core Home Lab services into isolated dev and prod environments.

## Scope

**In scope (dev/prod split):**
- HomeAPI, HomeAuth, HomeUI, HomeCollector

**Out of scope (prod only):**
- Anime-API, Anime-APP, Portfolio, Studio, Sweatvalley Bingo, Discord Bot

**Removed:**
- HomeContent (being replaced by standalone Content project)
- Status page (no longer exists)

## Target Architecture

| Service | Prod Subdomain | Dev Subdomain | Prod Port | Dev Port |
|---------|---------------|---------------|-----------|----------|
| HomeAuth | `auth.922-studio.com` | `auth-dev.922-studio.com` | 8100 | 8200 |
| HomeUI | `lab.922-studio.com` | `lab-dev.922-studio.com` | 8000 | 8001 |
| HomeAPI | `lab-api.922-studio.com` | `lab-api-dev.922-studio.com` | 8080 | 8180 |
| HomeCollector | `lab-collector.922-studio.com` | `lab-collector-dev.922-studio.com` | 8010 | 8110 |

> **Note**: HomeAuth renamed from `lab-auth` to `auth`.

### Infrastructure

| Service | Prod | Dev |
|---------|------|-----|
| PostgreSQL | `shared_postgres` :5432 | `dev_postgres` :5433 |
| Redis | `shared_redis` :6379 | `dev_redis` :6380 |
| Traefik | Shared — routes both via labels on `proxy` network |
| Docker network (routing) | `proxy` | `proxy` (shared with prod, Traefik needs it) |
| Docker network (infra) | `infra` | `infra` (shared network, dev containers use different hosts) |

### Branch Strategy

| Branch | Environment | Trigger |
|--------|-------------|---------|
| `prod` | prod | push → test → deploy prod |
| `dev` (default) | dev | push → test → deploy dev |

### Database Split

| Service | Prod DB @ shared_postgres | Dev DB @ dev_postgres |
|---------|--------------------------|----------------------|
| HomeAPI | `home_api` | `dev_home_api` |
| HomeAuth | `home_auth` | `dev_home_auth` |
| HomeCollector | `home_collector` | `dev_home_collector` |

## Completed Steps

### Step 1: Dev Infrastructure (HomeStructure) ✅
- Created `infra/docker-compose.dev.yaml` — dev_postgres (:5433) + dev_redis (:6380) on `infra` network
- Created `infra/.env.dev` — dev credentials
- Created `infra/init-dev-db.sh` — creates dev databases + users
- Server provisioned: dev_postgres + dev_redis running, databases initialized

### Step 2: Shared Workflows Update ✅
- Updated `deploy-docker.yml` — accepts `environment` input (default: `prod`)
- Boot script called with environment parameter
- Success banner shows `[DEV]` or `[PROD]`

### Step 3: Parameterized Docker Compose ✅
Single `docker-compose.yaml` per project, controlled by `.env`:
- `CONTAINER_PREFIX`, `COMPOSE_PROJECT_NAME` for isolation
- `DB_HOST`, `DB_USER`, `DB_NAME`, `REDIS_HOST` for infra targeting
- `ROUTER_NAME`, `TRAEFIK_HOST` for routing
- `API_PORT`, `FLOWER_PORT` etc. for port isolation
- All services on `proxy` + `infra` networks (shared with Traefik)

### Step 4: Deploy Scripts ✅
Simplified `deploy.sh` in all 4 projects — no env parameter needed, `.env` drives everything.

### Step 5: GitHub Workflows ✅
Updated `.github/workflows/deploy.yml` in all 4 projects:
- Trigger on both `dev` and `prod` branches
- `repository_path` selects `/home/lab/dev/X` or `/home/lab/X`
- `environment` input passed to `deploy-docker.yml`

### Step 6: Cloudflare Tunnel + DNS ✅
- Added dev subdomains: `auth-dev`, `lab-dev`, `lab-api-dev`, `lab-collector-dev`
- Renamed `lab-auth` → `auth`
- Removed: `status.922-studio.com`, `lab-content.922-studio.com`

### Step 7: Server Provisioning ✅
- Dev directories: `/home/lab/dev/{HomeAPI,HomeAuth,HomeUI,HomeCollector}`
- Dev `.env` files with `COMPOSE_PROJECT_NAME=*-dev`, `CONTAINER_PREFIX=dev_`, dev ports, dev DB hosts
- All 8 containers healthy (4 prod + 4 dev per service set)

### Step 8: Branch Sync ✅ (2026-03-24)
- All repos: `dev` = `prod` (identical SHA)
- HomeAPI: `698fb99`, HomeAuth: `6159c94`, HomeUI: `1b83742`, HomeCollector: `8290972`

### Step 9: Domain Reference Cleanup ✅ (2026-03-24)
- HomeCollector: removed `homecontent_api` from `DEFAULT_MONITORED_SERVICES` (16→15)
- HomeCollector: updated OpenAPI URLs `lab-auth` → `auth.922-studio.com`
- HomeAPI: updated OpenAPI URLs `lab-auth` → `auth.922-studio.com`
- HomeUI: updated vite proxy target `lab-auth` → `auth.922-studio.com`
- Tests updated accordingly

## Remaining Steps

### Step 10: Documentation Update
- [ ] Update `server.md` with dev ports, routes, containers
- [ ] Update project mappings with branch strategy and dev URLs

## Validation Results ✅

All validated on 2026-03-24:
- [x] 8 prod services healthy, 8 dev services healthy (16 total containers)
- [x] 8 Traefik routes active (4 prod + 4 dev subdomains)
- [x] 8 Cloudflare tunnel URLs resolving
- [x] Database write isolation confirmed (dev writes to dev_postgres, prod to shared_postgres)
- [x] Push to `dev` → triggers dev deploy, push to `prod` → triggers prod deploy
- [x] All 4 repos: dev branch = prod branch (identical SHA)
