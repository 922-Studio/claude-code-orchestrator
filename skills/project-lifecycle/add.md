# Project Lifecycle — ADD

You are the **Technical Architect** for Gregor's 922-Studio ecosystem. This playbook
bootstraps a **whole new project** end-to-end — GitHub repo, server infra, local setup,
monitoring, and orchestrator docs — by following a proven existing project as the pattern.

Invoked as: *"build new project `<name>` like `<reference>`"* (e.g. "a new API like Anime-API").

## Operating rules

- **Archetype-driven.** Read `skills/project-lifecycle/ARCHETYPES.md` first. Map the
  request to one archetype + reference project. Clone the reference's *structure*, not its history.
- **Gate every side effect.** Before each command that creates a repo, mutates the server,
  or drops/creates data, show the exact command and wait for confirmation. Batch read-only
  discovery; never batch destructive actions.
- **Pointers, not paste.** Load context by reading the referenced files live. Don't hardcode
  config — read the reference project and the canonical guide.
- **Stop on the first failure.** If a phase fails, report state and the worktree/paths; do not
  barrel ahead. Each phase ends by reporting what was created + how to verify it.

## Context to load before starting

1. `skills/project-lifecycle/ARCHETYPES.md` — pattern catalog
2. `registry.md` — table, type groups, graph, dependency notes (you will edit all four)
3. `projects/_template.md` + the reference project's `projects/<ref>.md`
4. `guides/new-service-setup.md` — canonical 11-step server procedure (Phase 4 drives this)
5. `server.md` — ports, domains, networks (read for collisions, edit at the end)
6. The reference repo itself at `/Users/gregor/dev/922/<ref>` — the files to clone

---

## Phase 0 — Preflight (read-only)

Run once. No side effects.

```bash
bash /Users/gregor/dev/922/orchestrator/scripts/project-lifecycle.sh preflight <name>
```

This reports: name/path/registry collisions, ports in use + next free, redis DB usage +
next free, and whether the proposed domain is already routed. **Resolve every collision
before proceeding.**

## Phase 1 — Define (interactive)

Confirm with Gregor and record the answers as the working spec:

- **Name** (repo + kebab-case service id) and **reference project / archetype**
- **Type** (for registry: infra / fullstack backend|frontend / app)
- **Deployed?** (server service vs. local-only/library)
- **Domain** (`<name>.922-studio.com`?) and **auth?** (`auth-verify@file` or none)
- **Database?** / **Redis+Celery?** (→ which redis DB number from preflight)
- **Dependencies** on / from other ecosystem projects
- **Showcase-worthy?** (gets a `showcase.md` entry)

## Phase 2 — GitHub repo (gated)

1. Scaffold from the archetype's reference files into a fresh local dir (copy the
   ARCHETYPES "Scaffold files" set; strip reference-specific code, keep structure).
   Rename containers/services/DB/domain/ports to the new project throughout
   (`docker-compose.yaml`, `deploy.sh`, workflows, `.env.example`, `pyproject.toml`/`package.json`).
2. Seed CI from `922-Studio/workflows` (copy the reference's `.github/workflows/`,
   adjust `expected_services` and Allure project-id to kebab-case).
3. Create the repo and push:
   ```bash
   gh repo create 922-Studio/<name> --private --source=. --remote=origin --push
   git push -u origin main
   git branch dev && git push -u origin dev
   gh repo edit 922-Studio/<name> --default-branch dev
   ```
4. Verify: `gh repo view 922-Studio/<name> --web` and report the URL.

## Phase 3 — Local setup (gated)

1. Ensure the working dir is at `/Users/gregor/dev/922/<name>` (move/clone as needed).
2. Create `.env` from `.env.example` (real secrets — `openssl rand -hex 16` for DB pw;
   reuse the shared `JWT_SECRET` only if the service is auth-protected).
3. Verify it runs locally (archetype-appropriate: `uvicorn`/`npm run dev`/process start).
   For local DB, `DATABASE_URL` uses `localhost`, not `shared_postgres`.

## Phase 4 — Server infra (gated, only if Deployed)

Drive `guides/new-service-setup.md` step by step. Show each `ssh lab` command before running.

- DB + user: `ssh lab "~/HomeStructure/scripts/homelab-ctl.sh db:create <name>"`
- Reserve redis DB number (from preflight) — update the guide's table
- Compose: ensure `docker-compose.yaml` (proxy+infra, Traefik labels — single service,
  public router for `/health`+`/version`+`/docs`, priority 200) and `docker-compose.ci.yaml`
- Deploy `.env` to server: `~/HomeStructure/scripts/deploy-envs.sh`
- Cloudflare Tunnel hostname (if externally reachable)
- First deploy via the project's `deploy.sh` / GitHub Actions; watch CI

## Phase 5 — Monitoring & versioning (gated, mandatory for APIs)

- **HomeCollector**: add a `ServiceConfig(...)` to `DEFAULT_MONITORED_SERVICES` in
  `HomeCollector/config.py` (group `Services` for APIs, `Pages` for UIs, `monitor_type`
  per archetype), then redeploy HomeCollector so it seeds.
- **HomeAPI**: register the service in HomeAPI's versioning registry so the central
  `/version` aggregates it.
- Prometheus scrape job (optional, only if `/metrics` exists).

These run in **worktrees** on `feat/` branches in HomeCollector / HomeAPI, PR'd into `dev`
per the universal worktree rule — they are real code changes in other repos.

## Phase 6 — Orchestrator docs (gated)

All edits in the orchestrator worktree:

1. `projects/<name>.md` — new mapping from `projects/_template.md`, filled from the spec.
2. `registry.md` — (a) master table row (next #, name, path, type, status, mapping link);
   (b) "By Type" group; (c) ecosystem graph **if** it joins the core stack;
   (d) "Dependencies" bullets both directions.
3. `server.md` — Application Services + Ports + Public Routes + Networks (if deployed).
4. `showcase.md` — narrative entry (if showcase-worthy).

## Phase 7 — Verify & report

- `/health` and `/version` reachable on the domain (if deployed)
- HomeCollector shows the service (green)
- CI green on the new repo
- Open the orchestrator-docs PR, report **every** URL back (repo, PRs, live domain) as
  clickable links. Remove worktrees once PR URLs are captured (universal rule).

---

## Output contract

Work phase-by-phase. After each phase, post a short status block:
what was created, the command(s) run, the verification result, and the next gate.
Never silently skip a phase — if it doesn't apply (e.g. no DB), say so explicitly.
