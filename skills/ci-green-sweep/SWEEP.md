# CI Green Sweep — playbook

You are the **Orchestration Lead** for Gregor's 922-Studio ecosystem. This playbook drives
**every repo to a green latest deploy and closes every CI-failure issue**, repo by repo, via
per-repo sub-agents. You orchestrate; sub-agents do the real work.

Invoked as: *"go through all repos, check open issues, close where green, fix where red, get
everything deployed green"* (`/ci-green-sweep`).

## Operating rules

- **Only real work happens in sub-agents.** You do read-only recon, triage, plan, dispatch,
  track, and report. Mutations (fixes, merges, issue closing) are delegated.
- **Sub-agent model: Sonnet** (standing preference; override only if asked).
- **Confirm scope/merge policy with Gregor up front** — see Phase 2. The two decisions that
  shape everything: (1) merge policy (auto-merge on green vs. PR-only), (2) infra scope
  (repo-code only vs. host changes allowed).
- **Cross-pollinate.** The moment one agent's fix resolves a symptom, push that exact pattern
  to every sibling repo showing the same symptom — even ones a prior agent called a "host
  blocker." Several "host blockers" are actually repo-code-fixable (see Gotchas).

---

## Phase 0 — Recon (read-only, do it yourself)

Read `registry.md` for the repo list + each repo's base branch (`dev` where it exists, else
`main`). Then sweep all repos:

```bash
# remotes + current branch
for d in <repos>; do git -C "$d" remote get-url origin; git -C "$d" rev-parse --abbrev-ref HEAD; done
# open issues + last 3 CI runs per repo
gh issue list -R 922-Studio/<repo> --state open --limit 100 --json number,title
gh run list -R 922-Studio/<repo> --limit 3 --json databaseId,name,headBranch,status,conclusion,createdAt
```

**Key triage signal:** compare each red run's `createdAt`/run-id to the others. A cluster of
failures at the *same timestamp* = a common root cause (an infra migration, a shared-workflow
change). Repos that **re-ran since** and went green prove the common fix already landed; repos
still showing the old red run just **need a re-run**, not a code fix.

For each still-red repo, get the failing job + step, then the failing log lines:
```bash
gh run view <id> -R 922-Studio/<repo> --json jobs -q '.jobs[]|select(.conclusion=="failure")|...'
gh run view <id> -R 922-Studio/<repo> --log-failed | grep -iE "error|fail|assert|exit code|no such|cannot|traceback|E   |would reformat" | head
```

Always read any `HANDOVER-*.md` in `orchestrator/` first — they often already name the root
cause and which fixes have landed.

---

## Phase 1 — Classify each repo

- **Latest deploy = success, has stale issues** → close all "CI Failure:" issues (comment +
  link the green run). No code change.
- **Latest run is the old common-failure wave, fixed upstream** → re-run; close issues if green.
- **Latest run is red post-fix** → genuine remaining failure; diagnose + fix (Phase 3 taxonomy).
- **Not a deployable service** (e.g. the `workflows` repo) → ignore stale runs.

## Phase 2 — Decisions to get from Gregor (AskUserQuestion)

1. **Merge policy** — *Auto-merge when PR-CI green* (fastest to "deployed green"; agents merge
   + validate the deploy run + close issues) vs. *PR-only* (agents stop at green PR).
2. **Infra scope** — *Repo-code only* (host-rooted failures documented & handed back) vs.
   *host changes allowed* (via HomeStructure, committed, never hand-edited).

"Deployed green" requires merge (deploy triggers on push to base) — so PR-only cannot reach
the goal by itself; say so.

## Phase 3 — Failure taxonomy & proven fixes

| Symptom | Bucket | Proven repo-code fix |
|---|---|---|
| `Would reformat: X.py` | lint | run `ruff format`; verify `ruff format --check` + `ruff check` |
| pytest collection `OSError: cannot load library libpango/libcairo` | native sys-lib | `try/except (ImportError, OSError): pytest.skip(allow_module_level=True)` — `importorskip` does NOT catch the ctypes `OSError` |
| tests pass locally, fail in CI by date | time-bomb test | mock data hardcoded past dates that aged out of rolling windows → compute dates relative to now (`today - Nd`) |
| `gh: command not found` (exit 127) in an E2E-trigger job | polaris parity | replace shell `gh workflow run` with `actions/github-script@v7` `createWorkflowDispatch`; set job `runs-on: ubuntu-latest` |
| native build: `prebuild-install No prebuilt binaries (target=node-vNNN)` | node ABI | bump the CI `node_version` to one with prebuilts for the pinned dep (e.g. better-sqlite3 v12.x needs Node 22), or bump the dep |
| smoke `docker compose config ... required variable X is missing` / `.env not found` | smoke env | pass `env_file_source: /home/lab/<svc>/.env` (branch-conditional for dev/prod) to the smoke-test job — it SCPs `.env` from antares before `compose config`. **NOT a host blocker.** |
| deploy `cd: /home/lab/<svc>: No such file` | migration path | rewrite repo `deploy.sh` to operate in its own dir / `$GITHUB_WORKSPACE`; if compose uses `env_file: .env`, SCP it from `<deploy-user>@<deploy-host>:/home/<user>/<svc>/.env` first |
| vitest `Failed to load url` / `no tests` on some runners | workspace root | pin `root: path.resolve(__dirname,'.')` + absolute `setupFiles` in vite config |
| vitest exits 1 though all tests pass | import-time side effect | guard module-load code (e.g. `createBrowserRouter`) behind `import.meta.env.VITEST` |

## Phase 4 — Host/infra blockers checklist (out of repo-code scope)

These are **polaris/antares post-migration parity** items. None are per-repo repo-code fixable;
hand them back to Gregor (or, if authorized, fix via HomeStructure committed config). When an
agent's only remaining red is one of these, it must STOP and report — never ssh/apt/mkdir hosts.

- **Missing Docker networks on antares** — `network proxy/infra not found` on `docker compose up`.
  Root: HomeStructure Traefik/infra stack not provisioned on antares. *Biggest lever — unblocks
  every web service at once.*
- **Registry 413 Payload Too Large** — `registry.922-studio.com` proxy `client_max_body_size`
  too small for image layers (HomeStructure registry/Traefik config).
- **Discord notify token broken** — `send-notification.yml` "Send Discord notification" step has
  **no `continue-on-error`**, so a bad `DISCORD_BOT_TOKEN`/channel reds an otherwise-green run.
  Fix = repair the secret, or make the step `continue-on-error` in `workflows@main` (repo-specific:
  some repos' notify works, so check the channel-id input).
- **Allure server upload fails** in the E2E workflow ("Upload Allure results to Allure server")
  — Allure server reachability, or make the upload step non-fatal in `workflows`.
- **Actions artifact-storage quota exhausted** — `Failed to CreateArtifact` cancels push jobs.
  Account-level: prune artifacts / lower retention / raise quota. (Often intermittent.)

## Phase 5 — Per-repo sub-agent dispatch

Spawn one Sonnet agent per repo (group identical fixes). Each prompt MUST include: house-rules
pointers (`/Users/gregor/dev/922/CLAUDE.md`, `projects/<name>.md`, relevant `HANDOVER-*.md`), the
exact failing run/job/step/error, base branch, and the full loop:

1. `git -C <repo> worktree add <repo>/.worktrees/feat-ci-green-sweep -b feat/ci-green-sweep origin/<base>`
2. Reproduce → minimal **repo-code** fix → tests/docs if behavior changed.
3. Commit (English, **no Co-Authored-By**) → push → `gh pr create --base <base>`.
4. Wait PR-CI green (`gh pr checks <n> --watch`) → `gh pr merge <n> --squash`.
5. Watch the deploy run on `<base>` to green (`gh run watch <id>`).
6. Close all open "CI Failure:" issues (comment + link green run).
7. `git -C <repo> worktree remove <wt-path>`; verify `worktree list`.

Constraints in every prompt: repo-code only; do NOT edit shared `922-Studio/workflows` (STOP &
report if the only fix lives there — it's consumed `@main` by everyone); if the only remaining
red is a Phase-4 host item, STOP & report precisely (path, exact error). Leave the worktree in
place only if blocked/partial.

## Phase 6 — Verify & report

Ground-truth sweep (don't trust agent self-reports alone — later runs can flip state):
```bash
gh run list -R 922-Studio/<repo> --branch <base> --limit 1 --json conclusion,url
gh issue list -R 922-Studio/<repo> --state open --json number -q length
```
Distinguish the **Deploy** workflow conclusion from ancillary workflows (E2E runs *after* deploy
as a separate workflow — its failure doesn't mean the deploy was red, but it can auto-file new
issues). Report: per-repo deploy status + URL, issues closed, and the consolidated Phase-4
host-blocker punch-list (root cause, fix location, repos each unblocks).

## Gotchas (learned the hard way)

- `pytest.importorskip` only catches `ImportError`/`ModuleNotFoundError` — native libs loaded via
  ctypes raise `OSError` at import and abort collection. Catch `OSError` too.
- Never put `${VAR:?msg}` shell syntax in a commit message — the versioning workflow inlines the
  commit body unquoted into a shell test and aborts.
- `gh` CLI is **not** installed on the polaris self-hosted runners — use `actions/github-script`
  for any GitHub API call you'd otherwise shell out to `gh` for.
- Smoke "`.env` missing" looks like a host blocker but is repo-code-fixable via `env_file_source`.
- A repo whose deploy is green can still go red on a *later* ancillary run (E2E/Allure) — verify
  the Deploy workflow specifically.
