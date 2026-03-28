#!/usr/bin/env bash
# Runs the HomeUI best practices audit and optionally saves the output to a report.
#
# Usage:
#   ./scripts/audit-homeui.sh           # print to stdout
#   ./scripts/audit-homeui.sh --save    # print + save to reports/homeui-bp-YYYY-MM-DD.txt

set -euo pipefail

HOMEUI_DIR="/Users/gregor/dev/922/HomeUI"
REPORTS_DIR="$(dirname "$0")/../reports"

if [ ! -d "$HOMEUI_DIR" ]; then
  echo "ERROR: HomeUI not found at $HOMEUI_DIR" >&2
  exit 1
fi

if [[ "${1:-}" == "--save" ]]; then
  mkdir -p "$REPORTS_DIR"
  REPORT_FILE="$REPORTS_DIR/homeui-bp-$(date +%Y-%m-%d).txt"
  cd "$HOMEUI_DIR"
  # Strip ANSI colour codes for the saved file
  npm run audit:bp 2>&1 | tee >(sed 's/\x1b\[[0-9;]*m//g' > "$REPORT_FILE")
  echo ""
  echo "Report saved → $REPORT_FILE"
else
  cd "$HOMEUI_DIR"
  npm run audit:bp 2>&1
fi
