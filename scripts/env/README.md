# Env tooling (orchestrator)

Env validation + delivery, runnable from the orchestrator (Gregor operates only from here).
Full rules and workflow: `../../guides/env-handling.md`.

## Scripts

- **`validate-env.sh <Service> [--dry-run]`** — checks the local `.env.dev` ↔ `.env.prod`
  divergence + completeness vs `.env.example`. Prints key **names** only, never values.
  Per-service exceptions in `env-rules/<Service>`.
- **`deliver-env.sh [--dry-run] [--force] <Service> [prod|dev]`** — validates, then atomically
  copies the local `.env.<env>` onto antares (`.env.prod` → `/home/lab/<svc>/.env`, `.env.dev` →
  `/home/lab/dev/<svc>/.env`), perms 600. Never edits the server file in place.
- **`_lib.sh`** — shared helpers (service→path mapping, ssh/antares helpers). Sourced by both.
- **`env-rules/<Service>`** — `allow_same:` / `must_differ:` exceptions. HomeAPI is the reference;
  the others are starter files generated from reconciled vault data — confirm before relying on them.

## Sources of truth

- Per-repo local `.env.dev` / `.env.prod` (gitignored) are what these scripts read.
- The central versioned vault `/Users/gregor/dev/922/envs/` is the reconciliation workbench and
  backup of every env (local + server). Restore repo working copies from there.
- `REPO_BASE` (default `/Users/gregor/dev/922`) overrides where repos are found.

## Note on HomeStructure

Originally these lived in `HomeStructure/scripts/prod-push/`, where `validate-env.sh` is still
wired into `preflight.sh`. This orchestrator copy is the operator-facing location. Fully retiring
the HomeStructure copy (and rewiring preflight to call these) is a separate HomeStructure PR.
