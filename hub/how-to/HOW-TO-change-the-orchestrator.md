# HOW-TO — Change / update / enhance the Orchestrator directory

Read this whenever you reshape **the structure of this directory itself** (folders, conventions,
config) — not the service repos it coordinates. The orchestrator is a coordination layer: rules,
plans, prompts, config, and portable tooling. It holds **no service code**. Keep it that way.

---

## The golden rule: the maps stay live

Two files must always reflect reality, updated in the **same session** as any structural change:

- **`overview.md`** = *where things are* (the directory map).
- **`CAPABILITIES.md`** = *what the orchestrator can do* (skills, automations, reports, setups).

**Update `overview.md` when you** add/remove/rename a top-level folder, or change what a section is for.
**Update `CAPABILITIES.md` when you** add a new capability — a skill, a `setup/` entry, a report, an
integration, a recurring workflow.
**Don't bother when** you only add/edit files *inside* an existing area — that's normal work.

How: read the live structure (`ls -1 .`, `ls -1 plans`) — never edit a map from memory — then sync
the tree diagram + lookup table. Keep them **maps, not documentation**: short labels, one line each.

---

## Where things belong

| Folder / file | For |
|---|---|
| `plans/` | tactical plans, `YYYY-MM-DD-<slug>.{html,md}` (format per `orchestrator.config.json`) |
| `plans/archive/` | completed / superseded plans (gitignored) |
| `hub/how-to/` | reusable guides like this one (committed) |
| `hub/{plans,learnings,discussions}/` | strategic notes (gitignored) |
| `setup/<id>/` | portable machine setups (SETUP.md + artifacts) |
| `prompts/`, `skills/`, `scripts/` | agent prompts, skills, helper scripts (committed framework) |
| `projects/`, `registry.md`, `server.md` | ecosystem data (gitignored) |
| `.planning/handover/` | transient session handovers (gitignored) |

Rules: never write plans to the repo root or into a service repo root. Before creating a new plan
topic, check `plans/` for an existing one and extend it rather than fork.

---

## Changing behavior (the config)

Runtime behavior is data, not prose: edit `orchestrator.config.json` (plan format, execution mode,
gates, models). Add a new switch there with a `description` — don't encode behavior choices in
`CLAUDE.md`. Per-machine differences go in the gitignored `orchestrator.config.local.json`.

## Editing `CLAUDE.md` (the rulebook)

It loads **every session**, so treat its size as a budget. Keep it to rules + the config pointer +
map pointers. Push long procedures into a `hub/how-to/` doc and link with one line (this file is an
example). Never duplicate content between `CLAUDE.md`, `overview.md`, and how-tos — link instead.
Ecosystem-specific rules go in `CLAUDE.local.md`, never in the committed `CLAUDE.md`.

## Committed vs. gitignored

The repo is a **shareable public framework**. Anything ecosystem- or machine-specific (plans,
projects, registry, server, handovers, hub notes) is **gitignored** — see `.gitignore`. When you
add a new area, decide which side it's on and update `.gitignore` + `README.md` accordingly.

---

## Hygiene
- **Read before you delete or overwrite.** If content contradicts how it was described, surface it.
- The orchestrator repo commits directly (no worktree/PR — see `CLAUDE.md`); *service* repos follow `execution_mode`.
- Prefer **fewer, well-named** folders over many shallow ones.
