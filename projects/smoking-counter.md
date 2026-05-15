# Project: Smoking Counter

## Overview
- **Type**: app (website)
- **Path**: /Users/gregor/dev/922/smoking-counter
- **Status**: planned (created 2026-05-15)
- **Description**: Tiny standalone web app to track cigarette counts per user with a global leaderboard. Username-only "login" (no password), one big +1 button, undo last entry. Public at `smoking.922-studio.com`.

## Tech Stack
- **Language(s)**: JavaScript (Node.js 20)
- **Framework(s)**: Express 4, vanilla HTML/CSS/JS for the client (no build step)
- **Data**: SQLite via `better-sqlite3`, single file at `/app/data/smoking.db` (named Docker volume `smoking_data`)
- **Auth**: HMAC-signed cookie (`COOKIE_SECRET` env), `HttpOnly`, `Secure`, `SameSite=Lax`
- **Infrastructure**: Docker Compose, Traefik (`proxy` network), Cloudflare Tunnel
- **CI/CD**: GitHub Actions via `922-Studio/workflows` (mirror of Sweatvalley Bingo pipeline)

## Key Files to Read

| File | Purpose | When to read |
|------|---------|--------------|
| `README.md` | Setup + run instructions | First time |
| `server/server.js` | Express app, route handlers | Backend changes |
| `server/db.js` | SQLite schema + prepared statements | DB changes |
| `server/auth.js` | Cookie sign/verify | Auth changes |
| `public/app.js` | Frontend logic (login, counter, leaderboard polling) | Frontend changes |
| `docker-compose.yml` | Traefik labels, volume, env | Deploy changes |
| `Dockerfile` | Node Alpine + native `better-sqlite3` deps | Build changes |
| `deploy.sh` | Pull → build → compose up | Deploy changes |
| `.github/workflows/deploy.yml` | CI pipeline | Pipeline changes |

## Best Practices
- Keep it tiny: no client-side framework, no transpile step
- All DB access via prepared statements (`better-sqlite3`)
- Never trust the client — username comes from the verified cookie, not the request body, on all mutating routes
- Cookie signature uses `crypto.timingSafeEqual` for verification
- SQLite WAL mode for better concurrency under multi-tab usage

## Testing Strategy
- **Unit tests**: `server/*.test.js` — Vitest
  - `db.test.js`: schema migration, insert + undo behavior
  - `auth.test.js`: sign/verify, tamper rejection
- **Integration tests**: `server/api.test.js` — supertest against the Express app
- **How to run**: `npm test` (also `npm run test:coverage` for CI)
- **Coverage gate**: ≥ 70%
- **Reporting**: Allure in CI (`smoking-counter-server` project id)

## Documentation
- **Where**: `README.md` (local), this mapping file (orchestrator)
- **Update rule**: Update README when API surface or env vars change

## Pipeline & Deployment
- **CI trigger**: Push to `main` + manual `workflow_dispatch`
- **Pipeline**: cancel-previous → version → server tests → smoke test → deploy → notify
- **Deploy**: `deploy.sh` over SSH, Docker Compose
- **Monitor after push**: Discord notification, then `curl https://smoking.922-studio.com/health`

## Dependencies on Other Projects
- **HomeStructure**: Traefik proxy network, Cloudflare Tunnel ingress
- **workflows**: Reusable CI/CD workflows (cancel-previous, versioning, frontend-tests, smoke-test)

## Notes
- Public URL: https://smoking.922-studio.com
- Internal port 3001, host port 3925
- DB lives in named Docker volume `smoking_data` — survives container recreate. Back up by `docker run --rm -v smoking_data:/data alpine tar czf - /data`.
- No HomeAuth integration by design — this is intentionally a tiny isolated toy app.
