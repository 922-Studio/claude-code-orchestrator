#!/usr/bin/env bash
# Migration 1.0.7 — install the migration-reminder PostToolUse hook, idempotently.
# The hook fires ONLY when Edit/Write touches the orchestrator's machine-facing
# paths (setup/, .github/workflows) and prints a once-per-session reminder to
# ship a provisioning migration. Zero standing context cost — it lives entirely
# in the hook, not in CLAUDE.md.
set -u
ORCH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SETTINGS="$HOME/.claude/settings.json"
chmod +x "$ORCH/setup/provision/migration-reminder.sh" 2>/dev/null || true
command -v python3 >/dev/null 2>&1 || { echo "python3 required"; exit 1; }
mkdir -p "$HOME/.claude"

python3 - "$SETTINGS" "$ORCH" <<'PY'
import json, os, sys
path, orch = sys.argv[1], sys.argv[2]
cmd = f'bash "{orch}/setup/provision/migration-reminder.sh"'
try:
    with open(path) as f: s = json.load(f)
except FileNotFoundError: s = {}
except Exception as e: print(f"cannot parse {path}: {e}"); sys.exit(1)
before = json.dumps(s, sort_keys=True)
groups = s.setdefault("hooks", {}).setdefault("PostToolUse", [])
for g in groups:                                  # refresh in place, no duplicate
    for h in g.get("hooks", []):
        if "migration-reminder.sh" in h.get("command", ""):
            h["command"], h["type"] = cmd, "command"
            g["matcher"] = "Edit|Write"
            break
    else: continue
    break
else:
    groups.append({"matcher": "Edit|Write", "hooks": [{"type": "command", "command": cmd}]})
if json.dumps(s, sort_keys=True) == before: print("settings.json already current"); sys.exit(0)
if os.path.exists(path):
    try:
        import shutil; shutil.copyfile(path, path + ".bak")
    except Exception: pass
with open(path, "w") as f: json.dump(s, f, indent=2); f.write("\n")
print("wired migration-reminder PostToolUse hook")
PY
