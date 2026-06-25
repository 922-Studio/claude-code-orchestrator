# Project: Drafter

## Overview
- **Type**: fullstack (monorepo)
- **Path**: /Users/gregor/dev/922/Drafter
- **Status**: active
- **Description**: Content Management & Scheduling App for social media posts. Next.js monorepo (API routes + frontend) replacing the HomeContent microservice. Collaborative project with shared ownership across backend and frontend.

## Tech Stack
- **Language(s)**: TypeScript (strict)
- **Framework(s)**: Next.js 16.2.1 (App Router, Turbopack), React 19.2.4, TypeScript 5.8.3
- **Package Manager**: pnpm
- **Node**: >=22 LTS
- **Database**: PostgreSQL (shared_postgres on home lab, DB name: `drafter`)
- **ORM**: Prisma 7.5.0 (models: Post, Media)
- **Auth**: jose 6.2.2
- **UI**: Base UI React 1.3.0, Tailwind CSS 4.2.2, Zod 3.24.0, swr 2.4.1, sonner 2.0.0
- **Storage**: AWS SDK S3 3.750.0 (MinIO)
- **Testing**: Vitest 4.1.1, Playwright 1.58.2
- **Infrastructure**: Docker, Docker Compose, Traefik
- **CI/CD**: GitHub Actions (922-Studio/workflows)

## Key Files to Read

| File | Purpose | When to read |
|------|---------|--------------|
| `CLAUDE.md` | Project conventions | Always |
| `docs/MVP-Scope.md` | MVP feature scope, frontend pages | Always |
| `docs/Open-Topics.md` | Resolved decisions (name, ORM, auth) | For context on past decisions |
| `Dockerfile` | Multi-stage pnpm build, Next.js standalone | When touching Docker/deployment |
| `docker-compose.yaml` | Parameterized dev/prod with Traefik labels | When touching Docker/deployment |
| `deploy.sh` | Zero-downtime deploy script (env parameter) | When touching deployment |
| `.github/workflows/deploy.yml` | CI/CD pipeline | When touching CI/CD |

## Best Practices
- Shared TypeScript types between API and frontend (no duplication)
- No `Co-Authored-By` trailers in commits
- Branches: `dev` (main branch, triggers CI/CD)
- pnpm for package management (not npm)

## Testing Strategy
- **Unit tests**: Vitest (via frontend-tests.yml reusable workflow)
- **E2E tests**: TBD (Playwright)
- **Coverage**: 70% minimum (standard)
- **Allure**: Project ID `drafter-unit`

## Documentation
- **Where**: `docs/` (Obsidian vault, shared notes)
- **Update rule**: Update docs when scope or architecture changes

## Pipeline & Deployment
- **CI trigger**: Push to `dev` (deploys dev), manual dispatch for prod
- **Pipeline**: cancel-previous → version → build → unit tests → **smoke test (enabled)** → push-dev → push-prod → deploy → notify
- **Deploy**: Docker Compose to home lab via deploy.sh (zero-downtime)
- **Domains**:
  - Prod: `drafter.922-studio.com` (container: `drafter`, port 3000 internal)
  - Dev: `drafter-dev.922-studio.com` (container: `drafter_dev`, port 3000 internal)
- **Server paths**: `~/Drafter` (prod, dev branch), `~/Drafter-dev` (dev branch)
- **Auth**: Traefik forward-auth via HomeAuth (public routes: /, /login, /_next, /api/health)
- **PR E2E**: Playwright runs against the dev environment (`drafter-dev.922-studio.com`) on every PR via the `e2e` workflow (PR previews deprecated 2026-06-24 — pr-demo stack removed from Drafter and the shared workflows repo)
- **Monitor after push**: Discord notifications, GitHub issue on failure

## Dependencies on Other Projects
- **HomeAuth**: JWT shared secret, Traefik forward-auth for protected routes
- **HomeStructure**: Shared PostgreSQL (shared_postgres), Traefik routing, Cloudflare tunnel
- **MinIO**: Object storage for media uploads (S3-compatible, `minio:9000` on `infra` network)
- **Workflows**: Uses reusable CI/CD workflows (versioning, frontend-tests, deploy-docker, send-notification)

## App Routes
- **(app)/**: branding, calendar, dashboard, media, posts, timeline
- **(auth)/**: login/auth pages
- **api/**: health, media, posts

## Notes
- Collaborative project: both contributors work across backend and frontend
- GitHub secrets configured: PAT_GITHUB, DISCORD_BOT_TOKEN, GEMINI_API_KEY, ALLURE_TOKEN (all set 2026-03-24)
- Database `drafter` created in shared_postgres (user: admin)
- Cloudflare DNS routes created for both subdomains
- Docker image served from registry.922-studio.com/drafter

## Current Status — CI/Deploy (2026-06-25)

**Smoke test: FIXED & merged. Dev deploy: still RED on registry push (handed to orchestrator).**

### What was fixed
- Original failure: smoke container exited (1) with `Cannot find module 'next'`. Root cause: pnpm's hidden `.pnpm` virtual store was dropped during the Dockerfile node_modules chunking, leaving dangling symlinks at runtime.
- Resolved across PRs #35–#45 by preserving `.pnpm` and splitting it into chunked Docker layers. **PR #45** (merged, commit `77cc798` on `dev`, v1.3.16) added a 3-way `.pnpm` split with a dedicated `pnpm-at` layer for `@`-scoped store entries.
- Smoke test now passes consistently (build + unit tests + smoke all green).

### What is still RED
- **Push dev image fails with 413 Payload Too Large.** Last dev deploy run `28097748882` died on the registry push; therefore **Deploy dev to antares never runs**.
- Root cause is architectural, NOT repo-code: `registry.922-studio.com` is behind Cloudflare, which enforces a hard **100 MB per-blob-upload cap**. Dockerfile layer-splitting reduces blob sizes but cannot reliably beat the cap for the largest layers (Next.js standalone `.pnpm` entries).

### Handoff
- The **orchestrator owns the real fix: push server-to-server, bypassing Cloudflare** (the Cloudflare cap is the actual constraint; layer-splitting was only a workaround).

### Outstanding for Gregor
- **CI-failure issues #23–#46** (auto-created "CI Failure on dev" stack) are still OPEN — intentionally not closed because the pipeline is still red on push. Close once the deploy goes green via the orchestrator's push fix.
- **`reports/`** dir in the Drafter checkout is untracked but NOT gitignored (local test-coverage artifacts, predates this work). Consider adding `reports/` to `.gitignore`.
- **GitHub Actions storage quota** warning ("Artifact storage quota has been hit") fails the unit-test artifact upload on every run — account-level GitHub storage issue, unrelated to Drafter code.

### Repo cleanup done
- All smoke/413 worktrees and feature branches removed (local + remote); checkout is on latest `origin/dev` with a clean tree.
