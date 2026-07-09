# Post-install setup — paste this into a fresh Claude Code session

> Launch Claude Code **inside the orchestrator repo** on the new machine (after `bash install.sh`
> has run), then paste everything below. It orients you, finishes the parts the installer can't do
> alone (ecosystem content, registry, MCP, verification), and reports what's left.

---

You are bootstrapping this orchestrator on a fresh machine. `install.sh` has already run. Work
through the phases below **interactively** — ask me the questions, confirm before writing, and keep
it tight. Don't start unrelated work.

## Phase 0 — Orient (read first, no edits)
Read, in order: `overview.md`, `CLAUDE.md`, `orchestrator.config.json`, `CAPABILITIES.md`, and
`CLAUDE.local.md` if it exists. Summarize in 3–4 lines what this instance is and its current config
(`plan_format`, `execution_mode`, `base_branch`). Detect whether this was a **fresh** install or a
**migration** (does `plans/_imported-planning/` or a populated `registry.md` already exist?).

## Phase 1 — Verify the install
Confirm and report a ✓/✗ table:
- `~/.claude/settings.json` has model/effort/theme/statusline (`jq '{model,effortLevel,theme,statusLine}' ~/.claude/settings.json`)
- `~/.claude/statusline/ctx_monitor.js` present
- `~/.claude/commands/` has the orchestrator commands (`ls ~/.claude/commands`)
- `git`, `jq`, `python3`, `gh` available; `gh auth status`
Fix anything ✗ by re-running the matching `setup/<id>/SETUP.md` Install step. If I need to restart
Claude Code for settings/commands to take effect, tell me.

## Phase 2 — Ecosystem overlay (`CLAUDE.local.md`)
Interview me for this machine's ecosystem, then write/refine `CLAUDE.local.md` (keep it lean —
ecosystem-specific rules only; generic rules already live in `CLAUDE.md`):
- Workspace root (where all repos live) and the ecosystem name
- Base branch + branch/worktree conventions; any prod/deploy rule
- Server/infra access (ssh aliases, management scripts, docs location)
- Env/secrets policy and any per-ecosystem checklists
If this was a migration, the file may already be seeded from the old `CLAUDE.md` — review it with me
and **trim** it to ecosystem specifics rather than starting over.

## Phase 3 — Projects & registry
- If `registry.md` is empty/skeleton: discover local repos under the workspace root (`ls`, check for
  `.git`), show me the list, and for each I confirm, add a row and create `projects/<name>.md` from
  the mapping template. For a full lifecycle setup use the `/project-new <name> like <ref>` skill.
- If migrated: verify the imported `registry.md` paths exist on THIS machine; flag any missing.

## Phase 4 — Per-machine integrations (not installed by the repo)
- **MCP servers** (e.g. Gmail/Teams/Jira/Tempo, or whatever I rely on): list what this machine
  should have, check current ones (`claude mcp list`), and walk me through adding the missing ones.
  These are machine-local auth — the repo can't ship them.
- **Global skills/plugins** I use that aren't in `skills/`: ask which I need; if any, help me install
  them into `~/.claude` (or fold reusable ones into the repo's `skills/` + the commands installer).

## Phase 5 — Migration follow-through (only if migrated)
Walk `setup/local/`, `plans/_imported-planning/`, and imported `hub/` notes with me: keep, reshape
into the flat `plans/YYYY-MM-DD-<slug>` convention, or discard. Reinstall any personal `setup/local/<id>`
via its `SETUP.md`.

## Phase 6 — Build the map & finish
- `python3 scripts/build-plan-index.py` → `plans/INDEX.md`
- Confirm `overview.md` still matches reality; update if this bootstrap changed the structure.
- Commit orchestrator changes (this is the Local Workflow Exception repo — direct commit; per
  `CLAUDE.local.md` orchestrator self-work is auto-commit + auto-push on my machines).

## Final report
Print a checklist: what's ✓ done, what still needs me (e.g. edit `CLAUDE.local.md` details, add an
MCP token, restart Claude Code), and the one command to re-verify later.
