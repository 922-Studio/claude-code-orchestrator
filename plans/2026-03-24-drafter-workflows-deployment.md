# Plan: Drafter Workflows, CI/CD & First Deployment

- **Date**: 2026-03-24
- **Project(s)**: Drafter, Workflows, HomeStructure
- **Goal**: Full CI/CD pipeline with versioning, dev/prod Docker stacks, PR-demo system, and live deployment on drafter.922-studio.com + drafter-dev.922-studio.com.

## Context

Read these files before proceeding:
- `projects/drafter.md` — project mapping and best practices
- `server.md` — server infrastructure reference
- `/Users/gregor/dev/922/Drafter/CLAUDE.md` — project conventions (pnpm, Node 22, Next.js 16)
- `/Users/gregor/dev/922/HomeStructure/docs/services/cloudflare-tunnel.md` — tunnel config
- `/Users/gregor/dev/922/HomeStructure/docs/services/traefik.md` — Traefik routing
- `/Users/gregor/dev/922/studio/Dockerfile` — reference Next.js Dockerfile
- `/Users/gregor/dev/922/studio/.github/workflows/deploy.yml` — reference Next.js pipeline

## Decisions

| Topic | Decision |
|-------|----------|
| Package manager | pnpm (per project CLAUDE.md) |
| Node version | 22 LTS |
| Ports | prod: 8030, dev: 8031 |
| Two stacks | Two server directories: ~/Drafter (prod), ~/Drafter-dev (dev) |
| Branches | `dev` → deploys dev stack, `main` → deploys prod stack |
| Auth | Traefik forward-auth via HomeAuth (to be integrated) |
| PR-Demo | Docker-based, Tailscale IP + deterministic port (9100+PR#) |
| GitHub Secrets | PAT_GITHUB, DISCORD_BOT_TOKEN, ALLURE_TOKEN, GEMINI_API_KEY |
| Versioning | Reuse existing versioning.yml (conventional commits) |

## Steps

### Step 1: Create Dockerfile
- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: Steps 2, 3, 4, 5
- **Description**: Multi-stage Dockerfile for Next.js standalone mode with pnpm. Based on Studio pattern but adapted for pnpm and Drafter's build args.
- **Context files to read**:
  - `/Users/gregor/dev/922/studio/Dockerfile` — reference pattern
  - `/Users/gregor/dev/922/Drafter/next.config.ts` — standalone output mode
  - `/Users/gregor/dev/922/Drafter/package.json` — scripts and deps
- **Acceptance criteria**:
  - [ ] Multi-stage build: pnpm install → build → standalone runtime
  - [ ] Uses node:22-alpine
  - [ ] Health check compatible (port 3000)
  - [ ] Supports build args for NEXT_PUBLIC_* env vars

### Step 2: Create docker-compose.yaml (parameterized)
- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: Steps 1, 3, 4, 5
- **Description**: Single docker-compose.yaml using env var substitution for container name, port, Traefik host, and router name. Works for both dev and prod via .env files.
- **Context files to read**:
  - `/Users/gregor/dev/922/studio/docker-compose.yaml` — reference pattern
  - `/Users/gregor/dev/922/Anime-APP/docker-compose.yaml` — Traefik labels pattern
- **Acceptance criteria**:
  - [ ] Env vars: CONTAINER_NAME, APP_PORT, TRAEFIK_HOST, ROUTER_NAME
  - [ ] Traefik labels with forward-auth middleware (auth-verify)
  - [ ] Public router for /, /login, /_next, /api/health (no auth)
  - [ ] Protected router for everything else (auth-verify middleware)
  - [ ] Health check using node fetch on localhost:3000
  - [ ] Networks: proxy, infra

### Step 3: Create deploy.sh
- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: Steps 1, 2, 4, 5
- **Description**: Deploy script that accepts environment parameter (dev/prod), uses corresponding .env file, builds and swaps containers with zero-downtime.
- **Context files to read**:
  - `/Users/gregor/dev/922/studio/deploy.sh` — reference pattern
- **Acceptance criteria**:
  - [ ] Accepts `dev` or `prod` as first argument
  - [ ] Copies .env.{env} to .env before build
  - [ ] Zero-downtime: build → swap pattern
  - [ ] Docker cache cleanup
  - [ ] Shows container status and logs after deploy

### Step 4: Create .env files
- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: Steps 1, 2, 3, 5
- **Description**: Create .env.dev and .env.prod templates with environment-specific values. Update .env.example.
- **Acceptance criteria**:
  - [ ] .env.dev: CONTAINER_NAME=drafter_dev, APP_PORT=8031, TRAEFIK_HOST=drafter-dev.922-studio.com, ROUTER_NAME=drafter-dev
  - [ ] .env.prod: CONTAINER_NAME=drafter, APP_PORT=8030, TRAEFIK_HOST=drafter.922-studio.com, ROUTER_NAME=drafter
  - [ ] Both include DATABASE_URL, JWT_SHARED_SECRET, NEXT_PUBLIC_APP_URL
  - [ ] .env.example updated with all new vars

### Step 5: Create version.txt
- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: Steps 1, 2, 3, 4
- **Description**: Initialize version.txt at 0.1.0 for versioning workflow.
- **Acceptance criteria**:
  - [ ] File contains `0.1.0`

### Step 6: Extend frontend-tests.yml for pnpm support
- **Project**: Workflows
- **Directory**: `/Users/gregor/dev/922/workflows`
- **Parallel with**: Step 7
- **Description**: Add `lockfile_name` input parameter to frontend-tests.yml. Cache hash should use pnpm-lock.yaml when specified. Ensure pnpm is available via corepack.
- **Context files to read**:
  - `/Users/gregor/dev/922/workflows/.github/workflows/frontend-tests.yml` — current workflow
- **Acceptance criteria**:
  - [ ] New input: `lockfile_name` (default: 'package-lock.json')
  - [ ] Cache hash uses specified lockfile
  - [ ] pnpm available when install_command uses pnpm (via corepack enable)
  - [ ] Backwards compatible — existing callers unaffected

### Step 7: Create PR-Demo system (generic)
- **Project**: Workflows
- **Directory**: `/Users/gregor/dev/922/workflows`
- **Parallel with**: Step 6
- **Description**: Create generic pr-demo.sh script and pr-demo.yml reusable workflow. Docker-based: builds container per PR, deterministic port, accessible via Tailscale. Workflow posts PR comment with preview URL.
- **Context files to read**:
  - `/Users/gregor/dev/922/Drafter/pr-demo` — original script (reference only)
- **Acceptance criteria**:
  - [ ] Generic script: configurable via env vars (PROJECT_NAME, REPO_PATH, PORT_BASE, DOCKERFILE, COMPOSE_FILE)
  - [ ] Commands: start <pr> <branch>, stop <pr>, list, status
  - [ ] Docker-based: builds and runs container per PR
  - [ ] Port = PORT_BASE + PR_NUMBER
  - [ ] Max 5 concurrent demos
  - [ ] Cleanup on stop (container, image, worktree)
  - [ ] Reusable workflow: triggers on PR events, SSH to server, manages lifecycle
  - [ ] Posts PR comment with Tailscale URL (http://100.112.171.16:PORT)

### Step 8: Create Drafter deploy.yml (caller workflow)
- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: Step 9
- **Depends on**: Steps 1-5 (files must exist)
- **Description**: Main CI/CD pipeline combining reusable workflows. Triggers on push to dev/main. Pipeline: cancel → version → tests → smoke → deploy → notify.
- **Context files to read**:
  - `/Users/gregor/dev/922/studio/.github/workflows/deploy.yml` — reference pipeline
  - `/Users/gregor/dev/922/Anime-APP/.github/workflows/deploy.yml` — reference pipeline
- **Acceptance criteria**:
  - [ ] Triggers: push to dev, push to main
  - [ ] Jobs: cancel-previous → versioning → frontend-tests → smoke-test → deploy-dev/deploy-prod → notify
  - [ ] Dev deploys to /home/lab/Drafter-dev with boot_script deploy.sh, environment dev
  - [ ] Prod deploys to /home/lab/Drafter with boot_script deploy.sh, environment prod
  - [ ] Uses pnpm: install_command='pnpm install --frozen-lockfile', lockfile_name='pnpm-lock.yaml'
  - [ ] Allure project: drafter-unit
  - [ ] Secrets: PAT_GITHUB, DISCORD_BOT_TOKEN, ALLURE_TOKEN, GEMINI_API_KEY

### Step 9: Create Drafter PR-Demo caller workflow
- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: Step 8
- **Depends on**: Step 7
- **Description**: Caller workflow for PR preview environments.
- **Acceptance criteria**:
  - [ ] Triggers on PR opened/synchronize/closed
  - [ ] Calls pr-demo.yml with Drafter-specific config
  - [ ] PORT_BASE=9100, PROJECT_NAME=drafter

### Step 10: Server — Clone repos & create database
- **Project**: HomeStructure / Server
- **Directory**: ssh lab
- **Parallel with**: —
- **Depends on**: Steps 1-5 committed and pushed
- **Description**: Clone Drafter repo twice (prod + dev), create PostgreSQL database, set up .env files on server.
- **Acceptance criteria**:
  - [ ] ~/Drafter exists (main branch)
  - [ ] ~/Drafter-dev exists (dev branch)
  - [ ] PostgreSQL database `drafter` created in shared_postgres
  - [ ] .env.dev in ~/Drafter-dev, .env.prod in ~/Drafter
  - [ ] Both .env files have real values (DATABASE_URL, JWT_SHARED_SECRET)

### Step 11: Server — Configure Cloudflare tunnel
- **Project**: HomeStructure / Server
- **Directory**: ssh lab → /etc/cloudflared/config.yml
- **Parallel with**: Step 10
- **Description**: Add drafter.922-studio.com and drafter-dev.922-studio.com to Cloudflare tunnel ingress. Both route through Traefik (port 80). Create DNS CNAME records.
- **Acceptance criteria**:
  - [ ] Two new ingress rules before catch-all (both → http://localhost:80)
  - [ ] `cloudflared tunnel ingress validate` passes
  - [ ] DNS routes created: `cloudflared tunnel route dns home-lab drafter.922-studio.com` + dev
  - [ ] `sudo systemctl restart cloudflared`
  - [ ] Config committed to HomeStructure repo and pushed

### Step 12: Set GitHub Secrets
- **Project**: Drafter (GitHub)
- **Parallel with**: Steps 10, 11
- **Description**: Configure repository secrets via `gh secret set`.
- **Acceptance criteria**:
  - [ ] PAT_GITHUB set
  - [ ] DISCORD_BOT_TOKEN set
  - [ ] ALLURE_TOKEN set
  - [ ] GEMINI_API_KEY set

### Step 13: First deployment (dev + prod)
- **Project**: Drafter / Server
- **Depends on**: Steps 10, 11, 12
- **Description**: Run deploy.sh on server for both dev and prod stacks. Verify containers are healthy and domains respond.
- **Acceptance criteria**:
  - [ ] drafter_dev container running and healthy
  - [ ] drafter container running and healthy
  - [ ] https://drafter-dev.922-studio.com responds
  - [ ] https://drafter.922-studio.com responds
  - [ ] /api/health returns 200 on both

### Step 14: Update Planner documentation
- **Project**: Planner
- **Directory**: `/Users/gregor/dev/922/Planner`
- **Parallel with**: —
- **Depends on**: Step 13
- **Description**: Update server.md, projects/drafter.md, and registry.md with new ports, domains, and deployment info.
- **Acceptance criteria**:
  - [ ] server.md: Drafter ports 8030/8031, containers, Cloudflare routes
  - [ ] drafter.md: Pipeline, deployment, testing info filled in
  - [ ] registry.md: Drafter status → active

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel — Drafter repo files):
  Step 1: Dockerfile → Drafter @ /Users/gregor/dev/922/Drafter
  Step 2: docker-compose.yaml → Drafter @ /Users/gregor/dev/922/Drafter
  Step 3: deploy.sh → Drafter @ /Users/gregor/dev/922/Drafter
  Step 4: .env files → Drafter @ /Users/gregor/dev/922/Drafter
  Step 5: version.txt → Drafter @ /Users/gregor/dev/922/Drafter

Wave 2 (parallel — Workflows repo + Drafter workflows):
  Step 6: Extend frontend-tests.yml → Workflows @ /Users/gregor/dev/922/workflows
  Step 7: PR-Demo system → Workflows @ /Users/gregor/dev/922/workflows
  Step 8: deploy.yml → Drafter @ /Users/gregor/dev/922/Drafter
  Step 9: pr-demo.yml → Drafter @ /Users/gregor/dev/922/Drafter

Wave 3 (parallel — Server + GitHub):
  Step 10: Clone repos & DB → Server (ssh lab)
  Step 11: Cloudflare tunnel → Server (ssh lab)
  Step 12: GitHub secrets → GitHub API (gh cli)

Wave 4 (sequential):
  Step 13: First deployment → Server (ssh lab)

Wave 5 (sequential):
  Step 14: Update docs → Planner @ /Users/gregor/dev/922/Planner
```

## Post-Execution Checklist
- [x] Both containers healthy on server — 2026-03-24
- [x] Both domains accessible via browser — 2026-03-24
- [x] /api/health returns 200 — 2026-03-24
- [x] GitHub Actions workflow visible in repo — 2026-03-24
- [x] Documentation updated (server.md, drafter.md, registry.md) — 2026-03-24
- [ ] Pipeline green on first push (pending: tests not yet configured in project)
