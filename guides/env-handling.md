# Env Handling — Agent Contract

**Read this in full before touching any `.env*` file, adding an env var, or working on deployment/env delivery in a 922-Studio service.** This is the single source of truth for how environment variables are managed. If your task does not involve env files, you do not need this guide.

Services in scope: **HomeAPI, HomeAuth, HomeCollector, HomeUI, Drafter**.

---

## The model in one paragraph

Each repo keeps two **local, git-untracked** files as the source of truth: `.env.dev` and `.env.prod`. The only env file that is **ever committed** is `.env.example` — the key contract (key names, no secret values). The active `.env` is a local working copy, also untracked. Servers receive env by **copying** the local file up — never by editing the server file in place. Validation and delivery go through the prod-push framework scripts. That's it.

## Hard rules (never violate)

1. **Never `git add` / commit `.env.dev`, `.env.prod`, or `.env`.** These contain live secrets. The only committable env file is `.env.example`.
2. **`.env.example` holds key names only — no real secret values.** Placeholders like `JWT_SECRET=` or `DB_PASSWORD=changeme` are fine; a real token is a leak.
3. **Never edit a server `.env` in place.** The server file is not in git and is not written by CI. All edits happen in the local `.env.dev`/`.env.prod`, then are *delivered* (copied) up. Editing the server directly creates drift that the next delivery silently clobbers or that CI can't reproduce.
4. **Env-specific values must differ between dev and prod.** Domains, hosts, DB URLs, spreadsheet IDs, CORS origins, Discord channel IDs, webhooks — reusing a dev value in prod is a bug, not a convenience. Genuinely-shared infra (one API key for both envs) is the documented exception (see env-rules below).
5. **Shared secrets rotate in lockstep.** The JWT secret is shared HomeAuth ↔ Drafter; changing it in one without the other breaks auth. Treat any cross-service shared key the same way.
6. **If you find a tracked `.env.dev`/`.env.prod`, stop and report it** as a leak — do not "fix" it by force-pushing a history rewrite mid-task. History remediation is a coordinated operation (see below).

## The gitignore pattern

Every service `.gitignore` must ignore the real env files and *only* un-ignore the example:

```gitignore
.env
.env.*
!.env.example
```

Beware the historical bug: some repos used `.gitignore` **negations** (`!.env.dev`) that re-tracked the secret files. If you see a negation for anything other than `.env.example`, that's the leak vector — remove it.

## Adding or changing an env var

1. Add the key to **`.env.example`** with a placeholder/empty value (this is the committed contract).
2. Add the real value to your **local `.env.dev` and `.env.prod`** (never committed).
3. If the value is genuinely identical across dev and prod (shared infra), add the key to `allow_same:` in `HomeStructure/scripts/prod-push/env-rules/<Service>` so `validate-env.sh` doesn't flag it. If it's env-specific but off the naming patterns, use `must_differ:`.
4. Run `validate-env.sh <svc>` and confirm GO before delivery.
5. When a new API needs env, remember the two-registry rule: add it to HomeCollector uptime + HomeAPI versioning (see the new-service guide).

## The scripts (prod-push framework)

Location: `HomeStructure/scripts/prod-push/`

- **`validate-env.sh <svc>`** — checks local `.env.dev` ↔ `.env.prod` divergence and completeness vs `.env.example`. Prints **key names only**, never values. HARD NO-GO if env-specific keys (`*URL*`, `*HOST*`, `*DOMAIN*`, `*SHEET*`, `*DB*`, `*CORS*`, `*ORIGIN*`, `*WEBHOOK*`, `*CHANNEL*`, …) are identical dev↔prod; SOFT WARN for `*SECRET*`/`*PASSWORD*`/`*TOKEN*`/`*KEY*`. Wired into `preflight.sh`.
- **`deliver-env.sh <svc> <env>`** — validates, then does an **atomic copy** of the local `.env.<env>` to the server (`.env.prod` → `/home/lab/<svc>/.env`, `.env.dev` → `/home/lab/dev/<svc>/.env`), perms `600`. Never edits in place.
- **`env-rules/<Service>`** — per-service exceptions. `allow_same:` for legitimately-shared keys; `must_differ:` for off-pattern env-specific keys. See `env-rules/HomeAPI` as the template.

Run env delivery **before** a prod push so the container recreate picks up the correct env.

## When a secret has leaked (into git history)

Untracking a file stops *future* commits but does **not** remove the secret from history — past commits on the remote still contain it. Remediation is one of:

- **Rotate** the secret at its provider (neutralizes exposure; old value in history becomes dead). Simplest, no re-clones.
- **Scrub history** with `git filter-repo` / BFG across the affected repos (defense-in-depth; rewrites history → all CI runners and checkouts must re-clone).

This is a coordinated operation owned by Gregor, tracked in a plan — not something to improvise inside an unrelated task. If you discover a leak, report it and point at the env-secrets follow-up plan.

## Related

- Root `CLAUDE.md` → Universal Rules (env pointer)
- `prompts/executor.md`, `prompts/reviewer.md` (agent-facing pointers)
- `guides/prod-push-handover.md` — how push + env delivery fit together
- Plan: `plans/2026-07-02-env-secrets-followup.html` — the live leak-remediation workstream
