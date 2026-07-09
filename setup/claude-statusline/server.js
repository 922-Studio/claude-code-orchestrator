#!/usr/bin/env node
"use strict";

// ============================================================================
// server.js — local control panel for the statusline.
//
//   node ~/.claude/statusline/server.js         # then open the printed URL
//
// Zero dependencies. Serves panel.html and a small JSON API the page uses to
// read the segment registry + current config and to apply changes. "Apply"
// writes segments.config.json AND runs the real renderer with sample data,
// returning the rendered bar so you can see exactly what the change produces.
// The config is per-directory; ctx_monitor.js picks it up on the next render.
// ============================================================================

const http = require("http");
const fs = require("fs");
const path = require("path");
const { SEGMENTS, sampleContext, renderSegment, renderBar } = require("./segments");
const {
  CONFIG_PATH,
  loadConfig,
  loadEffectiveConfig,
  registryDefaults,
  applyOverride,
  clearDirectory,
} = require("./config");

const PORT = Number(process.env.STATUSLINE_PANEL_PORT) || 4790;
const PANEL = path.join(__dirname, "panel.html");

// --- ANSI (subset we emit) -> HTML ------------------------------------------
const ANSI_COLORS = {
  "95": "#c586e6", // magenta
  "96": "#4ec9d4", // cyan
  "31": "#e05561", // red
  "34": "#4a9eff", // blue
  "36": "#37d5d5", // bright cyan
  "90": "#8a8a8a", // grey
  "33": "#e0c000", // yellow
  "32": "#3fb950", // green
  "38;5;208": "#ff8a34", // orange
};
function ansiToHtml(str) {
  let out = "";
  let open = false;
  const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  const re = /\x1b\[([0-9;]*)m/g;
  let last = 0;
  let m;
  while ((m = re.exec(str))) {
    out += esc(str.slice(last, m.index));
    last = re.lastIndex;
    const code = m[1];
    if (code === "0" || code === "") {
      if (open) { out += "</span>"; open = false; }
    } else if (ANSI_COLORS[code]) {
      if (open) out += "</span>";
      out += `<span style="color:${ANSI_COLORS[code]}">`;
      open = true;
    }
  }
  out += esc(str.slice(last));
  if (open) out += "</span>";
  return out;
}

// --- state payload the panel consumes ---------------------------------------
function statePayload() {
  const sample = sampleContext();
  return {
    configPath: CONFIG_PATH,
    registryDefaults: registryDefaults(),
    config: loadConfig(),
    segments: SEGMENTS.map((s) => ({
      id: s.id,
      label: s.label,
      description: s.description,
      default: s.default,
      line: s.line,
      order: s.order,
      // per-segment sample so the panel can show/hide without a round-trip
      sampleHtml: ansiToHtml(renderSegment(s.id, sample)),
    })),
  };
}

function renderPreview(enabledMap) {
  return ansiToHtml(renderBar(enabledMap, sampleContext()));
}

// --- http -------------------------------------------------------------------
function send(res, code, body, type = "application/json") {
  res.writeHead(code, { "Content-Type": type, "Cache-Control": "no-store" });
  res.end(typeof body === "string" ? body : JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve) => {
    let data = "";
    req.on("data", (c) => (data += c));
    req.on("end", () => {
      try { resolve(JSON.parse(data || "{}")); } catch { resolve({}); }
    });
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, "http://localhost");
  try {
    if (req.method === "GET" && url.pathname === "/") {
      return send(res, 200, fs.readFileSync(PANEL, "utf8"), "text/html; charset=utf-8");
    }
    if (req.method === "GET" && url.pathname === "/api/state") {
      const dir = url.searchParams.get("dir") || "";
      const p = statePayload();
      p.dir = dir;
      p.effective = dir ? loadEffectiveConfig(dir) : registryDefaults();
      return send(res, 200, p);
    }
    if (req.method === "POST" && url.pathname === "/api/apply") {
      const body = await readBody(req);
      const scope = body.scope === "defaults" ? "defaults" : String(body.dir || "").trim();
      if (!scope) return send(res, 400, { ok: false, error: "missing dir/scope" });
      const cfg = applyOverride(scope, body.overrides || {});
      const eff = scope === "defaults" ? { ...registryDefaults(), ...cfg.defaults } : loadEffectiveConfig(scope);
      return send(res, 200, { ok: true, config: cfg, effective: eff, previewHtml: renderPreview(eff) });
    }
    if (req.method === "POST" && url.pathname === "/api/reset") {
      const body = await readBody(req);
      const scope = body.scope === "defaults" ? "defaults" : String(body.dir || "").trim();
      if (!scope) return send(res, 400, { ok: false, error: "missing dir/scope" });
      const cfg = clearDirectory(scope);
      const eff = scope === "defaults" ? registryDefaults() : loadEffectiveConfig(scope);
      return send(res, 200, { ok: true, config: cfg, effective: eff, previewHtml: renderPreview(eff) });
    }
    return send(res, 404, { ok: false, error: "not found" });
  } catch (e) {
    return send(res, 500, { ok: false, error: String(e && e.message || e) });
  }
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`Statusline control panel:  http://127.0.0.1:${PORT}`);
  console.log(`Config file:               ${CONFIG_PATH}`);
  console.log(`Stop with Ctrl-C.`);
});
