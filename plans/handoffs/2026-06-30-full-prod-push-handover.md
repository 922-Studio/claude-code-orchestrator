# Full Production Push — Handover & Kickoff (fresh session)

**Goal:** Bring **production fully in sync with `dev`** across the entire home-lab — not just the ledger feature. Promote every applicable service, run all migrations safely (backups first), and verify each live before moving on. Prod is outward-facing and holds invoicing data — go **step by step, gated, verify-each-step**.

**Authoritative tooling:** the prod-push framework in **HomeStructure** — `scripts/prod-push/` (preflight/backup/promote/activate/postverify + per-service hooks) and `docs/runbooks/` (built in HomeStructure PR #11). **Merge PR #11 first** so the scripts are on HomeStructure `main`, then use them.

---

## Scope (verified 2026-06-30)

**Promote `dev→prod`** (in this order — dependency-aware):

| # | Service | dev-ahead | DB migrations → backup? | Notes |
|---|---|---|---|---|
| 1 | **workflows** | 6 | no | CI/CD reusable. **Verify the ref consumers use** (`@main` vs `@prod`) and promote that ref so deploy-docker/generate-mcp changes take effect. |
| 2 | **HomeStructure** | 3 (dev→**main**) | no | Infra/docs; contains this framework. Promote `dev→main`. Apply first if any infra/config is a prerequisite. |
| 3 | **HomeAuth** | 12 | yes (7) | Shared JWT — promote before HomeAPI/HomeUI. |
| 4 | **HomeAPI** | 91 | yes (48) | Backend + **ledger activation** (see below). Big migration batch. |
| 5 | **HomeCollector** | 17 | yes (4) | Monitoring; consumes HomeAPI. |
| 6 | **HomeUI** | 127 | no | Frontend; consumes all — promote last. |
| 7 | **Drafter** | 143 | yes (3) | Independent app; promote last / separate. |

**Nothing to push:** discord, Anime-APP, smoking-counter, sweatvalley_bingo (single-branch `main`); Anime-API, Portfolio, Studio (0 ahead).

---

## Per-service procedure (the 5-step flow, sequential)

For **each** service, in order, do NOT start the next until this one is verified green:

1. **preflight** — `scripts/prod-push/preflight.sh <service>` → GO/NO-GO (dev CI green, commit delta, alembic-head diff, health, env keys, creds-mount sanity). Abort the whole push if NO-GO.
2. **backup** (only services with a DB) — `scripts/prod-push/backup-prod-db.sh <db>` → timestamped `pg_dump -Fc` on antares, verified non-empty, restore cmd printed. **Never migrate without a fresh dump.**
3. **promote** — `scripts/prod-push/promote.sh <service>` → fast-forward `dev→prod` + push, monitor CI (`gh run`), **retry once on the containerd lease race** (`lease does not exist`), then **verify the running `/version` actually changed** (a green deploy can silently no-op), alembic head == dev, container healthy, and (creds-mount services) `/app/google.json` is a real file (not an empty dir).
4. **activate** — `scripts/prod-push/activate.sh <service>` → per-service hooks (see ledger activation below for HomeAPI).
5. **postverify** — `scripts/prod-push/postverify.sh <service>` → live smoke + summary.

---

## Ledger activation (rides on the HomeAPI + HomeUI promotion)

Before/at the HomeAPI step:
- Set prod `GOOGLE_DEPTS_SHEET_ID = 1UczY2evUabyimfBCN4lsQzJnTZMPdB2Hk_uWKIE2jno` ("PROD - Depts", already created, SA-shared) in `/home/lab/HomeAPI/.env` — must differ from prod backup `GOOGLE_SHEET_ID = 1waDhYPK5EUCxsI4sEpTTZvGRFAlbdL7UoaUxJ3hgeP8`. Confirm prod `HOST_APP_DIR=/home/lab/HomeAPI` and `OWNER_ORG_ID` (prod org owning ledger data).
- Enable global flag `ledger_insert_queue_enabled=true` in prod (`PUT /api/settings/ledger-insert-queue {enabled:true}` or `set_ledger_insert_queue_enabled`).
- **Fix the TZ-nit** (do on dev first so it promotes): `depts-reverse-sync` cron is UTC 02:00 but `sync-all-sheets` is Europe/Berlin 03:00 (=01:00 UTC summer) → import must run BEFORE backup. Align timezones in the `v003` seed + the live cron row.
- Regenerate prod MCP from the reproducible pipeline (workflows changes promoted).
- **Verify live:** backup export; reverse-sync round-trip on the prod depts sheet (seed + tear down a test Insert row); per-person UI; MCP from client; **invoice correctness** — invoice total == `max(0, net)` for a net-zero AND a net-credit person (the #77 invariant).

---

## Hazards to respect (encoded in the scripts + here)

- **Broken-deploy:** a green CI run can fail to update the running container — always verify `/version` after.
- **Lease race:** concurrent compose pull → `lease does not exist`; retry the deploy once.
- **Creds-mount:** must resolve to a real file (the `${HOST_APP_DIR}` fix); empty dir = broken gsheets creds.
- **NEVER** run registry GC `--delete-untagged`; **never** run heavy promtool/TSDB ops on the 16 GB antares host (OOM takes down all prod).
- **GH Actions artifact quota** full → tests red → deploy skipped (stale container) — preflight should sanity-check.
- Server `.env` (env_file_source) is NOT CI-overwritten — edit directly on antares; commit everything else.
- **discord ↔ HomeAPI:** the bot calls HomeAPI finance endpoints; after the `debts → finance/ledger` rename reaches prod, confirm the bot still uses valid paths (discord is single-branch main — no promotion, so it won't auto-update).

---

## Rollback

- Per service: restore that service's step-2 `pg_dump`; the HomeAPI ledger integrity migrations are reversible (`alembic downgrade`).
- Stop after the first failed verify — do not cascade.

## Reporting

After each service: post a one-line status (version before→after, migrations applied, verify result). At the end: a full prod-push summary + the discord-compat check result. Update HomeCollector uptime + HomeAPI versioning if any contract surface changed.

**Prod is gated:** confirm with Gregor at the start and before HomeAPI's migration step. Access needs Tailscale VPN on (`ssh antares`).
