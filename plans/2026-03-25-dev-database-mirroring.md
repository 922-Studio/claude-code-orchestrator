# Plan: Dev Database Mirroring from Prod

- **Date**: 2026-03-25
- **Project(s)**: HomeStructure, HomeAPI, HomeAuth, HomeCollector, Drafter, Workflows
- **Goal**: Mirror prod databases to dev_postgres so dev always has 1:1 prod data, fix Drafter DB isolation, and ensure shared_postgres remains prod-only.

## Context

Read these files before proceeding:
- `plans/2026-03-24-dev-prod-environment-split.md` — existing dev/prod split (completed steps 1-9)
- `HomeStructure/infra/docker-compose.yaml` — shared_postgres (prod)
- `HomeStructure/infra/docker-compose.dev.yaml` — dev_postgres
- `HomeStructure/infra/.env` and `.env.dev` — credentials
- `HomeStructure/infra/init-db/01-init-databases.sh` — prod DB init
- `HomeStructure/infra/init-dev-db.sh` — dev DB init

## Current State

### shared_postgres (prod, port 5432)
| Database | User | Used by |
|----------|------|---------|
| `home_api` | `home_api` | HomeAPI (prod) |
| `home_auth` | `home_auth` | HomeAuth (prod) |
| `home_collector` | `home_collector` | HomeCollector (prod) |
| `discord_bot` | `discord_bot` | Discord Bot |
| `anime_api` | `anime_api` | Anime-API |
| `drafter` | `postgres` | Drafter (prod AND dev!) |

### dev_postgres (dev, port 5433)
| Database | User | Used by |
|----------|------|---------|
| `dev_home_api` | `home_api` | HomeAPI (dev) |
| `dev_home_auth` | `home_auth` | HomeAuth (dev) |
| `dev_home_collector` | `home_collector` | HomeCollector (dev) |

### Issues to Fix
1. **Drafter dev uses shared_postgres** — both `.env.dev` and `.env.prod` point to `shared_postgres:5432/drafter`. Dev must use `dev_postgres`.
2. **Dev databases have no prod data** — they were initialized empty; need 1:1 mirror from prod.
3. **No sync mechanism** — no script exists to copy prod → dev.
4. **Drafter uses `postgres:postgres` superuser** — should have a dedicated `drafter` user like all other services.

## Completed Steps

### Step 1: Create Dedicated Drafter DB User in Prod ✅ (2026-03-25)
- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure`
- **Parallel with**: —
- **Description**: Add `drafter` user + password to prod init script and `.env`. Then create the user on the live server and transfer ownership of the `drafter` database.
- **Context files to read**:
  - `infra/init-db/01-init-databases.sh` — current init script
  - `infra/.env` — add `DRAFTER_DB_PASSWORD`
- **Changes**:
  1. Add `DRAFTER_DB_PASSWORD=<generated>` to `infra/.env`
  2. Add to `infra/init-db/01-init-databases.sh`:
     ```sql
     CREATE USER drafter WITH PASSWORD '${DRAFTER_DB_PASSWORD}';
     CREATE DATABASE drafter OWNER drafter;
     ```
  3. On live server, run:
     ```bash
     docker exec shared_postgres psql -U admin -d postgres -c \
       "CREATE USER drafter WITH PASSWORD '<password>'; ALTER DATABASE drafter OWNER TO drafter; GRANT ALL PRIVILEGES ON DATABASE drafter TO drafter;"
     docker exec shared_postgres psql -U drafter -d drafter -c \
       "REASSIGN OWNED BY postgres TO drafter;"
     ```
- **Acceptance criteria**:
  - [ ] `drafter` user exists on shared_postgres
  - [ ] `drafter` database owned by `drafter` user
  - [ ] Init script updated for future reprovisioning

### Step 2: Add Drafter Dev Database to dev_postgres ✅ (2026-03-25)
- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure`
- **Parallel with**: Step 1
- **Description**: Add `drafter` + `dev_drafter` database to dev_postgres init script and `.env.dev`.
- **Context files to read**:
  - `infra/init-dev-db.sh` — dev init script
  - `infra/.env.dev` — dev credentials
- **Changes**:
  1. Add `DEV_DRAFTER_DB_PASSWORD=dev_drafter_password` to `infra/.env.dev`
  2. Add to `infra/init-dev-db.sh`:
     ```sql
     -- Drafter (dev)
     DO $$ BEGIN
       IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'drafter') THEN
         CREATE USER drafter WITH PASSWORD '${DEV_DRAFTER_DB_PASSWORD}';
       END IF;
     END $$;
     CREATE DATABASE dev_drafter OWNER drafter;
     GRANT ALL PRIVILEGES ON DATABASE dev_drafter TO drafter;
     ```
  3. Run `init-dev-db.sh` on live server to create the database
- **Acceptance criteria**:
  - [ ] `dev_drafter` database exists on dev_postgres
  - [ ] `drafter` user exists on dev_postgres

### Step 3: Update Drafter .env Files ✅ (2026-03-25)
- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: Steps 1, 2
- **Description**: Fix Drafter env files so prod uses dedicated user on shared_postgres, dev uses dev_postgres.
- **Context files to read**:
  - `.env.dev` — currently points to shared_postgres
  - `.env.prod` — currently uses postgres:postgres
- **Changes**:
  1. `.env.prod`:
     ```
     DATABASE_URL=postgresql://drafter:<DRAFTER_DB_PASSWORD>@shared_postgres:5432/drafter
     ```
  2. `.env.dev`:
     ```
     DATABASE_URL=postgresql://drafter:<DEV_DRAFTER_DB_PASSWORD>@dev_postgres:5432/dev_drafter
     ```
  3. Update server-side `.env` files at:
     - `/home/lab/Drafter/.env` (prod) — copy of `.env.prod`
     - `/home/lab/dev/Drafter/.env` (dev) — copy of `.env.dev`
- **Acceptance criteria**:
  - [ ] Drafter prod connects to shared_postgres with `drafter` user
  - [ ] Drafter dev connects to dev_postgres with `drafter` user
  - [ ] Both containers start and pass health checks

### Step 4: Create Database Mirror Script ✅ (2026-03-25)
- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure`
- **Parallel with**: —
- **Description**: Create `infra/mirror-prod-to-dev.sh` that dumps all prod databases and restores them into dev_postgres.
- **Context files to read**:
  - `infra/docker-compose.yaml` — prod container name
  - `infra/docker-compose.dev.yaml` — dev container name
  - `infra/.env` — prod credentials
  - `infra/.env.dev` — dev credentials
- **Script logic**:
  ```bash
  #!/bin/bash
  set -euo pipefail

  # Databases to mirror (prod_db:dev_db:user)
  DATABASES=(
    "home_api:dev_home_api:home_api"
    "home_auth:dev_home_auth:home_auth"
    "home_collector:dev_home_collector:home_collector"
    "drafter:dev_drafter:drafter"
  )

  PROD_CONTAINER="shared_postgres"
  DEV_CONTAINER="dev_postgres"
  BACKUP_DIR="/tmp/db-mirror-$(date +%Y%m%d-%H%M%S)"

  mkdir -p "$BACKUP_DIR"

  for entry in "${DATABASES[@]}"; do
    IFS=: read -r prod_db dev_db db_user <<< "$entry"
    echo "=== Mirroring $prod_db → $dev_db ==="

    # 1. Dump prod
    docker exec "$PROD_CONTAINER" pg_dump -U "$db_user" -d "$prod_db" \
      --no-owner --no-acl --clean --if-exists > "$BACKUP_DIR/$prod_db.sql"

    # 2. Drop & recreate dev DB
    docker exec "$DEV_CONTAINER" psql -U admin -d postgres -c \
      "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$dev_db' AND pid <> pg_backend_pid();" || true
    docker exec "$DEV_CONTAINER" psql -U admin -d postgres -c \
      "DROP DATABASE IF EXISTS $dev_db;"
    docker exec "$DEV_CONTAINER" psql -U admin -d postgres -c \
      "CREATE DATABASE $dev_db OWNER $db_user;"

    # 3. Restore into dev
    docker exec -i "$DEV_CONTAINER" psql -U "$db_user" -d "$dev_db" < "$BACKUP_DIR/$prod_db.sql"

    echo "=== $prod_db → $dev_db complete ==="
  done

  echo ""
  echo "Mirror complete. Backups in: $BACKUP_DIR"
  echo "Restart dev services to pick up new data:"
  echo "  cd ~/HomeAPI && docker compose -p homeapi-dev restart"
  echo "  cd ~/HomeAuth && docker compose -p homeauth-dev restart"
  echo "  cd ~/HomeCollector && docker compose -p homecollector-dev restart"
  echo "  cd ~/Drafter && docker compose -p drafter-dev restart"
  ```
- **Acceptance criteria**:
  - [ ] Script runs without error on the server
  - [ ] All 4 dev databases contain prod data after run
  - [ ] Dev services start and work with mirrored data

### Step 5: Run Initial Mirror ✅ (2026-03-25)
- **Project**: HomeStructure (on server)
- **Directory**: `ssh lab` → `~/HomeStructure`
- **Parallel with**: — (depends on Steps 1-4)
- **Description**: Execute the mirror script on the server to do the initial data sync. Then restart all dev services.
- **Steps**:
  1. Stop dev services (avoid connection conflicts during restore):
     ```bash
     cd ~/dev/HomeAPI && docker compose -p homeapi-dev stop
     cd ~/dev/HomeAuth && docker compose -p homeauth-dev stop
     cd ~/dev/HomeCollector && docker compose -p homecollector-dev stop
     cd ~/dev/Drafter && docker compose -p drafter-dev stop
     ```
  2. Run mirror: `cd ~/HomeStructure && ./infra/mirror-prod-to-dev.sh`
  3. Start dev services:
     ```bash
     cd ~/dev/HomeAPI && docker compose -p homeapi-dev up -d
     cd ~/dev/HomeAuth && docker compose -p homeauth-dev up -d
     cd ~/dev/HomeCollector && docker compose -p homecollector-dev up -d
     cd ~/dev/Drafter && docker compose -p drafter-dev up -d
     ```
  4. Verify all dev containers are healthy
- **Acceptance criteria**:
  - [ ] All 4 dev databases contain prod data
  - [ ] All dev services healthy after restart
  - [ ] Alembic migrations run successfully (idempotent — already at head)

### Step 6: Update Server-Side .env Files ✅ (2026-03-25)
- **Project**: All affected projects (on server)
- **Directory**: `ssh lab`
- **Parallel with**: Step 3
- **Description**: Ensure all server-side `.env` files match the repo versions. Projects affected:
- **Files to update on server**:
  | Server Path | Source |
  |-------------|--------|
  | `/home/lab/Drafter/.env` | `Drafter/.env.prod` |
  | `/home/lab/dev/Drafter/.env` | `Drafter/.env.dev` |
  | `/home/lab/HomeStructure/infra/.env` | `HomeStructure/infra/.env` |
  | `/home/lab/HomeStructure/infra/.env.dev` | `HomeStructure/infra/.env.dev` |
- **Note**: HomeAPI, HomeAuth, HomeCollector server .env files don't change — they already point to the correct hosts.
- **Acceptance criteria**:
  - [ ] Server .env files match repo
  - [ ] All services restart successfully with updated .env

### Step 7: Update GitHub Workflows for Drafter Dev Deploy ✅ (2026-03-25)
- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: Step 3
- **Description**: Ensure Drafter's deploy workflow handles dev branch → dev directory with correct `.env`.
- **Context files to read**:
  - `.github/workflows/deploy.yml` — current deploy workflow
- **Changes**:
  - Verify `dev` branch triggers deploy to `/home/lab/dev/Drafter` with `.env.dev` as `.env`
  - Verify `prod` branch triggers deploy to `/home/lab/Drafter` with `.env.prod` as `.env`
- **Acceptance criteria**:
  - [ ] Push to `dev` → deploys with dev DB config
  - [ ] Push to `prod` → deploys with prod DB config

### Step 8: Commit, Push, and Update Documentation ✅ (2026-03-25)
- **Project**: HomeStructure, Drafter, Planner
- **Directory**: Multiple
- **Parallel with**: —
- **Description**: Commit all changes, push, verify CI/CD, and update docs.
- **Changes**:
  1. Commit + push HomeStructure (init scripts, mirror script, .env updates)
  2. Commit + push Drafter (env file updates)
  3. Update `server.md` — add dev_drafter to database table, add mirror script reference
  4. Update `projects/drafter.md` — document DB user change
  5. Update dev-prod split plan — mark Drafter as included
- **Acceptance criteria**:
  - [ ] All commits pushed
  - [ ] CI pipelines green
  - [ ] Documentation reflects new state

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Create drafter DB user in prod       → HomeStructure @ infra/
  Step 2: Add drafter to dev_postgres init      → HomeStructure @ infra/
  Step 3: Fix Drafter .env files                → Drafter @ /
  Step 7: Verify Drafter deploy workflow        → Drafter @ .github/workflows/

Wave 2 (after wave 1):
  Step 4: Create mirror-prod-to-dev.sh script   → HomeStructure @ infra/
  Step 6: Update server-side .env files         → Server (ssh lab)

Wave 3 (after wave 2):
  Step 5: Run initial mirror on server          → Server (ssh lab)

Wave 4 (after wave 3):
  Step 8: Commit, push, update docs             → HomeStructure, Drafter, Planner
```

## Post-Execution Checklist

- [x] shared_postgres has ONLY prod databases (home_api, home_auth, home_collector, discord_bot, anime_api, drafter)
- [x] dev_postgres has mirrored databases (dev_home_api, dev_home_auth, dev_home_collector, dev_drafter)
- [x] Drafter prod uses `drafter` user (not `postgres`)
- [x] Drafter dev uses `dev_postgres` (not `shared_postgres`)
- [x] Mirror script documented and working
- [x] All dev services healthy with prod data
- [x] All prod services unaffected
- [ ] Pipeline green for all affected repos (commit pending)
- [x] Documentation updated (server.md)

## Future Considerations

- **Scheduled mirroring**: Add a cron job or manual trigger to re-run mirror periodically (e.g., weekly). Could use GitHub Actions workflow_dispatch or a systemd timer on the server.
- **Data sanitization**: If sensitive data grows, add a post-mirror sanitization step (e.g., anonymize emails, reset passwords).
- **Drafter migrations**: Drafter uses Prisma — `npx prisma migrate deploy` runs on start. Mirror will include schema, so migrations should be idempotent.
