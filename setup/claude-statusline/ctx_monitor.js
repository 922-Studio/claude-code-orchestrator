#!/usr/bin/env node
"use strict";

// ============================================================================
// ctx_monitor.js — Claude Code statusline entry point.
//
// Reads the JSON Claude Code passes on stdin, resolves which segments are
// enabled for the current working directory (config.js), and prints the bar
// (segments.js). Segment definitions and per-directory enable/disable live in
// their own modules; this file is just the glue. Edit toggles with the control
// panel (server.js) — this script re-reads the config on every render, so a
// saved change shows up on the next turn with no restart.
// ============================================================================

const fs = require("fs");
const { buildContext, renderBar } = require("./segments");
const { loadEffectiveConfig } = require("./config");

let input = {};
try {
  input = JSON.parse(fs.readFileSync(0, "utf8"));
} catch {
  input = {};
}

const cwd = String(input.cwd ?? input.workspace?.current_dir ?? "");
const { enabled, variants } = loadEffectiveConfig(cwd);
const ctx = buildContext(input);

const bar = renderBar(enabled, variants, ctx);
if (bar) console.log(bar);
