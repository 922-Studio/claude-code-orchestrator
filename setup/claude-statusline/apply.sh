#!/usr/bin/env bash
# apply.sh — idempotent install for the config-driven statusline + control panel.
# Safe to re-run; called by setup/provision/provision.sh after every pull. It:
#   - copies the statusline modules into ~/.claude/statusline/
#   - installs the /edit-stl command into ~/.claude/commands/
#   - wires statusLine into ~/.claude/settings.json ONLY if it's absent
#     (the claude-code-settings template owns it otherwise — never clobber).
# The per-directory config (~/.claude/statusline/segments.config.json) is
# machine-local user state and is never touched here.
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCH="$(cd "$DIR/../.." && pwd)"
DST="$HOME/.claude/statusline"
CMDS="$HOME/.claude/commands"
SETTINGS="$HOME/.claude/settings.json"

mkdir -p "$DST" "$CMDS"
cp "$DIR"/{ctx_monitor.js,segments.js,config.js,server.js,panel.html,open-panel.sh} "$DST/"
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

if s.get("statusLine"):
    print("statusLine already set — left as is"); sys.exit(0)

cmd = f'node "{os.environ["HOME"]}/.claude/statusline/ctx_monitor.js"'
s["statusLine"] = {"type": "command", "command": cmd}
os.makedirs(os.path.dirname(p), exist_ok=True)
if os.path.exists(p):
    try:
        import shutil; shutil.copyfile(p, p + ".bak")
    except Exception: pass
with open(p, "w") as f:
    json.dump(s, f, indent=2); f.write("\n")
print("wired statusLine into settings.json (was absent)")
PY
