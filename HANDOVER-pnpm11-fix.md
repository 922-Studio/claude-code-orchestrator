> ## ✅ RESOLVED — 2026-06-23
>
> **Fix:** Pinned pnpm to `10.34.3` (latest 10.x) in Drafter via `packageManager`
> field + Dockerfile `corepack prepare`. PR [922-Studio/Drafter#20](https://github.com/922-Studio/Drafter/pull/20)
> (merged to `dev`).
>
> **Scope correction:** Drafter is the **only** pnpm repo in 922-Studio. HomeUI, Studio,
> Portfolio, Anime-APP and sweatvalley_bingo all build with `npm ci` (verified: Dockerfiles +
> `frontend-tests` `install_command: npm ci`) and were never affected. The reusable
> `workflows` repo needed no change — its `frontend-tests.yml` only runs `corepack enable`,
> so it honors the pinned `packageManager` field automatically.
>
> **Validation:** Deploy run `28035700812` on `dev` — `Build Docker image` ✅ green
> (pnpm 10.34.3, the previously-failing `pnpm install --frozen-lockfile` step), and the unit-test
> job ran pnpm 10.34.3 + `pnpm install` clean with 37/37 test files passing. Also confirmed
> locally: `pnpm@10.34.3 install --frozen-lockfile` → exit 0, `pnpm.onlyBuiltDependencies`
> honored (prisma builds), no `ERR_PNPM_IGNORED_BUILDS`.
>
> **Still red but OUT OF SCOPE (runner-migration infra, tracked in `HANDOVER-ci-polaris-deploy-fix.md`):**
> Smoke test (`.env` not found on `actions-runner-2`) and the unit-test job's *publish* step
> (GitHub Actions artifact storage quota hit). Neither involves pnpm.

---

# Handover Prompt — Fix pnpm 11 build breakage across 922-Studio pnpm repos

> Paste everything in the fenced block below into a fresh Claude Code session launched
> from `/Users/gregor/dev/922`. It is self-contained.

---

```
CONTEXT
Our CI builds started failing because Corepack now resolves `pnpm@latest` to pnpm 11.8.0,
which introduces a breaking change: pnpm 11 refuses to auto-run dependency build scripts
and exits non-zero. Symptom in CI:

    [ERR_PNPM_IGNORED_BUILDS] Ignored build scripts: @prisma/engines, msw, prisma, sharp, unrs-resolver
    Run "pnpm approve-builds" to pick which dependencies should be allowed to run scripts.
    ERROR: process "/bin/sh -c pnpm install --frozen-lockfile" did not complete successfully: exit code: 1

Also: pnpm 11 prints `[WARN] The "pnpm" field in package.json is no longer read by pnpm`
(e.g. `pnpm.onlyBuiltDependencies` is ignored — its config home moved).

This is NOT related to our recent server rename / runner migration (that is done and validated).
It is a pure dependency-tooling breakage that surfaces on any runner because the pnpm version
is fetched at build time via Corepack, not pinned.

EVIDENCE
- Failing run: Drafter Deploy, run id 28015353678 (github.com/922-Studio/Drafter), branch dev.
  Both "Build Docker image" and "Unit tests" jobs fail at `pnpm install --frozen-lockfile`.
- Last successful Drafter build was 2026-04-02 (pnpm was 10.x then).

WHERE THE PNPM VERSION COMES FROM (investigate + confirm)
1. Each pnpm repo's Dockerfile typically does: `RUN corepack enable && corepack prepare pnpm@latest --activate`
   → pulls pnpm 11. Grep each repo's Dockerfile(s).
2. The reusable workflow `922-Studio/workflows/.github/workflows/frontend-tests.yml` also sets up
   pnpm via corepack for the Unit-tests job. Check how it resolves the version (enable_corepack input).
3. `package.json` may or may not have a `packageManager` field. If absent, corepack falls back to latest.

AFFECTED REPOS (pnpm-based; all under /Users/gregor/dev/922)
- Drafter        (Next.js, prisma)
- HomeUI         (frontend)
- Studio         (frontend)
- Portfolio      (frontend)
- Anime-APP      (frontend)
- sweatvalley_bingo (frontend)
(Python repos — HomeAPI, HomeAuth, HomeCollector, Anime-API, discord — are NOT affected.)

RECOMMENDED FIX (chosen approach: pin pnpm to 10.x)
For each affected repo:
- Add/lock `"packageManager": "pnpm@10.<latest-10.x>"` in package.json (this is the value Corepack
  honors first, in both the Dockerfile `corepack prepare` and the reusable workflow).
- In the Dockerfile, change `corepack prepare pnpm@latest --activate` to use the pinned version
  (e.g. `corepack prepare pnpm@10.x.x --activate`, or rely on `packageManager` + `corepack enable`).
- Verify the reusable frontend-tests.yml path also respects the pinned version; if it hardcodes
  `pnpm@latest` anywhere, pin it there too (that's a change in the `workflows` repo, base `main`,
  which is consumed @main by all callers — coordinate carefully).
Confirm the exact latest pnpm 10.x at fix time.

ALTERNATIVE (only if you decide to adopt pnpm 11 instead of pinning)
- Move the build-script allowlist to the pnpm 11 config home: add `onlyBuiltDependencies:` to a
  `pnpm-workspace.yaml` (or the new settings location pnpm 11 documents) listing prisma, @prisma/engines,
  msw, sharp, unrs-resolver. More work, must be validated per repo.

WORKFLOW / HOUSE RULES (from /Users/gregor/dev/922/CLAUDE.md)
- All code work in an isolated git worktree on a feature branch: feat/pnpm11-fix
  Path: <repo>/.worktrees/feat/pnpm11-fix ; create with `git -C <repo> worktree add ...`.
- Branch off the repo's default base: most repos use `dev`; some only have `main`
  (check per repo with `git -C <repo> symbolic-ref --short refs/remotes/origin/HEAD`).
  Drafter's default is `dev`.
- One PR per repo, targeting that repo's base branch.
- Commit messages + PRs in English. NO Co-Authored-By trailers.
- After PR URL captured, remove the worktree. Do not delete remote branches.
- Org GitHub secrets exist for registry/PAT/discord; no secret changes needed for this fix.

VALIDATE
- After merging a repo's fix, the push triggers its Deploy workflow on the polaris runners.
  Watch the run: `gh run list --repo 922-Studio/<repo> --branch <base> --limit 3` then
  `gh run watch <id> --repo 922-Studio/<repo>`. Build + smoke + unit tests must go green.
- Use Drafter as the first canary (it has the most moving parts: prisma build scripts).

DELIVERABLE
- Green builds across all 6 pnpm repos on the polaris runners, pnpm version pinned and reproducible.
- Update orchestrator task #15 / mark this handover resolved.
```
