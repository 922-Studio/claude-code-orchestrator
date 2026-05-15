# Plan: Smoking Counter — Standalone Web App

- **Date**: 2026-05-15
- **Project(s)**: Smoking Counter (new), HomeStructure (cloudflared + DNS)
- **Goal**: Build a small standalone web app where a user signs in once with a username, taps a counter for cigarettes (with undo), and sees a leaderboard. Deploy under `smoking.922-studio.com` on the home lab.

## Decisions (confirmed with Gregor)
- **Storage**: SQLite (single file in a named Docker volume). No shared_postgres dependency.
- **Auth**: Username-only. Server issues a signed cookie (HMAC over `username|createdAt`) on first "login". No password. No HomeAuth integration.
- **Counter UX**: `+1` button + `Undo last` button. Undo removes the most recent entry for the current user.
- **Leaderboard**: All-time total per user, sorted descending. Live-ish refresh (poll every 5s; no WebSockets needed).

## Context

Read these files before proceeding:
- `projects/sweatvalley-bingo.md` — closest analog (small standalone Node/Express app on Traefik + Cloudflare Tunnel)
- `projects/smoking-counter.md` — project mapping for this app (created in Step 0)
- `server.md` — public routes table, Traefik labels pattern, cloudflared config location
- `prompts/executor.md` — executor agent contract
- `/Users/gregor/dev/922/sweatvalley_bingo/docker-compose.yml` — Traefik label pattern reference
- `/Users/gregor/dev/922/sweatvalley_bingo/Dockerfile` — single-stage Node Alpine pattern reference
- `/Users/gregor/dev/922/sweatvalley_bingo/deploy.sh` — deploy script pattern reference
- `/Users/gregor/dev/922/sweatvalley_bingo/.github/workflows/deploy.yml` — pipeline pattern reference

## Architecture

```
Browser
  │  https://smoking.922-studio.com
  ▼
Cloudflare Tunnel  ──►  Traefik (:80)  ──►  smoking-counter (:3001 internal, 3925 host)
                                                  │
                                                  ▼
                                         /data/smoking.db (SQLite, named volume)
```

- **Backend**: Node.js 20 (Alpine) + Express + `better-sqlite3` + `cookie` + `cookie-signature`.
- **Frontend**: Plain HTML/CSS/vanilla JS, served as static files from Express. No build step. (Keeps it small; no React needed.)
- **DB schema** (SQLite):
  - `users(id INTEGER PK, username TEXT UNIQUE NOT NULL, created_at INTEGER NOT NULL)`
  - `cigarettes(id INTEGER PK, user_id INTEGER NOT NULL REFERENCES users(id), ts INTEGER NOT NULL)`
  - Index on `cigarettes(user_id, ts DESC)`.
- **API**:
  - `POST /api/login` — body `{username}` → upserts user, sets signed `sc_user` cookie. Returns `{username, total}`.
  - `GET  /api/me` — returns `{username, total}` or `401`.
  - `POST /api/cigarettes` — adds one entry for current user. Returns `{total}`.
  - `DELETE /api/cigarettes/last` — removes the most recent entry for current user. Returns `{total}`.
  - `GET  /api/leaderboard` — returns `[{username, total}]` desc.
  - `POST /api/logout` — clears cookie.
  - `GET  /health` — `200 OK` for healthcheck.
- **Cookie**: `sc_user`, HMAC-SHA256 signed via `COOKIE_SECRET` env var. `HttpOnly`, `Secure`, `SameSite=Lax`, 1 year.

## Steps

### Step 0: Scaffold project + orchestrator metadata
- **Project**: Orchestrator + new repo
- **Directory**: `/Users/gregor/dev/922/smoking-counter` (new local dir) and `/Users/gregor/dev/922/orchestrator`
- **Parallel with**: —
- **Description**:
  1. Create new local project directory `smoking-counter/`.
  2. Create new GitHub repo `922-Studio/smoking-counter` (private), `git init` locally, set remote, push initial commit on `main`.
  3. Add `projects/smoking-counter.md` to orchestrator (mapping).
  4. Add row to `registry.md` and update Quick Reference.
- **Acceptance criteria**:
  - [ ] Repo exists on GitHub and locally
  - [ ] `projects/smoking-counter.md` committed in orchestrator
  - [ ] Registry row added

### Step 1: Implement backend + frontend in a worktree
- **Project**: smoking-counter
- **Directory**: `/Users/gregor/dev/922/smoking-counter/.worktrees/feat-initial-app` (branch `feat/initial-app`)
- **Parallel with**: —
- **Description**:
  Build the full app per the architecture above:
  - `server/server.js` — Express app with routes listed.
  - `server/db.js` — `better-sqlite3` connection, schema migration on boot, prepared statements.
  - `server/auth.js` — sign/verify cookie via `crypto.createHmac`.
  - `public/index.html`, `public/app.js`, `public/styles.css` — login form, counter view (big +1 button, undo button, current total), leaderboard table (auto-poll every 5s). Dark-mode friendly defaults.
  - `package.json` with scripts: `start`, `dev` (nodemon), `test`.
  - `.gitignore`, `README.md`.
- **Context files to read**:
  - `/Users/gregor/dev/922/sweatvalley_bingo/server/server.js` — Express pattern
  - `projects/smoking-counter.md` — conventions
- **Acceptance criteria**:
  - [ ] `npm start` boots the app on `:3001`, DB created at `./data/smoking.db`
  - [ ] Manual smoke: login → +1 ten times → undo → leaderboard shows total 9
  - [ ] No external runtime dependencies besides what's in `package.json`

### Step 2: Tests
- **Project**: smoking-counter
- **Directory**: same worktree as Step 1
- **Parallel with**: — (after Step 1)
- **Description**: Vitest unit + integration tests:
  - `server/db.test.js` — schema, insert/undo idempotency
  - `server/auth.test.js` — sign/verify roundtrip, rejects tampered cookies
  - `server/api.test.js` — supertest hits each route, including unauth, login, +1, undo, leaderboard
- **Acceptance criteria**:
  - [ ] `npm test` green
  - [ ] Coverage ≥ 70% on `server/`

### Step 3: Dockerfile + docker-compose + deploy.sh
- **Project**: smoking-counter
- **Directory**: same worktree
- **Parallel with**: — (after Step 1)
- **Description**:
  - `Dockerfile`: `node:20-alpine`, install prod deps (incl. native `better-sqlite3` build deps), copy `server/` + `public/`, expose 3001, `CMD ["node","server/server.js"]`.
  - `docker-compose.yml`: service `smoking-counter`, port `3925:3001`, named volume `smoking_data:/app/data`, env `COOKIE_SECRET` (from `.env`), Traefik labels for `smoking.922-studio.com`, network `proxy`, healthcheck on `/health`.
  - `deploy.sh`: model on `sweatvalley_bingo/deploy.sh` (pull → build → compose up --wait).
  - `.env.example` with `COOKIE_SECRET=`.
- **Acceptance criteria**:
  - [ ] `docker compose up` locally serves on `http://localhost:3925`
  - [ ] SQLite file persists across container recreate (volume mount)
  - [ ] Traefik labels match Bingo pattern (router on `web` entrypoint, port 3001)

### Step 4: CI/CD workflow
- **Project**: smoking-counter
- **Directory**: same worktree, `.github/workflows/deploy.yml`
- **Parallel with**: — (after Step 3)
- **Description**: Mirror `sweatvalley_bingo/.github/workflows/deploy.yml` — `cancel-previous-runs` → `versioning` → `frontend-tests` (Vitest+Allure on `server/`) → `smoke-test` → deploy via SSH → Discord notify. Adapt repository path to `/home/lab/smoking-counter`, expected service `smoking-counter`, healthcheck `{"smoking-counter":"3001:/health"}`. Allure project id `smoking-counter-server`.
- **Acceptance criteria**:
  - [ ] Workflow file syntactically valid (`actionlint` if available)
  - [ ] All reused workflow refs use `922-Studio/workflows/.github/workflows/*@main`

### Step 5: Open PR for initial app
- **Project**: smoking-counter
- **Directory**: same worktree
- **Parallel with**: — (after Step 4)
- **Description**: Push `feat/initial-app`, open PR titled `feat: initial smoking-counter app + CI + deploy` against `main`. Wait for green CI. **Do not merge** yet — Step 6 must land server-side prereqs first.
- **Acceptance criteria**:
  - [ ] PR opened, URL surfaced to Gregor
  - [ ] CI green (or any failures explained)

### Step 6: Server-side prereqs (cloudflared + DNS)
- **Project**: HomeStructure / server
- **Directory**: `ssh lab` — `/home/lab/HomeStructure/` and `~/.cloudflared/`
- **Parallel with**: — (after Step 5, before Step 7)
- **Description**:
  1. On server, add ingress rule for `smoking.922-studio.com` in `~/.cloudflared/config.yml` (immediately before the catch-all 404), service `http://localhost:80`.
  2. Add DNS route: `cloudflared tunnel route dns becd3c5e-5608-4ed2-a913-27ab63660d0d smoking.922-studio.com` (creates Cloudflare CNAME).
  3. Restart cloudflared: `sudo systemctl restart cloudflared`. Verify `journalctl -u cloudflared -n 30`.
  4. Pre-create the `smoking-counter` directory on server at `/home/lab/smoking-counter` by cloning the repo (the CI deploy step assumes the repo exists there).
  5. Generate `COOKIE_SECRET` and write `/home/lab/smoking-counter/.env` (`openssl rand -hex 32`).
  6. If `~/HomeStructure` tracks `cloudflared/config.yml` (per the "server-side changes must be committed" rule), commit the config change in `HomeStructure` via worktree + PR.
- **Acceptance criteria**:
  - [ ] `dig smoking.922-studio.com` resolves to Cloudflare
  - [ ] `curl -sI https://smoking.922-studio.com` returns a Traefik response (404 expected before app is deployed, NOT a tunnel-level error)
  - [ ] HomeStructure PR opened if cloudflared config is repo-tracked

### Step 7: Merge + deploy + smoke
- **Project**: smoking-counter
- **Parallel with**: — (after Step 6)
- **Description**: Merge the smoking-counter PR. CI deploys to server. After deploy:
  - `curl https://smoking.922-studio.com/health` → `200`
  - Open in browser, log in as `gregor`, +1 a few times, undo, check leaderboard.
- **Acceptance criteria**:
  - [ ] `https://smoking.922-studio.com` returns the login page over HTTPS
  - [ ] Manual end-to-end flow works
  - [ ] Discord deploy notification received

### Step 8: Documentation sync
- **Project**: Orchestrator
- **Directory**: `/Users/gregor/dev/922/orchestrator`
- **Parallel with**: — (after Step 7)
- **Description**:
  - Add `smoking.922-studio.com` row to `server.md` Public Routes table.
  - Add Smoking Counter under Application Services in `server.md` (port `3925:3001`, container `smoking-counter`).
  - Mark this plan done with date in `MEMORY` index if applicable.
  - Move plan file to `plans/archive/` per workflow.
- **Acceptance criteria**:
  - [ ] `server.md` updated and committed
  - [ ] Plan archived with completion date appended

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (sequential, orchestrator-driven):
  Step 0: Scaffold local dir, GitHub repo, project mapping, registry row  → smoking-counter + orchestrator
  Step 1: Implement backend + frontend in feat/initial-app worktree       → smoking-counter
  Step 2: Tests (Vitest + supertest)                                      → smoking-counter
  Step 3: Dockerfile + docker-compose + deploy.sh                         → smoking-counter
  Step 4: CI/CD workflow (mirror bingo pipeline)                          → smoking-counter
  Step 5: Push branch, open PR, wait for green CI                         → smoking-counter

Wave 2 (server prereqs, depends on PR existing):
  Step 6: cloudflared ingress + DNS CNAME + .env on server                → HomeStructure / lab

Wave 3 (after both PRs ready):
  Step 7: Merge PR, deploy, smoke test https://smoking.922-studio.com     → smoking-counter

Wave 4 (final):
  Step 8: Sync server.md, archive plan                                    → orchestrator
```

Steps 1–4 happen in the same worktree on the same feature branch, so they are sequential but can be executed by a single executor agent in one pass.

## Post-Execution Checklist
- [ ] All tests pass (server-tests job green in CI)
- [ ] Documentation updated (`server.md`, `projects/smoking-counter.md`, `registry.md`)
- [ ] Pipeline green on `main` after merge
- [ ] HomeStructure cloudflared config change committed if repo-tracked
- [ ] Plan archived under `plans/archive/` with completion date
