#!/usr/bin/env python3
"""Append one JSONL record for a SessionStart event.

Reads the hook payload from stdin; prints nothing to stdout (SessionStart stdout is
injected into the model's context). argv: <log_path> <max_entries>.
"""
import json
import os
import sys
import time

log = sys.argv[1]
maxn = int(sys.argv[2]) if len(sys.argv) > 2 else 0

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

sid = data.get("session_id") or ""
if not sid:
    sys.exit(0)

rec = {
    "ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "session_id": sid,
    "cwd": data.get("cwd", ""),
    "source": data.get("source", ""),
    "transcript_path": data.get("transcript_path", ""),
}

os.makedirs(os.path.dirname(log) or ".", exist_ok=True)
with open(log, "a") as f:
    f.write(json.dumps(rec) + "\n")

# Light-touch retention: only rewrite when meaningfully over the cap, to avoid
# churning the file on every single session start.
if maxn > 0:
    try:
        with open(log) as f:
            lines = f.readlines()
        if len(lines) > maxn * 1.25:
            with open(log, "w") as f:
                f.writelines(lines[-maxn:])
    except Exception:
        pass
