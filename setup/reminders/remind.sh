#!/usr/bin/env bash
# remind.sh — fire macOS notifications for reminders due today.
#
# Driven by a local, gitignored JSON registry (setup/local/reminders.config.json). Run once daily
# by launchd (com.orchestrator.reminders); posts a macOS notification per due, enabled reminder and
# records a per-reminder "last fired" date so it never double-fires on the same day (e.g. when
# launchd runs a missed-schedule catch-up after wake).
#
# The config path is baked in at install time (install.sh rewrites __CONFIG__). You can also
# override it with REMINDERS_CONFIG=/path/to/config.json for a manual test run.
set -euo pipefail

CONFIG="${REMINDERS_CONFIG:-__CONFIG__}"
STATE_DIR="$HOME/.local/state/claude-reminders"
mkdir -p "$STATE_DIR"

[ -f "$CONFIG" ] || { echo "remind.sh: config not found: $CONFIG" >&2; exit 0; }

TODAY="$(date +%Y-%m-%d)"

# python3 does the date/frequency logic and emits one TAB-separated line per DUE reminder:
#   <id>\t<title>\t<message>
# It reads each reminder's last-fired date from the state dir to enforce once-per-day and interval.
DUE="$(STATE_DIR="$STATE_DIR" TODAY="$TODAY" CONFIG="$CONFIG" python3 - <<'PY'
import json, os, sys, datetime

cfg_path = os.environ["CONFIG"]
state_dir = os.environ["STATE_DIR"]
today = datetime.date.fromisoformat(os.environ["TODAY"])

with open(cfg_path) as f:
    cfg = json.load(f)

def last_fired(rid):
    p = os.path.join(state_dir, rid + ".lastfired")
    try:
        with open(p) as fh:
            return datetime.date.fromisoformat(fh.read().strip())
    except Exception:
        return None

WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

for r in cfg.get("reminders", []):
    if not r.get("enabled", True):
        continue
    rid = r.get("id")
    if not rid:
        continue
    lf = last_fired(rid)
    if lf == today:            # already fired today
        continue

    freq = r.get("frequency", "weekly")
    due = False
    if freq == "daily":
        due = True
    elif freq == "weekly":
        want = str(r.get("weekday", "Mon"))[:3].title()
        due = WEEKDAYS[today.weekday()] == want
    elif freq == "monthly":
        due = today.day == int(r.get("day", 1))
    elif freq == "interval":
        n = int(r.get("every_days", 7))
        due = lf is None or (today - lf).days >= n

    if due:
        title = str(r.get("title", rid)).replace("\t", " ")
        msg = str(r.get("message", "")).replace("\t", " ")
        sys.stdout.write(f"{rid}\t{title}\t{msg}\n")
PY
)"

[ -n "$DUE" ] || exit 0

# osascript -e string args are single-quoted below; escape any embedded double-quotes for the
# AppleScript string literals.
esc() { printf '%s' "$1" | sed 's/"/\\"/g'; }

while IFS=$'\t' read -r rid title msg; do
  [ -n "$rid" ] || continue
  osascript -e "display notification \"$(esc "$msg")\" with title \"$(esc "$title")\" sound name \"Glass\"" || true
  printf '%s' "$TODAY" > "$STATE_DIR/$rid.lastfired"
  echo "$(date '+%Y-%m-%d %H:%M') fired: $rid"
done <<< "$DUE"
