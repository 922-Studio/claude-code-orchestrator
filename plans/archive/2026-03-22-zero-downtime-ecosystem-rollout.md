# Plan: Zero-Downtime Deployment — Ecosystem Rollout

- **Date**: 2026-03-22
- **Project(s)**: Discord, Sweatvalley-Bingo, Anime-APP, HomeUI, HomeAPI
- **Goal**: Roll out the zero-downtime deployment strategy to all remaining repos and align existing implementations to the gold standard pattern.

## Context

Read these files before proceeding:
- `plans/2026-03-21-zero-downtime-deployments.md` — Original plan (HomeUI + Portfolio)
- `guides/new-service-setup.md` — New service setup guide (needs update)

## Current State

### Gold Standard Pattern (HomeAPI/HomeCollector/HomeAuth/HomeSocial/Anime-API)
These repos have the **complete** pattern:
- `SKIP_PULL` support
- Pre-build cache cleanup (`docker builder prune -f`, `docker image prune -f`)
- Build-first with retry logic (`--no-cache` fallback)
- `docker compose up -d --wait --wait-timeout 120`
- Healthchecks in `docker-compose.yaml`

### Already Compliant but Simpler (HomeUI, Portfolio)
- Build-first pattern ✓
- `--wait` flag ✓
- Healthchecks ✓
- **Missing**: `SKIP_PULL`, pre-build cache cleanup, build retry with `--no-cache`

### Needs Full Update (2 repos)

| Repo | Issues |
|------|--------|
| **Discord** | Has `docker compose down` before build. No `SKIP_PULL`. No cache cleanup. No retry logic. No healthcheck (bot, no HTTP). |
| **Sweatvalley-Bingo** | Has `docker compose down \|\| true`. Uses `--build` instead of separate build step. No `--wait`. Manual `sleep 5` + curl healthcheck instead of Docker-native. No cache cleanup. No retry logic. |

### Missing Healthcheck Only (1 repo)

| Repo | Issues |
|------|--------|
| **Anime-APP** | deploy.sh is gold standard ✓, but `docker-compose.yaml` has **no healthcheck**. Uses `nginx:stable-alpine` (needs `curl` install like HomeUI). |

### HomeUI deploy.sh Uplift
HomeUI's deploy.sh works but is simpler than the gold standard. Should be aligned for consistency: add `SKIP_PULL`, cache cleanup, and build retry logic.

## Steps

### Step 1: Update Discord deploy.sh
- **Project**: Discord
- **Directory**: `/Users/gregor/dev/922/discord`
- **Parallel with**: Steps 2, 3, 4, 5
- **Description**: Update `deploy.sh` to gold standard pattern. Discord is a bot (no HTTP endpoint), so no healthcheck in docker-compose.yaml. The `--wait` flag still works — it waits for the container to be `running` (or `healthy` if healthcheck defined).
- **Context files to read**:
  - `deploy.sh` — current deploy script
  - `docker-compose.yaml` — current compose config
- **Changes**:

  **`deploy.sh`** — replace with:
  ```bash
  #!/bin/bash
  set -e

  echo "Starting deployment..."

  cd ~/discord

  # Pull latest code from GitHub (skip if SKIP_PULL=true)
  if [ "${SKIP_PULL}" != "true" ]; then
    echo "Pulling latest code from GitHub..."
    git pull origin main
  else
    echo "Skipping git pull (SKIP_PULL=true)"
  fi

  # Clean up Docker build cache and unused images BEFORE building
  echo "Cleaning up Docker build cache and unused images..."
  docker builder prune -f
  docker image prune -f

  # Build new images WHILE old containers are still running (zero-downtime)
  echo "Building new images (existing services still running)..."
  if ! docker compose build; then
    echo "Build failed, retrying with --no-cache..."
    docker builder prune -af
    docker compose build --no-cache
  fi

  # Swap: recreate only changed containers with the new images
  echo "Swapping to new containers..."
  docker compose up -d --wait --wait-timeout 120

  # Show container status
  echo "Deployment complete!"
  echo ""
  echo "Container status:"
  docker compose ps

  echo ""
  echo "Recent logs:"
  docker compose logs --tail=50
  ```

- **Acceptance criteria**:
  - [ ] No `docker compose down` in `deploy.sh`
  - [ ] Build-first with retry logic
  - [ ] `SKIP_PULL` support
  - [ ] Pre-build cache cleanup
  - [ ] Commit and push to main

### Step 2: Update Sweatvalley-Bingo deploy.sh
- **Project**: Sweatvalley-Bingo
- **Directory**: `/Users/gregor/dev/922/sweatvalley_bingo`
- **Parallel with**: Steps 1, 3, 4, 5
- **Description**: Replace old pattern with gold standard. Remove manual `sleep 5` + curl healthcheck — Docker's native healthcheck (already in docker-compose.yml) + `--wait` handles this properly.
- **Context files to read**:
  - `deploy.sh` — current deploy script
  - `docker-compose.yml` — verify healthcheck exists (it does: wget on port 3001)
- **Changes**:

  **`deploy.sh`** — replace with:
  ```bash
  #!/bin/bash
  set -e

  echo "Starting deployment..."

  cd ~/sweatvalley_bingo

  # Pull latest code from GitHub (skip if SKIP_PULL=true)
  if [ "${SKIP_PULL}" != "true" ]; then
    echo "Pulling latest code from GitHub..."
    git pull origin main
  else
    echo "Skipping git pull (SKIP_PULL=true)"
  fi

  # Clean up Docker build cache and unused images BEFORE building
  echo "Cleaning up Docker build cache and unused images..."
  docker builder prune -f
  docker image prune -f

  # Build new images WHILE old containers are still running (zero-downtime)
  echo "Building new images (existing services still running)..."
  if ! docker compose build; then
    echo "Build failed, retrying with --no-cache..."
    docker builder prune -af
    docker compose build --no-cache
  fi

  # Swap: recreate only changed containers with the new images
  echo "Swapping to new containers..."
  docker compose up -d --wait --wait-timeout 120

  # Show container status
  echo "Deployment complete!"
  echo ""
  echo "Container status:"
  docker compose ps

  echo ""
  echo "Recent logs:"
  docker compose logs --tail=50
  ```

- **Acceptance criteria**:
  - [ ] No `docker compose down` in `deploy.sh`
  - [ ] No manual `sleep` + curl healthcheck
  - [ ] Build-first with retry logic
  - [ ] `--wait` flag for native healthcheck integration
  - [ ] Commit and push to main

### Step 3: Add healthcheck to Anime-APP docker-compose.yaml + Dockerfile
- **Project**: Anime-APP
- **Directory**: `/Users/gregor/dev/922/Anime-APP`
- **Parallel with**: Steps 1, 2, 4, 5
- **Description**: Anime-APP's deploy.sh is already gold standard, but docker-compose.yaml has no healthcheck. Since it uses `nginx:stable-alpine`, install `curl` (same fix as HomeUI) and add healthcheck.
- **Context files to read**:
  - `docker-compose.yaml` — add healthcheck
  - `dockerfile` — add `curl` installation
- **Changes**:

  **`docker-compose.yaml`** — add healthcheck block:
  ```yaml
  services:
    app:
      build:
        context: .
        dockerfile: dockerfile
      container_name: anime_app
      ports:
        - "${APP_PORT:-8021}:80"
      restart: unless-stopped
      networks:
        - proxy
      healthcheck:
        test: ["CMD", "curl", "-f", "http://localhost:80/"]
        interval: 5s
        timeout: 3s
        retries: 5
        start_period: 10s
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.anime-app.rule=Host(`anime.922-studio.com`)"
        - "traefik.http.routers.anime-app.entrypoints=web"
        - "traefik.http.services.anime-app.loadbalancer.server.port=80"

  networks:
    proxy:
      external: true
  ```

  **`dockerfile`** — add curl to production stage:
  ```dockerfile
  FROM nginx:stable-alpine

  RUN apk add --no-cache curl

  COPY --from=build /app/dist /usr/share/nginx/html
  ```

- **Acceptance criteria**:
  - [ ] Healthcheck defined in `docker-compose.yaml`
  - [ ] `curl` installed in Dockerfile
  - [ ] Commit and push to main

### Step 4: Uplift HomeUI deploy.sh to gold standard
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Steps 1, 2, 3, 5
- **Description**: HomeUI's deploy.sh works but lacks `SKIP_PULL`, pre-build cache cleanup, and build retry logic. Align with gold standard for consistency.
- **Context files to read**:
  - `deploy.sh` — current simpler version
- **Changes**:

  **`deploy.sh`** — replace with:
  ```bash
  #!/bin/bash
  set -e

  echo "Starting HomeUI deployment..."

  cd ~/HomeUI

  # Pull latest code from GitHub (skip if SKIP_PULL=true)
  if [ "${SKIP_PULL}" != "true" ]; then
    echo "Pulling latest code from GitHub..."
    git pull origin main
  else
    echo "Skipping git pull (SKIP_PULL=true)"
  fi

  # Clean up Docker build cache and unused images BEFORE building
  echo "Cleaning up Docker build cache and unused images..."
  docker builder prune -f
  docker image prune -f

  # Build new image WHILE old container is still running (zero-downtime)
  echo "Building new image (old container still serving)..."
  if ! docker compose build; then
    echo "Build failed, retrying with --no-cache..."
    docker builder prune -af
    docker compose build --no-cache
  fi

  # Swap: stop old container, start new one (~2-3s downtime)
  echo "Swapping to new container..."
  docker compose up -d --wait --wait-timeout 120

  # Show container status
  echo "Deployment complete!"
  echo ""
  echo "Container status:"
  docker compose ps

  echo ""
  echo "Recent logs:"
  docker compose logs --tail=50
  ```

- **Acceptance criteria**:
  - [ ] `SKIP_PULL` support added
  - [ ] Pre-build cache cleanup added
  - [ ] Build retry with `--no-cache` fallback
  - [ ] Commit and push to main

### Step 5: Fix HomeAPI deploy.sh — Remove Caddy reference
- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: Steps 1, 2, 3, 4
- **Description**: HomeAPI's deploy.sh has a stale comment referencing Caddy and connects to `lab-network`. Caddy is not in the ecosystem — Traefik handles routing. This line should be removed or corrected.
- **Context files to read**:
  - `deploy.sh` — lines 35-37 reference Caddy/lab-network
- **Changes**:

  Remove lines 35-37:
  ```bash
  # DELETE these lines:
  # Connect API container to shared lab-network so Caddy can route to it by name
  echo "Connecting home_api_api to lab-network..."
  docker network connect lab-network home_api_api 2>/dev/null || true
  ```

  > Note: Verify with Gregor whether `lab-network` connection is still needed for any other reason. If it's only for Caddy routing, remove it. Traefik uses the `proxy` network defined in docker-compose.yaml.

- **Acceptance criteria**:
  - [ ] No Caddy references in deploy.sh
  - [ ] Verify `lab-network` is unused before removing
  - [ ] Commit and push to main

### Step 6: Update new-service-setup guide
- **Project**: Planner
- **Directory**: `/Users/gregor/dev/922/Planner`
- **Parallel with**: — (after Steps 1-5, needs final pattern)
- **Description**: Update `guides/new-service-setup.md` to include the zero-downtime deployment pattern in the deployment section (Schritt 9). Add the gold standard `deploy.sh` template and document the healthcheck requirement.
- **Changes to `guides/new-service-setup.md`**:

  1. **Schritt 4** — docker-compose template already has healthcheck ✓
  2. **Schritt 9 (Deployment)** — Replace the manual deployment section with:
     - Gold standard `deploy.sh` template (with `SKIP_PULL`, cache cleanup, retry, `--wait`)
     - Document that `docker compose down` must NEVER be used
     - Note about frontend services needing `curl` installed for healthcheck
  3. **Checkliste** — Add:
     - `deploy.sh` follows zero-downtime pattern (build-first, no `docker compose down`)
     - Healthcheck defined for all services with HTTP endpoints

- **Acceptance criteria**:
  - [ ] Schritt 9 includes gold standard deploy.sh template
  - [ ] Checkliste updated with deployment requirements
  - [ ] Commit and push to main

### Step 7: Update zero-downtime plan as reference
- **Project**: Planner
- **Directory**: `/Users/gregor/dev/922/Planner`
- **Parallel with**: Step 6
- **Description**: Mark the original plan (`plans/2026-03-21-zero-downtime-deployments.md`) as completed and reference this rollout plan. Update the ecosystem-wide status.
- **Acceptance criteria**:
  - [ ] Original plan marked complete
  - [ ] This plan referenced as follow-up

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (all parallel):
  Step 1: Update Discord deploy.sh         → Discord   @ /Users/gregor/dev/922/discord
  Step 2: Update Sweatvalley deploy.sh     → Bingo     @ /Users/gregor/dev/922/sweatvalley_bingo
  Step 3: Add Anime-APP healthcheck        → Anime-APP @ /Users/gregor/dev/922/Anime-APP
  Step 4: Uplift HomeUI deploy.sh          → HomeUI    @ /Users/gregor/dev/922/HomeUI
  Step 5: Fix HomeAPI Caddy reference      → HomeAPI   @ /Users/gregor/dev/922/HomeAPI

Wave 2 (after Wave 1):
  Step 6: Update new-service-setup guide   → Planner   @ /Users/gregor/dev/922/Planner
  Step 7: Update plan references           → Planner   @ /Users/gregor/dev/922/Planner
```

## Post-Execution Checklist
- [ ] All deploy.sh scripts follow gold standard pattern
- [ ] All HTTP services have Docker healthchecks
- [ ] No `docker compose down` anywhere in the ecosystem
- [ ] New service guide updated with deployment requirements
- [ ] All pipelines green after push
