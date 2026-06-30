# Idea: Dev-vs-Live-Dev Audit

**Status:** deferred — out of scope for the prod-push framework  
**Created:** 2026-06-30

---

## Problem

There is invisible drift between what is on the `dev` branch (code + config) and what is
actually running in the live dev environment. Examples of gaps that only surface at
prod-push time, as a vague manual check:

- A new service or endpoint exists in dev code but was never registered in HomeCollector
  uptime monitors.
- A new service was never added to the HomeAPI `/version` aggregation endpoint.
- Env keys that dev code expects are missing from the dev host `.env` file (usually caught
  only after a deploy fails).
- Alembic / Prisma migration heads on the dev branch do not match the running dev DB — the
  dev environment is running old schema.
- MCP definitions have drifted (dev API changed but the MCP tool spec was not regenerated).

Today these are caught reactively: a prod push reveals a gap, or a developer notices
unexpected 500s after deploying to dev.

---

## Idea

A standalone **dev audit** capability that compares dev branch state against the live dev
environment and flags drift **before** it ever reaches a prod-push gate:

| Check | Mechanism |
|---|---|
| Every dev service present in HomeCollector uptime monitors | Compare `registry.md` service list vs `/api/health/monitors` |
| Every service present in HomeAPI `/version` aggregation | Compare registry vs live `/version` JSON keys |
| Env keys on dev host match what dev code expects | Diff per-service `.env.example` vs actual dev host `.env` |
| Alembic heads on dev branch == live dev DB | `python -m alembic current` in dev container vs branch migration files |
| Prisma heads for Drafter | `prisma migrate status` in dev container |
| MCP tool spec up-to-date | Compare generated MCP JSON vs last committed version |

The audit would be **read-only** — no mutations. Output: a table of PASS / DRIFT per check,
with a concrete remediation hint for each drift.

---

## Why Deferred

The prod-push framework (`HomeStructure/scripts/prod-push/`) addresses the **dev → prod**
promotion path and assumes dev is correct. This audit catches the problem one layer earlier
— on dev itself. It is a separate concern and would add scope without benefit to the current
push.

---

## Where It Would Hook In

- **Registry input:** `orchestrator/registry.md` is the authoritative service list.
- **Prompt template:** `orchestrator/prompts/` (a new `dev-audit.md` prompt for an executor
  agent that runs the audit script and interprets the diff).
- **Script home:** `HomeStructure/scripts/dev-audit/` (mirrors the prod-push layout).
- **Trigger point:** ideal as a pre-condition check run before any prod-push plan is opened,
  or on a daily schedule via the Claude Code Remote scheduler.
