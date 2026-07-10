#!/usr/bin/env bash
# Show recent Claude sessions from the session log, newest first, as ready-to-paste
# resume commands — for recovering an accidentally-closed tab / post-reboot.
#
# Usage: recent.sh [N] [--here]
#   N        how many to show (default 15)
#   --here   only sessions whose logged cwd == the current directory
#   SESSION_LOG env var overrides the log path (default ~/.claude/session-log.jsonl)
set -u

LOG="${SESSION_LOG:-$HOME/.claude/session-log.jsonl}"
[ -s "$LOG" ] || { echo "No session log yet ($LOG)."; exit 0; }

n=15
here=""
for a in "$@"; do
  case "$a" in
    --here) here="$PWD" ;;
    ''|*[!0-9]*) : ;;   # ignore non-numeric args
    *) n="$a" ;;
  esac
done

python3 - "$LOG" "$n" "$here" <<'PY'
import json, sys
log, n, here = sys.argv[1], int(sys.argv[2]), sys.argv[3]
rows = []
with open(log) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            r = json.loads(line)
        except Exception:
            continue
        if here and r.get("cwd") != here:
            continue
        rows.append(r)
rows = rows[-n:][::-1]
if not rows:
    print("No matching sessions.")
    sys.exit(0)
w = max((len(r.get("cwd", "")) for r in rows), default=0)
for r in rows:
    print(f'{r.get("ts",""):25}  {r.get("source",""):8}  {r.get("cwd",""):{w}}  claude --resume {r.get("session_id","")}')
PY
