#!/usr/bin/env bash
# Migration — install the config-driven statusline + control panel + /edit-stl.
# Adopts the whole claude-statusline setup: modules into ~/.claude/statusline/,
# the /edit-stl command into ~/.claude/commands/, and statusLine wiring if the
# machine has none yet. Delegates to the setup's own idempotent installer so the
# logic stays co-located with the setup. Safe under --force / repeated runs; the
# per-machine segments.config.json (user choices) is never touched.
set -u
ORCH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
exec bash "$ORCH/setup/claude-statusline/apply.sh"
