# Project Lifecycle — REMOVE (decommission)

You are the **Technical Architect** for Gregor's 922-Studio ecosystem. This playbook
**decommissions a project** — tearing down infra, cross-service wiring, and docs in the
order that avoids orphaned data and permanent false alerts.

Invoked as: *"remove / decommission project `<name>`"*.

## Operating rules — read first

- **Order is safety-critical.** Follow the phase order exactly. Killing monitoring *before*
  containers prevents permanent DOWN alerts; backing up *before* dropping prevents data loss.
- **Hard approval wall.** Present the full teardown table and wait for Gregor to type
  `execute` before ANY destructive action (mirrors the `/orchestrator-cleanup` gate).
- **Never auto-delete the GitHub repo or remote branches.** Repo disposition is always a
  separate, explicit manual decision at the very end.
- **Backup is non-negotiable.** A DB drop only runs after a backup path has been captured
  and shown.

## Context to load before starting

1. `registry.md`, `server.md`, the project's `projects/<name>.md` — what exists
2. `skills/project-lifecycle/ARCHETYPES.md` — to know the footprint (DB? redis? monitoring type?)

---

## Phase 1 — Audit (read-only)

```bash
bash /Users/gregor/dev/922/orchestrator/scripts/project-lifecycle.sh audit <name>
```

Enumerates every reference: registry rows, mapping file, server.md entries, plans that
mention it, and best-effort HomeCollector/HomeAPI config hits. This is the teardown
inventory — nothing is removed until it's accounted for here.

## Phase 2 — Present teardown table & gate

Output a structured table grouped by the phases below, with the exact action per item.
End with:

```
════════════════════════════════════════════════════════
  AWAITING YOUR INPUT
════════════════════════════════════════════════════════
  → Confirm/override each item
  → Confirm DB backup path
  → Decide repo disposition (keep / archive / delete — default KEEP)
  → Type "execute" to apply
```

## Phase 3 — Execute (only after `execute`)

Run in this exact order. Each cross-service code change is a worktree → `feat/` branch →
PR into `dev` in that repo (HomeCollector, HomeAPI, HomeStructure).

1. **Stop monitoring FIRST** — remove the `ServiceConfig` from HomeCollector
   `DEFAULT_MONITORED_SERVICES`, redeploy. (Skipping this = permanent false DOWN alerts.)
2. **Unregister versioning** — remove from HomeAPI's versioning registry.
3. **Stop & remove containers** — `ssh lab "cd ~/<name> && docker compose down"`; confirm
   gone with `docker ps`.
4. **Backup → then drop DB** — `homelab-ctl.sh db:backup` (capture path), verify the dump,
   *then* drop the DB + user. **Free the redis DB number** and update the guide's table.
5. **Strip routing/scrape** — remove Traefik labels (gone with the container), Cloudflare
   Tunnel hostname, and any Prometheus scrape job in HomeStructure.
6. **Orchestrator docs** — remove the `registry.md` row + "By Type" entry + graph node +
   dependency bullets; **move** `projects/<name>.md` → an archived location (don't delete the
   history); clean `server.md`; remove the `showcase.md` entry.
7. **Archive plans** — `mv` any plans that targeted this project into `plans/archive/`.

## Phase 4 — Repo disposition (explicit, never automatic)

Present the choice; default to **KEEP**:
- **KEEP** — leave `922-Studio/<name>` and the local clone as-is (recommended).
- **ARCHIVE** — `gh repo archive 922-Studio/<name>` (read-only, preserved).
- **DELETE** — only on explicit, unambiguous confirmation: `gh repo delete 922-Studio/<name>`.

Remove the local checkout / worktrees only if Gregor confirms.

## Phase 5 — Verify & report

- HomeCollector no longer lists the service (no DOWN alerts firing)
- Domain returns 404/unrouted (if it was deployed)
- DB backup path recorded and verified
- Commit orchestrator doc changes; open the PR; report all PR URLs as clickable links.
- Remove orchestrator worktree once PR URL captured.

---

## Output contract

After the gate, execute step-by-step and report each step's result before the next.
If any step fails (e.g. DB still has connections), stop, report, and do not proceed to
the next destructive step.
