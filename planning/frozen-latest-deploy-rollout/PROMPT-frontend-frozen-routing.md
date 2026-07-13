---
title: Kickoff prompt — Frontend Frozen/Latest Routing
status: reference
created: 2026-07-08
updated: 2026-07-08
owner: gregor
summary: Ready-to-paste prompt for a new session to execute DOCB-13464 (two DocBits_Web builds under one domain, split by path, redirected by org release_channel).
---

# Kickoff prompt for a new session

Paste the block below as your first message in a fresh session.

---

Work on Jira ticket **DOCB-13464** — "Frontend: serve two DocBits_Web builds
(latest at `/`, frozen at `/frozen/`) with post-login channel redirect".

Full design doc, already written and reviewed:
`/Users/gregor/dev/orchestrator/planning/frozen-latest-deploy-rollout/PLAN-frontend-frozen-routing.md`

Read that plan in full before doing anything else — it has the product
context, the confirmed live infra facts (dev-frozen/dev namespaces, host
rewrite mechanism in DOCB-13416), and a local POC that already proved the
serving layer works (`planning/docbits-web-frozen-poc/`).

Also read the sibling backend plan it depends on/composes with:
`/Users/gregor/dev/orchestrator/planning/frozen-latest-deploy-rollout/PLAN-frozen-latest-rollout.md`
— this is the in-flight backend rollout (dev-frozen/stage-frozen namespaces,
Helm overlay, migrations gate) for the SAME `release_channel` flag. Don't
duplicate or conflict with it; frontend work here is additive.

Start with Wave 1 from the plan (§9): frontend code changes only, no CI/deploy
changes yet.

1. Set up a worktree per `/Users/gregor/dev/orchestrator/CLAUDE.md`'s
   Branch & Worktree Policy — do NOT check out a feature branch directly in
   `/Users/gregor/dev/DocBits_Web`. Pull `dev` first if the clone is clean.
2. Confirm the plan's §4.1 finding still holds: make `quasar.config.cjs`'s
   `publicPath` env-driven (`process.env.APP_VUE_PUBLIC_PATH || '/'`) —
   this was validated locally already but re-verify against current `dev`.
3. Implement §4.3 (the redirect layer): `getBuildChannel()` derived from the
   build's own base path/env, wired into the same call site where
   `setChannel()` currently triggers `window.location.reload()` in
   `src/store/User/user_details.store.ts` / `src/pages/api-base-url.ts`. On a
   mismatch between the running build's channel and the resolved org
   channel, do a full-page redirect into/out of `/frozen`, preserving the
   rest of the path. Guard against redirect loops.
4. Handle Service Worker scope per §4.3's last bullet — `/` and `/frozen/`
   builds must register with distinct `Service-Worker-Allowed` scopes (the
   POC's nginx config already demonstrates the header split needed on the
   serving side; confirm the app's own `sw.js` registration call respects
   `import.meta.env.BASE_URL`).
5. Before writing CI/deploy changes (§7, Wave 3), resolve the open question
   in §8: what is the actual frozen-frontend source (a new `*-frozen`
   frontend branch, mirroring the backend's branch convention, vs. reusing
   `stage`)? Ask Gregor if it isn't already decided elsewhere by the time you
   start — don't guess and build against the wrong branch.
6. Don't touch `stage`/`sandbox`/`demo`/`prod` deploy paths — dev only, per
   §7 point 5 and the backend rollout's phasing.

Work in small, reviewable commits. Open a PR per this repo's standard flow —
do not commit to `dev` directly (see `orchestrator/CLAUDE.md`, "Always open a
PR, never commit to main").
