# Plan: Zero-Downtime Deployments for HomeUI & Portfolio

- **Date**: 2026-03-21
- **Project(s)**: HomeUI, Portfolio
- **Goal**: Eliminate 1-3 minute downtime during deployments by building images before stopping containers and adding Docker healthchecks.

## Context

Read these files before proceeding:
- `projects/homeui.md` — HomeUI project mapping
- `projects/portfolio.md` — Portfolio project mapping
- `server.md` — Server infrastructure reference

## Root Cause

Both `deploy.sh` scripts follow this order:
1. `docker compose down` — **kills running container immediately**
2. `docker compose build` — builds new image (1-3 min, site is DOWN)
3. `docker compose up -d` — starts new container

The site is unavailable for the entire duration of step 2.

## Solution

**Build-first strategy**: Build the new Docker image while the old container is still serving traffic, then do a quick container swap.

New deploy order:
1. `docker compose build` — builds new image (old container keeps serving)
2. `docker compose up -d --wait` — stops old container, starts new one (~2-3s swap)

Additionally, add Docker healthchecks to `docker-compose.yaml` so `--wait` properly verifies the new container is healthy before reporting success. This also benefits Traefik routing.

## Steps

### Step 1: Update HomeUI deploy.sh + docker-compose.yaml
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 2
- **Description**:
  1. Update `deploy.sh`: Remove `docker compose down` line. Move `docker compose build` before `docker compose up`. The `up -d` command automatically recreates containers when the image changes.
  2. Add healthcheck to `docker-compose.yaml` using `curl` on the Nginx endpoint.
- **Context files to read**:
  - `deploy.sh` — current deploy script
  - `docker-compose.yaml` — current compose config
  - `nginx.conf` — verify health endpoint (root `/` returns 200)
- **Changes**:

  **`deploy.sh`** — new version:
  ```bash
  #!/bin/bash
  set -e

  echo "Starting HomeUI deployment..."

  cd ~/HomeUI

  echo "Pulling latest code from GitHub..."
  git pull origin main

  # Build new image while old container keeps serving traffic
  echo "Building new image (old container still serving)..."
  docker compose build

  # Quick swap: stop old container, start new one (~2-3s downtime)
  echo "Swapping to new container..."
  docker compose up -d --wait --wait-timeout 120

  echo "Cleaning up unused Docker images..."
  docker image prune -f

  echo "Deployment complete!"
  echo ""
  echo "Container status:"
  docker compose ps

  echo ""
  echo "Recent logs:"
  docker compose logs --tail=50
  ```

  **`docker-compose.yaml`** — add healthcheck:
  ```yaml
  services:
    homeui:
      build:
        context: .
        dockerfile: Dockerfile
        args:
          VITE_API_BASE_URL: ${VITE_API_BASE_URL:-http://home-lab:8080}
          VITE_AUTH_URL: ${VITE_AUTH_URL:-http://home-lab:8100}
      container_name: homeui
      ports:
        - '8000:8000'
      restart: unless-stopped
      networks:
        - proxy
      healthcheck:
        test: ["CMD", "wget", "--spider", "-q", "http://localhost:8000/"]
        interval: 5s
        timeout: 3s
        retries: 5
        start_period: 10s
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.homeui.rule=Host(`lab.922-studio.com`)"
        - "traefik.http.routers.homeui.entrypoints=web"
        - "traefik.http.services.homeui.loadbalancer.server.port=8000"

  networks:
    proxy:
      name: proxy
      external: true
  ```

  > Note: Using `wget` instead of `curl` because `nginx:1.27-alpine` has `wget` built-in but not `curl`.

- **Acceptance criteria**:
  - [ ] `deploy.sh` builds before swapping containers
  - [ ] No `docker compose down` in `deploy.sh`
  - [ ] Healthcheck defined in `docker-compose.yaml`
  - [x] Commit and push to main — done 2026-03-21

### Step 2: Update Portfolio deploy.sh + docker-compose.yaml
- **Project**: Portfolio
- **Directory**: `/Users/gregor/dev/922/portfolio`
- **Parallel with**: Step 1
- **Description**:
  Same changes as Step 1 but for Portfolio. Portfolio uses Node.js runtime (not Nginx), so healthcheck uses `wget` against port 3000.
- **Context files to read**:
  - `deploy.sh` — current deploy script
  - `docker-compose.yaml` — current compose config
  - `Dockerfile` — verify runtime (Node.js standalone, port 3000)
- **Changes**:

  **`deploy.sh`** — new version:
  ```bash
  #!/bin/bash
  set -e

  echo "Starting Portfolio deployment..."

  cd ~/portfolio

  if [ "$SKIP_PULL" != "true" ]; then
    echo "Pulling latest code from GitHub..."
    git pull origin main
  fi

  # Build new image while old container keeps serving traffic
  echo "Building new image (old container still serving)..."
  docker compose build

  # Quick swap: stop old container, start new one (~2-3s downtime)
  echo "Swapping to new container..."
  docker compose up -d --wait --wait-timeout 120

  echo "Cleaning up unused Docker images..."
  docker image prune -f

  echo "Deployment complete!"
  echo ""
  echo "Container status:"
  docker compose ps

  echo ""
  echo "Recent logs:"
  docker compose logs --tail=50
  ```

  **`docker-compose.yaml`** — add healthcheck:
  ```yaml
  services:
    portfolio:
      build:
        context: .
        dockerfile: Dockerfile
        args:
          NEXT_PUBLIC_GA_MEASUREMENT_ID: G-1GSBD62ZVM
      container_name: portfolio
      restart: unless-stopped
      networks:
        - proxy
      healthcheck:
        test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/"]
        interval: 5s
        timeout: 3s
        retries: 5
        start_period: 15s
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.portfolio.rule=Host(`gregor.922-studio.com`)"
        - "traefik.http.routers.portfolio.entrypoints=web"
        - "traefik.http.services.portfolio.loadbalancer.server.port=3000"

  networks:
    proxy:
      external: true
  ```

  > Note: `start_period` is 15s (vs 10s for HomeUI) because Next.js standalone takes slightly longer to boot than Nginx.

- **Acceptance criteria**:
  - [ ] `deploy.sh` builds before swapping containers
  - [ ] No `docker compose down` in `deploy.sh`
  - [ ] `SKIP_PULL` support preserved
  - [ ] Healthcheck defined in `docker-compose.yaml`
  - [x] Commit and push to main — done 2026-03-21

### Step 3: Verify deployments
- **Project**: HomeUI, Portfolio
- **Directory**: N/A (server)
- **Parallel with**: — (after Step 1 & 2)
- **Description**: After both pushes trigger CI/CD, monitor that:
  1. Both pipelines pass (check Discord notifications)
  2. Sites remain accessible during deployment (manual check or ask Gregor to verify)
  3. Healthchecks report healthy: `ssh lab` → `docker inspect --format='{{.State.Health.Status}}' homeui portfolio`
- **Acceptance criteria**:
  - [ ] Both pipelines green
  - [ ] Healthchecks show `healthy` on server
  - [ ] Downtime reduced to seconds (verified on next deploy)

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Update HomeUI deploy.sh + healthcheck → HomeUI @ /Users/gregor/dev/922/HomeUI
  Step 2: Update Portfolio deploy.sh + healthcheck → Portfolio @ /Users/gregor/dev/922/portfolio

Wave 2 (after wave 1):
  Step 3: Verify both deployments → Server (ssh lab)
```

## Post-Execution Checklist
- [ ] All tests pass
- [ ] Both pipelines green
- [ ] Healthchecks verified on server
- [ ] No documentation changes needed (deploy.sh is self-documenting)
