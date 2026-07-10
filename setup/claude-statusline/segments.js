#!/usr/bin/env node
"use strict";

// ============================================================================
// segments.js — the STATUSLINE SEGMENT REGISTRY (single source of truth).
//
// Everything the statusline can show is one entry in SEGMENTS below. The
// control panel (server.js) reads this list to render its checkboxes, and
// ctx_monitor.js reads it to render the actual bar. To add a new segment:
//   1. add an entry to SEGMENTS (id, label, description, default, line, order)
//   2. add a `render` case in renderSegment() and a sample in sampleContext()
// Existing user configs that predate the new segment simply don't mention it,
// so it falls through to its registry `default` — old configs keep working and
// nothing is destroyed. See config.js for the merge rules.
// ============================================================================

const fs = require("fs");
const { execFileSync } = require("child_process");

// --- ANSI palette -----------------------------------------------------------
const A = {
  reset: "\x1b[0m",
  magenta: "\x1b[95m",
  cyan: "\x1b[96m",
  red: "\x1b[31m",
  blue: "\x1b[34m",
  brightCyan: "\x1b[36m",
  grey: "\x1b[90m",
  yellow: "\x1b[33m",
  green: "\x1b[32m",
  orange: "\x1b[38;5;208m",
};

// --- Segment registry -------------------------------------------------------
// `line` groups segments onto output line 1 or 2; `order` sorts within a line.
// `default` is the value used when a config never mentions the segment.
const SEGMENTS = [
  { id: "model",   label: "Model name",          description: "The active model (e.g. Opus).",                         default: true,  line: 1, order: 10 },
  { id: "effort",  label: "Effort level",        description: "Reasoning effort from settings.json (if set).",         default: true,  line: 1, order: 20 },
  { id: "context", label: "Context-window usage",description: "% of the context window used + token count.",           default: true,  line: 1, order: 30 },
  { id: "cost",    label: "Session cost ($)",    description: "Total USD spent this session.",                          default: true,  line: 1, order: 40 },
  { id: "limit",   label: "5h session limit",    description: "Pro/Max 5h-window quota % + time to reset.",             default: true,  line: 1, order: 50 },
  { id: "session", label: "Session id",          description: "The Claude Code session UUID.",                          default: true,  line: 2, order: 10 },
  { id: "cwd",     label: "Working directory",   description: "Current working directory (home-relative).",             default: true,  line: 2, order: 20 },
  { id: "branch",  label: "Git branch",          description: "Current branch of the repo in the working directory.",    default: true,  line: 2, order: 30 },
  { id: "uptime",  label: "Session uptime",      description: "Elapsed time since this session started.",                default: true,  line: 2, order: 40 },
];

// ============================================================================
// buildContext(input) — turn the raw stdin JSON Claude Code passes into the
// computed values every segment needs. All the heavy lifting (transcript
// parsing, effort lookup, formatting) lives here so renderSegment() is trivial.
// ============================================================================
function buildContext(input) {
  input = input || {};
  const model = input.model || {};
  const name = String(model.display_name ?? "").trim();

  let effort = "";
  try {
    const s = JSON.parse(fs.readFileSync(`${process.env.HOME}/.claude/settings.json`, "utf8"));
    effort = s.effortLevel ? String(s.effortLevel) : "";
  } catch { /* ignore */ }

  const CONTEXT_WINDOW = Number(input.context_window?.context_window_size) || 200_000;
  const costUsd = Number(input.cost?.total_cost_usd) || 0;

  const cwdRaw = String(input.cwd ?? input.workspace?.current_dir ?? "").replace(/^\/Users\/gregor/, "");
  const slash = cwdRaw.lastIndexOf("/");
  const cwdParent = slash >= 0 ? cwdRaw.slice(0, slash + 1) : "";
  const cwdBase = slash >= 0 ? cwdRaw.slice(slash + 1) : cwdRaw;

  const scan = scanTranscript(input.transcript_path);
  const usage = scan.usage;
  const used = usedTotal(usage);
  const pct = CONTEXT_WINDOW > 0 ? Math.round((used * 1000) / CONTEXT_WINDOW) / 10 : 0;

  const fh = input.rate_limits?.five_hour;
  const limit = fh && fh.resets_at != null
    ? { pct: Math.round(Number(fh.used_percentage) || 0), secs: Number(fh.resets_at) - nowSecs() }
    : null;

  // Elapsed since the session's first transcript entry.
  const uptimeSecs = Number.isFinite(scan.firstTs) ? Math.floor(Date.now() / 1000) - Math.floor(scan.firstTs / 1000) : null;

  const cwdAbs = String(input.cwd ?? input.workspace?.current_dir ?? "");
  const branch = gitBranch(cwdAbs);

  return {
    sessionId: String(input.session_id ?? ""),
    name, effort, CONTEXT_WINDOW, costUsd,
    cwdParent, cwdBase,
    usage, used, pct, limit,
    uptimeSecs, branch,
  };
}

// ============================================================================
// renderSegment(id, ctx) — the ANSI string for one segment, or "" to omit it.
// A segment renders "" when it has nothing to show (e.g. limit before the first
// API response); the renderer then skips it and collapses the separators.
// ============================================================================
function renderSegment(id, ctx) {
  switch (id) {
    case "model":
      return ctx.name ? `${A.magenta}${ctx.name}${A.reset}` : "";
    case "effort":
      return ctx.effort ? `effort: ${A.cyan}${ctx.effort}${A.reset}` : "";
    case "context":
      if (!ctx.usage) return `${A.brightCyan}context window usage starts after your first question.${A.reset}`;
      return `${ctxColor(ctx.used)}context used ${ctx.pct.toFixed(1)}%${A.reset} - ` +
             `${A.yellow}(${comma(ctx.used)}/${comma(ctx.CONTEXT_WINDOW)})${A.reset}`;
    case "cost":
      return `cost: ${A.red}$${ctx.costUsd.toFixed(2)}${A.reset}`;
    case "limit":
      if (!ctx.limit) return "";
      return `${limitColor(ctx.limit.pct)}${ctx.limit.pct}%${A.reset} ` +
             `${A.grey}· resets in ${fmtDur(ctx.limit.secs)}${A.reset}`;
    case "session":
      return `session: ${A.grey}${ctx.sessionId}${A.reset}`;
    case "cwd":
      return `cwd: ${A.blue}${ctx.cwdParent}${A.brightCyan}${ctx.cwdBase}${A.reset}`;
    case "uptime":
      return ctx.uptimeSecs == null ? "" : `up: ${A.grey}${fmtDur(ctx.uptimeSecs)}${A.reset}`;
    case "branch":
      return ctx.branch ? `${A.green}⎇ ${ctx.branch}${A.reset}` : "";
    default:
      return "";
  }
}

// ============================================================================
// sampleContext() — representative values so the control panel can render a
// realistic preview of the bar without a live session.
// ============================================================================
function sampleContext() {
  return {
    sessionId: "3f9c1a2b-1234-5678-9abc-def012345678",
    name: "Opus",
    effort: "high",
    CONTEXT_WINDOW: 200_000,
    costUsd: 0.42,
    cwdParent: "/dev/922/",
    cwdBase: "orchestrator",
    usage: {}, used: 63_500, pct: 31.8,
    limit: { pct: 47, secs: 2 * 3600 + 12 * 60 },
    uptimeSecs: 1 * 3600 + 47 * 60,
    branch: "feat/statusline-panel",
  };
}

// --- render the full bar from an effective-enabled map ----------------------
function renderBar(enabled, ctx) {
  const byLine = {};
  for (const seg of [...SEGMENTS].sort((a, b) => a.line - b.line || a.order - b.order)) {
    if (enabled[seg.id] === false) continue;
    const s = renderSegment(seg.id, ctx);
    if (!s) continue;
    (byLine[seg.line] ??= []).push(s);
  }
  return Object.keys(byLine)
    .sort((a, b) => Number(a) - Number(b))
    .map((l) => byLine[l].join(" | "))
    .filter(Boolean)
    .join("\n");
}

// --- helpers ----------------------------------------------------------------
function nowSecs() {
  return Math.floor(Date.now() / 1000);
}
function ctxColor(used) {
  if (used >= 500_000) return A.red;
  if (used >= 400_000) return A.orange;
  if (used >= 300_000) return A.yellow;
  return A.green;
}
function limitColor(p) {
  if (p >= 90) return A.red;
  if (p >= 75) return A.orange;
  if (p >= 50) return A.yellow;
  return A.green;
}
function fmtDur(sec) {
  if (!Number.isFinite(sec) || sec <= 0) return "now";
  const totalMin = Math.ceil(sec / 60);
  const h = Math.floor(totalMin / 60);
  const m = totalMin % 60;
  return h > 0 ? `${h}h${String(m).padStart(2, "0")}m` : `${m}m`;
}
const comma = (n) =>
  new Intl.NumberFormat("en-US").format(Math.max(0, Math.floor(Number(n) || 0)));

function usedTotal(u) {
  return (
    (u?.input_tokens ?? 0) +
    (u?.output_tokens ?? 0) +
    (u?.cache_read_input_tokens ?? 0) +
    (u?.cache_creation_input_tokens ?? 0)
  );
}

// One read of the transcript → { usage, firstTs }:
//  - usage : newest main-context assistant usage by timestamp (skips
//    sidechains, synthetic messages, api errors, "no response requested").
//  - firstTs: earliest timestamp of any entry (session start), in ms.
function scanTranscript(transcript) {
  const out = { usage: null, firstTs: Infinity };
  if (!transcript) return out;
  let lines;
  try {
    lines = fs.readFileSync(transcript, "utf8").split(/\r?\n/);
  } catch {
    return out;
  }
  let latestTs = -Infinity;
  for (let i = lines.length - 1; i >= 0; i--) {
    const line = lines[i].trim();
    if (!line) continue;
    let j;
    try {
      j = JSON.parse(line);
    } catch {
      continue;
    }
    const ts = Date.parse(j?.timestamp);
    const t = Number.isFinite(ts) ? ts : -Infinity;
    if (Number.isFinite(ts) && ts < out.firstTs) out.firstTs = ts;

    const u = j.message?.usage;
    const synthetic = /synthetic/.test(String(j?.message?.model ?? "").toLowerCase());
    const noResp =
      Array.isArray(j?.message?.content) &&
      j.message.content.some((x) => x?.type === "text" && /no\s+response\s+requested/i.test(String(x.text)));
    if (
      j.isSidechain === true ||
      synthetic ||
      j.isApiErrorMessage === true ||
      usedTotal(u) === 0 ||
      noResp ||
      j?.message?.role !== "assistant"
    )
      continue;
    if (t > latestTs) {
      latestTs = t;
      out.usage = u;
    } else if (t === latestTs && usedTotal(u) > usedTotal(out.usage)) {
      out.usage = u;
    }
  }
  return out;
}

// Current branch of the repo at `dir`, or "" if not a repo / detached / error.
// Cheap enough to run per render; hard-capped so a slow FS can't stall the bar.
function gitBranch(dir) {
  if (!dir) return "";
  try {
    const b = execFileSync("git", ["-C", dir, "symbolic-ref", "--quiet", "--short", "HEAD"], {
      timeout: 250,
      stdio: ["ignore", "pipe", "ignore"],
      encoding: "utf8",
    }).trim();
    return b;
  } catch {
    return ""; // not a repo, or detached HEAD
  }
}

module.exports = { SEGMENTS, buildContext, renderSegment, sampleContext, renderBar };
