# HOW-TO — Install the orchestrator on a new machine

One interactive script does the whole bootstrap: **`bash install.sh`** from the repo root. It's
idempotent (safe to re-run) and never overwrites existing ecosystem files without saying so.

```bash
git clone https://github.com/922-Studio/claude-code-orchestrator.git
cd claude-code-orchestrator
bash install.sh
```

## Modes (the first prompt)

1. **Fresh install** — runs every step in order: overlay → config → `~/.claude` routing → projects → map → optional automations.
2. **Migrate** — import an existing orchestrator's data first, then finish the fresh steps.
3. **Custom** — pick individual steps by number.

## What each step does

| Step | Action | Touches |
|------|--------|---------|
| overlay | Create `CLAUDE.local.md` from the template (your ecosystem rules) | repo (gitignored) |
| config | Write `orchestrator.config.local.json` (asks: plan format, execution mode, base branch) | repo (gitignored) |
| cc-settings | Merge baseline Claude Code prefs (model/effort/theme/perms + statusline) into `~/.claude/settings.json` (backs up first, `jq` merge) | `~/.claude/settings.json` |
| statusline | Install the context-monitor statusline | `~/.claude/statusline/ctx_monitor.js` |
| commands | Install slash-commands, rewriting the repo path to this clone | `~/.claude/commands/*` |
| projects | Create `projects/` + a `registry.md` skeleton (populate with `/project-new`) | repo (gitignored) |
| map | Build `plans/INDEX.md`; point at `overview.md` / `CAPABILITIES.md` | repo (gitignored) |
| automations | Optional: daily `brew-autoupgrade` (launchd), `repo-sync` on PATH | `~/Library/LaunchAgents`, `~/.local/bin` |

Requires `git`, `jq`, `python3` (the script checks and tells you). Restart Claude Code afterward so
it picks up the new settings and commands.

## Migrating from an old orchestrator

Choose mode **2** (or step **9**) and give the path to the old orchestrator directory. The installer:

- Imports ecosystem **data** it finds there — `registry.md`, `server.md`, `projects/`, `dashboards/`,
  `ideas/`, `plans/`, `hub/{plans,learnings,discussions}/`, `.planning/` — without clobbering anything already present.
- Copies an **old `planning/<topic>/` layout** into `plans/_imported-planning/` (review and reshape into the flat `plans/YYYY-MM-DD-<slug>` convention).
- Copies the old machine's **`setup/` entries and `reports/`** into `setup/local/` (gitignored) so personal automations survive without polluting the shared framework.
- Seeds `CLAUDE.local.md` from the old `CLAUDE.md` (review and trim to ecosystem-specific rules — the generic framework rules already live in the committed `CLAUDE.md`).

After migrating: review `CLAUDE.local.md`, `setup/local/`, and `plans/_imported-planning/`, then
rebuild the index (`python3 scripts/build-plan-index.py`).

## Manual fallback
If you'd rather not run the script, each piece is documented in its `setup/<id>/SETUP.md` and can be
installed by hand from there.
