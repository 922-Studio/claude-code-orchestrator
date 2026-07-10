#!/usr/bin/env bash
# apply.sh — idempotent install for the session-log hook. Safe to re-run; called by
# setup/provision/provision.sh after every pull. It:
#   - makes the scripts executable
#   - seeds setup/local/session-log.config.json from the example (if missing)
#   - wires the SessionStart hook into ~/.claude/settings.json, refreshing the path
#     if the repo moved and never creating duplicates.
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCH="$(cd "$DIR/../.." && pwd)"
SETTINGS="$HOME/.claude/settings.json"

chmod +x "$DIR"/session-log.sh "$DIR"/recent.sh 2>/dev/null || true

# seed the per-machine config from the committed example if it's not there yet
if [ ! -f "$ORCH/setup/local/session-log.config.json" ]; then
  mkdir -p "$ORCH/setup/local"
  cp "$DIR/session-log.config.example.json" "$ORCH/setup/local/session-log.config.json" 2>/dev/null || true
fi

command -v python3 >/dev/null 2>&1 || { echo "python3 required"; exit 1; }
mkdir -p "$HOME/.claude"

python3 - "$SETTINGS" "$ORCH" <<'PY'
import json, os, sys

settings_path, orch = sys.argv[1], sys.argv[2]
cmd = f'bash "{orch}/setup/session-log/session-log.sh"'

try:
    with open(settings_path) as f:
        s = json.load(f)
except FileNotFoundError:
    s = {}
except Exception as e:
    print(f"cannot parse {settings_path}: {e}"); sys.exit(1)

before = json.dumps(s, sort_keys=True)
groups = s.setdefault("hooks", {}).setdefault("SessionStart", [])

found = False
for g in groups:                                       # refresh existing entry in place
    for h in g.get("hooks", []):
        if "session-log.sh" in h.get("command", ""):
            h["command"], h["type"] = cmd, "command"
            found = True
if not found:                                          # else append a new group
    groups.append({"hooks": [{"type": "command", "command": cmd}]})

if json.dumps(s, sort_keys=True) == before:
    print("settings.json already current"); sys.exit(0)

if os.path.exists(settings_path):
    try:
        import shutil; shutil.copyfile(settings_path, settings_path + ".bak")
    except Exception:
        pass
with open(settings_path, "w") as f:
    json.dump(s, f, indent=2); f.write("\n")
print("wired session-log SessionStart hook into settings.json")
PY
