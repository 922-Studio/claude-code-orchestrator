#!/usr/bin/env bash
# Install the launchd-driven macOS reminder system.
#
# - Seeds a local, gitignored config (setup/local/reminders.config.json) from the example if absent.
# - Installs remind.sh -> ~/.local/bin/claude-remind.sh, baking the absolute config path in.
# - Renders the launchd plist -> ~/Library/LaunchAgents/, baking in $HOME and the check time read
#   from the config (check_hour/check_minute).
# - (Re)loads the launchd job.
#
# Re-run after changing check_hour/check_minute (they live in the plist) or after editing remind.sh.
# Changes to the reminders[] list need NO reinstall — remind.sh reads the config fresh each run.
#
# Usage:  bash setup/reminders/install.sh          (run from repo root)
#         ORCH_ROOT=/path/to/orchestrator bash .../install.sh
set -euo pipefail

ORCH_ROOT="${ORCH_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SRC="$ORCH_ROOT/setup/reminders"
CONFIG="$ORCH_ROOT/setup/local/reminders.config.json"

BIN_DIR="$HOME/.local/bin"
SCRIPT_DEST="$BIN_DIR/claude-remind.sh"
LA_DIR="$HOME/Library/LaunchAgents"
PLIST_DEST="$LA_DIR/com.orchestrator.reminders.plist"
LABEL="com.orchestrator.reminders"

mkdir -p "$BIN_DIR" "$LA_DIR" "$ORCH_ROOT/setup/local"

# 1. Seed the local config if it doesn't exist yet.
if [ ! -f "$CONFIG" ]; then
  cp "$SRC/reminders.config.example.json" "$CONFIG"
  echo "seeded local config : $CONFIG   (edit it to add/adjust reminders)"
else
  echo "local config        : $CONFIG   (kept as-is)"
fi

# 2. Read the daily check time from the config.
read -r CHECK_HOUR CHECK_MINUTE < <(CONFIG="$CONFIG" python3 - <<'PY'
import json, os
c = json.load(open(os.environ["CONFIG"]))
print(int(c.get("check_hour", 9)), int(c.get("check_minute", 0)))
PY
)
echo "daily check time    : ${CHECK_HOUR}:$(printf '%02d' "$CHECK_MINUTE")"

# 3. Install the script, baking in the absolute config path.
sed "s|__CONFIG__|$CONFIG|g" "$SRC/remind.sh" > "$SCRIPT_DEST"
chmod +x "$SCRIPT_DEST"
echo "installed script    : $SCRIPT_DEST"

# 4. Render the plist.
sed -e "s|__HOME__|$HOME|g" \
    -e "s|__CHECK_HOUR__|$CHECK_HOUR|g" \
    -e "s|__CHECK_MINUTE__|$CHECK_MINUTE|g" \
    "$SRC/com.orchestrator.reminders.plist.template" > "$PLIST_DEST"
echo "installed plist     : $PLIST_DEST"

# 5. (Re)load the launchd job.
launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$PLIST_DEST"
launchctl enable "gui/$UID/$LABEL"
echo
echo "done — reminder job loaded. Test it now with:"
echo "  REMINDERS_CONFIG=\"$CONFIG\" bash \"$SCRIPT_DEST\"      # fires anything due today"
echo "  launchctl kickstart -k gui/$UID/$LABEL                   # run the launchd job on demand"
