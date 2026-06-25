# Handover Prompt — Fix CI/deploy failures after polaris runner migration

> Paste the fenced block into a fresh Claude Code session launched from `/Users/gregor/dev/922`.
> Self-contained. Companion handover for the (separate, app-level) pnpm 11 break:
> `orchestrator/HANDOVER-pnpm11-fix.md`.

---

```
SITUATION
We migrated all GitHub Actions self-hosted runners from antares (the Swarm manager, formerly
"home-lab") to polaris (a fresh worker, formerly "home-lab-exec-0"). We also refactored the
reusable workflows in the `922-Studio/workflows` repo to stop relying on a persistent
/home/lab/<Service> checkout and instead use actions/checkout into $GITHUB_WORKSPACE, with a
DOCKER_HOST=ssh://lab@astro-antares bridge so deploy commands still run containers on antares.

After merging the rename + refactor PRs, the first deploys on polaris went broadly RED across
repos. PRODUCTION IS SAFE: every failure happened before any image was pushed/deployed, so all
services still run their previous images. But CI is broken and must be fixed.

ROOT-CAUSE HYPOTHESIS (two intertwined buckets — confirm each)
A) Reusable-workflow refactor gaps (in 922-Studio/workflows, consumed @main by all repos):
   - actions/checkout for PRIVATE caller repos needs an explicit token; some jobs don't get it.
   - versioning needs full history + tags (shallow --depth=1 --no-tags hides existing tags →
     recomputes an already-used version → tag push rejected).
   - smoke-test / deploy-docker compute a workdir from $GITHUB_WORKSPACE but hit
     "Working directory does not exist" — checkout didn't populate, or working_directory subpath.
B) Polaris host not yet at parity with antares (servers are not 100% configured):
   - antares runners had a persistent _work dir with cached git credentials, accumulated git
     tags, and a docker login to registry.922-studio.com. Fresh polaris has none of this.
   - The DOCKER_HOST=ssh://lab@astro-antares bridge needs: working SSH key lab@polaris→lab@antares
     (verified manually), antares in known_hosts for the `lab` user non-interactively, and antares
     reachable for `docker compose pull/up`.
   - Polaris likely needs `docker login registry.922-studio.com` configured for the `lab` user so
     deploy/pull steps authenticate.

EXACT FAILURE TAXONOMY OBSERVED (use these runs as evidence)
- HomeAuth  (run 28016088079, version job): step "Create and push tag" →
    "! [rejected] v0.16.6 -> v0.16.6 (already exists)". Shallow checkout, no tags.
- Anime-API (version job, "Checkout Application Code"): "fatal: could not read Username for
    'https://github.com': terminal prompts disabled" → empty token on private-repo checkout.
    NOTE: versioning.yml's checkout DOES pass `token: ${{ secrets.PAT_GITHUB }}`, so the CALLER
    is not passing the PAT_GITHUB secret into the versioning reusable (check `secrets:` blocks /
    consider `secrets: inherit`). Same for Anime-APP.
- HomeAPI / HomeCollector (smoke job, "Generate isolated smoke compose config", preceded by
    "Working directory does not exist"): smoke-test.yml workspace not populated. env_file_source
    scp from antares SUCCEEDED, so the SSH/scp path works; the repo checkout is the gap.
- discord (deploy-docs, deploy-docker "Deploy with zero-downtime rolling update"):
    "Working directory does not exist!" — deploy-docker.yml checkout/workdir.
- HomeUI / Studio / Anime-APP (Build Docker image / Unit tests): pnpm 11 — SEPARATE handover.
- HomeCollector "Run pytest", smoking-counter "Install project dependencies": Python test env;
    may be deps or DB/service reachability from polaris — investigate (possibly bucket B).

AFFECTED REPOS (all under /Users/gregor/dev/922; org 922-Studio)
HomeAPI, HomeAuth, HomeCollector, Anime-API, Anime-APP, discord (Python/docs path)
+ HomeUI, Studio, Portfolio, sweatvalley_bingo, Drafter (also hit pnpm — other handover).

KEY FILES
- Reusables: 922-Studio/workflows/.github/workflows/{versioning,smoke-test,docker-build,
  deploy-docker,frontend-tests,frontend-e2e,python-tests}.yml  (base branch: main; consumed @main).
  Version-bump logic: workflows/.github/scripts/determine_version.py
- Server reference: orchestrator/server.md (cluster table; antares=manager, polaris=runners).
- Memory: feedback_server_changes — server config changes must be committed (CI/CD overwrites
  manual host edits); check whether runner host setup is codified in HomeStructure.

FIX APPROACH (methodical; do NOT mass-merge again until a full green canary)
1) In the `workflows` repo (branch off main, one PR):
   - Add `token: ${{ secrets.PAT_GITHUB }}` to EVERY actions/checkout of a caller/app repo that
     lacks it (smoke-test, docker-build, deploy-docker, frontend-*). Verify private repos clone.
   - For versioning.yml: set `fetch-depth: 0` and `fetch-tags: true` on the app checkout so tag
     computation is correct and deterministic on a fresh runner.
   - Ensure callers pass the PAT secret to versioning (audit each repo's `version:` job `secrets:`;
     prefer `secrets: inherit` if appropriate) OR make versioning resilient.
   - Re-check smoke-test/deploy-docker workdir logic against an actually-populated $GITHUB_WORKSPACE.
2) Polaris host config parity (commit any host setup the proper way — see memory; don't hand-edit):
   - `docker login registry.922-studio.com` for user `lab` on polaris (use REGISTRY_USERNAME/PASSWORD).
   - Confirm `lab@polaris` has antares in ~/.ssh/known_hosts (StrictHostKeyChecking) for the bridge.
   - Confirm DOCKER_HOST=ssh://lab@astro-antares works from a real Actions job context (it works
     from an interactive ssh; verify under the runner service user/environment).
3) Canary: re-run ONE Python repo (e.g. HomeAuth or Anime-API) to FULL green, then ONE deploy-docker
   repo (discord docs), then the rest. Fix pnpm repos via the other handover before re-running them.

PARTIAL STATE TO RECONCILE
Each failed run's version job had already done "Commit and push version file" BEFORE failing at the
tag step — so several repos have a `chore: Update version to X [ci skip]` commit on dev/main with NO
matching tag and NO deploy. Verify this didn't leave version.txt ahead of tags; the next clean run
should reconcile, but check determine_version.py handles "version file ahead of tags" gracefully.

HOUSE RULES (/Users/gregor/dev/922/CLAUDE.md)
- Worktree + feat/ branch per repo; PR to the repo's base (dev where it exists, else main);
  workflows repo base = main (requires 1 review). English; no Co-Authored-By. Remove worktree
  after PR URL captured; never delete remote branches. Server changes committed via HomeStructure,
  not hand-edited on the host.

VALIDATE
gh run list --repo 922-Studio/<repo> --branch <base> --limit 3
gh run watch <id> --repo 922-Studio/<repo>
Goal: a Python repo and a docs/deploy-docker repo both fully green on polaris runners.
```
