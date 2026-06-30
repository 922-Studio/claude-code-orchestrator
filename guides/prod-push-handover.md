# Handover: Prod-Push Framework

**Start here for a fresh prod-push session.**

This handover lives in the **orchestrator** (the command center). The operational
runbooks and the scripts themselves live in **HomeStructure** (next to the code they
drive):

- **`HomeStructure/docs/runbooks/prod-push-full.md`** — authoritative full-ecosystem
  runbook (workflows → HomeStructure → HomeAuth → HomeAPI → HomeCollector → HomeUI → Drafter)
- **`HomeStructure/docs/runbooks/prod-push-ledger.md`** — ledger feature appendix
  (HomeAPI-specific migration list, GSheets setup, feature flag, first-push checklist)

To drive the push as an orchestrated agent run with a live dashboard:
- **`orchestrator/prompts/prod-push-orchestrator.md`** — operator/runner prompt
- **`orchestrator/dashboards/prod-push-status.html`** — self-refreshing status board
  (`cd orchestrator/dashboards && python3 -m http.server 8099`)

---

## What the Framework Is

A set of fail-loud, idempotent bash scripts (`--dry-run` supported) that encode every
hard-won deploy hazard from past incidents. Service-specific behaviour is pluggable via
`hooks/<Service>.sh` files, so new services drop in without editing core scripts.

**Location**: `HomeStructure/scripts/prod-push/`

```
scripts/prod-push/
  _lib.sh               — shared helpers (SSH, logging, service mappings)
  check-connectivity.sh — Step 0: Tailscale/ssh/gh auth gate
  preflight.sh          — Step 1: GO/NO-GO check per service
  backup-all-dbs.sh     — Step 2: pg_dump all non-template DBs on antares
  promote.sh            — Step 3: merge dev→prod, monitor CI, verify
  activate.sh           — Step 4: service-specific post-deploy hooks
  postverify.sh         — Step 5: live smoke + push summary
  hooks/
    workflows.sh        — verify consumers reference @main, not @prod
    HomeStructure.sh    — verify deploy-docs + deploy-monitoring CI green
    HomeAuth.sh         — env keys, alembic head, /auth/health
    HomeAPI.sh          — env keys, feature flag, cron tz, MCP regen
    HomeCollector.sh    — env keys, alembic head, worker + beat running
    HomeUI.sh           — verify VITE_API_BASE_URL baked as prod URL
    Drafter.sh          — DATABASE_URL, healthcheck, Prisma migrations clean
.github/workflows/
  backup-prod-dbs.yml   — on-demand GHA workflow: backs up ALL DBs in one run
```

---

## Branch Reality

| Service | Target / prod branch |
|---------|---------------------|
| workflows | `main` (consumers pin `@main`) |
| HomeStructure | `main` (no `prod` branch) |
| HomeAuth, HomeAPI, HomeCollector, HomeUI, Drafter | `prod` |

**Single-branch repos** (e.g. discord) have no dev→prod promotion path and are
**never** part of a prod push.

---

## Command Sequence (full push, abbreviated)

Full detail in `HomeStructure/docs/runbooks/prod-push-full.md`. Skeleton:

```bash
cd HomeStructure

# 0. Connectivity gate (once)
./scripts/prod-push/check-connectivity.sh

# 1. Backup ALL prod databases (once, up front — GitHub Actions workflow)
gh workflow run backup-prod-dbs.yml --repo 922-Studio/HomeStructure
# → verify: ssh antares ls -lh /home/lab/backups/prod-push/
# → save the printed restore commands

# 2–5. Per-service loop (one at a time, in order):
for svc in workflows HomeStructure HomeAuth HomeAPI HomeCollector HomeUI Drafter; do
  ./scripts/prod-push/preflight.sh $svc
  ./scripts/prod-push/promote.sh $svc
  ./scripts/prod-push/activate.sh $svc
  ./scripts/prod-push/postverify.sh $svc
done
```

**Dry-run any step**:
```bash
./scripts/prod-push/promote.sh --dry-run HomeAPI
```

---

## Environment Variables (prod)

Prod `.env` files on antares are **not in git** and are **not overwritten by CI**. The
framework treats env management as a first-class step — define, validate, deliver — see
the **Environment Variables** section in `prod-push-full.md` for the full procedure.
Confirm every service's prod `.env` is complete and current before its promote step.

---

## Gated / Safety Rules

1. **Backup first.** The `Backup Prod Databases` GHA workflow (`backup-prod-dbs.yml`)
   dynamically enumerates and dumps every non-template DB in `shared_postgres` to
   `/home/lab/backups/prod-push/<ts>/` on antares in a single run. It covers all
   DB-backed services — no per-service backup runs needed. Exits 1 if any dump is empty.

2. **Preflight must be green.** `preflight.sh` exits 1 on any NO-GO.

3. **Version must change after deploy** (broken-deploy guard). `promote.sh` compares
   `/version` before and after and exits 1 if they match. Green CI ≠ updated code.

4. **Never run registry GC `--delete-untagged`** — nukes OCI/buildx layer blobs.

5. **Never run heavy promtool/TSDB ops on antares** — 16 GB RAM, OOM kills everything.

6. **Creds bind-mount must be a file, not a directory.** `promote.sh` checks that
   `/app/google.json` inside the HomeAPI container is a regular file. If `HOST_APP_DIR`
   is missing from `.env`, Docker creates an empty directory instead, breaking GSheets.

7. **Server `.env` files are NOT overwritten by CI.** See the Environment Variables
   procedure in `prod-push-full.md`.

8. **GH Actions artifact quota** can turn tests red and skip the deploy, leaving a stale
   container. `preflight.sh` warns on artifact storage usage.

---

## Rollback

1. Restore the relevant DB dump using the restore commands printed by the backup run:
   ```bash
   ssh antares "docker exec -i shared_postgres pg_restore \
     -U admin -d <db_name> --clean --if-exists \
     < /home/lab/backups/prod-push/<timestamp>/<db_name>_<timestamp>.dump"
   ```

2. Reset prod branch and force-push:
   ```bash
   git -C /Users/gregor/dev/922/<Service> checkout <prod|main>
   git -C /Users/gregor/dev/922/<Service> reset --hard <pre-push-sha>
   git -C /Users/gregor/dev/922/<Service> push --force-with-lease origin <prod|main>
   ```

3. Alembic: integrity migrations are reversible via `alembic downgrade`.
   Data-transforming migrations — restore from dump instead.

---

## Adding a New Service to the Framework

1. Add service mappings to `_lib.sh`.
2. Add required prod `.env` key checks to `preflight.sh` (and its `.env.example` contract).
3. Create `hooks/<Service>.sh` with activation steps.
4. Insert the service into the deployment order in `prod-push-full.md`.
5. Add it to the HomeCollector uptime registry and HomeAPI `/version` endpoint.
