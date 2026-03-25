# Plan: Registry-Based CI/CD Pipeline — Drafter Pilot

- **Date**: 2026-03-25
- **Project(s)**: Drafter, Workflows, HomeStructure
- **Goal**: Refactor Drafter's CI/CD to build images in CI, push to the self-hosted Docker Registry, and deploy via Watchtower on independent deployment servers. Establish patterns for ecosystem-wide rollout.

## Context

Read these files before proceeding:
- `projects/drafter.md` — Drafter project mapping
- `server.md` — server infrastructure reference
- `plans/critical-zero-downtime-migrations.md` — migration strategy for breaking changes
- `plans/generic-registry-cicd-rollout.md` — generic guide for rolling this out to other projects

### Current State
- Drafter CI: version → test → deploy (SSH to server, git pull, docker compose build + up)
- Reusable workflows: `deploy-docker.yml` (SSH-based), `smoke-test.yml` (builds from source)
- Server builds images locally on deploy — no registry, no multi-server support

### Target State
```
CI (runner server):
  build image → smoke-test (isolated DB) → unit tests → push to registry
  → registry.922-studio.com/drafter:dev + registry.922-studio.com/drafter:dev-v1.2.3
  → registry.922-studio.com/drafter:prod + registry.922-studio.com/drafter:prod-v1.2.3

Deployment servers (1 or more):
  Watchtower polls registry → detects new digest → pulls image → restarts container
  Container entrypoint → prisma migrate deploy → start server
  .env loaded from Syncthing-synced /home/lab/envs/drafter/.env
```

### New Pipeline Flow
```
Push to dev:
  1. cancel-previous-runs
  2. version (semantic tag)
  3. build (docker build, tag as dev-vX.Y.Z)
  4. smoke-test (isolated DB + built image, validate migrations + health)
  5. unit-tests (Vitest, pnpm test:ci)
  6. push-to-registry (push dev-vX.Y.Z + :dev mutable tag)
  7. notifications (Discord)
  GitHub Environment: development

Manual dispatch (prod):
  1-5: same as above
  6. push-to-registry (push prod-vX.Y.Z + :prod mutable tag)
  7. notifications (Discord)
  GitHub Environment: production (with approval gate)
```

## Steps

### Step 1: Create reusable `docker-build.yml` workflow
- **Project**: Workflows
- **Directory**: `/Users/gregor/dev/922/workflows/.github/workflows/`
- **Parallel with**: Step 2
- **Description**:
  Create a new reusable workflow `docker-build.yml` that builds a Docker image and optionally pushes it to a registry.

  **Inputs:**
  ```yaml
  inputs:
    registry_url:
      type: string
      required: true
      description: "Registry URL (e.g. registry.922-studio.com)"
    image_name:
      type: string
      required: true
      description: "Image name without registry prefix (e.g. drafter)"
    tag:
      type: string
      required: true
      description: "Primary image tag (e.g. dev-v1.2.3)"
    mutable_tag:
      type: string
      required: false
      description: "Mutable tag to also push (e.g. dev, prod). Watchtower watches this tag."
    build_args:
      type: string
      required: false
      description: "Build args as multiline KEY=VALUE"
    dockerfile:
      type: string
      default: "Dockerfile"
    context:
      type: string
      default: "."
    push:
      type: boolean
      default: true
      description: "Push to registry after build (false = build only, for smoke tests)"
    repository_path:
      type: string
      required: true
      description: "Absolute path to repo on self-hosted runner"
    pull_code:
      type: boolean
      default: false
      description: "Whether to git pull before building"
  secrets:
    REGISTRY_USERNAME:
      required: true
    REGISTRY_PASSWORD:
      required: true
    PAT_GITHUB:
      required: false
  outputs:
    image:
      description: "Full image reference (registry/name:tag)"
    digest:
      description: "Image digest (sha256:...)"
  ```

  **Steps:**
  1. Pull code (if `pull_code: true`)
  2. `docker login $registry_url`
  3. `docker build -t $registry_url/$image_name:$tag --build-arg ... -f $dockerfile $context`
  4. If `push: true`:
     - `docker push $registry_url/$image_name:$tag`
     - If `mutable_tag` provided: `docker tag ... :$mutable_tag && docker push ... :$mutable_tag`
  5. Output image reference and digest

- **Context files to read**:
  - `workflows/.github/workflows/deploy-docker.yml` — existing pattern for self-hosted runner workflows
  - `Drafter/Dockerfile` — understand build args needed
- **Acceptance criteria**:
  - [ ] `docker-build.yml` created in workflows repo
  - [ ] Supports build-only mode (push: false) for smoke tests
  - [ ] Supports dual-tagging (versioned + mutable)
  - [ ] Outputs image reference for downstream jobs

### Step 2: Refactor `smoke-test.yml` to support pre-built images
- **Project**: Workflows
- **Directory**: `/Users/gregor/dev/922/workflows/`
- **Parallel with**: Step 1
- **Description**:
  Extend the existing `smoke-test.yml` to accept a pre-built image instead of always building from source. The `generate_smoke_compose.py` script needs to support replacing `build:` with `image:` in the generated smoke compose config.

  **New input:**
  ```yaml
  inputs:
    prebuilt_image:
      type: string
      required: false
      description: "Pre-built image to use instead of building from source (e.g. registry.922-studio.com/drafter:dev-v1.2.3). Replaces 'build:' in compose config."
  ```

  **Changes to `generate_smoke_compose.py`:**
  - Accept `--prebuilt-image` flag
  - When provided: replace all `build:` sections with `image: <prebuilt_image>` in the output compose
  - Keep all other config (healthcheck, env, networks etc.) intact
  - The isolated DB and network are still generated fresh

  **Changes to `smoke-test.yml`:**
  - Skip "Build smoke images" step if `prebuilt_image` is provided (image already exists locally from prior build job)
  - Pass `--prebuilt-image` to `generate_smoke_compose.py`

  **For Drafter's Prisma migrations:**
  - Add `migration_service: drafter` input
  - Add `migration_success_pattern: "Running database migrations"` (from entrypoint.sh echo)
  - This validates migrations work on an isolated DB before pushing to registry

- **Context files to read**:
  - `workflows/.github/workflows/smoke-test.yml` — current implementation
  - `workflows/.github/scripts/generate_smoke_compose.py` — compose config generator
- **Acceptance criteria**:
  - [ ] `smoke-test.yml` accepts `prebuilt_image` input
  - [ ] `generate_smoke_compose.py` replaces `build:` with `image:` when flag provided
  - [ ] Smoke test still creates isolated DB and network
  - [ ] Migration verification works with Prisma pattern
  - [ ] Backward-compatible: existing callers without `prebuilt_image` still work

### Step 3: Refactor `deploy-docker.yml` to support registry pull mode
- **Project**: Workflows
- **Directory**: `/Users/gregor/dev/922/workflows/.github/workflows/`
- **Parallel with**: Steps 1, 2
- **Description**:
  Add a registry-pull deployment mode to the existing `deploy-docker.yml`. When an image is provided, the workflow pulls from registry instead of building on the server.

  **New inputs:**
  ```yaml
  inputs:
    image:
      type: string
      required: false
      description: "Registry image to pull (e.g. registry.922-studio.com/drafter:dev). When provided, skips build and does docker compose pull + up."
  secrets:
    REGISTRY_USERNAME:
      required: false
    REGISTRY_PASSWORD:
      required: false
  ```

  **New flow when `image` is provided:**
  1. SSH to server (existing pattern)
  2. `docker login` to registry
  3. `docker compose pull` (pulls the new image)
  4. `docker compose up -d --wait --wait-timeout 120` (starts with new image)
  5. Verify health
  6. Clean up old images

  **Existing flow preserved when `image` is not provided:**
  - No changes to current boot_script or default build path

  This is the **interim solution** while Watchtower is not yet set up. Once Watchtower is running, this step can be removed from the pipeline entirely.

- **Context files to read**:
  - `workflows/.github/workflows/deploy-docker.yml` — current implementation
- **Acceptance criteria**:
  - [ ] New `image` input added
  - [ ] Registry login step when `image` provided
  - [ ] `docker compose pull + up` path works
  - [ ] Existing callers without `image` input still work (backward-compatible)
  - [ ] Clean up old images after pull

### Step 4: Update Drafter Dockerfile with migration entrypoint
- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter/`
- **Parallel with**: Steps 1-3
- **Description**:
  Modify the Dockerfile to include Prisma for startup migrations and create an entrypoint script.

  **Create `entrypoint.sh`:**
  ```bash
  #!/bin/sh
  set -e

  # Run database migrations (Prisma acquires advisory lock — safe for concurrent starts)
  if [ -d "prisma" ]; then
    echo "Running database migrations..."
    npx prisma migrate deploy
    echo "Migrations complete."
  else
    echo "No prisma directory found, skipping migrations."
  fi

  echo "Starting application..."
  exec node server.js
  ```

  **Modify Dockerfile runtime stage:**
  ```dockerfile
  FROM node:22-alpine
  WORKDIR /app

  ENV NODE_ENV=production
  ENV HOSTNAME=0.0.0.0

  # Install prisma CLI for migrations
  RUN npm install -g prisma

  # Copy prisma schema + migrations for startup migrate
  COPY --from=build /app/prisma ./prisma
  COPY --from=build /app/node_modules/.prisma ./node_modules/.prisma

  # Copy standalone app
  COPY --from=build /app/.next/standalone ./
  COPY --from=build /app/.next/static ./.next/static
  COPY --from=build /app/public ./public

  # Entrypoint runs migrations then starts server
  COPY entrypoint.sh ./entrypoint.sh
  RUN chmod +x entrypoint.sh

  EXPOSE 3000

  ENTRYPOINT ["./entrypoint.sh"]
  ```

  **Note**: If Prisma is not yet initialized in Drafter, the entrypoint gracefully skips migrations (checks for `prisma/` directory). This is forward-compatible.

- **Context files to read**:
  - `Drafter/Dockerfile` — current multi-stage build
  - `plans/critical-zero-downtime-migrations.md` — migration strategy
- **Acceptance criteria**:
  - [ ] `entrypoint.sh` created
  - [ ] Dockerfile updated with prisma copy + entrypoint
  - [ ] Image still builds and runs correctly
  - [ ] Migrations run on startup if prisma directory exists
  - [ ] Graceful skip if no prisma directory

### Step 5: Update Drafter `docker-compose.yaml` for registry images
- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter/`
- **Parallel with**: Step 4
- **Description**:
  The docker-compose.yaml on deployment servers needs to use `image:` instead of `build:`. Create a deployment-specific compose file.

  **Create `docker-compose.deploy.yaml`** (used on deployment servers):
  ```yaml
  services:
    drafter:
      image: registry.922-studio.com/drafter:${IMAGE_TAG:-dev}
      container_name: ${CONTAINER_NAME:-drafter}
      restart: unless-stopped
      env_file:
        - .env
      networks:
        - proxy
        - infra
      healthcheck:
        test: ["CMD-SHELL", "node -e \"fetch('http://localhost:3000/api/health').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))\""]
        interval: 5s
        timeout: 3s
        retries: 5
        start_period: 30s
      labels:
        # Watchtower: auto-update this container
        - "com.centurylinklabs.watchtower.enable=true"
        # Public routes (no auth)
        - "traefik.enable=true"
        - "traefik.http.routers.${ROUTER_NAME:-drafter}-public.rule=Host(`${TRAEFIK_HOST:-drafter.922-studio.com}`) && (Path(`/`) || PathPrefix(`/login`) || PathPrefix(`/_next`) || PathPrefix(`/api/health`) || PathPrefix(`/favicon`))"
        - "traefik.http.routers.${ROUTER_NAME:-drafter}-public.entrypoints=web"
        - "traefik.http.routers.${ROUTER_NAME:-drafter}-public.priority=20"
        - "traefik.http.routers.${ROUTER_NAME:-drafter}-public.service=${ROUTER_NAME:-drafter}"
        # Protected routes (forward-auth via HomeAuth)
        - "traefik.http.routers.${ROUTER_NAME:-drafter}.rule=Host(`${TRAEFIK_HOST:-drafter.922-studio.com}`)"
        - "traefik.http.routers.${ROUTER_NAME:-drafter}.entrypoints=web"
        - "traefik.http.routers.${ROUTER_NAME:-drafter}.priority=10"
        - "traefik.http.routers.${ROUTER_NAME:-drafter}.middlewares=auth-verify@file"
        # Service port
        - "traefik.http.services.${ROUTER_NAME:-drafter}.loadbalancer.server.port=3000"

  networks:
    proxy:
      external: true
    infra:
      external: true
  ```

  **Update `.env.dev` and `.env.prod`** — add:
  ```env
  IMAGE_TAG=dev    # or IMAGE_TAG=prod
  ```

  **Keep existing `docker-compose.yaml`** with `build:` for local development and CI smoke tests.

  **Update `deploy.sh`** to use `docker-compose.deploy.yaml`:
  ```bash
  #!/bin/bash
  set -e

  ENV="${1:-prod}"
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

  echo "Starting Drafter deployment (env: $ENV)..."
  cd "$SCRIPT_DIR"

  # Use environment-specific .env file
  if [ -f ".env.$ENV" ]; then
    echo "Loading .env.$ENV..."
    cp ".env.$ENV" .env
  else
    echo "ERROR: .env.$ENV not found!"
    exit 1
  fi

  echo "Logging into registry..."
  docker login registry.922-studio.com -u "$REGISTRY_USER" -p "$REGISTRY_PASSWORD"

  echo "Pulling latest image..."
  docker compose -f docker-compose.deploy.yaml pull

  echo "Swapping to new container..."
  docker compose -f docker-compose.deploy.yaml up -d --wait --wait-timeout 120

  echo "Cleaning up old images..."
  docker image prune -f

  echo "Deployment complete! (env: $ENV)"
  docker compose -f docker-compose.deploy.yaml ps
  docker compose -f docker-compose.deploy.yaml logs --tail=20
  ```

- **Context files to read**:
  - `Drafter/docker-compose.yaml` — current compose config
  - `Drafter/.env.dev` and `Drafter/.env.prod` — current env files
  - `Drafter/deploy.sh` — current boot script
- **Acceptance criteria**:
  - [ ] `docker-compose.deploy.yaml` created with `image:` instead of `build:`
  - [ ] Watchtower label added
  - [ ] `IMAGE_TAG` variable in env files
  - [ ] `deploy.sh` updated to pull from registry
  - [ ] Original `docker-compose.yaml` preserved for local dev / CI builds
  - [ ] `start_period` increased to 30s (migrations need time)

### Step 6: Refactor Drafter `deploy.yml` GitHub Actions workflow
- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter/.github/workflows/`
- **Parallel with**: —
- **Description**:
  Major refactor of the CI/CD pipeline. New flow: build → smoke → test → push → notify.

  **New `deploy.yml`:**
  ```yaml
  name: Drafter Deploy

  permissions:
    contents: write
    actions: write
    issues: write

  on:
    push:
      branches:
        - dev
    workflow_dispatch:
      inputs:
        environment:
          description: 'Target environment'
          required: true
          type: choice
          options:
            - production
            - development
          default: 'production'

  jobs:
    cancel-previous-runs:
      uses: 922-Studio/workflows/.github/workflows/cancel-previous-runs.yml@main

    version:
      name: Create new version
      needs: cancel-previous-runs
      uses: 922-Studio/workflows/.github/workflows/versioning.yml@main
      secrets:
        PAT_GITHUB: ${{ secrets.PAT_GITHUB }}

    # ── Build Docker image (no push yet) ─────────────────────────────
    build:
      name: Build Docker image
      needs: version
      uses: 922-Studio/workflows/.github/workflows/docker-build.yml@main
      with:
        registry_url: registry.922-studio.com
        image_name: drafter
        tag: dev-v${{ needs.version.outputs.new_version }}
        build_args: |
          NEXT_PUBLIC_APP_URL=https://drafter-dev.922-studio.com
        push: false  # build only, push after tests pass
        repository_path: '/home/lab/Drafter-dev'
      secrets:
        REGISTRY_USERNAME: ${{ secrets.REGISTRY_USERNAME }}
        REGISTRY_PASSWORD: ${{ secrets.REGISTRY_PASSWORD }}
        PAT_GITHUB: ${{ secrets.PAT_GITHUB }}

    # ── Smoke test with built image (isolated DB) ────────────────────
    smoke-test:
      name: Smoke test (isolated DB + migrations)
      needs: [version, build]
      uses: 922-Studio/workflows/.github/workflows/smoke-test.yml@main
      with:
        repository_path: '/home/lab/Drafter-dev'
        prebuilt_image: registry.922-studio.com/drafter:dev-v${{ needs.version.outputs.new_version }}
        healthcheck_endpoints: '{"drafter":"3000:/api/health"}'
        migration_service: drafter
        migration_success_pattern: 'Running database migrations'
        pull_code: false
      secrets:
        PAT_GITHUB: ${{ secrets.PAT_GITHUB }}

    # ── Unit tests (Vitest) ──────────────────────────────────────────
    tests:
      name: Run unit tests (Vitest + Allure)
      needs: version
      uses: 922-Studio/workflows/.github/workflows/frontend-tests.yml@main
      with:
        node_version: '22'
        enable_corepack: true
        lockfile_name: 'pnpm-lock.yaml'
        install_command: 'pnpm install --frozen-lockfile'
        test_command: 'pnpm run test:ci'
        build_command: 'pnpm run build'
        run_build: false  # build already done in Docker, skip here
        allure_results_dir: 'reports/allure'
        allure_server_url: 'http://home-lab:5050'
        allure_project_id: 'drafter-unit'
        allure_launch_name: 'Drafter Unit Tests'
      secrets:
        ALLURE_TOKEN: ${{ secrets.ALLURE_TOKEN }}
        DISCORD_BOT_TOKEN: ${{ secrets.DISCORD_BOT_TOKEN }}
        PAT_GITHUB: ${{ secrets.PAT_GITHUB }}

    # ── Push dev image to registry ───────────────────────────────────
    push-dev:
      name: Push dev image to registry
      needs: [version, build, smoke-test, tests]
      environment: development
      uses: 922-Studio/workflows/.github/workflows/docker-build.yml@main
      with:
        registry_url: registry.922-studio.com
        image_name: drafter
        tag: dev-v${{ needs.version.outputs.new_version }}
        mutable_tag: dev
        build_args: |
          NEXT_PUBLIC_APP_URL=https://drafter-dev.922-studio.com
        push: true
        repository_path: '/home/lab/Drafter-dev'
        pull_code: false
      secrets:
        REGISTRY_USERNAME: ${{ secrets.REGISTRY_USERNAME }}
        REGISTRY_PASSWORD: ${{ secrets.REGISTRY_PASSWORD }}
        PAT_GITHUB: ${{ secrets.PAT_GITHUB }}

    # ── Push prod image to registry (manual dispatch only) ───────────
    push-prod:
      name: Push prod image to registry
      needs: [version, build, smoke-test, tests]
      if: github.event_name == 'workflow_dispatch' && github.event.inputs.environment == 'production'
      environment: production  # requires approval gate
      uses: 922-Studio/workflows/.github/workflows/docker-build.yml@main
      with:
        registry_url: registry.922-studio.com
        image_name: drafter
        tag: prod-v${{ needs.version.outputs.new_version }}
        mutable_tag: prod
        build_args: |
          NEXT_PUBLIC_APP_URL=https://drafter.922-studio.com
        push: true
        repository_path: '/home/lab/Drafter'
        pull_code: false
      secrets:
        REGISTRY_USERNAME: ${{ secrets.REGISTRY_USERNAME }}
        REGISTRY_PASSWORD: ${{ secrets.REGISTRY_PASSWORD }}
        PAT_GITHUB: ${{ secrets.PAT_GITHUB }}

    # ── Notifications ────────────────────────────────────────────────
    create-issue:
      needs: [tests, smoke-test, push-dev, push-prod]
      if: failure()
      uses: 922-Studio/workflows/.github/workflows/create-issue.yml@main
      with:
        job_name: 'build / smoke / tests / push'
        workflow_status: 'failure'
        repository_name: '${{ github.repository }}'
        branch_name: '${{ github.ref_name }}'
        run_number: '${{ github.run_number }}'
        run_url: '${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}'
        run_id: '${{ github.run_id }}'
        triggering_actor: '${{ github.actor }}'
      secrets:
        PAT_GITHUB: ${{ secrets.PAT_GITHUB }}

    notify-success:
      name: Discord notification (success)
      needs: [version, push-dev, push-prod]
      if: success()
      uses: 922-Studio/workflows/.github/workflows/send-notification.yml@main
      with:
        enable_email: false
        enable_discord: true
        discord_channel_id: '1465354445113000032'
        workflow_status: 'success'
        workflow_name: ${{ github.workflow }}
        repository_name: ${{ github.repository }}
        run_url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
        latest_version: ${{ needs.version.outputs.new_version }}
      secrets:
        DISCORD_BOT_TOKEN: ${{ secrets.DISCORD_BOT_TOKEN }}

    notify-failure:
      name: Discord notification (failure)
      needs: [tests, smoke-test, push-dev, push-prod, create-issue]
      if: failure()
      uses: 922-Studio/workflows/.github/workflows/send-notification.yml@main
      with:
        enable_email: false
        enable_discord: true
        discord_channel_id: '1465354445113000032'
        workflow_status: 'failure'
        workflow_name: ${{ github.workflow }}
        repository_name: ${{ github.repository }}
        run_url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
        issue_url: '${{ needs.create-issue.outputs.issue_url }}'
      secrets:
        DISCORD_BOT_TOKEN: ${{ secrets.DISCORD_BOT_TOKEN }}
        PAT_GITHUB: ${{ secrets.PAT_GITHUB }}
  ```

  **Important notes on the workflow:**
  - `build` job builds but does NOT push (push: false)
  - `smoke-test` uses the locally built image (still on runner disk from build job)
  - `tests` runs in parallel with `smoke-test` (both depend on version, tests don't need docker image)
  - `push-dev` only runs after smoke + tests both pass
  - `push-prod` requires manual dispatch + approval gate via GitHub Environment
  - Prod builds a SEPARATE image with different `NEXT_PUBLIC_APP_URL` baked in

  **GitHub repo secrets to add:**
  - `REGISTRY_USERNAME`: `gregor`
  - `REGISTRY_PASSWORD`: registry htpasswd password

  **GitHub Environment setup:**
  - `development`: no approval gate, tracks dev deployments
  - `production`: approval gate (Gregor must approve), tracks prod deployments

- **Context files to read**:
  - `Drafter/.github/workflows/deploy.yml` — current workflow to refactor
  - Steps 1-3 outputs — new reusable workflows
- **Acceptance criteria**:
  - [ ] Workflow uses build → smoke → test → push flow
  - [ ] Dev image pushed automatically on push to `dev`
  - [ ] Prod image requires manual dispatch + environment approval
  - [ ] Both versioned and mutable tags pushed
  - [ ] Discord notifications on success and failure
  - [ ] GitHub issue created on failure
  - [ ] GitHub Environments linked (development, production)

### Step 7: Set up Watchtower on deployment servers
- **Project**: HomeStructure
- **Directory**: server(s) — deployment servers
- **Parallel with**: —
- **Description**:
  **BLOCKED: Pending new server setup (Terraform, networking).** This step executes when deployment servers are ready.

  Set up Watchtower on each deployment server to auto-pull images from the registry.

  **Create `~/HomeStructure/watchtower/docker-compose.yaml`** on each deployment server:
  ```yaml
  services:
    watchtower:
      image: containrrr/watchtower
      container_name: watchtower
      environment:
        WATCHTOWER_LABEL_ENABLE: "true"  # only watch labeled containers
        WATCHTOWER_POLL_INTERVAL: 30     # check every 30 seconds
        WATCHTOWER_CLEANUP: "true"       # remove old images
        WATCHTOWER_INCLUDE_STOPPED: "false"
        WATCHTOWER_ROLLING_RESTART: "true"
        WATCHTOWER_NOTIFICATIONS: "shoutrrr"
        WATCHTOWER_NOTIFICATION_URL: "discord://${DISCORD_WEBHOOK_TOKEN}@${DISCORD_WEBHOOK_ID}"
      volumes:
        - /var/run/docker.sock:/var/run/docker.sock
        - /home/lab/.docker/config.json:/config.json:ro  # registry credentials
      restart: unless-stopped
      labels:
        - "922.group=Infrastructure"
  ```

  **Registry auth for Watchtower:**
  Watchtower reads Docker credentials from `/config.json`. On each deployment server:
  ```bash
  docker login registry.922-studio.com
  # This creates ~/.docker/config.json with registry credentials
  ```

  **Container labeling:**
  Only containers with `com.centurylinklabs.watchtower.enable=true` are watched. This is already set in `docker-compose.deploy.yaml` from Step 5.

  **Discord notifications:**
  Watchtower supports Discord via Shoutrrr. Configure webhook URL in Watchtower env vars.

- **Context files to read**:
  - Watchtower docs: https://containrrr.dev/watchtower/
  - `HomeStructure/docs/services/docker.md` — systemd service registration
- **Acceptance criteria**:
  - [ ] Watchtower running on each deployment server
  - [ ] Only label-enabled containers are watched
  - [ ] Registry authentication configured
  - [ ] Discord notifications on image updates
  - [ ] Registered in systemd for auto-start
  - [ ] Verified: push to registry → Watchtower pulls → container restarts

### Step 8: Set up centralized env management via Syncthing
- **Project**: HomeStructure
- **Directory**: server(s)
- **Parallel with**: Step 7
- **Description**:
  **BLOCKED: Pending new server setup.** This step executes when deployment servers are ready.

  Create a central `envs/` directory synced to all deployment servers via Syncthing.

  **Directory structure (on runner/management server):**
  ```
  ~/envs/
    drafter/
      .env.dev
      .env.prod
    homeapi/
      .env.dev
      .env.prod
    ...
  ```

  **Syncthing share config:**
  - Folder name: `envs`
  - Source: runner server `~/envs/`
  - Targets: both deployment servers `~/envs/`
  - Sync type: Send Only (from runner server, receive only on deployment servers)
  - Ignore patterns: none (sync everything)

  **Deployment server docker-compose.deploy.yaml:**
  Update env_file reference:
  ```yaml
  env_file:
    - /home/lab/envs/drafter/.env
  ```

  The `deploy.sh` copies the correct env file:
  ```bash
  cp "/home/lab/envs/drafter/.env.$ENV" "/home/lab/envs/drafter/.env"
  ```

  Or simpler: each deployment server only has the env file for its role:
  - Dev deployment server: `~/envs/drafter/.env` is the dev config
  - Prod deployment server: `~/envs/drafter/.env` is the prod config

- **Context files to read**:
  - `HomeStructure/docs/services/syncthing.md` — current Syncthing setup
- **Acceptance criteria**:
  - [ ] `~/envs/` directory created on runner server
  - [ ] Syncthing share configured to deployment servers
  - [ ] Drafter env files placed correctly
  - [ ] docker-compose.deploy.yaml references synced env path

### Step 9: Update documentation
- **Project**: Planner, HomeStructure
- **Directory**: `/Users/gregor/dev/922/Planner/`, `/Users/gregor/dev/922/HomeStructure/docs/`
- **Parallel with**: —
- **Description**:
  Update all documentation to reflect the new CI/CD architecture.

  **Planner updates:**
  - `server.md` — add Watchtower service entry
  - `projects/drafter.md` — update Pipeline & Deployment section
  - `registry.md` — note the CI/CD pattern change

  **HomeStructure docs:**
  - `docs/services/registry.md` — add CI/CD integration section with the new workflow pattern
  - `docs/services/watchtower.md` — new service doc
  - `docs/config/dev-prod-environments.md` — update with registry-based deployment model
  - `docs/neue-services-einrichten.md` — update with registry-based steps

- **Context files to read**:
  - All files being updated
  - `plans/generic-registry-cicd-rollout.md` — generic guide for reference
- **Acceptance criteria**:
  - [ ] All docs reflect new CI/CD flow
  - [ ] Watchtower documented as a service
  - [ ] New service guide updated
  - [ ] Changes committed and pushed

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Create docker-build.yml reusable workflow     → Workflows @ /Users/gregor/dev/922/workflows/
  Step 2: Refactor smoke-test.yml for pre-built images  → Workflows @ /Users/gregor/dev/922/workflows/
  Step 3: Refactor deploy-docker.yml registry pull mode → Workflows @ /Users/gregor/dev/922/workflows/
  Step 4: Update Drafter Dockerfile + entrypoint        → Drafter @ /Users/gregor/dev/922/Drafter/
  Step 5: Create docker-compose.deploy.yaml + update deploy.sh → Drafter @ /Users/gregor/dev/922/Drafter/

Wave 2 (after wave 1):
  Step 6: Refactor Drafter deploy.yml workflow          → Drafter @ /Users/gregor/dev/922/Drafter/
  (depends on Steps 1-5 being committed and pushed)

Wave 3 (BLOCKED — pending new server setup):
  Step 7: Set up Watchtower on deployment servers       → Server(s) via SSH
  Step 8: Set up centralized env via Syncthing          → Server(s) via SSH

Wave 4 (after wave 3):
  Step 9: Update all documentation                      → Planner + HomeStructure
```

**Interim deployment (before Watchtower):**
After Wave 2, CI pushes images to registry. On the current home-lab server, deploy-docker.yml pulls from registry (via Step 3 refactor). Once Watchtower is set up (Wave 3), the deploy step in CI becomes unnecessary — Watchtower handles it.

## Post-Execution Checklist
- [ ] All reusable workflows work (test with Drafter pipeline)
- [ ] Drafter dev image pushes to registry on push to `dev`
- [ ] Drafter prod image pushes on manual dispatch with approval
- [ ] Smoke test validates image + isolated DB before push
- [ ] Watchtower auto-deploys on image push (after Wave 3)
- [ ] Documentation fully updated
- [ ] Generic rollout guide validated against Drafter implementation
- [ ] Pipeline green
