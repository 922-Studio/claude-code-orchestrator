# Claude Code Orchestrator

A reusable **planning + execution scaffold for Claude Code** that spans multiple repositories.
It gives an agent a consistent way to author sequenced plans, delegate work to executor/reviewer
sub-agents, enforce quality gates, and reproduce local tooling across machines — while keeping all
project- and machine-specific data **out of version control**.

The repo ships the *framework* only. Your ecosystem's data (project registry, server info, plans,
handovers) stays local via a gitignored overlay, so the same public scaffold works for any
ecosystem and on any machine.

## What's in here

| Area | What it is |
|------|-----------|
| `CLAUDE.md` | Ecosystem-agnostic rulebook loaded every session |
| `orchestrator.config.json` | Behavior switches — plan format (html/md), execution mode (pr/autonomous/direct), quality gates, models |
| `overview.md` / `CAPABILITIES.md` | Living directory map / catalog of what the orchestrator can do |
| `plans/_template.html` + `pages-design-system.css` | Plan template + shared design system |
| `scripts/build-plan-index.py` | Generates `plans/INDEX.md` from html **and** md plans |
| `prompts/` | Planner / executor / reviewer agent prompts |
| `skills/` | Reusable skills (project lifecycle, CI sweep, …) |
| `setup/` | Machine Setup Registry — reproduce Claude Code settings, statusline, and commands on a new machine |
| `hub/how-to/` | Meta-guides for maintaining the directory itself |

## Adopt it for your own ecosystem

```bash
git clone https://github.com/922-Studio/claude-code-orchestrator.git
cd claude-code-orchestrator
bash install.sh        # interactive: overlay, config, ~/.claude routing, projects, map, automations
```

`install.sh` walks you through the whole bootstrap (fresh install **or** migration from an older
orchestrator) — see `hub/how-to/HOW-TO-install-on-a-new-machine.md`. It creates the gitignored
`CLAUDE.local.md` (your registry/server/conventions) and `orchestrator.config.local.json`, wires up
Claude Code settings/statusline/commands in `~/.claude`, and builds the plan index. Prefer to do it
by hand? Each piece is documented in its `setup/<id>/SETUP.md`.

## What is intentionally NOT tracked

`CLAUDE.local.md`, `orchestrator.config.local.json`, `plans/*` (except the template), `projects/`,
`registry.md`, `server.md`, `dashboards/`, `ideas/`, `hub/{plans,learnings,discussions}/`, and
`.planning/` are all gitignored — they hold ecosystem-specific or transient data. See `.gitignore`.
