# SETUP — Context-monitor statusline

**id:** `claude-statusline` · **type:** Node statusline · **platform:** any (needs `node`)

## What it does
Custom Claude Code statusline showing, per session: **model** · **effort** · **context-window
usage %** (color-coded as it fills) · **cost $** · **5h session-limit % + time-to-reset**
(color-coded by quota consumed) · **cwd** · session id. Reads effort from
`~/.claude/settings.json`, context/cost from the transcript Claude Code passes on stdin, and the
session-limit reset from `rate_limits.five_hour.{used_percentage,resets_at}` on stdin. The
`rate_limits` block appears only for Pro/Max subscribers after the first API response of a session;
when absent the limit label is silently omitted.

## Where it lives
| Path | Purpose |
|---|---|
| `~/.claude/statusline/ctx_monitor.js` | the statusline script |
| `~/.claude/settings.json` → `statusLine.command` | wires it in (set by `claude-code-settings`) |

Canonical copy lives next to this file: `ctx_monitor.js`.

## Install
```bash
SRC="$(pwd)/setup/claude-statusline"        # run from the orchestrator root
mkdir -p ~/.claude/statusline
cp "$SRC/ctx_monitor.js" ~/.claude/statusline/ctx_monitor.js

# Wire it into settings (if not already done by claude-code-settings):
node -e '
  const fs=require("fs"),p=process.env.HOME+"/.claude/settings.json";
  const s=fs.existsSync(p)?JSON.parse(fs.readFileSync(p,"utf8")):{};
  s.statusLine={type:"command",command:`node "${process.env.HOME}/.claude/statusline/ctx_monitor.js"`};
  fs.writeFileSync(p,JSON.stringify(s,null,2));
  console.log("statusLine wired:",s.statusLine.command);
'
```

## Verify
```bash
node ~/.claude/statusline/ctx_monitor.js <<< '{"model":{"display_name":"Opus"},"cost":{"total_cost_usd":0.12},"cwd":"'"$HOME"'/dev"}'
```
Prints a formatted status line (model / effort / cost / cwd) with no error. In a live session the
line appears at the bottom of the TUI. `node` must be on PATH.

## Fix / troubleshoot
| Symptom | Remedy |
|---|---|
| Blank statusline | `which node`; ensure `statusLine.command` path is correct; restart Claude Code. |
| `Cannot find module` | Re-copy `ctx_monitor.js` (Install step 1). |
| Effort not shown | It's read from `~/.claude/settings.json` `effortLevel`; set it (see `claude-code-settings`). |

## Uninstall
Remove `statusLine` from `~/.claude/settings.json` and delete `~/.claude/statusline/ctx_monitor.js`.
