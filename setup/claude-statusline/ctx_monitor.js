#!/usr/bin/env node
"use strict";

const fs = require("fs");

// --- input ---
const input = readJSON(0); // stdin
const sessionId = `\x1b[90m${String(input.session_id ?? "")}\x1b[0m`;
const transcript = input.transcript_path;
const model = input.model || {};
const name = `\x1b[95m${String(model.display_name ?? "")}\x1b[0m`.trim();
const effort = (() => {
  try {
    const s = JSON.parse(fs.readFileSync(`${process.env.HOME}/.claude/settings.json`, "utf8"));
    return s.effortLevel ? `\x1b[96m${s.effortLevel}\x1b[0m` : "";
  } catch {
    return "";
  }
})();
const effortLabel = effort ? ` | effort: ${effort}` : "";

// Prefer the actual window size Claude Code reports for the active model
// (varies per model, e.g. 200K vs 1M); fall back to a 200K guess if absent.
const CONTEXT_WINDOW = Number(input.context_window?.context_window_size) || 200_000;
const costUsd = `\x1b[31m$${(Number(input.cost?.total_cost_usd) || 0).toFixed(2)}\x1b[0m`;
const _cwdRaw = String(input.cwd ?? input.workspace?.current_dir ?? "")
  .replace(/^\/Users\/gregor/, "");
const _cwdSlash = _cwdRaw.lastIndexOf("/");
const _cwdParent = _cwdSlash >= 0 ? _cwdRaw.slice(0, _cwdSlash + 1) : "";
const _cwdBase   = _cwdSlash >= 0 ? _cwdRaw.slice(_cwdSlash + 1)    : _cwdRaw;
const cwd = `\x1b[34m${_cwdParent}\x1b[36m${_cwdBase}\x1b[0m`;

// --- helpers ---
function readJSON(fd) {
  try {
    return JSON.parse(fs.readFileSync(fd, "utf8"));
  } catch {
    return {};
  }
}
// Color by absolute tokens used (model quality degrades with absolute
// context, independent of the nominal window size).
function color(used) {
  if (used >= 500_000) return "\x1b[31m"; // red
  if (used >= 400_000) return "\x1b[38;5;208m"; // orange
  if (used >= 300_000) return "\x1b[33m"; // yellow
  return "\x1b[32m"; // green
}
// Color the session-limit % by how much of the 5h quota is consumed.
function limitColor(p) {
  if (p >= 90) return "\x1b[31m"; // red
  if (p >= 75) return "\x1b[38;5;208m"; // orange
  if (p >= 50) return "\x1b[33m"; // yellow
  return "\x1b[32m"; // green
}
// "1h04m" / "12m" from a seconds-until value.
function fmtDur(sec) {
  if (!Number.isFinite(sec) || sec <= 0) return "now";
  const totalMin = Math.ceil(sec / 60);
  const h = Math.floor(totalMin / 60);
  const m = totalMin % 60;
  return h > 0 ? `${h}h${String(m).padStart(2, "0")}m` : `${m}m`;
}
// Build the "5h limit N% · resets in Xh Ym" label from rate_limits.five_hour.
// The rate_limits block only appears for Pro/Max after the first API response,
// and each window may be independently absent — so degrade to "" silently.
function sessionLimitLabel() {
  const fh = input.rate_limits?.five_hour;
  if (!fh || fh.resets_at == null) return "";
  const pct = Math.round(Number(fh.used_percentage) || 0);
  const secs = Number(fh.resets_at) - Math.floor(Date.now() / 1000);
  const c = limitColor(pct);
  return `${c}5h limit ${pct}%\x1b[0m \x1b[90m· resets in ${fmtDur(secs)}\x1b[0m`;
}
const limitLabel = sessionLimitLabel();
const limitSuffix = limitLabel ? ` | ${limitLabel}` : "";

const comma = (n) =>
  new Intl.NumberFormat("en-US").format(
    Math.max(0, Math.floor(Number(n) || 0))
  );

function usedTotal(u) {
  return (
    (u?.input_tokens ?? 0) +
    (u?.output_tokens ?? 0) +
    (u?.cache_read_input_tokens ?? 0) +
    (u?.cache_creation_input_tokens ?? 0)
  );
}

function syntheticModel(j) {
  const m = String(j?.message?.model ?? "").toLowerCase();
  return m === "<synthetic>" || m.includes("synthetic");
}

function assistantMessage(j) {
  return j?.message?.role === "assistant";
}

function subContext(j) {
  return j?.isSidechain === true;
}

function contentNoResponse(j) {
  const c = j?.message?.content;
  return (
    Array.isArray(c) &&
    c.some(
      (x) =>
        x &&
        x.type === "text" &&
        /no\s+response\s+requested/i.test(String(x.text))
    )
  );
}

function parseTs(j) {
  const t = j?.timestamp;
  const n = Date.parse(t);
  return Number.isFinite(n) ? n : -Infinity;
}

// Find the newest main-context entry by timestamp (not file order)
function newestMainUsageByTimestamp() {
  if (!transcript) return null;
  let latestTs = -Infinity;
  let latestUsage = null;

  let lines;
  try {
    lines = fs.readFileSync(transcript, "utf8").split(/\r?\n/);
  } catch {
    return null;
  }

  for (let i = lines.length - 1; i >= 0; i--) {
    const line = lines[i].trim();
    if (!line) continue;

    let j;
    try {
      j = JSON.parse(line);
    } catch {
      continue;
    }
    const u = j.message?.usage;
    if (
      subContext(j) ||
      syntheticModel(j) ||
      j.isApiErrorMessage === true ||
      usedTotal(u) === 0 ||
      contentNoResponse(j) ||
      !assistantMessage(j)
    )
      continue;

    const ts = parseTs(j);
    if (ts > latestTs) {
      latestTs = ts;
      latestUsage = u;
    }
    else if (ts == latestTs && usedTotal(u) > usedTotal(latestUsage)) {
      latestUsage = u;
    }
  }
  return latestUsage;
}

// --- compute/print ---
const usage = newestMainUsageByTimestamp();
if (!usage) {
  console.log(
    `${name}${effortLabel} | \x1b[36mcontext window usage starts after your first question.\x1b[0m | cost: ${costUsd}${limitSuffix}\nsession: ${sessionId} | cwd: ${cwd}`
  );
  process.exit(0);
}

const used = usedTotal(usage);
const pct = CONTEXT_WINDOW > 0 ? Math.round((used * 1000) / CONTEXT_WINDOW) / 10 : 0;

const usagePercentLabel = `${color(used)}context used ${pct.toFixed(1)}%\x1b[0m`;
const usageCountLabel = `\x1b[33m(${comma(used)}/${comma(
  CONTEXT_WINDOW
)})\x1b[0m`;

console.log(
  `${name}${effortLabel} | ${usagePercentLabel} - ${usageCountLabel} | cost: ${costUsd}${limitSuffix}\nsession: ${sessionId} | cwd: ${cwd}`
);
