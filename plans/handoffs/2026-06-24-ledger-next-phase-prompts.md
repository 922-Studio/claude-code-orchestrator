# Ledger Feature — Next-Phase Handoff Prompts

Companion to `plans/2026-06-24-ledger-feature-completion.html`. Each block below is a **self-contained prompt to paste into a fresh Claude Code session** (launched from `/Users/gregor/dev/922`), so each topic runs cold and cheap. Run them in the order implied by dependencies.

**Status as of 2026-06-24:**
- ✅ Wave 0 (re-baseline) — done. dev is at HomeUI v0.71.0 / HomeAPI v0.71.0; finance UI overhaul + quick-add already merged.
- 🔄 Wave 1 backend foundation — `feat/ledger-integrity-hardening` (steps 02–05) + `feat/gsheets-backup-hardening` (step 08) exist as **local worktrees only** (not pushed, no PRs, not merged). **This is the critical path for Prompt C.**
- 🔵 Prompt A (frontend, steps 06–07) — **PR open**: HomeUI [#129](https://github.com/922-Studio/HomeUI/pull/129) → `dev`. Includes full debts→ledger rename. ⚠️ HomeUI CI does not run on PR-to-dev; tests first exercise on merge.
- 🔵 Prompt B (local MCP, step 11) — **PRs open**: HomeAPI [#66](https://github.com/922-Studio/HomeAPI/pull/66) + workflows [#11](https://github.com/922-Studio/workflows/pull/11) → `dev`; server.md committed to main. `homeapi-dev` MCP connected & smoke-tested green on dev. Prod regen waits on #11 merge + prod push.
- ⏸️ Prompt C (reverse-sync, steps 09–10) — **blocked** until the two Wave 1 backend PRs are merged to dev.
- ⏸️ Step 12 (prod migration) — blocked until A/B/C all land and verify on dev.

Dependency note: **Prompt C (reverse-sync) must wait until the two backend-foundation PRs are merged to `dev`.** Prompts A (frontend) and B (MCP) are independent and can run in parallel now.

---

## Prompt A — Frontend: per-person ledger drill-down + overview polish (plan steps 06–07)

```
Act as orchestrator for the 922-Studio ecosystem. Execute steps 06–07 of the plan
orchestrator/plans/2026-06-24-ledger-feature-completion.html (read it first, plus
orchestrator/projects/homeui.md and the root + HomeUI CLAUDE.md).

Context already verified: HomeUI dev (v0.71.0) has the finance overhaul merged — ledger
page, finance overview, invoice list/detail, person-RECORD CRUD page, quick-add. The gap:
the backend endpoint GET /api/finance/ledger/persons/{name}/history (returns running_balance,
first_transaction_date, last_transaction_date, per-tx running balance) is UNUSED — there is
no per-person ledger drill-down; the overview currently re-derives history client-side from
~500 rows. The ledger model is dated money entries (amount + transaction_date + person), so
"times" = transaction dates/timeline, not hours.

Do:
1. Add API fn + Zod schema (DebtPersonHistoryResponse) + queryOptions factory + hook for the
   history endpoint in src/api/ + src/types/api/, matching HomeAPI app/schemas/debt.py.
2. Add a dedicated per-person ledger drill-down route/page (running balance, first/last dates,
   full server-side history) — replace the client-side fetch-and-group. Wire PATCH to edit a
   transaction.
3. Polish the ledger overview: transaction-date timeline, totals, date-range filter.
4. (Recommended) finish the debts→ledger code-symbol rename (module path under
   src/features/, query keys) so there's one coherent finance/ledger module. Skip if churn
   is unwanted — say so.
5. Tests: unit (RTL) + Playwright E2E for the new per-person page, edit, delete happy path,
   and the date-range filter. Hold the 70% gate; fully cover the new flows.

Workflow: branch off origin/dev (feat/ledger-ui-per-person), worktree under
HomeUI/.worktrees/, run bin/setup-worktree.mjs for env, npm run test:ci + test:e2e green,
push, open PR with `gh pr create --base dev` referencing the plan, report the PR URL, then
remove the worktree (keep the remote branch). Use Sonnet for any execution sub-agents.
```

---

## Prompt B — Personal local MCP, reproducible (plan step 11)

```
Act as orchestrator for the 922-Studio ecosystem. Execute step 11 of the plan
orchestrator/plans/2026-06-24-ledger-feature-completion.html (read it first, plus
orchestrator/projects/homeapi.md, orchestrator/server.md, and
workflows/docs/generate-mcp.md).

Goal: a PERSONAL, LOCAL stdio MCP so I can interact with HomeAPI directly from my Claude
client — pointed at dev first, then prod — authenticated with my own bearer token + X-Org-ID.
No new hosted service, no Traefik, no monitoring.

Current state (verified): a working FastMCP stdio server already exists on antares
(/home/lab/openclaw/mcp-servers/homeapi/, 150 tools incl. 8 finance/ledger) BUT it is
server-side-only, hand-patched (run.sh token injection, HOMEAPI_ORG_ID, a local-only
generator commit + untracked support files api_client_httpx.py / patch_api_methods.py), built
against API v0.64.8, and NOT reproducible from a clean pipeline run. The generate-mcp pipeline
(HomeAPI .github/workflows/deploy.yml → workflows/.github/workflows/generate-mcp.yml) runs
only on prod/manual-dispatch.

Do:
1. Make generation reproducible: commit the generator support files + the HOMEAPI_ORG_ID
   patch into the workflows/generator repo so a clean run reproduces the working server.
2. Produce a committed LOCAL path (HomeAPI/scripts/mcp/ + docs): generate the FastMCP server
   from the dev openapi.json and run it over stdio against dev (then prod) with my personal
   token + X-Org-ID. Register it in my local Claude config (~/.claude or Claude Desktop).
3. Smoke test: list_tools works; a finance/ledger tool round-trips against dev.
4. Docs: HomeAPI MCP usage README + register the MCP in orchestrator/server.md (currently has
   zero MCP references).

Constraints: secrets stay local/out of git. workflows repo follows its normal worktree→PR→dev
workflow; orchestrator/server.md edits commit directly (orchestrator exception). Report PR
URL(s) and the exact local steps for me to connect my client. Note: this is easier to verify
AFTER the backend-hardening PRs land (current API shape), but generation/repro work can start
now.
```

---

## Prompt C — Reverse-sync: per-person manual sheet entry → app (plan steps 09–10) — RUN AFTER backend-foundation PRs are merged

```
Act as orchestrator for the 922-Studio ecosystem. Execute steps 09–10 of the plan
orchestrator/plans/2026-06-24-ledger-feature-completion.html (read it first, plus
orchestrator/projects/homeapi.md, HomeAPI CLAUDE.md, docs/services/google-sheets.md,
docs/api/sync.md). PREREQUISITE: the feat/ledger-integrity-hardening and
feat/gsheets-backup-hardening PRs must already be merged to dev — confirm before starting.

Goal (Goal B): a Google Sheet per-person overview where I manually enter NEW ledger entries
and they sync into the app automatically — with ZERO data-loss risk for invoicing data.

DEV/PROD SHEET SPLIT (must hold): dev and prod use SEPARATE spreadsheets. dev's GOOGLE_SHEET_ID
lives in /home/lab/dev/HomeAPI/.env (env_file_source); prod's in /home/lab/HomeAPI/.env. ALL
reverse-sync build + tests run ONLY against the dev spreadsheet — never the prod sheet. Service
account for sharing any sheet: home-server@home-server-480516.iam.gserviceaccount.com (Editor).

Locked design (from the plan): APP IS SOURCE OF TRUTH; the manual-entry sheet is a SEPARATE,
append-only input surface, DISTINCT from the existing backup mirror, and is NEVER clear()ed.
The existing backup is a generic 1:1 DB→Sheet full-replace mirror (daily 03:00 via cron_jobs)
— do not entangle the input surface with it. The current generic import skips blank-id rows,
does no type coercion, and would be wiped by the backup clear() — that is exactly what this
phase must replace for the ledger domain.

Do:
1. Ledger-specialized import on the separate input surface: blank-id → mint UUID; coerce +
   validate amount (Decimal) and transaction_date (Date); resolve/auto-create Person within
   org; reject malformed rows with a per-row error report; write the assigned id + a "synced ✓"
   marker back so each row imports exactly once (idempotent re-import = no-op).
2. Schedule it via a cron_jobs row ordered BEFORE the daily backup export, plus a manual
   trigger endpoint; Discord notify on imported/failed rows.
3. Prove import-then-export ordering so manual entries are always persisted before any export.
4. Tests to 100% on the reverse-sync paths INCLUDING data-loss scenarios (manual row survives
   the next export), malformed-input rejection, idempotent re-import, and org/FK validation
   (never import into the wrong org).

Decide & confirm with me: separate spreadsheet vs separate tabs in the same sheet (plan
recommends a separate spreadsheet for cleanest isolation), and the exact per-person sheet
column layout.

Workflow: worktree off origin/dev (feat/ledger-reverse-sync), tests green, push, PR
`--base dev` referencing the plan, report PR URL, remove worktree. Use Sonnet for sub-agents.
```

---

## After all phases land → Production migration (plan step 12)

Once dev is green with every PR merged and all four goals verified on dev, run a final session
for step 12: promote dev→prod (HomeAPI + HomeUI), run migrations, regenerate the prod MCP from
the now-reproducible pipeline, enable the reverse-sync cron in prod, verify all four goals live,
and update HomeCollector uptime + HomeAPI versioning if any contract surface changed.
