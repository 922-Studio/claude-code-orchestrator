# PROMPT — Wave 0.6b: wire the full dev→stage→sandbox→demo→prod frozen chain
# (helm values + promotion workflows), both regions, all onboarded services

You are picking up the **frozen/latest deploy channel rollout** for DocBits.
Prior sessions got EU `dev-frozen` fully healthy for 7 services and found (but
did not yet fix) a structural gap: **the frozen channel only exists at the
`dev-frozen` stage.** Nothing past it — `stage-frozen` (partially), `sandbox-frozen`,
`demo-frozen`, `prod-frozen` — has the helm values, env files, ConfigMap-sync
wiring, or promotion automation needed for a service to actually reach those
environments through CI. Your job this session: build that out, end to end, for
both EU and US, so a service onboarded to frozen today can be promoted all the
way to `prod-frozen` the same way `latest` is promoted today — no further than
that, no less.

## Read first — mandatory, in this order
1. `planning/frozen-latest-deploy-rollout/PLAN-frozen-latest-rollout.md` —
   **read the `## STATUS` block in full**, especially the "🔵 NEXT SESSION
   (2026-07-09)" section (item 2) which has the exact, filesystem-verified
   inventory of what's missing. Also read §12.1 (Wave 0.6b design intent) and
   §3.1 (the 3-layer values overlay mechanism).
2. `planning/frozen-latest-deploy-rollout/MATRIX-migration-per-service.md` —
   which services are actually onboarded today (has a `dev-frozen` values file
   + build trigger) vs. still queued.
3. `planning/frozen-latest-deploy-rollout/TICKET-beats-channel-readiness.md` —
   what NOT to touch.
4. `/Users/gregor/dev/DevOps/scripts/scaffold-frozen-values.sh` — the values-delta
   generator you'll use repeatedly (read its header comment; it's short).

## Ground truth, verified 2026-07-08 by direct filesystem inspection — do not re-derive, act on this

**Onboarded services today (have a `dev-frozen` values file + live in EU
`dev-frozen`):** FTP (`ftp_import/api`), OCR (`ocr/api`, `ocr/celery`),
Extraction (`extraction/api`, `extraction/celery`), BarCode (`barcode/api`,
`barcode/celery`), PO-Matching (`pomatch/api`, `pomatch/celery`),
Auto-Accounting (`autoacc/api`), DocFlow (`DocFlow/docflow`,
`DocFlow/docflow-celery`) — **12 component dirs across 7 services.** (Note:
`email_import/api/dev-frozen.yaml` also exists but Email_Import is NOT yet
onboarded — its `build-deploy.yaml` also has an ungated inline migration job,
see the plan's Stream D findings. Leave Email_Import out of this session's
scope unless you also fix that gate; simplest is to exclude it entirely here.)

**Helm values state (`DevOps/services/<svc>/<component>/values/`):**
- `dev-frozen.yaml` exists for all 12 component dirs above. Nothing else.
- `stage-frozen.yaml`, `sandbox-frozen.yaml`, `demo-frozen.yaml`,
  `prod-frozen.yaml` **do not exist anywhere, for any service.**

**`envs` repo `.env` files:**
- `dev-frozen/{eu,us}/*.env` — fully populated (all services, pre-existing).
- `stage-frozen/eu/*.env` — populated. **`stage-frozen/us/` directory does not
  exist.**
- `sandbox-frozen/{eu,us}/*.env` — fully populated (pre-existing hand-bootstrap,
  same as dev-frozen).
- `demo-frozen/` and `prod-frozen/` — **do not exist at all**, neither region.

**ConfigMap-sync workflow path triggers (`envs/.github/workflows/`):**
- `deploy-configmap-dev-stage.yml` (EU, dev-stage cluster): has `dev-frozen/*`,
  `dev-frozen/eu/*`, `stage-frozen/*`, `stage-frozen/eu/*`.
- `deploy-configmap-us.yml` (US, us-docbits cluster): has `dev-frozen/us/*`,
  `stage-frozen/us/*`, `sandbox-frozen/us/*`.
- `deploy-configmap.yml` (EU, polydocs cluster — sandbox/demo/prod live here):
  has **only** `sandbox-frozen/eu/*`.
- **No workflow anywhere has a `demo-frozen/*` or `prod-frozen/*` pattern.**
  Even once env files exist there, nothing will sync them into a ConfigMap.

**Promotion automation (`DevOps/.github/workflows/`):**
- `nightly-dev-to-stage.yml` and `nightly-stage-to-sandbox.yml` exist for
  **latest only**. No frozen equivalent exists (Wave 0.6b, confirmed not built).
- **Important scoping fact:** latest itself has **no automated demo/prod
  promotion** either — no `nightly-*-to-demo` or `nightly-*-to-prod` workflow.
  Demo/prod promotion for latest is manual-dispatch today. **Match this depth
  exactly for frozen — do not build automation frozen has that latest lacks.**

## Guardrails — MANDATORY, do not violate
- **`sandbox-frozen` stays config/scaffolding-only.** You may create
  `sandbox-frozen.yaml` values files and confirm/backfill env files if any are
  missing, but do **not** trigger a deploy into the live `sandbox-frozen`
  namespace, do not build/enable a `stage-frozen → sandbox-frozen` promotion
  workflow run, and do not touch its two pre-existing crash-looping components
  (`barcode-celery`, `ocr-celery`). This matches the precedent already set by
  the ingress-registry frozen envs (Daniel's `4498301`, done EU dev-frozen-only
  in effect) — config exists and is correct, but nothing fires against that
  cluster from this work.
- Do **not** touch any `beats` scheduler component or `docnet-discord-bot`.
- **Ask before every `git push` / merge / PR merge**, across all 3 repos
  touched (`DevOps`, `envs`, and any per-service repo if a values-delta needs a
  matching `registry.yaml` `release-channels` entry). Never merge without
  explicit sign-off.
- Use worktrees per the orchestrator branch policy (`DevOps` off `main`, `envs`
  off `main`); remove after PR creation.
- Do not fold Email_Import into this session's onboarding — it's still queued
  behind its own migration-gate fix (see plan Stream D findings).
- Before any cluster mutation, confirm with the user first — this session
  should mostly be values/workflow authoring + CI verification, not manual
  kubectl surgery, but if a stage-frozen ownership issue resurfaces mid-verify,
  follow the same diff-before-delete discipline as prior sessions.

## Task — four parts, can be worked in sequence or split across parallel streams

### Part 1 — `stage-frozen` values + verify live (highest priority — this is the one environment already partially "live" via hand-bootstrap, so getting CI to own it properly is the most urgent piece)
1. For each of the 12 component dirs, run
   `scripts/scaffold-frozen-values.sh --values-dir services/<svc>/<component> --base-env stage --target-env stage-frozen --channel frozen [--queue-prefix-var CELERY_QUEUE_PREFIX for celery components]`.
   Review each generated delta — confirm it doesn't duplicate `stage.yaml`, and
   add any `stage`-specific host/queue override the delta needs (check against
   the already-existing `dev-frozen.yaml` sibling for the same component as a
   pattern reference).
2. Add a `release-channels` entry per component in `registry.yaml` for
   `stage-frozen`, mirroring the `dev-frozen` entries already there (§4 of the
   plan has the schema).
3. `envs` repo: create `stage-frozen/us/*.env` for these 7 services (copy from
   `dev-frozen/us/*.env` as the closest existing analog, then diff against
   `stage/us/*.env` for any stage-specific values that must be layered in —
   do not blindly duplicate; check DB URIs, hostnames, etc. per service).
4. `envs` repo: add `stage-frozen/us/*` path pattern... wait, it already exists
   in `deploy-configmap-us.yml` — verify this, don't re-add. Confirm
   `deploy-configmap-dev-stage.yml`'s existing `stage-frozen/eu/*` pattern is
   sufficient for EU (it is, per the ground truth above) — no EU changes needed
   for stage-frozen sync triggers.
5. PR the `DevOps` values+registry changes and the `envs` env-file changes
   separately (they're different repos). Get sign-off, merge.
6. Verify: trigger (or wait for) a promotion/dispatch into `stage-frozen` for at
   least 2-3 of the 7 services in both EU and US, confirm ConfigMap syncs,
   confirm helm-ownership lands correctly on first try (should, since these are
   fresh CI-driven objects, not hand-bootstrapped — if ownership still fails,
   that's the EU `stage-frozen`/US `dev-frozen` remediation from the prior
   session that may still be in flight; check the plan's Session 2 log first).

### Part 2 — Frozen promotion chain (Wave 0.6b core, §12.1)
1. Build a frozen equivalent of `nightly-dev-to-stage.yml` (promoting
   `dev-frozen`'s running pinned image tag to `stage-frozen`) and
   `nightly-stage-to-sandbox.yml` (`stage-frozen` → `sandbox-frozen`, config-only
   per the guardrail above — build the workflow but do not enable/run it against
   the live sandbox-frozen cluster this session; land it disabled or gated
   behind a manual-only dispatch that you don't invoke).
   - Prefer **parameterizing** the existing nightly workflows over duplicating
     them if `deploy-all-services.yml` can take a channel/env-pair parameter
     cleanly — check its current inputs first. If parameterizing risks
     regressing the latest promotion path, duplicate instead and say why.
   - Confirm region handling: frozen promotions are `region: all` (mirrors
     `dev-frozen`'s own build trigger), matching §3.9.
   - Confirm the `deploy_mode != 'pinned'` migration-skip gate in `deploy.yml`
     already covers promotion-triggered runs (it should — verified in a prior
     session for latest's nightly promotion; confirm it also holds for the new
     frozen promotion path once built).
2. Do **not** build `sandbox-frozen → demo-frozen` or `demo-frozen → prod-frozen`
   automated promotion — matching latest's own lack of such automation. Instead,
   confirm `deploy.yml`/`_helm-deploy.yml` can be **manually dispatched** against
   `demo-frozen`/`prod-frozen` once Part 3's scaffolding exists (a dry-run /
   `--dry-run` style check is enough, don't actually deploy there).

### Part 3 — `demo-frozen` + `prod-frozen` scaffolding (forward-looking, lower urgency — get the plumbing in place, don't deploy)
1. `envs` repo: create `demo-frozen/{eu,us}/` and `prod-frozen/{eu,us}/`
   directories with `.env` files for the 7 onboarded services, based on
   `demo/`/`prod/` as the base, with `RELEASE_CHANNEL=frozen` injected (same
   pattern as every other frozen env file — check one for the exact key).
2. `envs` repo: add `demo-frozen/*` and `prod-frozen/*` path patterns to
   `deploy-configmap.yml` (polydocs/EU — this is where demo/prod actually live)
   and to `deploy-configmap-us.yml` (US leg, if demo/prod have a US presence —
   check `registry.yaml` cluster membership first, since not all services may
   deploy demo/prod in both regions).
3. `DevOps` repo: scaffold `demo-frozen.yaml`/`prod-frozen.yaml` values deltas
   for the same 12 component dirs, `--base-env demo`/`--base-env prod`
   respectively.
4. Add matching `release-channels` entries in `registry.yaml`.
5. **Do not trigger any deploy into `demo-frozen`/`prod-frozen`** this session —
   this is scaffolding only, to unblock a future manual-dispatch promotion once
   product actually wants a frozen hotfix in those tiers. State this explicitly
   in your PR description.

### Part 4 — Update the plan
1. Update `PLAN-frozen-latest-rollout.md`'s `## STATUS` block with what got
   built vs. deferred, PR numbers, and verification evidence — same detail
   level as prior sessions' entries.
2. Update the Wave table (0.6b row) to reflect completion state.
3. Delete this prompt file once all four parts are done or explicitly deferred
   with a reason (Part 3 in particular may reasonably be partially deferred if
   time runs out — say so plainly rather than silently skipping it).

## Definition of done for this session
- Part 1: `stage-frozen` live and CI-verified (not hand-bootstrapped) for at
  least the services you test explicitly, values+registry PR merged, env-file
  PR merged.
- Part 2: frozen `dev-frozen → stage-frozen` promotion workflow built, merged,
  and either verified via a real run or explicitly scheduled for next
  verification window. `stage-frozen → sandbox-frozen` workflow exists but is
  not enabled/run against live infra.
- Part 3: `demo-frozen`/`prod-frozen` env files + values + registry entries +
  ConfigMap-sync path patterns exist and are merged; explicitly NOT deployed
  anywhere.
- Part 4: STATUS block and wave table updated; prompt file deleted.
