#!/usr/bin/env bash
# apply.sh — idempotent install for the VESTA/NOVA track guard. Safe to re-run;
# called by setup/provision/provision.sh after every pull. It:
#   - makes the guard executable
#   - wires it as a PreToolUse(Bash) hook in ~/.claude/settings.json, refreshing
#     the path if the repo moved and never creating duplicates.
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCH="$(cd "$DIR/../.." && pwd)"
SETTINGS="$HOME/.claude/settings.json"

chmod +x "$DIR"/vesta-nova-guard.sh 2>/dev/null || true

command -v python3 >/dev/null 2>&1 || { echo "python3 required"; exit 1; }
mkdir -p "$HOME/.claude"

python3 - "$SETTINGS" "$ORCH" <<'PY'
import json, sys

settings_path, orch = sys.argv[1], sys.argv[2]
cmd = f'bash "{orch}/setup/vesta-nova-guard/vesta-nova-guard.sh"'
marker = "vesta-nova-guard/vesta-nova-guard.sh"

try:
    with open(settings_path) as f:
        s = json.load(f)
except FileNotFoundError:
    s = {}
except Exception as e:
    print(f"cannot parse {settings_path}: {e}"); sys.exit(1)

before = json.dumps(s, sort_keys=True)

groups = s.setdefault("hooks", {}).setdefault("PreToolUse", [])
group = next((g for g in groups if g.get("matcher") == "Bash"), None)
if group is None:
    group = {"matcher": "Bash", "hooks": []}
    groups.append(group)

hooks = group.setdefault("hooks", [])
entry = next((h for h in hooks if marker in str(h.get("command", ""))), None)
if entry is None:
    hooks.append({
        "type": "command",
        "if": "Bash(git *)",
        "command": cmd,
        "statusMessage": "Checking VESTA/NOVA track guard...",
    })
else:
    entry["command"] = cmd          # refresh path if the repo moved
    entry.setdefault("type", "command")
    entry.setdefault("if", "Bash(git *)")

if json.dumps(s, sort_keys=True) != before:
    with open(settings_path, "w") as f:
        json.dump(s, f, indent=2)
        f.write("\n")
    print("vesta-nova-guard: hook wired into settings.json")
else:
    print("vesta-nova-guard: already installed")
PY
