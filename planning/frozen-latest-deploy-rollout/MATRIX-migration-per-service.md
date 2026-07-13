---
title: Wave 0.7 — Per-service migration matrix
status: in-progress
created: 2026-07-08
updated: 2026-07-08
owner: gregor
summary: Per-service migration configuration audit for the frozen rollout. The deploy.yml gate (deploy_mode != 'pinned' on validate-chain-eu + apply-migration-eu + apply-migration-us) is implemented (PR #380). This matrix confirms each service's migration config and flags inline (non-templated) migration jobs that must be gated off on *-frozen branches.
---

# Wave 0.7 — Per-service migration matrix

**Templated gate status:** `deploy_mode != 'pinned'` is applied to all three
migration jobs (`validate-chain-eu`, `apply-migration-eu`, `apply-migration-us`),
both regions — in PR #380 (Wave 0 commit 2). So for any `pinned` (frozen) env,
the templated apply path is skipped uniformly.

**Remaining risk = inline (non-templated) migration jobs** in each service's own
`build-deploy.yaml`, which the DevOps gate cannot see. Each must be audited and,
if it runs migration logic or mutates the branch, gated off for `*-frozen`.

| Service (repo) | `has-migrations` | `db-uri-env-var` | Inline migration job? | Frozen gate status |
|---|---|---|---|---|
| DocBits_FTP_Import | true | SQLALCHEMY_DATABASE_URI | **yes** — `alembic-validation` (auto-merges heads, commits+pushes) | ✅ gated (this PR) |
| DocBits_API | true | SQLALCHEMY_DATABASE_URI | bespoke pipeline (Wave 5 cutover) | 🔴 **NOT gated, live on `dev-frozen` today** — see plan STATUS block top-priority finding (Stream A) |
| DocBits_DocNet | true | SQLALCHEMY_DATABASE_URI | **no** — inline `database-validation` job is present in `build-deploy.yaml` but fully **commented out** (lines 25-32, `# database-validation: … uses: ./.github/workflows/validation-database.yml`); nothing executes. Templated apply path (`has-migrations: true`) will be the only active migration mechanism once onboarded. | ✅ **audited this session — no live inline job, safe to onboard as-is** (Wave 6) |
| DocFlow | true | SQL_URI | audited: `build-deploy.yaml` has **no** alembic/migration grep hits at all — no inline job, ever. Migrations run only via the templated `deploy.yml` path, which the `deploy_mode != 'pinned'` gate already covers. **Confirmed onboarded and working**: DocFlow is live in EU `dev-frozen` (this session, Daniel Jordan's onboarding batch) and its `validate-chain-eu`/`apply-migration-eu`/`apply-migration-us` jobs show `skipped` in live run logs, same as the other 6 generic-pipeline services. | ✅ **onboarded + verified — migrations correctly skipped on frozen** |
| DocBits_Auth | true | SQLALCHEMY_DATABASE_URI | audit at onboarding | ⏳ on-demand |
| DocBits_Operator | true | SQLALCHEMY_URI | audit at onboarding | ⏳ on-demand |
| DocBits_Email_Import | true | SQLALCHEMY_DATABASE_URI | **yes** — `alembic-validation` job (`build-deploy.yaml` lines 43-119), **byte-for-byte the same pre-fix pattern FTP had**: validates/auto-merges Alembic heads, then `git commit` + `git push origin HEAD:${{ github.ref_name }}` back onto whatever branch triggered the run. Currently **ungated** — no `if:` condition restricts it from any branch. | 🟡 **NOT yet live on frozen** (repo's `build-deploy.yaml` trigger is still `dev`-only, no `dev-frozen` push trigger exists yet — see §3.8) but **must be gated in the same PR that adds the Wave 3a `dev-frozen` trigger**, using the identical FTP fix (`if: ${{ !endsWith(github.ref_name, '-frozen') }}` on the job). Flagging now so the Wave 3a trigger PR doesn't ship without it. |
| DocBits_OCR | false | — | n/a | ✅ no migrations |
| DocBits_BarCode | false | — | n/a | ✅ no migrations |
| DocBits_Extraction-Service | false | — | n/a | ✅ no migrations |
| DocBits_PO-Matching | false | — | n/a | ✅ no migrations |
| DocBits_FullText | false (registry `has-migrations` is about the SQLAlchemy/Alembic DB path only) | — | **yes — different data store, same bug class.** `build-deploy.yaml`'s `deploy-opensearch-templates` job (lines 579-668) runs `opensearch_migrate_templates.py upgrade` unconditionally against **every regional OpenSearch cluster the branch deploys to** (loops `eu`+`us` env files), gated only by `if: github.event_name == 'push'` — **no branch/environment condition at all**. This is a genuine inline schema-migration job (applies OpenSearch index/component templates, i.e. "Alembic-style" per the job's own header comment) that registry.yaml's `has-migrations` flag doesn't cover because it's not the Postgres/Alembic path the templated `_apply-migration.yml` gate governs. See flag below. | 🟡 **NOT yet live on frozen** (trigger is `dev`-only today) but **will start running unconditionally on `dev-frozen` the moment Wave 4's trigger PR adds that branch**, unless gated first. |
| auto-accounting-service | false | — | n/a | ✅ no migrations |

**Audit rule per onboarding wave:** for any service with `has-migrations: true`,
grep its `build-deploy.yaml` for `alembic`/migration steps that either run
migration logic or `git commit/push` to the branch, and gate them with
`if: ${{ !endsWith(github.ref_name, '-frozen') }}` (the FTP pattern). Services
with `has-migrations: false` need no gate — **except this audit found one
exception: `DocBits_FullText`, whose bespoke OpenSearch-template migration job
sits outside the `has-migrations` flag's scope entirely (different data store)
and must be audited/gated the same way despite `has-migrations: false`.**

**Verified this session:** FTP (the pilot, prior session) + DocFlow (confirmed
onboarded and skipping migrations correctly, this session) + a full audit pass
of the three remaining `has-migrations: true` queued services (Email_Import,
FullText, DocNet).

**New findings this session (not yet fixed — flag for the owning onboarding wave):**
1. **DocBits_Email_Import** — ungated inline `alembic-validation` job (same class
   as FTP's pre-fix pattern: auto-merge + git push). Not live today (no `dev-frozen`
   trigger yet), but must be gated in the Wave 3a trigger PR, before that PR adds
   the `dev-frozen` push trigger — otherwise this becomes a live data-safety bug
   the moment the trigger lands, same as the `DocBits_API` case.
2. **DocBits_FullText** — ungated inline `deploy-opensearch-templates` job
   (OpenSearch schema/template migration, not SQL/Alembic, so it evaded the
   registry `has-migrations` flag entirely). Also not live today (no `dev-frozen`
   trigger yet), same required fix: gate it in the Wave 4 trigger PR before that
   PR adds `dev-frozen`.

Neither of these is "live today" in the way `DocBits_API`'s bug is (no `*-frozen`
branch trigger exists yet for either repo) — so they are **not** an active
data-safety incident right now. But both are the *exact same latent bug class*,
caught here before onboarding instead of after, and must be fixed as part of
their respective trigger PRs (Wave 3a / Wave 4), not deferred to "audit later."

**DocBits_DocNet** — audited, no live inline job (the only migration-related
step in `build-deploy.yaml` is fully commented out) — safe to onboard for Wave 6
without an additional gate PR, pending the templated-path gate which already
covers it via `has-migrations: true`.
