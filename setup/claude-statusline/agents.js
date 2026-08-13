#!/usr/bin/env node
"use strict";

// ============================================================================
// agents.js — everything sub-agent.
//
// Two consumers:
//   1. subagent_monitor.js — wired into settings.json → subagentStatusLine.
//      Claude Code runs it once per refresh tick and hands it EVERY visible
//      agent-panel row in one JSON payload; we render each row's body here.
//   2. segments.js — the `agents` segment of the main status bar, which shows
//      the aggregate (how many running, tokens burned, longest runtime).
//
// The main statusLine payload carries NO sub-agent data — Claude Code only
// exposes it to subagentStatusLine. So (1) writes a small per-session cache and
// (2) reads it. The cache expires (AGENT_CACHE_TTL_MS): when the last agent
// finishes, its rows disappear, subagentStatusLine stops being called, the
// cache goes stale, and the bar segment removes itself on its own.
//
// Row segments live in the SAME registry/config system as the bar segments
// (group: "agentrow", ids prefixed `arow_`), so the control panel gets its
// checkboxes and the per-directory overrides work identically.
// ============================================================================

const fs = require("fs");
const path = require("path");
const {
  A,
  pctColor,
  fmtElapsed,
  fmtTokens,
  comma,
  shortModel,
  visibleLength,
  truncateAnsi,
  clip,
} = require("./util");

// --- cache ------------------------------------------------------------------
const CACHE_DIR =
  process.env.CLAUDE_STATUSLINE_AGENT_CACHE ||
  `${process.env.HOME}/.claude/statusline/agents-cache`;

// A cache older than this is treated as "no agents running". Must comfortably
// exceed the refresh cadence (event-driven + refreshInterval) so a live agent
// never flickers out of the bar between ticks.
const AGENT_CACHE_TTL_MS = 15_000;

// Stale session caches are swept on write; sessions can end without a final
// tick, so nothing else would ever remove them.
const CACHE_SWEEP_MS = 6 * 60 * 60 * 1000;

const cacheFile = (sessionId) =>
  path.join(CACHE_DIR, `${String(sessionId).replace(/[^A-Za-z0-9_-]/g, "")}.json`);

// Persist the aggregate shape only — the bar never needs full task detail.
function writeAgentCache(sessionId, tasks) {
  if (!sessionId) return;
  try {
    fs.mkdirSync(CACHE_DIR, { recursive: true });
    const payload = {
      ts: Date.now(),
      tasks: (tasks || []).map((t) => ({
        id: t.id,
        name: agentName(t),
        status: t.status,
        state: taskState(t),
        tokenCount: Number(t.tokenCount) || 0,
        contextWindowSize: Number(t.contextWindowSize) || 0,
        startMs: startMs(t),
      })),
    };
    fs.writeFileSync(cacheFile(sessionId), JSON.stringify(payload));
    sweepCache();
  } catch {
    /* the bar must never fail because a cache write did */
  }
}

function readAgentCache(sessionId) {
  if (!sessionId) return null;
  try {
    const raw = JSON.parse(fs.readFileSync(cacheFile(sessionId), "utf8"));
    if (!raw || !Array.isArray(raw.tasks)) return null;
    if (Date.now() - Number(raw.ts || 0) > AGENT_CACHE_TTL_MS) return null;
    return raw;
  } catch {
    return null;
  }
}

function sweepCache() {
  try {
    const now = Date.now();
    for (const f of fs.readdirSync(CACHE_DIR)) {
      const p = path.join(CACHE_DIR, f);
      try {
        if (now - fs.statSync(p).mtimeMs > CACHE_SWEEP_MS) fs.unlinkSync(p);
      } catch { /* ignore */ }
    }
  } catch { /* ignore */ }
}

// --- task interpretation ----------------------------------------------------
// `status` is a free-form string from Claude Code; classify defensively so an
// unseen value degrades to "running" (the useful default) instead of vanishing.
const DONE_RE = /^(completed?|done|success(ful)?|succeeded|finished|resolved)$/i;
const FAIL_RE = /^(failed?|error(ed)?|cancell?ed|aborted|killed|stopped|timed?_?out|rejected)$/i;
const WAIT_RE = /^(pending|queued|waiting|created|scheduled|idle)$/i;

function taskState(t) {
  const s = String(t?.status ?? "").trim();
  if (DONE_RE.test(s)) return "done";
  if (FAIL_RE.test(s)) return "failed";
  if (WAIT_RE.test(s)) return "pending";
  return "running";
}

const STATE_ICON = { running: "▶", pending: "⏸", done: "✓", failed: "✗" };
const STATE_COLOR = {
  running: A.brightCyan,
  pending: A.grey,
  done: A.green,
  failed: A.red,
};

// Real payloads carry no `name` — the identity is `type` (the subagent type,
// or "local_agent" for an in-process one). `name` is honoured first anyway in
// case a future build adds it.
function agentName(t) {
  return String(t?.name || t?.type || t?.id || "agent").trim();
}

// tokenSamples is a rolling series of token counts. Rendered as a sparkline it
// shows at a glance whether an agent is still growing or has gone quiet.
const SPARK = "▁▂▃▄▅▆▇█";
function sparkline(samples, width = 12) {
  const xs = (Array.isArray(samples) ? samples : [])
    .map((v) => (typeof v === "number" ? v : Number(v?.tokens ?? v?.value ?? NaN)))
    .filter((v) => Number.isFinite(v))
    .slice(-width);
  if (xs.length < 2) return "";
  const min = Math.min(...xs);
  const max = Math.max(...xs);
  const span = max - min;
  return xs
    .map((v) => SPARK[span <= 0 ? 0 : Math.min(SPARK.length - 1, Math.floor(((v - min) / span) * (SPARK.length - 1)))])
    .join("");
}

// startTime may be epoch ms, epoch seconds, or an ISO string depending on the
// Claude Code build — normalise all three, reject anything implausible.
function startMs(t) {
  const v = t?.startTime;
  if (v == null) return null;
  if (typeof v === "number" && Number.isFinite(v)) {
    return v > 1e12 ? v : v > 1e9 ? v * 1000 : null;
  }
  const p = Date.parse(String(v));
  return Number.isFinite(p) ? p : null;
}

function elapsedSecs(startedMs) {
  if (!Number.isFinite(startedMs)) return null;
  const s = (Date.now() - startedMs) / 1000;
  return s >= 0 ? s : null;
}

// --- agent-row segment registry ---------------------------------------------
// Same shape as the bar registry in segments.js. `line`/`order` order the parts
// within the single row; `joinNext` overrides the " · " separator after a part.
const AGENT_ROW_SEGMENTS = [
  { id: "arow_status", group: "agentrow", label: "Status icon",   description: "▶ running · ⏸ pending · ✓ done · ✗ failed.",           default: true,  line: 1, order: 10, joinNext: " " },
  { id: "arow_name",   group: "agentrow", label: "Agent name",    description: "The sub-agent's name (falls back to its type).",       default: true,  line: 1, order: 20 },
  { id: "arow_desc",   group: "agentrow", label: "Description",   description: "What the agent was asked to do (fixed for its lifetime).", default: true, line: 1, order: 30 },
  { id: "arow_label",  group: "agentrow", label: "Current action",description: "What the agent is doing right now — updates live.",     default: true,  line: 1, order: 35 },
  { id: "arow_model",  group: "agentrow", label: "Model",         description: "Resolved model the agent runs on (opus, sonnet, …).",  default: true,  line: 1, order: 40 },
  { id: "arow_effort", group: "agentrow", label: "Effort level",  description: "Reasoning effort — absent when inherited from you.",   default: true,  line: 1, order: 50 },
  { id: "arow_ctx",    group: "agentrow", label: "Context usage", description: "The agent's own context fill, against its own window.",default: true,  line: 1, order: 60,
    defaultVariant: "pct_num",
    variants: [
      { id: "pct",     label: "% only" },
      { id: "num",     label: "tokens only" },
      { id: "num_max", label: "tokens / max" },
      { id: "pct_num", label: "% + tokens" },
    ] },
  { id: "arow_spark",  group: "agentrow", label: "Token trend",   description: "Sparkline of the agent's recent token growth.",        default: false, line: 1, order: 65 },
  { id: "arow_time",   group: "agentrow", label: "Runtime",       description: "How long the agent has been going.",                   default: true,  line: 1, order: 70 },
  { id: "arow_cwd",    group: "agentrow", label: "Directory",     description: "The agent's working directory — useful across repos.", default: false, line: 1, order: 80 },
];

// The parts that stretch into whatever width is left over on the row.
const ELASTIC = new Set(["arow_desc", "arow_label"]);

// --- one row's parts --------------------------------------------------------
function renderRowSegment(id, t, variant, budget) {
  const state = taskState(t);
  switch (id) {
    case "arow_status":
      return `${STATE_COLOR[state]}${STATE_ICON[state]}${A.reset}`;

    case "arow_name": {
      const n = agentName(t);
      return n ? `${STATE_COLOR[state]}${clip(n, 22)}${A.reset}` : "";
    }

    case "arow_desc": {
      const d = t?.description || "";
      if (!d) return "";
      return `${A.grey}${clip(d, Math.max(8, Math.min(46, budget ?? 46)))}${A.reset}`;
    }

    case "arow_label": {
      // The agent's live activity line — the closest thing to watching it work.
      const l = t?.label || "";
      if (!l) return "";
      return `${A.brightCyan}${clip(l, Math.max(8, Math.min(52, budget ?? 52)))}${A.reset}`;
    }

    case "arow_spark": {
      const s = sparkline(t?.tokenSamples);
      return s ? `${A.grey}${s}${A.reset}` : "";
    }

    case "arow_model": {
      const m = shortModel(t?.model);
      return m ? `${A.magenta}${m}${A.reset}` : "";
    }

    case "arow_effort": {
      const e = t?.effort;
      if (e == null || e === "") return "";
      // Either an effort level string or a numeric token budget.
      const txt = typeof e === "number" ? fmtTokens(e) : String(e);
      return `${A.cyan}${txt}${A.reset}`;
    }

    case "arow_ctx": {
      const tok = Number(t?.tokenCount) || 0;
      const win = Number(t?.contextWindowSize) || 0;
      if (!tok && !win) return "";
      const pct = win > 0 ? Math.round((tok * 1000) / win) / 10 : null;
      const col = pct == null ? A.yellow : pctColor(pct);
      const pctStr = pct == null ? "" : `${col}${pct.toFixed(1)}%${A.reset}`;
      const numStr = `${A.yellow}${fmtTokens(tok)}${A.reset}`;
      const maxStr = `${A.yellow}${fmtTokens(tok)}/${fmtTokens(win)}${A.reset}`;
      switch (variant) {
        case "pct":     return pctStr || numStr;
        case "num":     return numStr;
        case "num_max": return win > 0 ? maxStr : numStr;
        case "pct_num":
        default:        return pctStr ? `${pctStr} ${A.grey}(${fmtTokens(tok)})${A.reset}` : numStr;
      }
    }

    case "arow_time": {
      const s = elapsedSecs(startMs(t));
      return s == null ? "" : `${A.grey}${fmtElapsed(s)}${A.reset}`;
    }

    case "arow_cwd": {
      const c = String(t?.cwd || "").replace(/^\/Users\/[^/]+/, "~");
      if (!c) return "";
      return `${A.blue}${clip(c.split("/").slice(-2).join("/"), 24)}${A.reset}`;
    }

    default:
      return "";
  }
}

// Render one agent-panel row body. `columns` is the usable row width Claude
// Code reports; we stay inside it so nothing wraps into the next row.
function renderAgentRow(enabled, variants, task, columns) {
  enabled = enabled || {};
  variants = variants || {};

  const segs = [...AGENT_ROW_SEGMENTS].sort((a, b) => a.order - b.order);

  // Measure the fixed-width parts first, so the elastic text parts can be given
  // exactly the width that is actually left over — and share it evenly.
  let fixed = 0;
  let elastic = 0;
  for (const s of segs) {
    if (enabled[s.id] === false) continue;
    if (ELASTIC.has(s.id)) {
      if (task?.[s.id === "arow_desc" ? "description" : "label"]) elastic++;
      continue;
    }
    const txt = renderRowSegment(s.id, task, variants[s.id] || s.defaultVariant);
    if (txt) fixed += visibleLength(txt) + 3; // + separator
  }
  const room = Number.isFinite(columns) && columns > 0 ? columns - fixed - 3 : 100;
  const budget = elastic > 0 ? Math.floor(room / elastic) : room;

  const parts = [];
  for (const s of segs) {
    if (enabled[s.id] === false) continue;
    const txt = renderRowSegment(s.id, task, variants[s.id] || s.defaultVariant, budget);
    if (txt) parts.push({ txt, joinNext: s.joinNext });
  }
  if (!parts.length) return "";

  let out = "";
  parts.forEach((p, i) => {
    out += p.txt;
    if (i < parts.length - 1) out += p.joinNext ?? `${A.grey} · ${A.reset}`;
  });

  return Number.isFinite(columns) && columns > 0 ? truncateAnsi(out, columns) : out;
}

// --- the aggregate for the main bar -----------------------------------------
// Reads the cache written by subagent_monitor.js. Returns null when no agents
// are live (or the cache is stale), so the segment renders nothing at all.
function agentSummary(sessionId) {
  const c = readAgentCache(sessionId);
  if (!c || !c.tasks.length) return null;

  const counts = { running: 0, pending: 0, done: 0, failed: 0 };
  let tokens = 0;
  let oldestLive = null;
  let oldestAny = null;

  for (const t of c.tasks) {
    const st = t.state || "running";
    if (counts[st] == null) counts[st] = 0;
    counts[st]++;
    tokens += Number(t.tokenCount) || 0;
    const s = Number(t.startMs);
    if (Number.isFinite(s)) {
      if (oldestAny == null || s < oldestAny) oldestAny = s;
      if ((st === "running" || st === "pending") && (oldestLive == null || s < oldestLive)) oldestLive = s;
    }
  }

  const live = counts.running + counts.pending;
  if (!live && !counts.done && !counts.failed) return null;

  return {
    counts,
    live,
    total: c.tasks.length,
    tokens,
    // The bar shows how long the work has been going: the longest-running live
    // agent, or the whole batch's span once they've all finished.
    elapsedSecs: elapsedSecs(oldestLive ?? oldestAny),
    names: c.tasks.filter((t) => t.state === "running" || t.state === "pending").map((t) => t.name),
  };
}

// The `agents` segment body for the main bar (see segments.js).
function renderAgentSummary(sum, variant) {
  if (!sum) return "";

  const c = sum.counts;
  const countStr = [
    c.running ? `${A.brightCyan}${c.running}▶${A.reset}` : "",
    c.pending ? `${A.grey}${c.pending}⏸${A.reset}` : "",
    c.done    ? `${A.green}${c.done}✓${A.reset}` : "",
    c.failed  ? `${A.red}${c.failed}✗${A.reset}` : "",
  ].filter(Boolean).join(" ");

  const tokenStr = sum.tokens ? `${A.yellow}${fmtTokens(sum.tokens)}${A.reset}` : "";
  const timeStr = sum.elapsedSecs == null ? "" : `${A.grey}${fmtElapsed(sum.elapsedSecs)}${A.reset}`;
  const nameStr = sum.names.length ? `${A.grey}${clip(sum.names.join(", "), 34)}${A.reset}` : "";

  const label = `${A.grey}agents:${A.reset}`;
  const join = (...p) => `${label} ${p.filter(Boolean).join(`${A.grey} · ${A.reset}`)}`;

  switch (variant) {
    case "count":  return join(countStr);
    case "tokens": return join(countStr, tokenStr);
    case "names":  return join(countStr, nameStr);
    case "full":
    default:       return join(countStr, tokenStr, timeStr);
  }
}

// Representative rows so the control panel can preview without a live agent.
function sampleTasks() {
  const now = Date.now();
  return [
    { id: "t1", type: "Explore", status: "running", description: "scan statusline segments", label: "Reading segments.js", model: "claude-opus-5", effort: "xhigh", tokenCount: 24_800, contextWindowSize: 200_000, tokenSamples: [12_000, 14_500, 18_200, 21_000, 24_800], startTime: now - 48_000, cwd: "/Users/gregor/dev/orchestrator" },
    { id: "t2", type: "general-purpose", status: "running", description: "fix the CI deploy gate", label: "Editing deploy.yml", model: "claude-opus-5", effort: "high", tokenCount: 62_000, contextWindowSize: 200_000, tokenSamples: [55_000, 58_400, 59_100, 61_000, 62_000], startTime: now - 191_000, cwd: "/Users/gregor/dev/DevOps" },
    { id: "t3", type: "code-review", status: "completed", description: "review PR 493", label: "Done", model: "claude-sonnet-5", effort: "low", tokenCount: 116_400, contextWindowSize: 200_000, tokenSamples: [110_000, 113_000, 116_400, 116_400], startTime: now - 362_000, cwd: "/Users/gregor/dev/API" },
  ];
}

function sampleSummary() {
  return {
    counts: { running: 2, pending: 0, done: 1, failed: 0 },
    live: 2,
    total: 3,
    tokens: 203_200,
    elapsedSecs: 362,
    names: ["Explore", "general-purpose"],
  };
}

module.exports = {
  AGENT_ROW_SEGMENTS,
  AGENT_CACHE_TTL_MS,
  CACHE_DIR,
  writeAgentCache,
  readAgentCache,
  renderRowSegment,
  renderAgentRow,
  agentSummary,
  renderAgentSummary,
  taskState,
  agentName,
  sampleTasks,
  sampleSummary,
};
