#!/usr/bin/env node
"use strict";

// ============================================================================
// util.js — primitives shared by the status bar (segments.js) and the agent
// panel rows (agents.js): the ANSI palette, the formatters, and the colour
// ramps. Kept in its own module so both renderers stay byte-identical in look
// and neither has to require the other (no import cycle).
// ============================================================================

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

// --- colour ramps -----------------------------------------------------------
// Absolute-token ramp, used by the main bar (its window is the session's).
function ctxColor(used) {
  if (used >= 500_000) return A.red;
  if (used >= 400_000) return A.orange;
  if (used >= 300_000) return A.yellow;
  return A.green;
}
// Percentage ramp — for agent rows, where each agent has its own window size
// and only the fill ratio is comparable between them.
function pctColor(p) {
  if (p >= 90) return A.red;
  if (p >= 75) return A.orange;
  if (p >= 50) return A.yellow;
  return A.green;
}
function limitColor(p) {
  return pctColor(p);
}

// --- formatters -------------------------------------------------------------
function fmtDur(sec) {
  if (!Number.isFinite(sec) || sec <= 0) return "now";
  const totalMin = Math.ceil(sec / 60);
  const h = Math.floor(totalMin / 60);
  const m = totalMin % 60;
  return h > 0 ? `${h}h${String(m).padStart(2, "0")}m` : `${m}m`;
}

// Short elapsed time for agent rows: seconds matter while an agent is young,
// so this stays at m:ss until the hour mark instead of rounding up to minutes.
function fmtElapsed(sec) {
  if (!Number.isFinite(sec) || sec < 0) return "";
  const s = Math.floor(sec);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const ss = s % 60;
  if (h > 0) return `${h}h${String(m).padStart(2, "0")}m`;
  return `${m}m${String(ss).padStart(2, "0")}s`;
}

const comma = (n) =>
  new Intl.NumberFormat("en-US").format(Math.max(0, Math.floor(Number(n) || 0)));

// Compact token count for the narrow agent rows: 25k, 203k, 1.2M.
function fmtTokens(n) {
  const v = Math.max(0, Math.floor(Number(n) || 0));
  if (v >= 1_000_000) return `${(v / 1_000_000).toFixed(1)}M`;
  if (v >= 1_000) return `${Math.round(v / 1000)}k`;
  return String(v);
}

// Sum of every token bucket that occupies the context window.
function usedTotal(u) {
  return (
    (u?.input_tokens ?? 0) +
    (u?.output_tokens ?? 0) +
    (u?.cache_read_input_tokens ?? 0) +
    (u?.cache_creation_input_tokens ?? 0)
  );
}

// "claude-opus-5" / "claude-haiku-4-5-20251001" -> "opus" / "haiku".
// Anything unrecognised is passed through untouched rather than mangled.
function shortModel(id) {
  const s = String(id || "").trim();
  if (!s) return "";
  const m = s.replace(/^claude[-.]/i, "").match(/^([a-z]+)/i);
  return m ? m[1].toLowerCase() : s;
}

// --- width-aware helpers ----------------------------------------------------
const ANSI_RE = /\x1b\[[0-9;]*m/g;
const visibleLength = (s) => String(s).replace(ANSI_RE, "").length;

// Truncate to `max` VISIBLE columns, keeping ANSI codes intact and always
// closing colour state so a clipped row can't bleed into the rest of the UI.
function truncateAnsi(s, max) {
  const str = String(s);
  if (!Number.isFinite(max) || max <= 0 || visibleLength(str) <= max) return str;
  let out = "";
  let vis = 0;
  let i = 0;
  ANSI_RE.lastIndex = 0;
  while (i < str.length) {
    if (str[i] === "\x1b") {
      const m = /^\x1b\[[0-9;]*m/.exec(str.slice(i));
      if (m) {
        out += m[0];
        i += m[0].length;
        continue;
      }
    }
    if (vis >= max - 1) break;
    out += str[i];
    vis++;
    i++;
  }
  return out + "…" + A.reset;
}

// Clip a plain string to `max` characters on a word-ish boundary.
function clip(s, max) {
  const str = String(s ?? "").replace(/\s+/g, " ").trim();
  if (!Number.isFinite(max) || max <= 0 || str.length <= max) return str;
  return str.slice(0, Math.max(1, max - 1)).trimEnd() + "…";
}

module.exports = {
  A,
  ctxColor,
  pctColor,
  limitColor,
  fmtDur,
  fmtElapsed,
  comma,
  fmtTokens,
  usedTotal,
  shortModel,
  visibleLength,
  truncateAnsi,
  clip,
};
