# Generic Guide: Registry-Based CI/CD Rollout

- **Date**: 2026-03-25
- **Purpose**: Step-by-step guide for migrating any project from local-build deployment to registry-based CI/CD with Watchtower auto-deployment.
- **Pilot**: Drafter (see `plans/2026-03-25-registry-cicd-drafter-pilot.md`)
- **Prerequisites**: Docker Registry running at `registry.922-studio.com`, reusable workflows updated (docker-build.yml, smoke-test.yml, deploy-docker.yml)

## Overview

### Before (local build)
```
CI → SSH to server → git pull → docker compose build → docker compose up
```

### After (registry-based)
```
CI → docker build → smoke test → unit tests → docker push to registry
Deployment server → Watchtower polls registry → pulls new image → restarts container
```

## Migration Checklist Per Project

### 1. Dockerfile Changes

Add migration entrypoint if project uses a database:

```bash
# Create entrypoint.sh
#!/bin/sh
set -e

# For Prisma projects:
if [ -d "prisma" ]; then
  echo "Running database migrations..."
  npx prisma migrate deploy
fi

# For Alembic (Python) projects:
# if [ -d "alembic" ]; then
#   echo "Running database migrations..."
#   alembic upgrade head
# fi

echo "Starting application..."
exec "$@"
```

Update Dockerfile runtime stage:
- Copy migration files (prisma/ or alembic/)
- Copy entrypoint.sh
- Set ENTRYPOINT to entrypoint.sh
- Pass original CMD as default args

### 2. Create `docker-compose.deploy.yaml`

This file is used on deployment servers (no build context):

```yaml
services:
  SERVICE_NAME:
    image: registry.922-studio.com/IMAGE_NAME:${IMAGE_TAG:-dev}
    container_name: ${CONTAINER_NAME:-service}
    restart: unless-stopped
    env_file:
      - .env
    networks:
      - proxy
      - infra   # if DB needed
    healthcheck:
      # project-specific health check
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
      # Traefik labels...
```

Keep original `docker-compose.yaml` with `build:` for local dev and CI smoke tests.

### 3. Update Environment Files

Add to `.env.dev`:
```env
IMAGE_TAG=dev
```

Add to `.env.prod`:
```env
IMAGE_TAG=prod
```

### 4. Update `deploy.sh`

Change from build-on-server to pull-from-registry:

```bash
#!/bin/bash
set -e
ENV="${1:-prod}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Load env
cp ".env.$ENV" .env

# Pull and deploy
docker login registry.922-studio.com -u "$REGISTRY_USER" -p "$REGISTRY_PASSWORD"
docker compose -f docker-compose.deploy.yaml pull
docker compose -f docker-compose.deploy.yaml up -d --wait --wait-timeout 120
docker image prune -f

echo "Deployment complete ($ENV)"
docker compose -f docker-compose.deploy.yaml ps
```

### 5. Refactor GitHub Actions Workflow

Replace the deploy.yml with the new pattern:

```yaml
jobs:
  version:        # semantic versioning
  build:          # docker build (push: false)
  smoke-test:     # isolated DB + pre-built image
  tests:          # unit/integration tests (parallel with smoke)
  push-dev:       # push image with :dev + :dev-vX.Y.Z tags
    environment: development
  push-prod:      # push image with :prod + :prod-vX.Y.Z tags
    environment: production  # approval gate
    if: workflow_dispatch + production
  notify:         # Discord
```

Use reusable workflows:
- `922-Studio/workflows/.github/workflows/docker-build.yml@main`
- `922-Studio/workflows/.github/workflows/smoke-test.yml@main`
- `922-Studio/workflows/.github/workflows/frontend-tests.yml@main` (or `python-tests.yml`)

### 6. GitHub Repository Setup

**Secrets to add:**
| Secret | Value | Purpose |
|--------|-------|---------|
| `REGISTRY_USERNAME` | `gregor` | Docker Registry login |
| `REGISTRY_PASSWORD` | (htpasswd password) | Docker Registry login |
| `PAT_GITHUB` | (existing) | Repo access |
| `DISCORD_BOT_TOKEN` | (existing) | Notifications |
| `ALLURE_TOKEN` | (existing) | Test reporting |

**Environments to create:**
| Name | Protection | Purpose |
|------|-----------|---------|
| `development` | None | Tracks dev deployments |
| `production` | Required reviewer: Gregor | Tracks prod deployments, approval gate |

### 7. Image Tagging Strategy

| Tag | Purpose | Example |
|-----|---------|---------|
| `:dev` | Mutable, Watchtower watches | `drafter:dev` |
| `:prod` | Mutable, Watchtower watches | `drafter:prod` |
| `:dev-vX.Y.Z` | Immutable, rollback/audit | `drafter:dev-v1.2.3` |
| `:prod-vX.Y.Z` | Immutable, rollback/audit | `drafter:prod-v1.2.3` |

**Rollback:** Retag an older version to the mutable tag:
```bash
docker tag registry.922-studio.com/PROJECT:dev-v1.1.0 registry.922-studio.com/PROJECT:dev
docker push registry.922-studio.com/PROJECT:dev
```

### 8. Deployment Server Setup

Per deployment server:

```bash
# 1. Docker login (creates ~/.docker/config.json for Watchtower)
docker login registry.922-studio.com

# 2. Clone/create project directory
mkdir -p ~/PROJECT_NAME
cp docker-compose.deploy.yaml ~/PROJECT_NAME/
cp .env.{dev|prod} ~/PROJECT_NAME/.env

# 3. Start the service
cd ~/PROJECT_NAME
docker compose -f docker-compose.deploy.yaml pull
docker compose -f docker-compose.deploy.yaml up -d

# 4. Watchtower handles future updates automatically
```

### 9. Migration Strategy

Read: `plans/critical-zero-downtime-migrations.md`

**Safe migrations** (add column, add table): handled automatically by container entrypoint.

**Breaking migrations** (rename, drop): two-phase expand-and-contract deployment.

### 10. Verify

After completing migration:

- [ ] Push to `dev` branch triggers build → smoke → test → push dev image
- [ ] `docker pull registry.922-studio.com/PROJECT:dev` returns the new image
- [ ] Watchtower detects and deploys within polling interval
- [ ] Container starts, runs migrations, passes health check
- [ ] Manual dispatch with prod builds and pushes prod image
- [ ] Approval gate required for production
- [ ] Discord notifications for success/failure
- [ ] Rollback via retag works

## Projects to Migrate (Priority Order)

| # | Project | Complexity | Notes |
|---|---------|-----------|-------|
| 1 | Drafter | Medium | Pilot project, Next.js + Prisma |
| 2 | HomeAPI | Medium | FastAPI + Alembic, Celery workers |
| 3 | HomeAuth | Low | Simple FastAPI, no workers |
| 4 | HomeCollector | Medium | FastAPI + Alembic, Celery workers |
| 5 | HomeUI | Low | React SPA, no DB |
| 6 | Anime-API | Low | FastAPI, simple |
| 7 | Anime-APP | Low | React SPA, no DB |
| 8 | Portfolio | Low | Next.js, static |
| 9 | Studio | Low | Next.js, static |
| 10 | Discord Bot | Medium | Python, async SQLAlchemy |
| 11 | Sweatvalley Bingo | Low | Express + React, Socket.io |

**Python projects**: Use Alembic instead of Prisma in entrypoint:
```bash
if [ -d "alembic" ]; then
  alembic upgrade head
fi
```
