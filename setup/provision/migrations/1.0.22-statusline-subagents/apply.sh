#!/usr/bin/env bash
# Migration — the statusline learns about sub-agents:
#   * a new `subagentStatusLine` hook renders every agent-panel row (status,
#     name, task, live action, model, effort, own context %, runtime)
#   * a new `agents` segment on the main bar shows the aggregate while agents
#     are running, and hides itself when none are
#   * `statusLine.refreshInterval` keeps the bar ticking while the main loop
#     only waits on background agents (event triggers go quiet there)
# Delegates to the statusline setup's own idempotent installer, which copies the
# new modules (agents.js, util.js, subagent_monitor.js) and wires the settings
# only where they are still absent. The per-machine segments.config.json (user
# choices) is never touched.
set -u
ORCH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
exec bash "$ORCH/setup/claude-statusline/apply.sh"
