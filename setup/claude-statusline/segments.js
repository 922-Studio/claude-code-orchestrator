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
// A segment may also declare `variants` (a list of {id,label}) + `defaultVariant`
// to offer display modes (e.g. context: % vs number vs number/max). renderSegment
// receives the chosen variant id.
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
  { id: "context", label: "Context-window usage",description: "How much of the context window is used.",              default: true,  line: 1, order: 30,
    defaultVariant: "pct_num_max",
    variants: [
      { id: "pct",         label: "% only" },
      { id: "num",         label: "number only" },
      { id: "num_max",     label: "number / max" },
      { id: "pct_num",     label: "% + number" },
      { id: "pct_num_max", label: "% + number + max" },
    ] },
  { id: "cost",    label: "Session cost ($)",    description: "Total USD spent this session.",                          default: true,  line: 1, order: 40 },
  { id: "limit",   label: "5h session limit",    description: "Pro/Max 5h-window quota % + time to reset.",             default: true,  line: 1, order: 50 },
  { id: "versions",label: "Versions (cc + orch)",description: "Claude Code version + orchestrator version.txt.",         default: true,  line: 2, order: 5 },
  { id: "session", label: "Session id",          description: "The Claude Code session UUID.",                          default: true,  line: 2, order: 10 },
  { id: "cwd",     label: "Working directory",   description: "Current working directory (home-relative).",             default: true,  line: 2, order: 20 },
  { id: "branch",  label: "Git branch",          description: "Current branch of the repo in the working directory.",    default: true,  line: 2, order: 30 },
  { id: "uptime",  label: "Session uptime",      description: "Wall-clock time since this session started.",             default: true,  line: 2, order: 40 },
  { id: "active",  label: "Active time",         description: "Time actually worked in-session (idle gaps >5m excluded).",default: true,  line: 2, order: 50 },
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

  // Elapsed since the session's first transcript entry (wall clock).
  const uptimeSecs = Number.isFinite(scan.firstTs) ? Math.floor(Date.now() / 1000) - Math.floor(scan.firstTs / 1000) : null;
  // Active engagement: sum of inter-entry gaps, excluding idle stretches.
  const activeSecs = scan.activeSecs;

  const cwdAbs = String(input.cwd ?? input.workspace?.current_dir ?? "");
  const branch = gitBranch(cwdAbs);

  const ccVersion = String(input.version ?? "").trim();
  const orchVersion = readOrchVersion();

  return {
    sessionId: String(input.session_id ?? ""),
    name, effort, CONTEXT_WINDOW, costUsd,
    cwdParent, cwdBase,
    usage, used, pct, limit,
    uptimeSecs, activeSecs, branch,
    ccVersion, orchVersion,
  };
}

// ============================================================================
// renderSegment(id, ctx, variant) — the ANSI string for one segment, or "" to
// omit it. `variant` is the chosen display mode id for segments that declare
// `variants` (ignored otherwise). A segment renders "" when it has nothing to
// show (e.g. limit before the first API response); the renderer then skips it
// and collapses the separators.
// ============================================================================
function renderSegment(id, ctx, variant) {
  switch (id) {
    case "model":
      return ctx.name ? `${A.magenta}${ctx.name}${A.reset}` : "";
    case "effort":
      return ctx.effort ? `effort: ${A.cyan}${ctx.effort}${A.reset}` : "";
    case "context": {
      if (!ctx.usage) return `${A.brightCyan}context window usage starts after your first question.${A.reset}`;
      const pct = `${ctxColor(ctx.used)}context used ${ctx.pct.toFixed(1)}%${A.reset}`;
      const num = `${A.yellow}(${comma(ctx.used)})${A.reset}`;
      const numMax = `${A.yellow}(${comma(ctx.used)}/${comma(ctx.CONTEXT_WINDOW)})${A.reset}`;
      switch (variant) {
        case "pct":     return pct;
        case "num":     return num;
        case "num_max": return numMax;
        case "pct_num": return `${pct} - ${num}`;
        case "pct_num_max":
        default:        return `${pct} - ${numMax}`;
      }
    }
    case "cost":
      return `cost: ${A.red}$${ctx.costUsd.toFixed(2)}${A.reset}`;
    case "limit":
      if (!ctx.limit) return "";
      return `${limitColor(ctx.limit.pct)}${ctx.limit.pct}%${A.reset} ` +
             `${A.grey}· resets in ${fmtDur(ctx.limit.secs)}${A.reset}`;
    case "versions": {
      const parts = [];
      if (ctx.ccVersion) parts.push(`cc: ${ctx.ccVersion}`);
      if (ctx.orchVersion) parts.push(`orch: ${ctx.orchVersion}`);
      return parts.length ? `${A.grey}${parts.join(", ")}${A.reset}` : "";
    }
    case "session":
      return `session: ${A.grey}${ctx.sessionId}${A.reset}`;
    case "cwd":
      return `cwd: ${A.blue}${ctx.cwdParent}${A.brightCyan}${ctx.cwdBase}${A.reset}`;
    case "uptime":
      return ctx.uptimeSecs == null ? "" : `up: ${A.grey}${fmtDur(ctx.uptimeSecs)}${A.reset}`;
    case "active":
      return ctx.activeSecs == null ? "" : `active: ${A.grey}${fmtDur(ctx.activeSecs)}${A.reset}`;
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
    activeSecs: 58 * 60,
    branch: "feat/statusline-panel",
    ccVersion: "2.1.205",
    orchVersion: "1.0.7",
  };
}

// --- render the full bar from effective enable + variant maps ---------------
function renderBar(enabled, variants, ctx) {
  variants = variants || {};
  const byLine = {};
  for (const seg of [...SEGMENTS].sort((a, b) => a.line - b.line || a.order - b.order)) {
    if (enabled[seg.id] === false) continue;
    const variant = variants[seg.id] || seg.defaultVariant;
    const s = renderSegment(seg.id, ctx, variant);
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
// The orchestrator's live version.txt. apply.sh writes the repo root path to
// ~/.claude/statusline/orch-root at install/provision time; we read version.txt
// fresh on every render so it always reflects the checked-out version. Returns
// "" if the pointer or file is missing (non-orchestrator machine).
function readOrchVersion() {
  try {
    const root = fs.readFileSync(`${process.env.HOME}/.claude/statusline/orch-root`, "utf8").trim();
    if (!root) return "";
    return fs.readFileSync(`${root}/version.txt`, "utf8").trim();
  } catch {
    return "";
  }
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

// Gaps longer than this (seconds) between consecutive transcript entries count
// as idle (you stepped away) and are excluded from "active" time.
const ACTIVE_IDLE_GAP = 300;

// One read of the transcript → { usage, firstTs, activeSecs }:
//  - usage : newest main-context assistant usage by timestamp (skips
//    sidechains, synthetic messages, api errors, "no response requested").
//  - firstTs: earliest timestamp of any entry (session start), in ms.
//  - activeSecs: sum of inter-entry gaps ≤ ACTIVE_IDLE_GAP (engaged time), or
//    null if the transcript has no usable timestamps.
function scanTranscript(transcript) {
  const out = { usage: null, firstTs: Infinity, activeSecs: null };
  if (!transcript) return out;
  let lines;
  try {
    lines = fs.readFileSync(transcript, "utf8").split(/\r?\n/);
  } catch {
    return out;
  }
  let latestTs = -Infinity;
  const stamps = [];
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
    if (Number.isFinite(ts)) {
      if (ts < out.firstTs) out.firstTs = ts;
      stamps.push(ts);
    }

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
  if (stamps.length >= 2) {
    stamps.sort((a, b) => a - b);
    let active = 0;
    for (let k = 1; k < stamps.length; k++) {
      const gap = (stamps[k] - stamps[k - 1]) / 1000;
      if (gap > 0 && gap <= ACTIVE_IDLE_GAP) active += gap;
    }
    out.activeSecs = Math.round(active);
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
