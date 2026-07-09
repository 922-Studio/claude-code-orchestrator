#!/usr/bin/env bash
# apply.sh — idempotent install for the git-freshness hooks. Safe to re-run;
# called by setup/provision/provision.sh after every pull. It:
#   - makes the hook scripts executable
#   - seeds setup/local/git-freshness.config.json from the example (if missing)
#   - wires the PreToolUse + SessionStart hooks into ~/.claude/settings.json,
#     refreshing the path if the repo moved and never creating duplicates.
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCH="$(cd "$DIR/../.." && pwd)"
SETTINGS="$HOME/.claude/settings.json"

chmod +x "$DIR"/worktree-fetch.sh "$DIR"/session-fetch.sh 2>/dev/null || true

# seed the per-machine config from the committed example if it's not there yet
if [ ! -f "$ORCH/setup/local/git-freshness.config.json" ]; then
  mkdir -p "$ORCH/setup/local"
  cp "$DIR/git-freshness.config.example.json" "$ORCH/setup/local/git-freshness.config.json" 2>/dev/null || true
fi

command -v python3 >/dev/null 2>&1 || { echo "python3 required"; exit 1; }
mkdir -p "$HOME/.claude"

python3 - "$SETTINGS" "$ORCH" <<'PY'
import json, os, sys

settings_path, orch = sys.argv[1], sys.argv[2]
wt  = f'bash "{orch}/setup/git-freshness/worktree-fetch.sh"'
ses = f'bash "{orch}/setup/git-freshness/session-fetch.sh"'

try:
    with open(settings_path) as f:
        s = json.load(f)
except FileNotFoundError:
    s = {}
except Exception as e:
    print(f"cannot parse {settings_path}: {e}"); sys.exit(1)

before = json.dumps(s, sort_keys=True)
hooks = s.setdefault("hooks", {})

def ensure(event, matcher, basename, command):
    groups = hooks.setdefault(event, [])
    for g in groups:                                  # refresh existing entry in place
        for h in g.get("hooks", []):
            if basename in h.get("command", ""):
                h["command"], h["type"] = command, "command"
                if matcher is not None:
                    g["matcher"] = matcher
                return
    g = {"hooks": [{"type": "command", "command": command}]}   # else append
    if matcher is not None:
        g["matcher"] = matcher
    groups.append(g)

ensure("PreToolUse",   "Bash", "worktree-fetch.sh", wt)
ensure("SessionStart", None,   "session-fetch.sh",  ses)

if json.dumps(s, sort_keys=True) == before:
    print("settings.json already current"); sys.exit(0)

if os.path.exists(settings_path):
    try:
        import shutil; shutil.copyfile(settings_path, settings_path + ".bak")
    except Exception:
        pass
with open(settings_path, "w") as f:
    json.dump(s, f, indent=2); f.write("\n")
print("wired hooks into settings.json")
PY
