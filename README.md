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

1. Clone the repo.
2. Copy `CLAUDE.local.md.example` → `CLAUDE.local.md` (gitignored) and fill in your registry/server/conventions.
3. Adjust `orchestrator.config.json` (or add a gitignored `orchestrator.config.local.json`) to taste.
4. Walk `setup/` to install the local tooling (Claude Code settings, statusline, slash-commands) on the machine.
5. Put your plans in `plans/`, project mappings in `projects/`, server notes in `server.md` — all gitignored by default.

## What is intentionally NOT tracked

`CLAUDE.local.md`, `orchestrator.config.local.json`, `plans/*` (except the template), `projects/`,
`registry.md`, `server.md`, `dashboards/`, `ideas/`, `hub/{plans,learnings,discussions}/`, and
`.planning/` are all gitignored — they hold ecosystem-specific or transient data. See `.gitignore`.
