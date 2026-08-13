# SETUP — Context-monitor statusline (config-driven, per-directory)

**id:** `claude-statusline` · **type:** Node statusline + control panel · **platform:** any (needs `node`)

## What it does
Custom Claude Code statusline showing, per session: **model** · **effort** · **context-window
usage** · **cost $** · **5h session-limit % + reset** · **versions** (Claude Code + orchestrator
`version.txt`) · **session id** · **cwd** · **git branch** · **session uptime** (wall clock) ·
**active time** (engaged time, idle gaps >5m excluded) · **sub-agents** (how many are running,
their combined token burn, longest runtime — the segment hides itself when none are).

It also restyles the **agent panel** under the prompt: one row per running sub-agent, showing
**status** (▶ running · ⏸ pending · ✓ done · ✗ failed) · **name** · **task** · **current action**
(live) · **model** · **effort** · that agent's **own context %** · optional **token trend**
sparkline · **runtime** · optional **directory**.

Every one of those is a toggleable **segment**. Which segments show is driven by a config file,
resolved **per working directory**: no config → everything on (the historical default). Some
segments also offer **display modes** — the context segment can show `%`, `number`, `number/max`,
`% + number`, or `% + number + max`. A small **control panel** (a local web page) lets you tick
segments on/off and pick their mode, globally or for a specific directory; **Apply** writes the
config. `ctx_monitor.js` re-reads the config on every render, so a saved change appears on the next
turn — no restart, no regeneration.

## Files
| Path (`~/.claude/statusline/`) | Purpose |
|---|---|
| `ctx_monitor.js` | Status **bar** entry point — wired into `settings.json → statusLine.command` |
| `subagent_monitor.js` | Agent-**panel** entry point — wired into `settings.json → subagentStatusLine.command`; also caches the tasks for the bar's `agents` segment |
| `segments.js` | **Segment registry** (single source of truth) + bar renderers |
| `agents.js` | Agent-row segments + row renderer, the sub-agent cache, and the bar's aggregate |
| `util.js` | Palette, colour ramps and formatters shared by the bar and the rows |
| `config.js` | Load / merge / save the per-directory config (non-destructive) |
| `server.js` | Local control-panel server (zero deps) |
| `panel.html` | The interactive checkbox UI |
| `open-panel.sh` | Launcher — starts the server (idempotent) + opens the browser scoped to a dir |
| `segments.config.json` | The saved config (created on first Apply; **absent = all defaults**) |
| `orch-root` | Pointer to the orchestrator checkout, written by `apply.sh`; the `versions` segment reads `<orch-root>/version.txt` live |
| `agents-cache/<session>.json` | Machine-local scratch: the last sub-agent tick per session (see below). Swept automatically |
| `~/.claude/commands/edit-stl.md` | `/edit-stl` slash command → opens the panel for the current dir |

Canonical copies live next to this file in `setup/claude-statusline/`.

## How the sub-agent parts fit together
Claude Code exposes sub-agent data to **one** hook only: `subagentStatusLine`, which is called once
per refresh tick with **all** visible agent rows at once (`tasks[]` — id, type, status, description,
label, startTime, model, effort, contextWindowSize, tokenCount, tokenSamples, cwd). The main
`statusLine` payload contains **nothing** about sub-agents, and there is no signal for "which agent
am I currently looking at" — so the bar cannot follow you into an agent view. Instead:

1. `subagent_monitor.js` renders each row **and** writes the tick to `agents-cache/<session>.json`.
2. The bar's `agents` segment reads that cache. It ignores anything older than 15s, so when the last
   agent finishes — rows disappear, the hook stops being called — the segment removes itself.
3. `statusLine.refreshInterval: 5` keeps the bar re-rendering while the main loop is only *waiting*
   on background agents. Without it the event-driven triggers go quiet and the bar freezes.

A row Claude Code isn't told about keeps its **default** rendering, so switching every agent-row
segment off in the panel returns the stock `name · description · token count` row.

## Config format (`segments.config.json`)
```json
{
  "version": 2,
  "defaults":    { "enabled": { "session": false }, "variants": {} },
  "directories": {
    "/abs/path/to/project": { "enabled": { "limit": false }, "variants": { "context": "pct" } }
  }
}
```
Each scope carries two maps: `enabled` (show/hide) and `variants` (display mode). Effective value,
most-specific first: `directory override → global default override → registry default (segments.js)`.
Directory match is **longest-prefix**, so a parent path cascades to its children unless a child
overrides. Anything missing at every level falls through to the registry default.

**Why old configs never break:** adding a new segment (or variant) only means a new entry in
`segments.js`. Pre-existing configs simply don't mention it, so it resolves to its registry default
(on) — existing overrides are untouched. Saves merge **per key**; `config.js`'s `migrate()` lifts
old **v1** flat `{segId:bool}` configs into the v2 `{enabled,variants}` shape without losing a single
enable choice (and only rewrites the file when you actually save a change).

## Install
```bash
bash setup/claude-statusline/apply.sh        # run from the orchestrator root — idempotent
```
That copies the modules, installs `/edit-stl`, writes `orch-root`, and wires the settings below
**only where they are absent** (an existing `statusLine.command` is never clobbered):
```jsonc
{
  "statusLine":         { "type": "command", "command": "node \"$HOME/.claude/statusline/ctx_monitor.js\"",
                          "refreshInterval": 5 },
  "subagentStatusLine": { "type": "command", "command": "node \"$HOME/.claude/statusline/subagent_monitor.js\"" }
}
```
`refreshInterval` (seconds, min 1) is what keeps the bar alive while sub-agents run — leave it set.

## Use the control panel
From a Claude Code session, just run **`/edit-stl`** — it opens the panel in the browser
pre-scoped to the session's directory (starting the server if needed). Or manually:
```bash
node ~/.claude/statusline/server.js        # prints http://127.0.0.1:4790
# or, scoped to a directory + auto-open:
bash ~/.claude/statusline/open-panel.sh /abs/path/to/project
```
Open the URL. Pick **This directory** (paste the absolute path you run Claude Code in) or
**Global default**, tick the segments you want, watch the live preview, press **Apply**. The page
has two groups — **Status bar segments** and **Agent panel rows** — each with its own preview. The
config file path is shown at the top. Override the port with `STATUSLINE_PANEL_PORT`, or the
config location with `CLAUDE_STATUSLINE_CONFIG`.

## Verify
```bash
# the bar — renders a full line with all defaults:
node ~/.claude/statusline/ctx_monitor.js <<< '{"model":{"display_name":"Opus"},"cost":{"total_cost_usd":0.12},"cwd":"'"$HOME"'/dev"}'

# the agent rows — one JSON line out per row in:
cd ~/.claude/statusline && node -e 'const{sampleTasks}=require("./agents");
  process.stdout.write(JSON.stringify({session_id:"probe",cwd:process.env.HOME,columns:120,tasks:sampleTasks()}))' \
  | node ~/.claude/statusline/subagent_monitor.js
```

## Fix / troubleshoot
| Symptom | Remedy |
|---|---|
| Blank statusline | `which node`; check `statusLine.command` path; restart Claude Code. |
| `Cannot find module ./segments` | Re-copy **all** modules (`bash setup/claude-statusline/apply.sh`) — they load each other. |
| Change didn't take effect | Confirm the dir path in the panel matches the session's cwd exactly (or a parent); the effective value shows a `set here / from global / default` tag per segment. |
| Panel won't start | Port in use → set `STATUSLINE_PANEL_PORT=4791`. |
| Effort not shown | Read from `~/.claude/settings.json` `effortLevel`; set it (see `claude-code-settings`). Per-agent effort is absent whenever the agent inherits yours. |
| Agent rows unchanged | `subagentStatusLine` missing from settings, or every agent-row segment is off (that deliberately restores the default row). |
| `agents` segment never appears | It needs `subagentStatusLine` wired (it feeds the cache) and only shows while agents run. Check `ls ~/.claude/statusline/agents-cache/`. |
| Bar freezes while agents work | `statusLine.refreshInterval` is missing — event triggers go quiet when the main loop only waits. |
| Row fields look wrong / build changed the payload | `touch ~/.claude/statusline/.debug-subagent` → the next tick dumps the raw payload to `.debug-subagent.json`. Delete the marker when done. |

## Uninstall
Remove `statusLine` + `subagentStatusLine` from `~/.claude/settings.json` and delete
`~/.claude/statusline/`.
