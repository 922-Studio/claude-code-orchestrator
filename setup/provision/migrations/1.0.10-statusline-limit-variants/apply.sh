#!/usr/bin/env bash
# Migration — the statusline '5h session limit' segment gains display modes
# (% used / DESC vs % left / ASC), selectable in the control panel. Delegates
# to the statusline setup's own idempotent installer to re-copy the updated
# modules. Safe under --force / repeated runs; the per-machine
# segments.config.json (user choices) is never touched.
set -u
ORCH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
exec bash "$ORCH/setup/claude-statusline/apply.sh"
