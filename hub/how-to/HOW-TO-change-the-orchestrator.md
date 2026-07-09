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

## The second golden rule: build load-on-demand by default

Everything in the **always-loaded set** — `CLAUDE.md`, `CLAUDE.local.md`, the `MEMORY.md` index — is
a tax paid on **every session, every turn, forever**, whether or not the session touches it. At ~100
sessions/day, 1k standing tokens = 100k tokens/day of pure overhead. So the default for anything new
is **load-on-demand**: a pointer, a skill, a script, or a guide that costs nothing until it's needed.

Something earns a place in the always-loaded set **only** if it passes this test:

> **Would a session that never does X still need to know this?**
> **Yes** → it's a universal rule; it may load always. **No** → it's a pointer / skill / script / guide.

This is the build-time counterpart to `/token-diet` (`skills/token-diet/`): token-diet *trims
existing* standing overhead after the fact; this rule keeps new work from adding it in the first
place. Apply it every time you add a rule, a capability, or a fact.

### Where does a new thing belong?

| You're adding… | Put it in | Loads | Why |
|---|---|---|---|
| A rule every session needs, ecosystem-agnostic | `CLAUDE.md` | always | passes the test; the shared rulebook |
| Same, but ecosystem/machine-specific | `CLAUDE.local.md` | always (local) | keeps `CLAUDE.md` generic & shareable |
| A **behavior choice** (format, mode, gate, model, branch) | `orchestrator.config.json` (+ `.local.json`) | read at session start | data, not prose — never encode choices in `CLAUDE.md` |
| A procedure for **one task type** | `hub/how-to/HOW-TO-*.md` + 1-line pointer | when that task comes up | fails the test → pointer |
| Long-form domain knowledge (env, server, a service) | `guides/*.md` + 1-line pointer | on demand | reference material, not a rule |
| A repeatable, **named** multi-step operation | `skills/` (slash command) | when invoked | it's an *action* you re-run |
| Deterministic, mechanical work | `scripts/*.{sh,py}` | when run | code beats prose for machines |
| A durable fact for future sessions | auto-memory file + index line | recalled on relevance | only the one-line index entry is standing cost |

**When you add a skill or command, its *name + description* joins the always-loaded catalog** (the
body loads only on invoke). So keep that description tight and specific — it's the standing cost of
the capability. Same for a memory's index line and a how-to's pointer: the pointer is the tax, the
content is free until used.

Never duplicate content across the always-loaded set and a guide — **link, don't copy**. If two
files would state the same rule, keep one authoritative statement and point at it (the env-handling
rule is the model: one pointer line in `CLAUDE.md`, all detail in `guides/env-handling.md`).

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

Runtime behavior is **data, not prose**: add a switch to `orchestrator.config.json` with a
`description` — never encode a behavior choice in `CLAUDE.md`. Per-machine overrides go in the
gitignored `orchestrator.config.local.json` (shallow-merges, local wins).

## Editing the always-loaded set (`CLAUDE.md` / `CLAUDE.local.md`)

Every byte here loads on every session — treat size as a budget (see *build load-on-demand by
default* above). Before adding a line, run the test: **would a session that never does X still need
it?** If no, it's a pointer to a how-to/guide/skill, not inline prose. Keep `CLAUDE.md` to universal
rules + config pointer + map pointers; ecosystem/machine specifics go in `CLAUDE.local.md`. Link,
never duplicate, across `CLAUDE.md` / `overview.md` / how-tos.

## Committed vs. gitignored

The repo is a **shareable public framework**. Anything ecosystem- or machine-specific (plans,
projects, registry, server, handovers, hub notes) is **gitignored** — see `.gitignore`. When you
add a new area, decide which side it's on and update `.gitignore` + `README.md` accordingly.

---

## Hygiene
- **Read before you delete or overwrite.** If content contradicts how it was described, surface it.
- The orchestrator repo commits directly (no worktree/PR — see `CLAUDE.md`); *service* repos follow `execution_mode`.
- Prefer **fewer, well-named** folders over many shallow ones.
