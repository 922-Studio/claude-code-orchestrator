#!/usr/bin/env bash
# Migration — add the cc + orchestrator version segment to the statusline and
# write the orch-root pointer so the bar can read version.txt live. Delegates to
# the statusline setup's own idempotent installer (re-copies the updated modules
# and refreshes orch-root). Safe under --force / repeated runs; the per-machine
# segments.config.json (user choices) is never touched.
set -u
ORCH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
exec bash "$ORCH/setup/claude-statusline/apply.sh"
