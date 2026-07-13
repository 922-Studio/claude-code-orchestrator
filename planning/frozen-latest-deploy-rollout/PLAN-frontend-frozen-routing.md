---
title: Frontend Frozen/Latest Routing — Two Web-App Builds, One Domain
status: proposed
created: 2026-07-08
updated: 2026-07-08
owner: gregor
summary: E2E design for DocBits_Web to serve two independently-built frontend versions (latest at `/`, frozen at `/frozen/`) from a single nginx container/domain, with a post-login navigation redirect deciding which one a user lands on based on their org's `release_channel` flag (DocBits_Auth). Validated locally against a real quasar build + the production nginx.conf/Dockerfile; complements (does not replace) the existing host-rewrite mechanism from DOCB-13416 and the backend rollout in PLAN-frozen-latest-rollout.md.
---

# Frontend Frozen/Latest Routing — Two Web-App Builds, One Domain

## 1. Problem this solves (and doesn't)

Today's shipped mechanism (`mo-frontend-frozen-routing` / DOCB-13416, extended by
`mo-frozen-all-services`) ships **one** frontend bundle. At runtime it reads the
active org's `release_channel` and rewrites which **backend hostnames**
(`dev.api.docbits.com` vs `dev.api.frozen.docbits.com`, confirmed live for ~10
services in the `dev` / `dev-frozen` k8s namespaces) it calls. The frontend
**code itself is always current** — a frozen org still runs today's JS talking
to yesterday's (pinned) API.

This plan is for a genuinely different, additive requirement: **the frontend
code itself must also be pinned for frozen orgs** — i.e. two real builds of
DocBits_Web running simultaneously under one domain, chosen per-user by the
same `release_channel` flag. This does not touch or replace the existing
host-rewrite mechanism; a frozen-channel build still needs to talk to the
frozen backend, so both mechanisms compose (see §5).

**Confirmed out of scope / not needed:** the `dev-latest` k8s namespace and
`dev-latest.api.docbits.com` are not used for this — per Gregor, all
service traffic is exclusively `dev.api.docbits.com` (latest) or
`dev.api.frozen.docbits.com` (frozen). `dev-latest` is a leftover, unrelated
DO Apps Platform slot for the *web* app only and is not part of this design.

## 2. Product flow

1. User authenticates. Auth returns the org list, each with `release_channel
   ∈ {latest, frozen}` (`DocBits_Auth.organisation.release_channel`, already
   shipped — plain JSON field, not a JWT claim).
2. Frontend resolves the active org's channel exactly as `channelFromOrgs()`
   already does today (`src/utils/region-sync.ts` on `mo-frontend-frozen-routing`).
3. **New behavior:** if the resolved channel doesn't match which build the
   user is currently running (tracked by URL prefix, not by a stored flag —
   see §4.3), the app performs a full navigation redirect into the matching
   build's path prefix, carrying the rest of the route with it.
4. Both builds are served by the same nginx container/domain
   (`dev.docbits.com/` = latest, `dev.docbits.com/frozen/` = frozen) — proven
   locally, see §6.
5. Each build's own bundled config/env points its API calls directly at the
   matching backend (root → `dev.api.docbits.com`, frozen →
   `dev.api.frozen.docbits.com`) — build-time, not runtime-detected, because a
   frozen bundle should never be able to drift onto latest APIs (see §5).

## 3. Why this needs a redirect, not edge-only routing

The channel is **org-scoped, known only after authentication**. nginx cannot
decide which build to serve for an anonymous first hit — there is no
pre-login signal (no cookie, no header, confirmed no JWT claim exists today —
see prior investigation of `DocBits_Auth/oauth/routes.py`). So:

- **First anonymous load always serves root (`/`, latest).** This is the
  fixed default — same principle as `setChannel()` defaulting to `latest`
  for any org that never opted in.
- **After login**, the resolved channel may require moving the user from `/`
  to `/frozen/...` (or back). This is a client-side `window.location` redirect
  (full reload — unavoidable, since it's a different JS bundle, not an SPA
  route), mirroring the existing reload-on-channel-change lifecycle in
  `setChannel()`.
- **Org switching mid-session** (multi-org users) re-runs the same check on
  every org switch, exactly where `setChannel()` already hooks in
  (`user_details.store.ts`).
- **Logout** always returns the user to `/` (root/latest) as the safe
  pre-login default.

## 4. Frontend changes required

### 4.1 Build-time: parametrize `publicPath`

`quasar.config.cjs` hardcodes `publicPath: '/'` and `vueRouterMode: 'history'`.
Validated locally (see §6) that changing this to
`publicPath: process.env.APP_VUE_PUBLIC_PATH || '/'` is sufficient — Vite/Quasar
correctly rewrites every asset reference (`/assets/...` → `/frozen/assets/...`)
and the router base with no other code changes.

### 4.2 Build-time: pin each build's backend targets

The frozen build must not rely on the runtime host-rewrite (`buildServiceUrl()`)
picking the right host — it should be built with its API base URLs **already**
pointed at the frozen hosts (`dev.api.frozen.docbits.com` etc. for whichever
services are in scope), via a dedicated `_frozen.env` (or equivalent) consumed
at `quasar build` time, parallel to the existing `_sandbox.env`/`_stage.env`
pattern. This makes "frozen build talks to frozen API" a build-time invariant
instead of a runtime one — removing the failure mode where a frozen bundle
accidentally reloads/reruns latest-channel logic and drifts onto normal hosts.

### 4.3 Runtime: the redirect layer (new code, small surface)

- Add a `getBuildChannel(): 'latest' | 'frozen'` derived from
  `import.meta.env.BASE_URL` (or an injected build-time constant) — i.e. "which
  build is this JS actually running as", independent of `release_channel`
  storage.
- In the same place `setChannel()` currently triggers `window.location.reload()`
  on a channel change, additionally compare `getBuildChannel()` against the
  resolved org channel. On mismatch, redirect:
  `window.location.href = (resolvedChannel === 'frozen' ? '/frozen' : '') + currentPathWithoutPrefix`.
- Guard against redirect loops (e.g. a frozen build somehow resolving
  `latest` for its own org — should not happen if §4.2 is correct, but the
  redirect must be idempotent / single-shot per navigation).
- Service Worker scope: each build's `sw.js` must be registered with
  `Service-Worker-Allowed` scoped to its own prefix (already handled in the
  nginx config validated in §6 — `/` vs `/frozen/` get distinct
  `Service-Worker-Allowed` headers) so the two PWAs don't fight over scope.

## 5. Composing with the existing host-rewrite mechanism

Two independent axes, both driven by the same `release_channel` flag, serving
different purposes:

| Axis | Owner | Decides |
|---|---|---|
| Build/path (`/` vs `/frozen/`) | **This plan** | Which **frontend code** a user runs |
| Host rewrite (`buildServiceUrl()`) | DOCB-13416 (shipped) | Which **backend** a given service call hits |

Once §4.2 ships (build-time pinned backend targets), the frozen build has no
practical need to *also* do runtime host-rewriting for itself — but the
existing mechanism should be left in place unchanged (harmless — it'll always
resolve to the same hosts the frozen build was already pinned to) rather than
special-cased or removed, to avoid touching shipped, working code for a
version-parity reason DOCB-13416 doesn't need.

## 6. Local validation performed (this session)

Built and ran a working local proof of concept confirming the serving layer:

- Pulled `dev` (fast-forwarded, current HEAD) and `stage` (used as the
  practical "frozen" stand-in, since no dedicated frozen frontend branch
  exists yet) into separate git worktrees.
- Patched `quasar.config.cjs`'s `publicPath` to be env-driven (local-only,
  not committed) and ran the **real** `quasar build -m pwa` pipeline for
  both, once with `APP_VUE_PUBLIC_PATH=/`, once with `=/frozen/`, both against
  `_sandbox.env`.
- Assembled a combined docroot (latest at root, frozen nested under `frozen/`)
  and took the **actual production** `deploy/nginx.conf` from the repo,
  extending it with a mirrored `/frozen/*` location block (exact-match
  no-cache control files, `^~ /frozen/assets/` immutable caching,
  `try_files $uri /frozen/index.html` SPA fallback).
- Built and ran this in Docker (stock `nginx:alpine`; skipped the
  brotli/zstd module-compile stage as irrelevant to the routing question).
- **Verified:** `/` and `/frozen/` both serve correct, genuinely different
  app versions (different version strings, different content-hashed asset
  filenames, both rewritten correctly to their own path prefix); deep routes
  under `/frozen/...` correctly SPA-fallback to `/frozen/index.html`;
  cache headers match production semantics on both paths; hashed assets are
  immutable-cached identically on both paths.
- Artifacts: `planning/docbits-web-frozen-poc/{Dockerfile,nginx.conf,docroot/}`.

**Not yet validated (needs the real ticket's work):** the post-login redirect
layer (§4.3) — the POC only proves nginx can serve two builds side-by-side, not
that the app correctly navigates a user between them.

## 7. CI/deploy pipeline changes needed

Per the real deploy flow (`deployment.yaml` — build runs on the GitHub Actions
runner via `quasar build`, output is pushed as flat files to the separate
`FELLOWPRO/Docbits_app` repo, one branch per environment, then
`doctl apps create-deployment` rebuilds a single DO App Platform service per
branch):

1. Add a second `quasar build -m pwa` invocation per deploy run (frozen
   config/env), building into `dist/pwa-frozen/` alongside the existing
   `dist/pwa/`.
2. The `Deploy SPA+PWA to Docbits_app` step's cleanup/pruning logic (the
   `find ... ! -name assets ! -name js ...` block) must add `frozen` to its
   keep-list, or the frozen tree gets deleted every deploy.
3. `cp -R ../dist/pwa/. ./` gains a second line copying the frozen build into
   `./frozen/`.
4. `deploy/nginx.conf` (regenerated into the deploy repo every deploy, per
   existing pattern) needs the `/frozen/*` block from §6 added permanently.
5. Decide which environments actually need this (dev only, to start, per the
   backend rollout's phasing in `PLAN-frozen-latest-rollout.md`) — do not
   wire this into `stage`/`sandbox`/`demo`/`prod` deploy paths until the
   backend frozen slots exist there too.

## 8. Risks / open questions

- **Double build time.** Every CI deploy now runs `quasar build` twice —
  measure actual added minutes before assuming it's negligible (the existing
  `_tests.yml`/`_quality-gates.yml` gates plus one `quasar build` are already
  the slowest part of `deployment.yaml`).
- **Version skew of the frozen frontend source.** What exactly does "frozen
  frontend code" pin to — a tag bumped only on hotfixes to the frozen line
  (mirrors the backend's "frozen only receives hotfixes" model in
  `PLAN-frozen-latest-rollout.md` §0), or a manually-maintained `stage-frozen`
  frontend branch? This needs a decision before Wave 1 — recommend mirroring
  whatever branch/tagging convention the backend rollout settles on for
  consistency (`*-frozen` branches, e.g. a new `dev-frozen` **frontend**
  branch, not reusing `stage` as this plan's POC did for convenience).
- **Redirect UX flash.** A full-page redirect after login is a visible reload;
  confirm this is acceptable (it already happens today for region-switch via
  `setApiRegion`, so likely fine, but worth confirming with product).
- **Bookmarked/shared `/frozen/...` deep links** for a user whose org is
  actually `latest` (or vice versa) — decide whether to honor the URL as
  requested or force-redirect to the resolved channel unconditionally
  (recommend: unconditional redirect, to prevent a stale bookmark silently
  running the wrong app version against the wrong API).
- **SEO/CDN interaction.** Cloudflare sits in front of this (per
  `deploy/README.md`) — confirm the `/frozen/*` control-file no-cache headers
  survive the CDN identically to root's (should, since it's the same origin
  nginx rule, but the CI plan in §7 should include the same `curl` smoke test
  the current deploy validates root with).

## 9. Suggested execution waves

1. **Wave 1 — Frontend code:** `quasar.config.cjs` env-driven `publicPath`,
   `getBuildChannel()`, redirect logic in the `setChannel()` call site,
   Service-Worker scope handling. Ship behind a flag/dev-only branch first.
2. **Wave 2 — Frozen frontend source-of-truth:** decide + create the actual
   `*-frozen` frontend branch/tagging convention (see §8), separate from this
   plan's throwaway `stage`-as-stand-in POC.
3. **Wave 3 — CI/deploy pipeline:** the `deployment.yaml` + `deploy/nginx.conf`
   changes in §7, dev environment only.
4. **Wave 4 — Validation:** end-to-end test with a real frozen-channel test
   org (per `E2E_TEST_ORG_ID` pattern already in `_sandbox.env`), confirming
   redirect, correct API pinning, and SW scope isolation.
5. **Wave 5 — Rollout to stage/sandbox/demo/prod**, gated on the backend
   rollout (`PLAN-frozen-latest-rollout.md`) having live frozen slots in the
   same environments.

## 10. References

- `planning/frozen-latest-deploy-rollout/PLAN-frozen-latest-rollout.md` —
  backend/infra generalization this plan depends on and composes with.
- `planning/docbits-web-frozen-poc/` — local POC artifacts from this session.
- DOCB-13416 / `mo-frontend-frozen-routing`, `mo-frozen-all-services` —
  shipped host-rewrite mechanism this plan is additive to.
- DOCB-13379 — parent epic ("Multi-Org Login & Release-Kanäle").
