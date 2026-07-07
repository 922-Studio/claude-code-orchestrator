# Kickoff — Prod-Push Framework v2 execution

Paste this into a fresh session launched from `/Users/gregor/dev/922` to execute the v2 plan.

---

You are the orchestration lead executing **Prod-Push Framework v2**.

**Read first (context via pointers — do not ask me to paste anything):**
- Plan: `orchestrator/plans/2026-07-07-prod-push-framework-v2.html` — 8 numbered steps, 3 waves.
- Issue log: `orchestrator/plans/2026-07-02-prod-push-framework-issues.html` — the 29 rows the steps reference.
- Memories: `project_prod_push_framework`, `feedback_prod_mirrors_dev`, `feedback_env_workflow`,
  `incident_remote_daemon_bind_mounts` (Step 07 decision recorded there), `reference_registry_413_ssh_transfer`,
  `feedback_compose_project_separation`, `incident_org_secrets_free_plan`, `project_polaris_deploy_topology`.
- Target-repo files listed in each step's `<meta-row>` (HomeStructure `scripts/prod-push/*`, per-service `.env.example`, hooks, `HomeAPI/.github/workflows/deploy.yml`).

**Rules:**
- Sonnet sub-agents per step (Opus only for the hard bits — `_lib.sh` correctness, reconcile logic, generate-mcp topology).
- All code changes: worktree → feat branch off `dev` → push → PR **to `dev`** → report URL → remove worktree. HomeStructure is the primary repo; some steps also touch HomeAPI / Drafter / workflows / per-service repos.
- The **orchestrator repo is exempt** (commit directly) — use it to mark step status + close issue-log rows.
- Quality gates before marking a step done: tests, docs (runbook + runner prompt), CI green, per-project best-practices.

**Waves (respect dependencies in each step's footer):**
- **Wave 1 (parallel):** 02 `_lib.sh` correctness · 04 promote CI-trigger/run-watch · 05 env contracts.
- **Wave 2 (parallel, after Wave 1):** 01 selective `prod-push.sh <service…>` · 03 dev-wins branch reconciliation · 06 hooks + generate-mcp.
- **Wave 3:** 07 infra — **decision already made: bake repo-shipped config into images + named/absolute volumes, zero relative binds under remote `DOCKER_HOST`** (runners are all on polaris, image builds there then moves to antares); confirm registry-413 transfer + per-env `COMPOSE_PROJECT_NAME`/`IMAGE_TAG` are framework-wide; fix stale runner-location claim in `orchestrator/projects/homestructure.md`. Then 08 — unblock Drafter (transfer_target/pull_image:false) and push it via `prod-push.sh Drafter` as the real-world test of selective mode.

Start with Wave 1: spawn the three steps in parallel, report each PR URL back. After each wave, pause for my go/no-go before the next.

**Prod scope (authorized 2026-07-07):** full plan incl. Step 08. Waves 1–2 + 07 touch nothing (PRs to `dev` only). Step 08 is the **only** live prod contact — a single-service gated `prod-push.sh Drafter`, run only after the Wave 3 go/no-go. No other service is pushed.
