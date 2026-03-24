# Project Registry

Master list of all projects in Gregor's ecosystem.

| # | Project | Path | Type | Status | Mapping |
|---|---------|------|------|--------|---------|
| 1 | HomeAPI | /Users/gregor/dev/922/HomeAPI | fullstack (backend) | active | [mapping](projects/homeapi.md) |
| 2 | HomeAuth | /Users/gregor/dev/922/HomeAuth | fullstack (backend) | active | [mapping](projects/homeauth.md) |
| 3 | HomeCollector | /Users/gregor/dev/922/HomeCollector | fullstack (backend) | active | [mapping](projects/homecollector.md) |
| 4 | HomeStructure | /Users/gregor/dev/922/HomeStructure | infra | active | [mapping](projects/homestructure.md) |
| 5 | HomeUI | /Users/gregor/dev/922/HomeUI | fullstack (frontend) | active | [mapping](projects/homeui.md) |
| 6 | Discord Bot | /Users/gregor/dev/922/discord | app | active | [mapping](projects/discord.md) |
| 7 | Portfolio | /Users/gregor/dev/922/portfolio | app (website) | active | [mapping](projects/portfolio.md) |
| 8 | Sweatvalley Bingo | /Users/gregor/dev/922/sweatvalley_bingo | app | active | [mapping](projects/sweatvalley-bingo.md) |
| 9 | Workflows | /Users/gregor/dev/922/workflows | infra | active | [mapping](projects/workflows.md) |
| 10 | Anime-API | /Users/gregor/dev/922/Anime-API | fullstack (backend) | active | [mapping](projects/anime-api.md) |
| 11 | Anime-APP | /Users/gregor/dev/922/Anime-APP | fullstack (frontend) | active | [mapping](projects/anime-app.md) |
| 12 | Studio | /Users/gregor/dev/922/studio | app (website) | active | [mapping](projects/studio.md) |
| 13 | Drafter | /Users/gregor/dev/922/Drafter | fullstack (monorepo) | setup | [mapping](projects/drafter.md) |

## Quick Reference

### By Type
- **Infrastructure**: HomeStructure (#4), Workflows (#9)
- **Full-Stack Backend**: HomeAPI (#1), HomeAuth (#2), HomeCollector (#3), Anime-API (#10)
- **Full-Stack Frontend**: HomeUI (#5), Anime-APP (#11)
- **Full-Stack Monorepo**: Drafter (#13)
- **App/Website**: Discord Bot (#6), Portfolio (#7), Sweatvalley Bingo (#8), Studio (#12)

### Core Ecosystem (Home Lab Stack)
```
                    ┌─────────────┐
                    │  Workflows  │  (CI/CD for all)
                    └──────┬──────┘
                           │
                 ┌─────────┴─────────┐
                 │  HomeStructure    │  (infra: PostgreSQL, Redis, Traefik, Monitoring)
                 └─────────┬─────────┘
                           │
         ┌─────────┬───────┼───────┬──────────┐
         │         │       │       │          │
    ┌────┴───┐ ┌───┴────┐ ┌┴────┐ ┌┴────────┐ ┌┴──────┐
    │HomeAuth│ │HomeAPI │ │HomeUI│ │Collector│ │Discord│
    └────────┘ └────────┘ └──┬──┘ └────┬────┘ └───────┘
         │         │         │         │          │
         └────┬────┘         │         │          │
              │              └────┬────┘          │
         JWT shared         consumes          calls API
                         HomeAPI (domain)    ideas/debts
                       + Collector (all monitoring)
```

### Dependencies
- **HomeStructure → all**: PostgreSQL (shared_postgres), Redis (shared_redis), Traefik routing
- **Workflows → all**: Reusable CI/CD workflows
- **HomeAuth ↔ HomeAPI**: Shared JWT_SECRET
- **HomeAuth ↔ HomeCollector**: Shared JWT_SECRET
- **HomeUI → HomeAPI**: Frontend consumes core domain API (debts, tasks, ideas, wellbeing, etc.)
- **HomeUI → HomeAuth**: Login/register, token management
- **HomeUI → HomeCollector**: ALL monitoring data (uptime, GitHub Actions, Allure, system metrics, overview)
- **HomeCollector → GitHub API**: Workflow runs, runners, analytics (GITHUB_TOKEN)
- **HomeCollector → Allure**: Test results and history (ALLURE_URL)
- **HomeCollector → Prometheus**: System and container metrics (PROMETHEUS_URL)
- **HomeCollector → HomeAPI**: REST call for pending todos count (HOMEAPI_BASE_URL)
- **Discord → HomeAPI**: Debts, ideas, wellbeing via HTTP
- **Portfolio**: Standalone (only depends on HomeStructure for Traefik)
- **Sweatvalley Bingo**: Standalone (only depends on HomeStructure for Traefik + Cloudflare)
- **Studio**: Standalone (only depends on HomeStructure for Traefik)
- **Drafter**: Next.js monorepo (content management). Depends on HomeAuth (JWT), HomeStructure (PostgreSQL, Traefik). Collaborative project.

### Shared Conventions (all projects)
- No `Co-Authored-By` trailers in git commits
- All use 922-Studio/workflows for CI/CD
- All deploy via Docker Compose
- All notify via Discord on deploy
- Python projects: ruff + mypy linting
- Frontend projects: ESLint strict + TypeScript
