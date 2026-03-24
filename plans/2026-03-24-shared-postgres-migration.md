# Plan: Migrate Anime-API to shared_postgres

**Date**: 2026-03-24
**Status**: Ready to execute
**Goal**: Consolidate all service databases onto a single shared_postgres instance, eliminating the last isolated PostgreSQL container (Anime-API).

---

## Background

All 922-Studio services except Anime-API already use `shared_postgres` (HomeStructure/infra). Anime-API runs a dedicated `anime_api_db` container on an isolated `anime_api_net` network at host port 5435. This plan migrates it to shared_postgres and cleans up the orphaned infrastructure.

**Already completed (code changes committed):**
- `HomeStructure/infra/init-db/01-init-databases.sh` — added `homesocial` and `anime_api` entries
- `Anime-API/docker-compose.yaml` — removed `db` service, switched to `infra` network + `shared_postgres`
- `server.md` — updated database table to reflect accurate state

---

## Database Architecture After Migration

```
shared_postgres:5432 (shared_postgres container, HomeStructure/infra)
├── home_api       → HomeAPI (api, worker, beat)
├── home_auth      → HomeAuth
├── home_collector → HomeCollector (api, worker, beat)
├── discord_bot    → Discord Bot
├── homesocial     → HomeContent (api, worker, beat)
└── anime_api      → Anime-API                         ← NEW
```

---

## Execution Steps (Server-Side)

### Step 1: Add ANIME_API_DB_PASSWORD to HomeStructure infra .env

```bash
ssh lab
# Edit ~/HomeStructure/infra/.env and add:
# ANIME_API_DB_PASSWORD=<strong-password>
```

> Use the same password you'll set in ~/Anime-API/.env for DB_PASSWORD.

### Step 2: Create anime_api database on shared_postgres

The init-db script only runs on first postgres initialization — so create the DB manually:

```bash
ssh lab
docker exec -it shared_postgres psql -U admin -d postgres <<'EOF'
CREATE USER anime_api WITH PASSWORD '<same-password-as-above>';
CREATE DATABASE anime_api OWNER anime_api;
EOF
```

Verify:
```bash
docker exec -it shared_postgres psql -U admin -d postgres -c "\l" | grep anime_api
```

### Step 3: Migrate existing data from anime_api_db → shared_postgres

```bash
ssh lab

# Dump from old container (get DB_PASSWORD from ~/Anime-API/.env)
docker exec anime_api_db pg_dump -U anime_api -d anime_api -Fc > /tmp/anime_api_dump.dump

# Restore into shared_postgres
docker exec -i shared_postgres pg_restore -U admin -d anime_api --no-owner --role=anime_api /tmp/anime_api_dump.dump < /tmp/anime_api_dump.dump

# Verify row counts
docker exec anime_api_db psql -U anime_api -d anime_api -c "SELECT schemaname, tablename, n_live_tup FROM pg_stat_user_tables ORDER BY tablename;"
docker exec shared_postgres psql -U anime_api -d anime_api -c "SELECT schemaname, tablename, n_live_tup FROM pg_stat_user_tables ORDER BY tablename;"
```

> Alternatively (cleaner):
> ```bash
> docker exec anime_api_db pg_dump -U anime_api -d anime_api | \
>   docker exec -i shared_postgres psql -U anime_api -d anime_api
> ```

### Step 4: Update Anime-API .env on the server

```bash
ssh lab
# The DB_USER, DB_NAME stay the same (anime_api)
# DB_PASSWORD: ensure it matches what you set in Step 1
# No other changes needed — DATABASE_URL is built from these vars in docker-compose
cat ~/Anime-API/.env | grep DB_
```

### Step 5: Deploy Anime-API with new docker-compose

```bash
ssh lab
cd ~/Anime-API && git pull && ./deploy.sh
```

Monitor:
```bash
docker logs anime_api --tail=50
curl -s http://localhost:8020/health
```

### Step 6: Verify the migration

```bash
# Check service is healthy
curl http://localhost:8020/health

# Check it's connected to shared_postgres (not old container)
docker inspect anime_api | grep -A5 Networks

# Spot check data
docker exec shared_postgres psql -U anime_api -d anime_api -c "SELECT COUNT(*) FROM anime_entries;"
```

### Step 7: Remove old anime_api_db container and volume

Only do this after Step 6 passes:

```bash
ssh lab
docker stop anime_api_db
docker rm anime_api_db
docker volume rm anime-api_anime_api_db_data
rm /tmp/anime_api_dump.dump
```

### Step 8: Commit HomeStructure and push

```bash
cd ~/HomeStructure && git add infra/init-db/01-init-databases.sh && git commit -m "infra: add anime_api and homesocial databases to init-db script" && git push
```

---

## Quality Gates

- [ ] `curl http://localhost:8020/health` returns 200
- [ ] `docker exec shared_postgres psql -U anime_api -d anime_api -c "SELECT COUNT(*) FROM anime_entries;"` matches old count
- [ ] `anime_api_db` container no longer running
- [ ] Discord notification received after deploy
- [ ] HomeCollector uptime check for anime-api stays green

---

## Rollback

If Step 5 fails:

```bash
ssh lab
# Revert docker-compose on server (old version still in git history)
cd ~/Anime-API && git stash  # or checkout previous docker-compose
docker compose up -d
```

The old `anime_api_db` container still has data until Step 7 — do not run Step 7 until fully verified.

---

## Notes

- Anime-API uses **sync SQLAlchemy** (`psycopg2-binary`) — DATABASE_URL format is `postgresql://` not `postgresql+asyncpg://`
- The `homesocial` database already exists on the server (HomeContent is live) — the init-db addition only affects fresh installs
- `HOMESOCIAL_DB_PASSWORD` should also be added to `~/HomeStructure/infra/.env` for completeness/reproducibility
