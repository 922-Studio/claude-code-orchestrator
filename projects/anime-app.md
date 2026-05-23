# Project: Anime-APP

## Overview
- **Type**: fullstack (frontend)
- **Path**: /Users/gregor/dev/922/Anime-APP
- **Status**: active
- **Description**: React SPA frontend for anime collection management. Connects to Anime-API. Allows users to browse, add, and manage anime collections with data sourced from MyAnimeList via the Jikan API proxy.

## Tech Stack
- **Language(s)**: JavaScript (JSX), React 19.2.0
- **Framework(s)**: Vite 7.2.4, Tailwind CSS 4.1.18
- **HTTP**: Axios 1.13.4
- **Icons**: lucide-react 0.577.0
- **Testing**: Vitest 3.2.4, @testing-library/react 16.3.0
- **Infrastructure**: Docker (Node build → Nginx), Docker Compose, Traefik
- **CI/CD**: GitHub Actions (922-Studio/workflows), ESLint

## Key Files to Read

| File | Purpose | When to read |
|------|---------|--------------|
| `src/App.jsx` | Root component, routing | Always |
| `package.json` | Dependencies and scripts | When planning changes |
| `vite.config.js` | Build + test config | When touching build/test |
| `docker-compose.yaml` | Container setup | When touching infra |
| `.github/workflows/deploy.yml` | CI/CD pipeline | When pushing changes |
| `deploy.sh` | Deployment script | When touching deployment |

## Best Practices
- No TypeScript (plain JSX) — do not add TS without a dedicated plan
- Tailwind CSS 4 — use utility classes, not custom CSS
- `npm ci` for installs (not `npm install`)
- No `Co-Authored-By` trailers in commits

## Testing Strategy
- **Unit tests**: `src/**/*.test.jsx` — `npm run test:coverage`
- **Coverage**: 0% minimum initially (to be raised in a separate plan)
- **Reporting**: Allure at `http://astro-antares:5050` (project: `anime-app`)
- **No E2E tests** — to be added in a separate plan

## Documentation
- **Where**: `README.md`
- **Update rule**: Update when significant features are added

## Pipeline & Deployment
- **CI trigger**: Push to main
- **Pipeline**: cancel-previous → version → tests → smoke-test → deploy → notify
- **Deploy**: Docker (Node build → Nginx), Docker Compose via `deploy.sh` on server at `~/Anime-APP`
- **Monitor after push**: Check Discord notification, verify `anime.922-studio.com` loads

## Public Routes
- **App**: `anime.922-studio.com` → Traefik :80 → container port 80 (Nginx)
- No auth — public access

## Port & Container Reference
| Resource | Value |
|---|---|
| App port (host) | 8021 |
| App container | `anime_app` |

## Dependencies on Other Projects
- **Anime-API**: Backend for all data (collections, anime, search proxy)
- **workflows**: Uses reusable CI/CD workflows
- **HomeStructure**: Traefik routing, Cloudflare Tunnel

## Notes
- Nginx serves static build artifacts on container port 80, mapped to host 8021
- No `.env` file needed at runtime (all config is baked at build time or uses API URL)
- `APP_PORT=8021` in `.env` controls the host port binding only
