#!/usr/bin/env node
"use strict";

// ============================================================================
// subagent_monitor.js — Claude Code SUB-AGENT statusline entry point.
//
// Wired into settings.json → subagentStatusLine.command. Claude Code runs it
// once per refresh tick and passes EVERY visible agent-panel row in a single
// JSON object on stdin: the base hook fields, `columns` (usable row width) and
// a `tasks` array (id, name, type, status, description, label, startTime,
// model, effort, contextWindowSize, tokenCount, tokenSamples, cwd).
//
// We answer with one JSON line per row we want to restyle:
//     {"id": "<task id>", "content": "<row body>"}
// A row we say nothing about keeps Claude Code's default rendering — which is
// exactly what should happen when every row segment is switched off.
//
// Side effect: the tasks are cached (agents.js) so the MAIN bar's `agents`
// segment can show the aggregate. The main statusLine payload contains no
// sub-agent data, so this hook is the only source for it.
// ============================================================================

const fs = require("fs");
const { renderAgentRow, writeAgentCache, AGENT_ROW_SEGMENTS } = require("./agents");
const { loadEffectiveConfig } = require("./config");

let input = {};
try {
  input = JSON.parse(fs.readFileSync(0, "utf8"));
} catch {
  input = {};
}

// Troubleshooting hatch: `touch ~/.claude/statusline/.debug-subagent` and the
// next tick dumps the raw payload next to it, so the real task shape (which
// varies by Claude Code build) can be inspected without guessing. Delete the
// marker to switch it off again.
try {
  const marker = `${process.env.HOME}/.claude/statusline/.debug-subagent`;
  if (fs.existsSync(marker)) fs.writeFileSync(`${marker}.json`, JSON.stringify(input, null, 2));
} catch { /* never let debugging break a row */ }

const tasks = Array.isArray(input.tasks) ? input.tasks : [];

// Scope the config the same way the main bar does. Agents can run in another
// repo than the session (worktrees), so fall back to the first task's cwd.
const cwd = String(input.cwd ?? input.workspace?.current_dir ?? tasks[0]?.cwd ?? "");
const { enabled, variants } = loadEffectiveConfig(cwd);

// Cache first: the aggregate must keep flowing to the bar even if a row fails
// to render (e.g. every row segment turned off).
writeAgentCache(input.session_id ?? input.sessionId, tasks);

const allOff = AGENT_ROW_SEGMENTS.every((s) => enabled[s.id] === false);
if (!allOff) {
  const columns = Number(input.columns) || 0;
  const out = [];
  for (const t of tasks) {
    if (t?.id == null) continue;
    const content = renderAgentRow(enabled, variants, t, columns);
    if (!content) continue; // stay silent -> Claude Code keeps its default row
    out.push(JSON.stringify({ id: String(t.id), content }));
  }
  if (out.length) console.log(out.join("\n"));
}
