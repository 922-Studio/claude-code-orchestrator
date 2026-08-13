#!/usr/bin/env bash
# apply.sh — idempotent install for the config-driven statusline + control panel.
# Safe to re-run; called by setup/provision/provision.sh after every pull. It:
#   - copies the statusline modules into ~/.claude/statusline/
#   - installs the /edit-stl command into ~/.claude/commands/
#   - wires statusLine into ~/.claude/settings.json ONLY if it's absent
#     (the claude-code-settings template owns it otherwise — never clobber)
#   - wires subagentStatusLine (agent-panel rows) the same way, and sets
#     statusLine.refreshInterval so the bar stays live while sub-agents run.
# The per-directory config (~/.claude/statusline/segments.config.json) is
# machine-local user state and is never touched here.
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCH="$(cd "$DIR/../.." && pwd)"
DST="$HOME/.claude/statusline"
CMDS="$HOME/.claude/commands"
SETTINGS="$HOME/.claude/settings.json"

mkdir -p "$DST" "$CMDS"
cp "$DIR"/{ctx_monitor.js,subagent_monitor.js,segments.js,agents.js,util.js,config.js,server.js,panel.html,open-panel.sh} "$DST/"
chmod +x "$DST/open-panel.sh" 2>/dev/null || true
cp "$DIR/edit-stl.md" "$CMDS/edit-stl.md"
# Pointer to this checkout so the statusline can read version.txt live (the
# 'versions' segment). Refreshed each run, so a moved repo self-heals.
printf '%s\n' "$ORCH" > "$DST/orch-root"
echo "statusline: modules + /edit-stl installed into ~/.claude (orch-root → $ORCH)"

# Wire statusLine only if the user has none yet (fresh machine). If present,
# leave it — claude-code-settings owns the canonical value.
command -v python3 >/dev/null 2>&1 || { echo "python3 required to check settings"; exit 0; }
python3 - "$SETTINGS" <<'PY'
import json, os, sys
p = sys.argv[1]
try:
    with open(p) as f: s = json.load(f)
except FileNotFoundError:
    s = {}
except Exception as e:
    print(f"cannot parse {p}: {e} — leaving settings untouched"); sys.exit(0)

home = os.environ["HOME"]
changed = []

# 1. The bar itself — only on a fresh machine; claude-code-settings owns it.
if s.get("statusLine"):
    print("statusLine already set — left as is")
else:
    s["statusLine"] = {"type": "command", "command": f'node "{home}/.claude/statusline/ctx_monitor.js"'}
    changed.append("statusLine")

# 2. Keep the bar ticking while sub-agents run. The event-driven triggers go
#    quiet whenever the main loop is just waiting on background agents, which
#    would freeze the agents/uptime/active segments. Additive — never touches
#    an existing command, and left alone if the user already chose a value.
sl = s.get("statusLine")
if isinstance(sl, dict) and "refreshInterval" not in sl:
    sl["refreshInterval"] = 5
    changed.append("statusLine.refreshInterval=5")

# 3. The agent-panel rows.
if s.get("subagentStatusLine"):
    print("subagentStatusLine already set — left as is")
else:
    s["subagentStatusLine"] = {"type": "command", "command": f'node "{home}/.claude/statusline/subagent_monitor.js"'}
    changed.append("subagentStatusLine")

if not changed:
    sys.exit(0)

os.makedirs(os.path.dirname(p), exist_ok=True)
if os.path.exists(p):
    try:
        import shutil; shutil.copyfile(p, p + ".bak")
    except Exception: pass
with open(p, "w") as f:
    json.dump(s, f, indent=2); f.write("\n")
print("settings.json updated: " + ", ".join(changed))
PY
