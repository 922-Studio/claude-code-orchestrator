#!/usr/bin/env bash
# Migration — the statusline 'versions' segment gains display modes (cc + orch /
# cc only / orch only), selectable in the control panel. Delegates to the
# statusline setup's own idempotent installer to re-copy the updated modules.
# Safe under --force / repeated runs; the per-machine segments.config.json (user
# choices) is never touched.
set -u
ORCH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
exec bash "$ORCH/setup/claude-statusline/apply.sh"
