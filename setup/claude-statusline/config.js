#!/usr/bin/env node
"use strict";

// ============================================================================
// config.js — load / merge / save the per-directory statusline config.
//
// File shape (segments.config.json):
//   {
//     "version": 1,
//     "defaults":    { "<segId>": true|false, ... },   // global overrides
//     "directories": { "<abs-dir>": { "<segId>": true|false, ... }, ... }
//   }
//
// EFFECTIVE value for a segment in a given cwd, most→least specific:
//   directory override  ??  global default override  ??  registry default
// A segment missing at every level falls through to its registry `default`,
// so NEW segments light up automatically for every pre-existing config and
// nothing old is destroyed. Directory match is longest-prefix, so setting a
// parent dir cascades to its children unless a child overrides.
// ============================================================================

const fs = require("fs");
const path = require("path");
const { SEGMENTS } = require("./segments");

const CONFIG_PATH =
  process.env.CLAUDE_STATUSLINE_CONFIG ||
  `${process.env.HOME}/.claude/statusline/segments.config.json`;

const CURRENT_VERSION = 1;

function registryDefaults() {
  const m = {};
  for (const s of SEGMENTS) m[s.id] = s.default;
  return m;
}

function readRaw() {
  try {
    return JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
  } catch {
    return null;
  }
}

// Bring any config (old, partial, or empty) up to the current shape WITHOUT
// dropping keys we don't recognise — future-proofing against a newer panel
// having written fields this version doesn't know about yet.
function migrate(cfg) {
  if (!cfg || typeof cfg !== "object") {
    return { version: CURRENT_VERSION, defaults: {}, directories: {} };
  }
  // Place future version bumps here, e.g. if (cfg.version < 2) { ... }
  cfg.version = CURRENT_VERSION;
  cfg.defaults = cfg.defaults && typeof cfg.defaults === "object" ? cfg.defaults : {};
  cfg.directories = cfg.directories && typeof cfg.directories === "object" ? cfg.directories : {};
  return cfg;
}

function loadConfig() {
  return migrate(readRaw());
}

// Longest directory key that is `cwd` itself or a parent of it.
function bestDirKey(cfg, cwd) {
  let best = null;
  for (const key of Object.keys(cfg.directories || {})) {
    const parent = key.endsWith("/") ? key : key + "/";
    if (cwd === key || cwd.startsWith(parent)) {
      if (!best || key.length > best.length) best = key;
    }
  }
  return best;
}

// The resolved {segId: bool} map for a cwd.
function loadEffectiveConfig(cwd) {
  const cfg = loadConfig();
  const eff = { ...registryDefaults(), ...cfg.defaults };
  const dk = bestDirKey(cfg, cwd || "");
  if (dk) Object.assign(eff, cfg.directories[dk]);
  // Guard: only keep keys that are actual booleans.
  for (const k of Object.keys(eff)) if (typeof eff[k] !== "boolean") delete eff[k];
  return eff;
}

// Merge a partial override into scope ("defaults" or a directory path),
// preserving every other key/scope. Returns the saved config.
function applyOverride(scope, overrides) {
  const cfg = loadConfig();
  const clean = {};
  for (const [k, v] of Object.entries(overrides || {})) {
    if (typeof v === "boolean") clean[k] = v;
  }
  if (scope === "defaults") {
    cfg.defaults = { ...cfg.defaults, ...clean };
  } else {
    cfg.directories[scope] = { ...(cfg.directories[scope] || {}), ...clean };
  }
  saveConfig(cfg);
  return cfg;
}

// Drop a directory's overrides entirely (revert it to defaults/registry).
function clearDirectory(scope) {
  const cfg = loadConfig();
  if (scope === "defaults") cfg.defaults = {};
  else delete cfg.directories[scope];
  saveConfig(cfg);
  return cfg;
}

function saveConfig(cfg) {
  cfg.version = CURRENT_VERSION;
  fs.mkdirSync(path.dirname(CONFIG_PATH), { recursive: true });
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(cfg, null, 2) + "\n");
}

module.exports = {
  CONFIG_PATH,
  CURRENT_VERSION,
  registryDefaults,
  loadConfig,
  loadEffectiveConfig,
  bestDirKey,
  applyOverride,
  clearDirectory,
  saveConfig,
};
