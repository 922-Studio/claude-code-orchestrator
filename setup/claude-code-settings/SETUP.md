# SETUP — Claude Code settings

**id:** `claude-code-settings` · **type:** config file · **platform:** any (macOS/Linux)

## What it does
Applies Gregor's baseline Claude Code preferences — default **model** (`opus`), **effort** (`medium`),
**theme** (`dark`), **fullscreen TUI**, no `Co-Authored-By` trailers, permission mode `auto`, the
dangerous/auto permission-prompt skips, and wires the **context-monitor statusline**. These are the
machine-agnostic keys; machine-specific bits (plugins, marketplace, per-project permission allowlists)
are intentionally NOT in the template.

## Where it lives
| Path | Purpose |
|---|---|
| `~/.claude/settings.json` | global Claude Code settings (the merge target) |
| `settings.template.json` (next to this file) | canonical baseline keys, `__HOME__`-templated |

## Install
Merges the template over any existing settings (existing keys win only where the template is silent;
template values win on conflict). Requires `jq`.

```bash
SRC="$(pwd)/setup/claude-code-settings"     # run from the orchestrator root
mkdir -p ~/.claude
TMP="$(mktemp)"
sed "s|__HOME__|$HOME|g" "$SRC/settings.template.json" > "$TMP"

if [ -f ~/.claude/settings.json ]; then
  cp ~/.claude/settings.json ~/.claude/settings.json.bak       # backup first
  jq -s '.[0] * .[1]' ~/.claude/settings.json "$TMP" > ~/.claude/settings.json.new
  mv ~/.claude/settings.json.new ~/.claude/settings.json
else
  cp "$TMP" ~/.claude/settings.json
fi
rm -f "$TMP"
```
> Then install the statusline it references: see `setup/claude-statusline/`.

## Verify
```bash
jq '{model, effortLevel, theme, tui, includeCoAuthoredBy, permissions, statusLine}' ~/.claude/settings.json
```
Expect `model=opus`, `effortLevel=medium`, `theme=dark`, `tui=fullscreen`,
`includeCoAuthoredBy=false`, `permissions.defaultMode=auto`, and a `statusLine.command` pointing at
`~/.claude/statusline/ctx_monitor.js`. Restart Claude Code to pick up changes.

## Fix / troubleshoot
| Symptom | Remedy |
|---|---|
| `jq: command not found` | `brew install jq` (macOS) / `apt install jq` (Linux), re-run Install. |
| Old settings clobbered | Restore `~/.claude/settings.json.bak`, re-run with the jq merge (not a plain copy). |
| Statusline shows nothing | Install `setup/claude-statusline/` and confirm the path in `statusLine.command`. |
| Wrong model/effort at launch | These are defaults; `/model` and `/effort` override per-session. Re-run Install to reset defaults. |

## Uninstall
Restore the backup: `mv ~/.claude/settings.json.bak ~/.claude/settings.json` (or edit out the keys).
