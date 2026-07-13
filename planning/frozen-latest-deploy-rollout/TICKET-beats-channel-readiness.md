---
title: "TICKET: Make beats schedulers channel-aware before frozen/latest rollout"
status: proposed
created: 2026-07-08
updated: 2026-07-08
owner: gregor
summary: Ready-to-file engineering ticket covering the application-code changes required in api-beats (DocBits_API), fulltext-beat (DocBits_FullText), and docnet-beats (DocBits_DocNet) before any of them can safely run as two channel-scoped instances. Blocking prerequisite for those components in the frozen/latest rollout plan — not executed as part of that rollout; scope and assign separately.
---

# TICKET — Make beats schedulers channel-aware before frozen/latest rollout

**Type:** Engineering / platform prerequisite
**Blocks:** `PLAN-frozen-latest-rollout.md` Wave 4 (`DocBits_FullText`), Wave 5 (`DocBits_API`), Wave 6 (`DocBits_DocNet`) — specifically, the `beats`-type component in each service. Every other component type in those services (api, celery, callbacks, beats-tasks) is unaffected by this ticket and can proceed independently.

## Summary

DocBits is splitting deployments into parallel "latest" and "frozen" release channels, each running as an independent, fully-parallel stack sharing the same database and message broker (a deliberate architecture decision — no infra isolation between channels). For stateless/worker components this is solvable with config alone (a channel-specific queue prefix). For a **beats scheduler** — which runs on a timer and, for org-scoped periodic tasks, must decide *which organisations* to act on — config alone is not enough: the scheduler needs to know which channel it's running as, and either avoid double-firing (if a shared lock exists) or actively split its per-org dispatch by the org's release channel.

Three services have a `beats`-type component in `DevOps/services/registry.yaml`: `DocBits_API` (`api-beats`), `DocBits_FullText` (`fulltext-beat`), `DocBits_DocNet` (`docnet-beats`). None of them are channel-aware today. This ticket scopes the work per service.

## Why this can't be config-only

- All three services' frozen and latest deployments will point at the **same** Celery broker/Redis instance (confirmed: `envs/dev/eu/*.env` vs `envs/dev-frozen/eu/*.env` are broker/DB-identical for all three).
- `DocBits_API`'s `api-beats` uses **RedBeat** with a Redis-backed distributed lock (`celeryconfig.py`: `redbeat_lock_key = "celery-beat"`, hardcoded as a bare Python literal — not env-driven). Two `api-beats` pods pointed at the same broker will fight over this identical lock; only one will ever actually tick, the other becomes a silent, non-dispatching standby. **This is a code change, not a values-file change** — the lock key must be parameterized by channel.
- `DocBits_FullText` and `DocBits_DocNet` use Celery's default **file-based `PersistentScheduler`** (no RedBeat, no distributed lock at all) — so they don't have the lock-collision problem, but they also have **zero existing mechanism** to decide which orgs a given beat instance should act on.
- Even once locking/independence is solved, every periodic task that loops over organisations and dispatches per-org work needs an explicit **channel filter** (read the org's `release_channel` and skip if it doesn't match this instance's own channel) — otherwise both instances will still process the same org's work twice.

## Acceptance criteria

For each service in scope:
1. Two independent `beats` deployments (one per channel) can run concurrently against the shared broker without lock contention or duplicate scheduling.
2. Every periodic task that dispatches per-organisation work only acts on organisations whose cached `release_channel` (see `DocBits_API/util/org_channel_resolver.py` — the existing, safe-to-call resolver already used by the downstream queue-prefix mechanism) matches this beat instance's own channel.
3. Global/org-agnostic housekeeping tasks (see per-service lists below) are explicitly exempted from the filter — either left unfiltered, or ownership pinned to exactly one channel by config, per a documented decision (not left ambiguous).
4. The channel value each instance uses is read from a config/env var (e.g. `RELEASE_CHANNEL`), never inferred by string-matching a branch or environment name inside application code.

## Scope by service

### 1. `DocBits_API` — `api-beats` (highest scope; audit already done, this ticket just needs implementation)

Full audit of `celeryconfig.py`'s `beat_schedule` (51 tasks total) already completed — see `PLAN-frozen-latest-rollout.md` §3.3 for the reference methodology. Work items:

1. **Parameterize the RedBeat lock.** `celeryconfig.py` hardcodes `redbeat_key_prefix = "redbeat:"` and `redbeat_lock_key = "celery-beat"` as bare literals. Change both to incorporate the channel (e.g. `redbeat_key_prefix = f"redbeat:{RELEASE_CHANNEL}:"`, `redbeat_lock_key = f"celery-beat-{RELEASE_CHANNEL}"`), sourced from an env var, so latest and frozen each get their own lock namespace and both tick independently against the shared Redis.
2. **Fix beat-dispatch queue routing.** `celery_initializer.py::build_schedule()` hardcodes literal, unprefixed queue names directly in `options["queue"]` for every task (e.g. `"beats-tasks"`, `"analytics-background"`, `"cleanup_tasks"`), completely bypassing the already-working `CeleryConfig.q()` prefix mechanism. Route every `options["queue"]` value through `CeleryConfig.q(...)` so beat-dispatched tasks actually land on the channel-prefixed queue once `CELERY_QUEUE_PREFIX` is set per deployment.
3. **Add the per-org channel filter to 15 tasks** (each already has `org_id` in hand from a per-row/per-org loop — add a `resolve_org_channel(org_id)` skip before dispatch):
   `simple_document_timeout`, `monitor_stuck_tasks` (Phase 1 only), `reconcile_new_documents`, `sync_receive_delivery_data`, `update_all_models`, `clean_pending_docs`, `touch_less_export` (needs a query change — currently only returns `d.id`, not `org_id`, so this one is *not* a trivial one-liner), `send_status_alerts`, `execute_dashboard_export_request`, `send_tasks_email`, `clean_purchase_orders` (override-path loop only), `clean_expired_docs`, `sync_bod_aws_stream`.
4. **36 tasks need no change** — confirmed global/org-agnostic housekeeping with no per-org dispatch (e.g. `monitor_task_registration`, `monitor_priority_queue_depth`, `sync_cache_data`, `cleanup_tasks`, `clean_ai_cache_table`, `clean_tfidf_records`, `aws_stream_functionality_check`, and others — see PLAN §3.3 for the full list).
5. **Decide ownership for 2 special tasks:** `organisation_cache_sync` and `verify_cache_sync` maintain the org/channel metadata itself and must not be filtered the same way — decide explicitly whether both channel deployments run them redundantly (simplest, some wasted compute) or ownership is pinned to one channel (needs a config flag).

### 2. `DocBits_FullText` — `fulltext-beat`

No RedBeat lock issue (file-based scheduler, no shared lock to parameterize). Work items:
1. Full per-task audit of `celery_run.py`'s beat schedule, using the same methodology as API's (identify which tasks iterate orgs vs are global). Known from prior investigation: includes `sync-graph-all-orgs` (every 6h), `thumbnail-health-check` (every 4h), `index-sync-health-check` (every 5 min — "the actual self-heal cadence"), `broker-queue-guard` (every 15 min, reaps orphaned queues on the **shared** broker — flag this one specifically, since it actively mutates shared broker state and running it from both channels simultaneously needs explicit ownership, not just a filter).
2. Add the per-org channel filter to whichever tasks the audit confirms need it.
3. Decide ownership for `broker-queue-guard` (shared-infra-mutating, likely single-channel-owned rather than duplicated).

### 3. `DocBits_DocNet` — `docnet-beats`

No RedBeat lock issue either (also file-based scheduler). Existing partial mitigation: `heartbeat_tasks.py`'s "Checkout" step already guards against two heartbeat cycles grabbing the same issue via an atomic `checked_out_by` DB lock — but the other 8 of 9 steps in the per-agent heartbeat cycle (identity load, approval/assignment queries, `agent_runtime_state` writes, delegation) have no such guard. Work items:
1. Full per-task/per-step audit of the heartbeat cycle and any other periodic tasks in `src/celery_config.py`'s `beat_schedule`.
2. Add the per-org channel filter to org-scoped steps beyond the already-guarded checkout step.
3. Confirm whether the existing checkout-lock guard is sufficient on its own for the remaining steps, or whether they also need explicit filtering.

## Explicitly out of scope for this ticket

- `DocBits_DocFlow`'s RedBeat-driven cron triggers — separate open question (its production topology is unconfirmed; see `PLAN-frozen-latest-rollout.md` Wave 3b) and not included here.
- Discord bot (`DocBits_DocNet`'s `docnet-discord-bot`) — deprecated, explicitly out of scope for the whole frozen/latest rollout, not just this ticket.
- The Helm/registry.yaml/CI plumbing to actually deploy a second `beats` instance per channel — that's the generic pipeline work in `PLAN-frozen-latest-rollout.md`, not this ticket. This ticket is application-code only.

## References

- `PLAN-frozen-latest-rollout.md` (this rollout's main plan) §3.3 for the full API task-by-task audit table and methodology, §4 for the `release-channels`/`dedup-strategy` config schema this work slots into once complete.
- `DocBits_API/util/org_channel_resolver.py` — existing, already-safe-to-call org→channel resolver.
- `DocBits_API/celeryconfig.py`, `DocBits_API/celery_initializer.py::build_schedule()` — the two files needing the RedBeat/queue-routing code changes.
