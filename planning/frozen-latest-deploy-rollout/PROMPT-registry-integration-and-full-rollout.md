# PROMPT — Frozen/latest rollout: generic promotion → full onboarding → API cutover

You are picking up the **frozen/latest deploy channel rollout** for DocBits.
The foundation is done and live: FTP + 6 other services (OCR, Extraction,
BarCode, PO-Matching, Auto-Accounting, DocFlow) are healthy and correctly
Helm-owned in EU `dev-frozen`, US `dev-frozen`, and EU `stage-frozen`, all with
clean CI runs. `DocBits_API`'s worst live data-safety bug (unconditional
migrations on frozen) is already patched with a stopgap PR.

**Step 1 (registry integration) is done, merged, and live-verified** —
`registry.py` now enforces `release-channels`: a service deploying to a
channel env (e.g. `dev-frozen`) without a declared entry fails the run
loudly, and components not listed in that entry are excluded from the deploy
instead of running anyway. All 7 onboarded services have both `dev-frozen`
and `stage-frozen` entries (`DevOps`#385, merged; live-verified with a real
FTP deploy to both envs, no regression). Full detail in the plan's "Where we
stand" section — don't re-litigate it, it's closed.

Your job this session is to continue the remaining **three sequential,
dependent steps** (2 → 3 → 4) that turn the rest of the foundation into the
real, generic, templated mechanism the plan always intended. Do not
parallelize these across agents the way earlier sessions did with independent
streams — each step here builds on the previous one's output, so work through
them in order, starting at Step 2.

## Read first — mandatory
1. `planning/frozen-latest-deploy-rollout/PLAN-frozen-latest-rollout.md` — read
   the whole thing. The "Where we stand" section has Step 1's outcome; "Roadmap"
   §Step 2 onward is the spec for this session. The "Architecture reference"
   section has the exact mechanisms (3-layer values overlay, migration gate,
   region rules, `release-channels` schema) you'll be extending, not replacing.
2. `planning/frozen-latest-deploy-rollout/MATRIX-migration-per-service.md` —
   per-service migration audit status, needed for Step 3's onboarding order.
3. `planning/frozen-latest-deploy-rollout/TICKET-beats-channel-readiness.md` —
   why every `beats` component stays excluded from every step below.

## Guardrails — MANDATORY, apply to every step
- **Ask before every `git push` / merge / PR merge.** Never merge without
  explicit sign-off, even for "obviously safe" changes.
- Use worktrees per the orchestrator branch policy (`git -C <repo> worktree
  add <repo>-wt/<branch> -b <branch>`); remove after PR creation.
- Do **not** touch `sandbox-frozen`, anywhere, in any repo or cluster.
- Do **not** touch any `beats` scheduler component or `docnet-discord-bot`.
- Before any cluster mutation (delete/annotate), diff live state against the
  pipeline's intended target first — zero tolerance for silent data loss.
- Do **not** push directly to any shared repo's `main`/`dev` — every change
  goes through a PR, no exceptions, regardless of how small.
- Each step below has its own PR(s). Do not bundle multiple steps into one PR
  — reviewability matters more than velocity here, and each step needs to be
  independently verifiable before the next one builds on it.
- **Live-verification constraint (learned in Step 1):** service `deploy.yaml`
  wrappers (e.g. `DocBits_FTP_Import/.github/workflows/deploy.yaml`) call
  `FELLOWPRO/DevOps/.github/workflows/deploy.yml@main`, and that workflow's own
  checkout of the `DevOps` repo has no ref-override input — it always resolves
  to `DevOps`'s default branch. Any change to `deploy.yml`, `_helm-deploy.yml`,
  or a new promotion workflow can only be exercised live **after merge to
  `main`**, not from a feature branch. Plan review → merge → live-verify in
  that order for every step below, same as Step 1.

## Step 2 — Adjust the generic deployment workflow to natively support frozen deployments

**Goal:** replace the manual per-service promotion bridge (hand-reading a live
image tag via `kubectl` and passing it to `gh workflow run deploy.yaml -f
image_tag=...`) with a real, automated, templated promotion mechanism.

1. Build a frozen equivalent of the `latest` nightly promotion chain
   (`nightly-dev-to-stage.yml` → `nightly-stage-to-sandbox.yml` →
   `deploy-all-services.yml`): `dev-frozen → stage-frozen`,
   `stage-frozen → sandbox-frozen`. Each promotion reads the source frozen
   env's currently-running pinned image tag and redeploys it to the target
   frozen env, `region` mirroring the base env's own region rule (recall:
   `stage`/`stage-frozen` is EU-only, `dev`/`dev-frozen`/`sandbox`/
   `sandbox-frozen` is `region: all`).
2. Prefer parameterizing the existing nightly workflows over duplicating them,
   unless that risks regressing the `latest` promotion path — if so,
   duplicate and say why in the PR description.
3. Match `latest`'s own depth of automation, don't exceed it: no automated
   `sandbox→demo`/`demo→prod` promotion for frozen either, since `latest`
   doesn't have that automation. Manual-dispatch is fine there.
4. Fold in the ConfigMap-sync-vs-Helm race fix: add a pre-flight `kubectl get
   configmap` check in `_helm-deploy.yml` before `helm upgrade --install`,
   failing fast with a clear message instead of burning the `--wait` timeout
   on a first-time namespace/service deploy. This has bitten FTP once and 6
   services once already — fix it structurally here, don't leave it ad-hoc.
5. Migrations remain gated via the existing `deploy_mode != 'pinned'` clause —
   don't touch that mechanism, this step is only about the promotion trigger.
6. PR against `DevOps`, reviewed, and **tested with at least one real
   `dev-frozen → stage-frozen` promotion run** for one service before merge
   (it can't be validated locally — GitHub Actions runtime only).

**Do not proceed to Step 3 until this is merged and you've watched at least
one automated promotion succeed end to end.**

## Step 3 — Onboard `dev-frozen` + `stage-frozen` for all 14 registry services

**Goal:** every service in `registry.yaml`, not just the current 7, has
working `dev-frozen`+`stage-frozen` values/env files and reaches
`stage-frozen` via Step 2's real promotion mechanism.

Per-service prerequisites (check before onboarding, not after):
- **`fulltext`** (`DocBits_FullText`) — fix the ungated
  `deploy-opensearch-templates` inline migration job first (runs
  unconditionally against EU+US OpenSearch, gated only on
  `github.event_name == 'push'` — it evaded the registry `has-migrations`
  audit because it targets OpenSearch, not Postgres/Alembic). `fulltext-api`
  can onboard once fixed; `fulltext-beat` stays blocked on the beats ticket.
- **`docnet`** (`DocBits_DocNet`) — migration job is already fully commented
  out (confirmed safe), `docnet-api` can onboard now with no migration fix
  needed. `docnet-beats` blocked on the beats ticket. `docnet-discord-bot`
  **never onboards** — deprecated, permanently excluded.
- **`email_import`** (`DocBits_Email_Import`) — fix the ungated
  `alembic-validation` job first (same pattern FTP had pre-fix, including a
  self-push-back commit step) before adding its `dev-frozen` build trigger.
- **`auth`**, **`operator`**, **`ideas`** — no known migration blocker found
  yet; audit each for a residual inline migration job (same grep pattern:
  search for `alembic`/`migrate`/`migration` in their deploy workflows) before
  onboarding. Lower priority, on-demand.
- **The 7 already-onboarded services** — backfill their Step 1
  `release-channels` entries if not already done, and migrate them off the old
  manual `stage-frozen` bridge onto Step 2's real promotion path (re-verify
  they still work through it).

Per-service onboarding bundle (same for every service): build-trigger PR (add
`dev-frozen` via `deploy-branches.yaml` + `sync-build-deploy-triggers.py`),
migration-gate fix if flagged above, Helm values
(`dev-frozen.yaml`/`stage-frozen.yaml` via `scaffold-frozen-values.sh`),
`registry.yaml` `release-channels` entry per Step 1's schema. One PR bundle
per service, not one giant PR for all of them.

**`doc2-api` (`DocBits_API`) is explicitly OUT of scope for this step** — it's
handled entirely in Step 4, since it's not onboarding via the normal
build-trigger path (it's already registered in `registry.yaml`, the problem
is its bespoke workflow chain, not missing scaffolding).

## Step 4 (last) — Fold `DocBits_API`'s migration step into the templated solution

**Goal:** retire `DocBits_API`'s entire bespoke `deployment-deploy-*.yml`
workflow chain, cutting it onto `registry.yaml`/`deploy.yml`/`_helm-deploy.yml`
exactly like the other 13 services. This is the step that finally supersedes
and deletes the `#10174` stopgap outright — not just the one patched step,
the whole bespoke file chain.

1. `registry.yaml`'s `doc2-api` entry already exists and is fully specified
   (`api`, `api-celery`, `api-celery-callbacks`, `beats`, `beats-tasks`,
   `api-websocket`, `api-flower`, `has-migrations: true` with full migration
   config) — you are not building registry scaffolding from scratch, you're
   cutting the trigger path over.
2. Execute the celery queue-prefix wiring
   (`CELERY_QUEUE_PREFIX`-equivalent) for
   `api-celery`/`api-celery-callbacks`/`api-beats-tasks` as part of this
   cutover — config/values-file change only, no application code. Get review
   before merge; this affects live queue routing.
3. `api-beats` stays excluded from this cutover's `release-channels`
   component list — blocked on `TICKET-beats-channel-readiness.md`, not part
   of this step.
4. Migrate the delta-only Helm values for `api`/`api-celery`/
   `api-celery-callbacks`/`api-flower` into the registry convention (Step
   1/3's pattern), add API's `dev-frozen`/`stage-frozen` `release-channels`
   entries.
5. Create `DocBits_API`'s own `deploy.yaml` wrapper (mirroring the other 13
   services' pattern — calls `FELLOWPRO/DevOps/.github/workflows/deploy.yml@main`).
6. **Shadow-run one full cycle on the generic pipeline before deleting
   anything** — prove parity against the bespoke path's current behavior for
   at least one full `dev-frozen` deploy.
7. Only after shadow-run parity is confirmed: delete
   `deployment-deploy-dev-frozen.yml`/`deployment-deploy-stage-frozen.yml`/
   `deployment-deploy-base.yml` outright (this also removes the need for
   `#10174`'s patched step — it goes away with the file).

## Definition of done for this session

Work through Steps 2→4 in order; it is fine and expected to not finish all
three in one session — stop at whichever step you're on, update the plan's
"Where we stand" section with exactly which step is done/in-progress/blocked,
and leave a clear resume point. Do not skip ahead to a later step if an
earlier one isn't merged and verified — the dependency is real, not
procedural caution.

Update `PLAN-frozen-latest-rollout.md` at the end of the session (or at each
step boundary if the session runs long): move completed steps into the
"Where we stand" summary (compressed — this plan intentionally does not carry
a session-by-session narrative log anymore, keep it that way), and leave the
roadmap section accurate for whatever's left.
