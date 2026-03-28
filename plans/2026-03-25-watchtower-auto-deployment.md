# Watchtower Auto-Deployment Setup

**Date**: 2026-03-25
**Status**: Done
**Projects**: HomeStructure, Drafter (pilot)
**Depends on**: Docker Registry (running), Drafter CI/CD (registry-based pipeline)

## Goal

Set up Watchtower on the home lab server to automatically deploy containers when new images are pushed to the Docker Registry. This decouples deployment from CI/CD — the pipeline only needs to build, test, and push. Watchtower handles the rest.

## Deployment Flow

```
Developer pushes to dev branch
  → GitHub Actions: build → smoke test → unit tests → push to registry
  → CI pipeline DONE (no SSH deploy needed)
  → Watchtower detects new :dev digest (within 30s)
  → Watchtower pulls new image, swaps container
  → Traefik routes traffic to new container
```

## Steps

### Step 1: Create Watchtower compose in HomeStructure [DONE]

- **Project**: HomeStructure
- **Files created**:
  - `watchtower/docker-compose.yaml` — label-based Watchtower with registry auth
  - `watchtower/.env.example` — credential template

### Step 2: Update homelab-ctl.sh [DONE]

- **Project**: HomeStructure
- **File modified**: `scripts/homelab-ctl.sh`
  - Added `WATCHTOWER_DIR` variable
  - Added `watchtower` to `STACKS` and `STARTUP_ORDER` (after allure, before homeauth)

### Step 3: Create Watchtower documentation [DONE]

- **Project**: HomeStructure
- **File created**: `docs/services/watchtower.md`
  - Full architecture diagram (CI → Registry → Watchtower → Container → Traefik → Internet)
  - Image tagging strategy (mutable + immutable)
  - Label-based opt-in
  - Rollback procedure
  - Troubleshooting guide
- **File modified**: `mkdocs.yml` — added Watchtower to nav

### Step 4: Deploy Watchtower on server [DONE]

- **Project**: HomeStructure (server-side)
- **Note**: Required `DOCKER_API_VERSION: "1.54"` env var — Watchtower ships with client API v1.25 which is too old for the host Docker daemon. Added to compose and docs.
- `.env` created with registry credentials, Watchtower started and polling.

### Step 5: Verify Watchtower picks up Drafter [DONE]

- **Project**: Drafter
- **Changes made**:
  - Added `image: ${IMAGE:-registry.922-studio.com/drafter:dev}` to `docker-compose.yaml`
  - Added `com.centurylinklabs.watchtower.enable=true` label
  - Added `IMAGE=registry.922-studio.com/drafter:dev` to server `~/Drafter-dev/.env`
  - Recreated `drafter_dev` container from registry image
- **Verified**: Watchtower scans 2 containers, 0 failures, `drafter_dev` has watchtower label

### Step 6: Remove SSH deploy step from Drafter CI [DONE - already not present]

- The Drafter deploy pipeline already uses the registry-push pattern (build → test → push). No SSH deploy step exists.

## Quality Gates

- [x] Watchtower container running on server
- [x] Watchtower logs show it's polling the registry
- [x] Drafter container has Watchtower label
- [x] Push to dev triggers automatic container swap (verified via `docker logs watchtower`)
- [x] Documentation updated (DOCKER_API_VERSION, troubleshooting, file references fixed)
- [x] homelab-ctl can manage watchtower stack

## Rollback

Stop Watchtower, pin container to immutable tag, fix, restart Watchtower.
See `HomeStructure/docs/services/watchtower.md` for full procedure.
