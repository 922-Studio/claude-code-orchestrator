#!/usr/bin/env bash
# SessionStart hook — append one JSONL record per session start to a machine-global
# session log, so an accidentally-closed tab, a crash, or a reboot can be recovered
# with `claude --resume <id>` (list them with recent.sh).
#
# Writes ONLY to the log file: prints nothing to stdout (SessionStart stdout is
# injected into the model's context, and this would bloat it). Non-blocking: exits 0.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCH="$(cd "$SELF_DIR/../.." && pwd)"
CONFIG="$ORCH/setup/local/session-log.config.json"

log="$HOME/.claude/session-log.jsonl"
enabled=true
max=2000

if [ -f "$CONFIG" ]; then
  enabled="$(python3 -c 'import json,sys;print(str(json.load(open(sys.argv[1])).get("enabled",True)).lower())' "$CONFIG" 2>/dev/null || echo true)"
  cfg_log="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("log_path","") or "")' "$CONFIG" 2>/dev/null || echo '')"
  max="$(python3 -c 'import json,sys;print(int(json.load(open(sys.argv[1])).get("max_entries",2000)))' "$CONFIG" 2>/dev/null || echo 2000)"
  [ -n "$cfg_log" ] && log="${cfg_log/#\~/$HOME}"
fi
[ "$enabled" = "false" ] && exit 0

# session-log.py reads the hook JSON from stdin; the config readers above never touch
# stdin, so the payload is still buffered for it here.
python3 "$SELF_DIR/session-log.py" "$log" "$max" >/dev/null 2>&1 || true
exit 0
