# Project: Drafter

## Overview
- **Type**: fullstack (monorepo)
- **Path**: /Users/gregor/dev/922/Drafter
- **Status**: setup
- **Description**: Content Management & Scheduling App for social media posts. Next.js monorepo (API routes + frontend) replacing the HomeContent microservice. Collaborative project with shared ownership across backend and frontend.

## Tech Stack
- **Language(s)**: TypeScript (strict)
- **Framework(s)**: Next.js (App Router)
- **Database**: PostgreSQL (shared_postgres on home lab)
- **ORM**: Prisma
- **Infrastructure**: Docker, Docker Compose, Traefik
- **CI/CD**: GitHub Actions (922-Studio/workflows)

## Key Files to Read

| File | Purpose | When to read |
|------|---------|--------------|
| `CLAUDE.md` | Project conventions | Always |
| `docs/MVP-Scope.md` | MVP feature scope, frontend pages | Always |
| `docs/Open-Topics.md` | Resolved decisions (name, ORM, auth) | For context on past decisions |

## Best Practices
- Shared TypeScript types between API and frontend (no duplication)
- No `Co-Authored-By` trailers in commits
- Branches: `main` (stable), `dev` (development), `prod` (production)

## Testing Strategy
- **Unit tests**: TBD (after tech stack setup)
- **E2E tests**: TBD
- **Coverage**: 70% minimum (standard)

## Documentation
- **Where**: `docs/` (Obsidian vault, shared notes)
- **Update rule**: Update docs when scope or architecture changes

## Pipeline & Deployment
- **CI trigger**: TBD (after workflow setup)
- **Deploy**: Docker Compose to home lab
- **Domain**: drafter.922-studio.com
- **Monitor after push**: TBD

## Dependencies on Other Projects
- **HomeAuth**: JWT shared secret, Traefik forward-auth for protected routes
- **HomeStructure**: Shared PostgreSQL (shared_postgres), Traefik routing
- **Workflows**: Uses reusable CI/CD workflows

## Notes
- Collaborative project: both contributors work across backend and frontend
- GitHub secrets configured: PAT_GITHUB, DISCORD_BOT_TOKEN, GEMINI_API_KEY, ALLURE_TOKEN
- PAT_GITHUB and ALLURE_TOKEN still have placeholder values — need real values from GitHub settings
