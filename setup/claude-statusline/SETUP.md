# SETUP — Context-monitor statusline (config-driven, per-directory)

**id:** `claude-statusline` · **type:** Node statusline + control panel · **platform:** any (needs `node`)

## What it does
Custom Claude Code statusline showing, per session: **model** · **effort** · **context-window
usage** · **cost $** · **5h session-limit % + reset** · **versions** (Claude Code + orchestrator
`version.txt`) · **session id** · **cwd** · **git branch** · **session uptime** (wall clock) ·
**active time** (engaged time, idle gaps >5m excluded).

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
| `ctx_monitor.js` | Statusline entry point — wired into `settings.json → statusLine.command` |
| `segments.js` | **Segment registry** (single source of truth) + renderers |
| `config.js` | Load / merge / save the per-directory config (non-destructive) |
| `server.js` | Local control-panel server (zero deps) |
| `panel.html` | The interactive checkbox UI |
| `open-panel.sh` | Launcher — starts the server (idempotent) + opens the browser scoped to a dir |
| `segments.config.json` | The saved config (created on first Apply; **absent = all defaults**) |
| `orch-root` | Pointer to the orchestrator checkout, written by `apply.sh`; the `versions` segment reads `<orch-root>/version.txt` live |
| `~/.claude/commands/edit-stl.md` | `/edit-stl` slash command → opens the panel for the current dir |

Canonical copies live next to this file in `setup/claude-statusline/`.

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
SRC="$(pwd)/setup/claude-statusline"        # run from the orchestrator root
DST="$HOME/.claude/statusline"
mkdir -p "$DST"
cp "$SRC"/{ctx_monitor.js,segments.js,config.js,server.js,panel.html,open-panel.sh} "$DST/"
chmod +x "$DST/open-panel.sh"
cp "$SRC/edit-stl.md" "$HOME/.claude/commands/edit-stl.md"   # the /edit-stl command
printf '%s\n' "$(cd "$SRC/../.." && pwd)" > "$DST/orch-root"  # for the versions segment

# Wire it in (if not already done by claude-code-settings):
node -e '
  const fs=require("fs"),p=process.env.HOME+"/.claude/settings.json";
  const s=fs.existsSync(p)?JSON.parse(fs.readFileSync(p,"utf8")):{};
  s.statusLine={type:"command",command:`node "${process.env.HOME}/.claude/statusline/ctx_monitor.js"`};
  fs.writeFileSync(p,JSON.stringify(s,null,2));
  console.log("statusLine wired:",s.statusLine.command);
'
```

## Use the control panel
From a Claude Code session, just run **`/edit-stl`** — it opens the panel in the browser
pre-scoped to the session's directory (starting the server if needed). Or manually:
```bash
node ~/.claude/statusline/server.js        # prints http://127.0.0.1:4790
# or, scoped to a directory + auto-open:
bash ~/.claude/statusline/open-panel.sh /abs/path/to/project
```
Open the URL. Pick **This directory** (paste the absolute path you run Claude Code in) or
**Global default**, tick the segments you want, watch the live preview, press **Apply**. The
config file path is shown at the top. Override the port with `STATUSLINE_PANEL_PORT`, or the
config location with `CLAUDE_STATUSLINE_CONFIG`.

## Verify
```bash
# renders a full line with all defaults:
node ~/.claude/statusline/ctx_monitor.js <<< '{"model":{"display_name":"Opus"},"cost":{"total_cost_usd":0.12},"cwd":"'"$HOME"'/dev"}'
```

## Fix / troubleshoot
| Symptom | Remedy |
|---|---|
| Blank statusline | `which node`; check `statusLine.command` path; restart Claude Code. |
| `Cannot find module ./segments` | Re-copy **all five** files (Install step) — they load each other. |
| Change didn't take effect | Confirm the dir path in the panel matches the session's cwd exactly (or a parent); the effective value shows a `set here / from global / default` tag per segment. |
| Panel won't start | Port in use → set `STATUSLINE_PANEL_PORT=4791`. |
| Effort not shown | Read from `~/.claude/settings.json` `effortLevel`; set it (see `claude-code-settings`). |

## Uninstall
Remove `statusLine` from `~/.claude/settings.json` and delete `~/.claude/statusline/`.
