#!/bin/zsh
#
# brew-autoupgrade.sh — unattended daily Homebrew upgrade (formulae only).
# Launched by ~/Library/LaunchAgents/com.gregor.brew-autoupgrade.plist at 07:00,
# or on the next wake if the Mac was asleep/off at that time.
#
# Homebrew runs non-interactively by default — `brew upgrade` does NOT prompt
# for y/n, so no confirmation is needed. We only upgrade formulae (CLI tools /
# libraries) to keep this fully password-free; casks are intentionally skipped.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
export HOMEBREW_NO_ENV_HINTS=1          # quieter output
export HOMEBREW_NO_INSTALL_UPGRADE=0

LOG="$HOME/Library/Logs/brew-autoupgrade.log"

# Keep the log from growing forever: trim to the last 2000 lines on each run.
if [[ -f "$LOG" ]]; then
  tail -n 2000 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
fi

{
  echo "================================================================"
  echo "brew-autoupgrade  $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "----------------------------------------------------------------"

  echo "--- brew update ---"
  brew update

  echo "--- brew upgrade (formulae) ---"
  brew upgrade

  echo "--- brew cleanup ---"
  brew cleanup

  echo "--- done $(date '+%H:%M:%S') ---"
  echo
} >> "$LOG" 2>&1
